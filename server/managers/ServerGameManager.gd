extends Node
"""
ServerGameManager - Server-authoritative game logic

Handles all server-side game management:
- Server startup orchestration
- Authoritative player spawning
- Server RPC handlers (can define RPCs directly as a Node)
- Server-authoritative game state control (IN_LOBBY, PLAYING, ENDING)
- Late join handling
"""

# Player scene path
const PLAYER_SCENE_PATH := "res://shared/game/player/Player.tscn"

# Server-authoritative game states
enum GameState { IN_LOBBY, PLAYING, ENDING }
var game_state: GameState = GameState.IN_LOBBY
var is_verbose: bool = false

signal game_state_changed(new_state: GameState)

# Track player spawn acknowledgments from clients (for late joiners)
# Format: {client_peer_id: {player_peer_id: true}}
var _player_spawn_acks: Dictionary = {}
var script_name: String = "ServerGameManager"

func _ready() -> void:
	name = "ServerGameManager"
	set_process_mode(Node.PROCESS_MODE_ALWAYS)  # Always process, even when paused
	_connect_signals()

# GameManager is accessed directly as an autoload singleton (no helper function needed)

func _connect_signals() -> void:
	"""Connect to Gnet and SceneManager signals for server-side handling."""
	# Connect to Gnet signals
	if Gnet:
		Gnet.peer_connected.connect(_on_gnet_peer_connected)
		Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)

	# Connect to SceneManager for scene ready
	if SceneManager:
		SceneManager.scene_ready.connect(_on_scene_ready)

func _on_gnet_connection_succeeded() -> void:
	"""Handle connection succeeded. Server loads world for itself and any connected clients."""
	if not multiplayer.is_server():
		return

	if is_verbose:
		Logger.info("Connection succeeded, loading GameWorld for server", [], script_name, "_on_gnet_connection_succeeded")
	# Load gameworld for server directly
	_load_gameworld_for_host()

	# Load gameworld for any already-connected clients
	var connected_peers = Gnet.get_connected_players() if Gnet else []
	for peer_id in connected_peers:
		if peer_id != 1:  # Skip server (peer_id 1)
			if is_verbose:
				Logger.info("Loading GameWorld for connected client {0}", [peer_id], script_name, "_on_gnet_connection_succeeded")
			_load_gameworld_for_peer.rpc_id(peer_id)

func _on_gnet_peer_connected(peer_id: int) -> void:
	"""Handle peer connection. Only acts if we're the server."""
	if not multiplayer.is_server():
		return

	if is_verbose:
		Logger.info("Peer connected: {0}, game_state: {1}", [peer_id, game_state], script_name, "_on_gnet_peer_connected")

	_load_gameworld_for_peer.rpc_id(peer_id)

func _on_gnet_spawn_requested(peer_id: int) -> void:
	"""Handle spawn request from Gnet. Only acts if we're the server."""
	if not multiplayer.is_server():
		return

	handle_spawn_request(peer_id)

func _on_scene_ready(scene_name: String) -> void:
	"""Handle scene ready. Server-only: spawns players and sets state."""
	if not multiplayer.is_server():
		return

	if scene_name == "GameWorld":
		# Server: spawn all players and set state to IN_LOBBY
		if is_verbose:
			Logger.info("GameWorld ready, setting state to IN_LOBBY and spawning all players", [], script_name, "_on_scene_ready")
		_set_game_state(GameState.IN_LOBBY)

		# Get all connected peers and prepare spawn data
		var connected_peers = Gnet.get_connected_players()
		if connected_peers.is_empty():
			connected_peers = [1]  # Spawn host if no peers in list yet

		if not SpawnManager:
			push_error("ServerGameManager: SpawnManager autoload not found!")
			return

		var players_data: Array = []
		for peer_id in connected_peers:
			var spawn_index = peer_id - 1  # peer_id 1 = index 0
			var spawn_position = SpawnManager.get_spawn_point(spawn_index)
			players_data.append({"peer_id": peer_id, "position": spawn_position})

		if is_verbose:
			Logger.info("players_data: {0}", [players_data], script_name, "_on_scene_ready")
		# Spawn all players and broadcast to all clients
		spawn_players(players_data, [], false)

