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

signal game_state_changed(new_state: GameState)

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
		Gnet.spawn_requested.connect(_on_gnet_spawn_requested)
		Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)

	# Connect to SceneManager for scene ready
	if SceneManager:
		SceneManager.scene_ready.connect(_on_scene_ready)

func _on_gnet_connection_succeeded() -> void:
	"""Handle connection succeeded. Server loads world for all."""
	if not multiplayer.is_server():
		return

	Logger.info("ServerGameManager: Connection succeeded, loading GameWorld for all")
	# Trigger RPC to load world for all
	_load_gameworld_for_all.rpc()

func _on_gnet_peer_connected(peer_id: int) -> void:
	"""Handle peer connection. Only acts if we're the server."""
	if not multiplayer.is_server():
		return

	Logger.info("ServerGameManager: Peer connected: {0}, game_state: {1}", [peer_id, game_state])
	handle_peer_connected(peer_id, game_state)

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
		Logger.info("ServerGameManager: GameWorld ready, setting state to IN_LOBBY and spawning all players")
		_set_game_state(GameState.IN_LOBBY)
		spawn_all_players()

## SERVER STATE MANAGEMENT ##

func _set_game_state(new_state: GameState) -> void:
	"""Set server-authoritative game state and broadcast to all clients."""
	if game_state == new_state:
		return

	game_state = new_state
	game_state_changed.emit(new_state)

	# Broadcast state change to all clients via RPC
	_sync_game_state.rpc(new_state)

	Logger.info("ServerGameManager: Game state changed to: {0}", [GameState.keys()[new_state]])

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
		Logger.info("ServerGameManager: Cleaning up existing multiplayer connection...")
		Gnet.disconnect_game()

	Logger.info("ServerGameManager: Starting server...")
	return Gnet.host_game(options)

## PLAYER SPAWNING (AUTHORITATIVE) ##

func spawn_all_players() -> void:
	"""Spawn all connected players in the current scene. Server-only."""
	if not multiplayer.is_server():
		push_warning("ServerGameManager: spawn_all_players called on client")
		return

	if not multiplayer.has_multiplayer_peer():
		Logger.warning("ServerGameManager: spawn_all_players - no multiplayer peer")
		return

	var connected_peers = Gnet.get_connected_players()
	Logger.info("ServerGameManager: spawn_all_players - connected peers: {0}", [connected_peers])

	if connected_peers.is_empty():
		Logger.info("ServerGameManager: spawn_all_players - no connected peers, spawning host manually")
		# If no peers in list yet, spawn host (peer_id 1) manually
		spawn_player(1)
		return

	for peer_id in connected_peers:
		Logger.info("ServerGameManager: spawn_all_players - spawning peer_id: {0}", [peer_id])
		spawn_player(peer_id)

func spawn_player(peer_id: int) -> void:
	"""
	Spawn a player for the given peer_id. Server-authoritative.
	Finds SpawnManager in current scene and uses spawn points.
	On server: spawns player and sends RPC to all clients.
	"""
	if not multiplayer.is_server():
		push_warning("ServerGameManager: spawn_player called on client")
		return

	Logger.info("ServerGameManager: spawn_player called for peer_id: {0}", [peer_id])

	if not multiplayer.has_multiplayer_peer():
		push_warning("ServerGameManager: Cannot spawn - no active connection")
		return

	# Check if player already exists
	if _find_player(peer_id):
		Logger.info("ServerGameManager: Player {0} already spawned, skipping", [peer_id])
		return

	# Use SpawnManager autoload to get spawn position
	if not SpawnManager:
		push_error("ServerGameManager: SpawnManager autoload not found!")
		return

	# Get spawn point for this peer (use peer_id as index)
	var spawn_index = peer_id - 1  # peer_id 1 = index 0
	var spawn_position = SpawnManager.get_spawn_point(spawn_index)
	Logger.info("ServerGameManager: Spawn position: {0}", [spawn_position])

	# Spawn on server first (authoritative)
	_spawn_player_impl(peer_id, spawn_position)

	# Then send RPC to all clients to spawn this player
	# This ensures all clients (including late-joiners) receive the player reliably
	_spawn_player_rpc.rpc(peer_id, spawn_position)
	Logger.info("ServerGameManager: Sent spawn RPC for player {0} to all clients", [peer_id])

