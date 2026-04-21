extends Node
"""
ServerManager - Server-authoritative game logic

Handles all server-side game management:
- Server startup orchestration
- Server RPC handlers (can define RPCs directly as a Node)
- Server-authoritative game state control (IN_LOBBY, PLAYING, ENDING)
"""

signal game_state_changed(new_state: Game.GameState)
signal remote_peer_left_session(peer_id: int)
const IS_VERBOSE: bool = false

var script_name: String = "ServerManager"
var player_spawner: PlayerSpawner
# do this on launch
var game: Game = Game.new(temp, temp)

func temp() -> void:
	pass

# INIT
#===================================================================================#
func _ready() -> void:
	name = "ServerManager"
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	player_spawner = PlayerSpawner.new()
	player_spawner.name = "PlayerSpawner"
	add_child(player_spawner)
	_connect_signals()

func _connect_signals() -> void:
	"""Connect to Gnet and SceneManager signals for server-side handling."""
	if Gnet:
		Gnet.peer_connected.connect(_on_gnet_peer_connected)
		Gnet.peer_disconnected.connect(_on_gnet_peer_disconnected)
		Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)

	if SceneManager:
		SceneManager.scene_ready.connect(_on_scene_ready)
#===================================================================================#

func _is_active_server() -> bool:
	"""True when we have a peer and are the server. Must be used before multiplayer.is_server()."""
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

# GNET SIGNALS
#===================================================================================#
func _on_gnet_connection_succeeded() -> void:
	"""Handle connection succeeded. Server loads world for itself and any connected clients."""
	if not _is_active_server():
		return

	if IS_VERBOSE:
		SweetLogger.info("Connection succeeded, loading GameWorld for server", [], script_name, "_on_gnet_connection_succeeded")

	_load_gameworld_for_host()

	# Load gameworld for any already-connected clients
	var connected_peers = Gnet.get_connected_players() if Gnet else []
	for peer_id in connected_peers:
		if peer_id != 1:  # Skip server (peer_id 1)
			if IS_VERBOSE:
				SweetLogger.info("Loading GameWorld for connected client {0}", [peer_id], script_name, "_on_gnet_connection_succeeded")
			_load_gameworld_for_peer.rpc_id(peer_id)

func _on_gnet_peer_connected(peer_id: int) -> void:
	"""Handle peer connection. Only acts if we're the server."""
	if not _is_active_server():
		return

	if IS_VERBOSE:
		SweetLogger.info("Peer connected: {0}, game_state: {1}", [peer_id, game.state], script_name, "_on_gnet_peer_connected")
	
	_load_gameworld_for_peer.rpc_id(peer_id)

func _on_gnet_peer_disconnected(peer_id: int) -> void:
	"""Host: a remote peer left — remove their character locally and tell other clients to do the same."""
	if not _is_active_server():
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if IS_VERBOSE:
		SweetLogger.info("Peer disconnected: {0}, despawning their player", [peer_id], script_name, "_on_gnet_peer_disconnected")

	if PlayerUtils:
		PlayerUtils.despawn_player(peer_id)
	_despawn_remote_player.rpc(peer_id)
	remote_peer_left_session.emit(peer_id)

func _on_gnet_spawn_requested(peer_id: int) -> void:
	"""Handle spawn request from Gnet. Only acts if we're the server."""
	if not _is_active_server():
		return

	handle_spawn_request(peer_id)
#===================================================================================#

# SCENE MANAGER SIGNALS
#===================================================================================#
func _on_scene_ready(scene_name: String) -> void:
	"""Handle scene ready. Server-only: spawns players and sets state."""
	if not _is_active_server():
		return

	if scene_name == "GameWorld":
		# Server: spawn all players and set state to IN_LOBBY
		if IS_VERBOSE:
			SweetLogger.info("GameWorld ready, setting state to IN_LOBBY and spawning all players", [], script_name, "_on_scene_ready")
		
		var new_state = Game.GameState.RUNNING
		game.set_state(new_state)
		game_state_changed.emit(new_state)

		# Get all connected peers and prepare spawn data
		var connected_peers = Gnet.get_connected_players()
		if connected_peers.is_empty():
			connected_peers = [1]  # Spawn host if no peers in list yet

		if not SpawnManager:
			push_error("ServerManager: SpawnManager autoload not found!")
			return

		var players_data: Array = []
		for peer_id in connected_peers:
			var spawn_index = peer_id - 1  # peer_id 1 = index 0
			var spawn_position = SpawnManager.get_spawn_point(spawn_index)
			players_data.append({"peer_id": peer_id, "position": spawn_position})

		if IS_VERBOSE:
			SweetLogger.info("players_data: {0}", [players_data], script_name, "_on_scene_ready")
		player_spawner.spawn_players(players_data, [])

func _load_gameworld_for_host() -> void:
	"""Load GameWorld for the server (called directly, not via RPC)."""
	if not ClientManager:
		return

	if not SceneManager:
		return

	if IS_VERBOSE:
		SweetLogger.info("Loading GameWorld for server", [], script_name, "_load_gameworld_for_all")
	# Update server state to LOADING
	ClientManager.set_session_state(ClientSession.SessionState.LOADING)
	SceneManager.request_scene_change("GameWorld")
#===================================================================================#