## SERVER STATE MANAGEMENT ##

func _set_game_state(new_state: GameState) -> void:
	"""Set server-authoritative game state and broadcast to all clients."""
	if game_state == new_state:
		return

	game_state = new_state
	game_state_changed.emit(new_state)

	# Broadcast state change to all clients via RPC
	_sync_game_state.rpc(new_state)

	if is_verbose:
		Logger.info("Game state changed to: {0}", [GameState.keys()[new_state]], script_name, "_set_game_state")

func get_game_state() -> GameState:
	"""Get current server-authoritative game state."""
	return game_state

## SERVER STARTUP ##

func start_server(options: Dictionary = {}) -> bool:
	"""
	Start the server. Orchestrates server startup via Gnet.
	Returns true if server startup was initiated successfully.
	"""
	# Clean up any existing multiplayer connection first
	if multiplayer.has_multiplayer_peer():
		if is_verbose:
			Logger.info("Cleaning up existing multiplayer connection...", [], script_name, "start_server")
		Gnet.disconnect_game()

	if is_verbose:
		Logger.info("Starting server...", [], script_name, "start_server")
	return Gnet.host_game(options)

## PLAYER SPAWNING (AUTHORITATIVE) ##

func spawn_players(players: Array, target_peer_ids: Array = [], initialize_acks: bool = false) -> void:
	"""
	Unified function to spawn players on server and send RPCs to clients.

	Args:
		players: Array of dictionaries with 'peer_id' (int) and 'position' (Vector3)
		target_peer_ids: Array of peer IDs to send RPCs to. Empty array = broadcast to all clients.
		initialize_acks: If true, initialize acknowledgment tracking (for late join scenarios)

	Example:
		# Initial spawn - broadcast to all
		spawn_players([{peer_id: 1, position: Vector3(0, 0, 0)}], [], false)

		# Late join - send all existing players to new client
		spawn_players(all_players, [new_client_id], true)
	"""
	if not multiplayer.is_server():
		push_warning("ServerGameManager: spawn_players called on client")
		return

	if not multiplayer.has_multiplayer_peer():
		if is_verbose:
			Logger.warning("spawn_players - no multiplayer peer", [], script_name, "spawn_players")
		return

	if players.is_empty():
		if is_verbose:
			Logger.warning("spawn_players - no players to spawn", [], script_name, "spawn_players")
		return

	if is_verbose:
		Logger.info("spawn_players called with {0} players: {1}, targets: {2}", [players.size(), players, target_peer_ids], script_name, "spawn_players")

	# Initialize acknowledgment tracking if requested
	if initialize_acks and not target_peer_ids.is_empty():
		var client_peer_id = target_peer_ids[0]  # For late join, there's typically one target
		if not _player_spawn_acks.has(client_peer_id):
			_player_spawn_acks[client_peer_id] = {}
		_player_spawn_acks[client_peer_id].clear()

	for player_data in players:
		var peer_id = player_data.get("peer_id", 0)
		var position = player_data.get("position", Vector3.ZERO)

		if peer_id == 0:
			continue

		# Spawn on server first (authoritative)
		await _spawn_player_impl(peer_id, position)

	# Send batched RPC to clients (only if there are clients to send to)
	# Server already has players spawned, so we only need to notify clients
	var connected_clients = Gnet.get_connected_players() if Gnet else []

	if target_peer_ids.is_empty():
		# Broadcast to all clients (only if there are any)
		if not connected_clients.is_empty():
			var remaining_clients = connected_clients.filter(func(p): return p != 1)

			_spawn_players_rpc.rpc(remaining_clients)
			if is_verbose:
				Logger.info("Sent spawn RPC for {0} players to all clients", [remaining_clients.size()], script_name, "spawn_players")
		else:
			if is_verbose:
				Logger.info("No connected clients to send spawn RPC to (server-only)", [], script_name, "spawn_players")
	else:
		# Send to specific clients (only if they're actually connected)
		for target_peer_id in target_peer_ids:
			if connected_clients.has(target_peer_id) and target_peer_id != 1:
				_spawn_players_rpc.rpc_id(target_peer_id, players)
				if is_verbose:
					Logger.info("Sent spawn RPC for {0} players to client {1}", [players.size(), target_peer_id], script_name, "spawn_players")
			else:
				if target_peer_id != 1:
					if is_verbose:
						Logger.warning("Target client {0} is not connected, skipping spawn RPC", [target_peer_id], script_name, "spawn_players")

	# Wait for RPCs to be processed (only if initializing acks)
	if initialize_acks:
		await get_tree().process_frame
		await get_tree().process_frame