func _spawn_player_impl(peer_id: int, spawn_position: Vector3) -> void:
	"""
	Internal helper function to actually spawn a player node.
	Used by both server (directly) and clients (via RPC).
	"""
	# Check if player already exists
	var existing_player = _find_player(peer_id)
	if existing_player:
		Logger.info("ServerGameManager: Player {0} already exists, updating position", [peer_id])
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

	Logger.info("ServerGameManager: Player instantiated: {0} for peer_id: {1}", [player.name, peer_id])

	player.peer_id = peer_id

	# Find scene root
	var scene_root = get_tree().current_scene
	if not scene_root:
		# Try to find GameWorld by name in root's children
		for child in get_tree().root.get_children():
			if child.name == "GameWorld":
				scene_root = child
				break

	if not scene_root:
		push_error("ServerGameManager: No scene root found")
		return

	# Add to scene tree
	scene_root.add_child(player, true)  # Use force_readable_name=true for multiplayer replication

	player.global_position = spawn_position

	if not multiplayer.is_server():
		# We're on a client - check if this is our player
		var my_id = multiplayer.get_unique_id()
		if peer_id == my_id:
			var camera = player.get_node_or_null("PlayerCamera")
			if camera:
				camera.current = true
				Logger.info("ServerGameManager: Set camera as current for local player (peer_id: {0})", [peer_id])
			else:
				push_warning("ServerGameManager: PlayerCamera not found for local player")

	Logger.info("ServerGameManager: Spawned player {0} at {1}", [peer_id, spawn_position])

func _find_player(peer_id: int) -> Node:
	"""Find existing player node for peer_id in current scene."""
	var scene_root = get_tree().current_scene

	# If current_scene is null, try to find GameWorld in the scene tree
	if not scene_root:
		# Try to find GameWorld by name in root's children
		for child in get_tree().root.get_children():
			if child.name == "GameWorld":
				scene_root = child
				break
		if not scene_root:
			return null

	# Recursively search for player nodes
	return _find_player_recursive(scene_root, peer_id)

func _find_player_recursive(node: Node, peer_id: int) -> Node:
	"""
	Recursively search for player node by finding Input node with matching peer_id.
	According to netfox CSP guide: Input node has authority of peer_id, player node has server authority.
	"""
	# Check if this node is an Input node with matching authority
	# If so, return its parent (the player CharacterBody3D)
	if node.name == "Input" and node.get_multiplayer_authority() == peer_id:
		var parent = node.get_parent()
		if parent and (parent.has_method("setNameplate") or parent is CharacterBody3D):
			return parent

	# Search children
	for child in node.get_children():
		var result = _find_player_recursive(child, peer_id)
		if result:
			return result

	return null


## SERVER RPC HANDLERS ##

@rpc("any_peer", "call_remote", "reliable")
func _notify_client_ready() -> void:
	"""
	RPC called by late-joining client to notify host that they're ready.
	Server spawns the new client's player and sends RPCs for all players.
	"""
	if not multiplayer.is_server():
		return

	var client_peer_id = multiplayer.get_remote_sender_id()
	Logger.info("ServerGameManager: Late-joining client {0} is ready", [client_peer_id])

	# Wait a frame to ensure the client's scene is fully loaded
	await get_tree().process_frame

	# Spawn the new client's player on the server first (if not already spawned)
	# This ensures the player exists before we send RPCs
	# We use _spawn_player_impl directly instead of spawn_player to avoid broadcasting
	# to all clients - spawn_all_players_for_client will handle sending RPCs to the late joiner
	if not _find_player(client_peer_id):
		# Use SpawnManager autoload to get spawn position
		if not SpawnManager:
			push_error("ServerGameManager: SpawnManager autoload not found!")
			return

		# Get spawn point for this peer (use peer_id as index)
		var spawn_index = client_peer_id - 1  # peer_id 1 = index 0
		var spawn_position = SpawnManager.get_spawn_point(spawn_index)
		Logger.info("ServerGameManager: Spawning late-joining player {0} at position {1}", [client_peer_id, spawn_position])

		# Spawn on server only (no broadcast - spawn_all_players_for_client will handle RPCs)
		_spawn_player_impl(client_peer_id, spawn_position)
	else:
		Logger.info("ServerGameManager: Player {0} already exists on server", [client_peer_id])

	# Wait another frame to ensure the player is fully spawned on server
	await get_tree().process_frame

	# Send RPCs to spawn all players (including the new client's own player) for this client
	# This uses RPCs exclusively - no reliance on automatic replication
	spawn_all_players_for_client(client_peer_id)