# SERVER STATE MANAGEMENT
#===================================================================================#
func _set_game_state(new_state: Game.GameState) -> void:
	"""Set server-authoritative game state and broadcast to all clients."""
	if game.get_state() == new_state:
		return

	game.set_state(new_state)

	# Broadcast state change to all clients via RPC
	_sync_game_state.rpc(new_state)

	if IS_VERBOSE:
		SweetLogger.info("Game state changed to: {0}", [Game.GameState.keys()[new_state]], script_name, "_set_game_state")

func get_game_state() -> Game.GameState:
	"""Get current server-authoritative game state."""
	return game.get_state()
#===================================================================================#

# SERVER STARTUP
#===================================================================================#
func start_server(options: Dictionary = {}) -> bool:
	"""
	Start the server. Orchestrates server startup via Gnet.
	Returns true if server startup was initiated successfully.
	"""
	if multiplayer.has_multiplayer_peer():
		if IS_VERBOSE:
			SweetLogger.info("Cleaning up existing multiplayer connection...", [], script_name, "start_server")
		Gnet.disconnect_game()

	if IS_VERBOSE:
		SweetLogger.info("Starting server...", [], script_name, "start_server")
	game.set_state(Game.GameState.RUNNING)
	game_state_changed.emit(game.get_state())
	return Gnet.host_game(options)
#===================================================================================#

# HOST SHUTDOWN
#===================================================================================#
func stop_host_session() -> void:
	"""Reset server game state when the host leaves the session. Call before Gnet.disconnect_game()."""
	if not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server():
		return
	if game.get_state() == Game.GameState.IDLE:
		return
	game.set_state(Game.GameState.IDLE)
	game_state_changed.emit(game.get_state())
#===================================================================================#

# SERVER RPC HANDLERS
#===================================================================================#
@rpc("any_peer", "call_remote", "reliable")
func _notify_client_ready() -> void:
	"""RPC called by late-joining client to notify host that they're ready."""
	if not _is_active_server():
		return
	var client_peer_id = multiplayer.get_remote_sender_id()
	if IS_VERBOSE:
		SweetLogger.info("Late-joining client {0} is ready", [client_peer_id], script_name, "_notify_client_ready")
	await player_spawner.spawn_late_joiner(client_peer_id)

@rpc("authority", "call_local", "reliable")
func _start_game_for_all() -> void:
	"""RPC called by host to start the game."""
	# Transition from IN_LOBBY (limited area) to PLAYING (full game)
	if game.get_state() != Game.GameState.IDLE:
		push_warning("ServerManager: Can only start game from IN_LOBBY state")
		return

	game.start()

@rpc("authority", "call_remote", "reliable")
func _despawn_remote_player(peer_id: int) -> void:
	"""Remove the disconnected peer's puppet on each remaining client."""
	if multiplayer.is_server():
		return
	if PlayerUtils:
		PlayerUtils.despawn_player(peer_id)

@rpc("authority", "call_remote", "reliable")
func _load_gameworld_for_peer() -> void:
	"""RPC called by host to load GameWorld for a late-joining client."""
	if IS_VERBOSE:
		SweetLogger.info("_load_gameworld_for_peer RPC received on client", [], script_name, "_load_gameworld_for_peer")

	if not ClientManager:
		push_error("ServerManager: ClientManager not available on client")
		return

	if not SceneManager:
		push_error("ServerManager: SceneManager not available on client")
		return

	if IS_VERBOSE:
		SweetLogger.info("Setting client state to LOADING and loading GameWorld", [], script_name, "_load_gameworld_for_peer")
	ClientManager.set_session_state(ClientSession.SessionState.LOADING)
	SceneManager.goto_scene("GameWorld")
	if IS_VERBOSE:
		SweetLogger.info("Called SceneManager.goto_scene('GameWorld')", [], script_name, "_load_gameworld_for_peer")

@rpc("authority", "call_local", "reliable")
func _sync_game_state(server_state: int) -> void:
	"""RPC called by server to sync game state to clients."""
	game_state_changed.emit(server_state)
#===================================================================================#

# SERVER PEER CONNECTION HANDLING
#===================================================================================#
func handle_spawn_request(peer_id: int) -> void:
	"""Handle spawn request from Gnet. Called when Gnet requests spawning a late-joining player."""
	if not _is_active_server():
		return

	if not SpawnManager:
		push_error("ServerManager: SpawnManager autoload not found!")
		return

	var spawn_index = peer_id - 1  # peer_id 1 = index 0
	var spawn_position = SpawnManager.get_spawn_point(spawn_index)
	var players_data = [{"peer_id": peer_id, "position": spawn_position}]
	player_spawner.spawn_players(players_data, [])
#===================================================================================#

# GAME LAUNCH CONTROL
#===================================================================================#
func launch_game() -> void:
	"""
	Host launches the game for all connected players (opens doors, unlocks full game).
	Only the host/server can call this.
	Players are already in GameWorld in limited area, this unlocks the full game.
	"""
	if not multiplayer.has_multiplayer_peer():
		push_warning("ServerManager: Cannot launch - no active connection")
		return

	if not multiplayer.is_server():
		push_warning("ServerManager: Only host can launch game")
		return

	if game.get_state() != Game.GameState.IDLE:
		push_warning("ServerManager: Can only launch from IN_LOBBY state")
		return

	# Unlock game for all clients via RPC (no scene change needed)
	_start_game_for_all.rpc()
#===================================================================================#