func _spawn_player_impl(peer_id: int, spawn_position: Vector3) -> void:
	"""
	Internal helper function to actually spawn a player node.
	Used by both server (directly) and clients (via RPC).
	"""
	# Check if player already exists
	var existing_player = _find_player(peer_id)
	if existing_player:
		if is_verbose:
			Logger.info("Player {0} already exists, updating position", [peer_id], script_name, "_spawn_player_impl")
		existing_player.global_position = spawn_position
		return

	# Load and instantiate player scene
	var player_scene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("ServerGameManager: Failed to load player scene: " + PLAYER_SCENE_PATH)
		return

	var player = player_scene.instantiate()
	if not player:
		push_error("ServerGameManager: Failed to instantiate player scene")
		return

	if is_verbose:
		Logger.info("Player instantiated: {0} for peer_id: {1}", [player.name, peer_id], script_name, "_spawn_player_impl")

	player.peer_id = peer_id

	# Give player a unique name based on peer_id for multiplayer path resolution
	player.name = "Player_%d" % peer_id

	var players_container = _get_players_container()
	if not players_container:
		push_error("ServerGameManager: PlayersContainer not found")
		return

	# Use force_readable_name=true for multiplayer replication
	players_container.add_child(player, true)

	# Wait for the player to be fully ready
	await get_tree().process_frame
	if not player.is_node_ready():
		await player.ready

	# Wait a frame for RollbackSynchronizer initialization
	await get_tree().process_frame

	# Set position AFTER RollbackSynchronizer is initialized to avoid visual jumps
	player.global_position = spawn_position

	if is_verbose:
		Logger.info("Spawned player {0} at {1}", [peer_id, spawn_position], script_name, "_spawn_player_impl")

func _find_player(peer_id: int) -> Node:
	"""Find existing player node for peer_id in PlayersContainer."""
	var players_container = _get_players_container()
	if not players_container:
		return null

	# Players are direct children named "Player_%d"
	return players_container.get_node_or_null("Player_%d" % peer_id)

func _get_players_container() -> Node:
	"""Gets the Players node from the Main scene."""
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("Players")
	return null


## SERVER RPC HANDLERS ##

@rpc("any_peer", "call_remote", "reliable")
func _notify_client_ready() -> void:
	"""
	RPC called by late-joining client to notify host that they're ready.
	Server spawns the new client's player on its own client.
	Server spawns the new client's player on existing peers.
	Server sends all existing players to the new late-joining client including its own player.
	"""
	if not multiplayer.is_server():
		return

	var client_peer_id = multiplayer.get_remote_sender_id()
	if is_verbose:
		Logger.info("Late-joining client {0} is ready", [client_peer_id], script_name, "_notify_client_ready")

	# Get position for new player
	var new_player_position: Vector3 = SpawnManager.get_spawn_point(0)

	# Spawn new player on server and on existing peers
	var new_player_data = [{"peer_id": client_peer_id, "position": new_player_position}]

	var all_connected = Gnet.get_connected_players()
	var existing_peers = all_connected.filter(func(p): return p != client_peer_id)

	if is_verbose:
		Logger.info("All connected players: {0}", [all_connected], script_name, "_notify_client_ready")
	if is_verbose:
		Logger.info("Spawning new player {0} to existing clients {1}", [new_player_data, existing_peers], script_name, "_notify_client_ready")
	spawn_players(new_player_data, existing_peers, false)

	# Send all existing players to the new late-joining client
	var players_container = _get_players_container()
	if not players_container:
		if is_verbose:
			Logger.warning("PlayersContainer not found for spawning players", [], script_name, "_notify_client_ready")
		return

	var existing_players = _find_all_players(players_container)
	var all_players_data: Array = []
	for player_data in existing_players:
		var player = player_data.player
		var player_peer_id = player_data.peer_id
		if player_peer_id != 0:
			var current_position = player.global_position
			all_players_data.append({"peer_id": player_peer_id, "position": current_position})

	if not all_players_data.is_empty():
		if is_verbose:
			Logger.info("Spawning existing players {0} to new client {1}", [all_players_data, client_peer_id], script_name, "_notify_client_ready")
		spawn_players(all_players_data, [client_peer_id], true)