func spawn_all_players_for_client(client_peer_id: int) -> void:
	"""
	Spawn all existing players (including the new client's own player) for a late-joining client.
	Server-only. Uses RPCs to ensure reliable spawning.
	"""
	if not multiplayer.is_server():
		return

	Logger.info("ServerGameManager: Spawning all players for late-joining client: {0}", [client_peer_id])

	# Find all existing player nodes in the scene
	var scene_root = get_tree().current_scene
	if not scene_root:
		# Try to find GameWorld in the scene tree
		for child in get_tree().root.get_children():
			if child.name == "GameWorld":
				scene_root = child
				break

	if not scene_root:
		Logger.warning("ServerGameManager: No scene root found for spawning players")
		return

	# Find all player nodes and spawn them for the new client via RPC
	var existing_players = _find_all_players(scene_root)
	Logger.info("ServerGameManager: Found {0} existing players to replicate", [existing_players.size()])

	for player_data in existing_players:
		var player = player_data.player
		var player_peer_id = player_data.peer_id
		if player_peer_id != 0:
			# Spawn this player for the late-joining client via RPC
			# This includes the new client's own player if it was already spawned on server
			Logger.info("ServerGameManager: Sending spawn RPC for player {0} to client {1} at position {2}", [player_peer_id, client_peer_id, player.global_position])
			_spawn_player_rpc.rpc_id(client_peer_id, player_peer_id, player.global_position)

func _find_all_players(node: Node) -> Array:
	"""
	Recursively find all player nodes in the scene.
	Returns array of dictionaries with 'player' (CharacterBody3D) and 'peer_id' (from Input node).
	"""
	var players = []

	# Check if this node is an Input node (which has the peer_id authority)
	if node.name == "Input":
		var peer_id = node.get_multiplayer_authority()
		if peer_id != 0:
			var parent = node.get_parent()
			if parent and (parent.has_method("setNameplate") or parent is CharacterBody3D):
				players.append({"player": parent, "peer_id": peer_id})

	# Search children
	for child in node.get_children():
		players.append_array(_find_all_players(child))

	return players

@rpc("authority", "call_remote", "reliable")
func _spawn_player_rpc(peer_id: int, position: Vector3) -> void:
	"""
	RPC to spawn a player on clients.
	Used for both initial spawning and late-joining clients.
	Delegates to the shared implementation function.
	"""
	if multiplayer.is_server():
		return

	var my_id = multiplayer.get_unique_id()
	Logger.info("ServerGameManager: Client (unique_id: {0}) received _spawn_player_rpc for peer_id: {1}", [my_id, peer_id])
	Logger.info("ServerGameManager: This client should {0} this player's input", ["control" if peer_id == my_id else "NOT control"])
	_spawn_player_impl(peer_id, position)

@rpc("authority", "call_local", "reliable")
func _start_game_for_all() -> void:
	"""RPC called by host to start the game (unlock doors, full gameplay)."""
	# Transition from IN_LOBBY (limited area) to PLAYING (full game)
	if game_state != GameState.IN_LOBBY:
		push_warning("ServerGameManager: Can only start game from IN_LOBBY state")
		return

	_set_game_state(GameState.PLAYING)

@rpc("authority", "call_local", "reliable")
func _load_gameworld_for_all() -> void:
	"""RPC called when connection succeeds - loads GameWorld for all players."""
	if not GameManager:
		return

	# Update client state to LOADING
	GameManager._set_state(GameManager.SessionState.LOADING)
	SceneManager.request_scene_change("GameWorld")

@rpc("authority", "call_remote", "reliable")
func _load_gameworld_for_peer() -> void:
	"""RPC called by host to load GameWorld for a late-joining client."""
	Logger.info("ServerGameManager: _load_gameworld_for_peer RPC received on client")

	if not GameManager:
		push_error("ServerGameManager: GameManager not available on client")
		return

	if not SceneManager:
		push_error("ServerGameManager: SceneManager not available on client")
		return

	Logger.info("ServerGameManager: Setting client state to LOADING and loading GameWorld")
	GameManager._set_state(GameManager.SessionState.LOADING)
	# Client should call goto_scene directly, not request_scene_change
	SceneManager.goto_scene("GameWorld")
	Logger.info("ServerGameManager: Called SceneManager.goto_scene('GameWorld')")

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

	Logger.info("ServerGameManager: handle_peer_connected for peer_id: {0}, game_state: {1}", [peer_id, current_game_state])

	# If we're already in gameworld, load it for the new client
	if current_game_state == GameState.IN_LOBBY or current_game_state == GameState.PLAYING:
		Logger.info("ServerGameManager: Host detected late-joining peer, loading GameWorld for peer_id: {0}", [peer_id])
		# Wait a frame to ensure the client is fully connected before sending RPCs
		await get_tree().process_frame
		# Trigger RPC to load world for this peer
		_load_gameworld_for_peer.rpc_id(peer_id)
		# Also sync the current game state to the late joiner
		_sync_game_state.rpc_id(peer_id, current_game_state)
		Logger.info("ServerGameManager: Sent late-join RPCs to peer_id: {0}", [peer_id])

func handle_spawn_request(peer_id: int) -> void:
	"""Handle spawn request from Gnet. Called when Gnet requests spawning a late-joining player."""
	if not multiplayer.is_server():
		return

	spawn_player(peer_id)

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