func _find_all_players(players_container: Node) -> Array:
	"""
	Find all player nodes in PlayersContainer.
	Returns array of dictionaries with 'player' (CharacterBody3D) and 'peer_id'.
	"""
	var players = []

	# Players are direct children of PlayersContainer
	for child in players_container.get_children():
		var peer_id = child.peer_id
		if peer_id != 0:
			players.append({"player": child, "peer_id": peer_id})

	return players

@rpc("any_peer", "call_remote", "reliable")
func _player_spawned_ack(player_peer_id: int) -> void:
	"""RPC called by client to acknowledge that a player has been spawned."""
	if not multiplayer.is_server():
		return

	var client_peer_id = multiplayer.get_remote_sender_id()
	if not _player_spawn_acks.has(client_peer_id):
		_player_spawn_acks[client_peer_id] = {}

	_player_spawn_acks[client_peer_id][player_peer_id] = true
	if is_verbose:
		Logger.info("Client {0} acknowledged spawn of player {1}", [client_peer_id, player_peer_id], script_name, "_player_spawned_ack")

@rpc("authority", "call_remote", "reliable")
func _spawn_players_rpc(players_data: Array) -> void:
	"""
	RPC to spawn multiple players on clients.
	Used for both initial spawning and late-joining clients.
	Takes an array of dictionaries with 'peer_id' (int) and 'position' (Vector3).
	After spawning each player, sends acknowledgment to server.
	"""
	if multiplayer.is_server():
		return

	var my_id = multiplayer.get_unique_id()
	if is_verbose:
		Logger.info("Client (unique_id: {0}) received _spawn_players_rpc for {1} players :: {2}", [my_id, players_data.size(), players_data], script_name, "_spawn_players_rpc")

	# Spawn each player
	for player_data in players_data:
		var peer_id = player_data.get("peer_id", 0)
		var position = player_data.get("position", Vector3.ZERO)

		if peer_id == 0:
			continue

		if is_verbose:
			Logger.info("Spawning player {0} on client", [peer_id], script_name, "_spawn_players_rpc")
		if is_verbose:
			Logger.info("This client should {0} this player's input", ["control" if peer_id == my_id else "NOT control"], script_name, "_spawn_players_rpc")

		# Spawn the player and wait for it to complete
		await _spawn_player_impl(peer_id, position)

		# Wait a frame for initialization
		await get_tree().process_frame

		# Notify server that this player is ready
		_player_spawned_ack.rpc_id(1, peer_id)
		if is_verbose:
			Logger.info("Client notified server that player {0} is ready", [peer_id], script_name, "_spawn_players_rpc")

@rpc("authority", "call_local", "reliable")
func _start_game_for_all() -> void:
	"""RPC called by host to start the game (unlock doors, full gameplay)."""
	# Transition from IN_LOBBY (limited area) to PLAYING (full game)
	if game_state != GameState.IN_LOBBY:
		push_warning("ServerGameManager: Can only start game from IN_LOBBY state")
		return

	_set_game_state(GameState.PLAYING)

func _load_gameworld_for_host() -> void:
	"""Load GameWorld for the server (called directly, not via RPC)."""
	if not GameManager:
		return

	if not SceneManager:
		return

	if is_verbose:
		Logger.info("Loading GameWorld for server", [], script_name, "_load_gameworld_for_all")
	# Update server state to LOADING
	GameManager._set_state(GameManager.SessionState.LOADING)
	SceneManager.request_scene_change("GameWorld")

@rpc("authority", "call_remote", "reliable")
func _load_gameworld_for_peer() -> void:
	"""RPC called by host to load GameWorld for a late-joining client."""
	if is_verbose:
		Logger.info("_load_gameworld_for_peer RPC received on client", [], script_name, "_load_gameworld_for_peer")

	if not GameManager:
		push_error("ServerGameManager: GameManager not available on client")
		return

	if not SceneManager:
		push_error("ServerGameManager: SceneManager not available on client")
		return

	if is_verbose:
		Logger.info("Setting client state to LOADING and loading GameWorld", [], script_name, "_load_gameworld_for_peer")
	GameManager._set_state(GameManager.SessionState.LOADING)
	SceneManager.goto_scene("GameWorld")
	if is_verbose:
		Logger.info("Called SceneManager.goto_scene('GameWorld')", [], script_name, "_load_gameworld_for_peer")

@rpc("authority", "call_local", "reliable")
func _sync_game_state(server_state: int) -> void:
	"""RPC called by server to sync game state to clients."""
	if not GameManager:
		return

	# Map server GameState enum to GameManager SessionState enum
	# ServerGameManager.GameState: IN_LOBBY=0, PLAYING=1, ENDING=2
	# GameManager.SessionState: IN_LOBBY=3, PLAYING=5, ENDING=6
	match server_state:
		0:  # IN_LOBBY
			GameManager._set_state(GameManager.SessionState.IN_LOBBY)
		1:  # PLAYING
			GameManager._set_state(GameManager.SessionState.PLAYING)
		2:  # ENDING
			GameManager._set_state(GameManager.SessionState.ENDING)

## SERVER PEER CONNECTION HANDLING ##

func handle_peer_connected(peer_id: int, current_game_state: GameState) -> void:
	"""Handle peer connection. Called when a peer connects."""
	if not multiplayer.is_server():
		return

	if is_verbose:
		Logger.info("handle_peer_connected for peer_id: {0}, game_state: {1}", [peer_id, current_game_state], script_name, "handle_peer_connected")

	# If we're already in gameworld, load it for the new client
	if current_game_state == GameState.IN_LOBBY or current_game_state == GameState.PLAYING:
		# Trigger RPC to load world for this peer
		_load_gameworld_for_peer.rpc_id(peer_id)
		# Also sync the current game state to the late joiner
		_sync_game_state.rpc_id(peer_id, current_game_state)
		if is_verbose:
			Logger.info("Sent late-join RPCs to peer_id: {0}", [peer_id], script_name, "handle_peer_connected")

func handle_spawn_request(peer_id: int) -> void:
	"""Handle spawn request from Gnet. Called when Gnet requests spawning a late-joining player."""
	if not multiplayer.is_server():
		return

	if not SpawnManager:
		push_error("ServerGameManager: SpawnManager autoload not found!")
		return

	var spawn_index = peer_id - 1  # peer_id 1 = index 0
	var spawn_position = SpawnManager.get_spawn_point(spawn_index)
	var players_data = [{"peer_id": peer_id, "position": spawn_position}]
	spawn_players(players_data, [], false)

## GAME LAUNCH CONTROL ##

func launch_game() -> void:
	"""
	Host launches the game for all connected players (opens doors, unlocks full game).
	Only the host/server can call this.
	Players are already in GameWorld in limited area, this unlocks the full game.
	"""
	if not multiplayer.has_multiplayer_peer():
		push_warning("ServerGameManager: Cannot launch - no active connection")
		return

	if not multiplayer.is_server():
		push_warning("ServerGameManager: Only host can launch game")
		return

	if game_state != GameState.IN_LOBBY:
		push_warning("ServerGameManager: Can only launch from IN_LOBBY state")
		return

	# Unlock game for all clients via RPC (no scene change needed)
	_start_game_for_all.rpc()
