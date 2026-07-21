extends Node
"""
ServerManager - Server-authoritative game logic

Handles all server-side game management:
- Server startup orchestration
- Server RPC handlers (can define RPCs directly as a Node)
- Server-authoritative game state control (IN_LOBBY, PLAYING, ENDING)
"""

signal game_state_changed(new_state: Game.GameState)
const IS_VERBOSE: bool = false

var script_name: String = "ServerManager"
var player_spawner: PlayerSpawner
var server_relay: ServerRelay
var message_router: MessageRouter

# do this on launch
var game: Game = Game.new(temp, temp)

func temp() -> void:
	pass

# TODO: ONLY INITIALIZE AND LOAD THE SERVER MANAGER WHEN GAME STARTS

# INIT
#===================================================================================#
func _ready() -> void:
	name = "ServerManager"
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	_create_children()
	_connect_signals()

func _create_children() -> void:
	_create_player_spawner()
	_create_server_relay()
	_create_message_router()

func _create_player_spawner() -> void:
	player_spawner = PlayerSpawner.new()
	player_spawner.name = "PlayerSpawner"
	add_child(player_spawner)

func _create_server_relay() -> void:
	server_relay = ServerRelay.new()
	server_relay.name = "ServerRelay"
	add_child(server_relay)

func _create_message_router() -> void:
	message_router = MessageRouter.new()
	message_router.name = "MessageRouter"
	message_router.setup(server_relay)
	add_child(message_router)

func _connect_signals() -> void:
	"""Connect to Gnet and SceneManager signals for server-side handling."""
	if Gnet:
		Gnet.peer_connected.connect(_on_gnet_peer_connected)
		Gnet.peer_disconnected.connect(_on_gnet_peer_disconnected)
		Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)

# TODO: EXCLUDE ALL CLIENTS EXCEPT THE SERVER FROM THIS FUNCTION VIA 'set_process()'
func _process(_delta: float) -> void:
	if not _is_active_server():
		return
	message_router.process()
#===================================================================================#

# HELPERS
#===================================================================================#
func _is_active_server() -> bool:
	return Gnet.is_authority()

@rpc("any_peer", "call_remote", "reliable")
func handle_client_message(packed: Dictionary) -> void:
	"""Public wrapper for ServerRelay._handle_client_message"""
	if server_relay == null:
		SweetLogger.error("ServerRelay not found", [], script_name, "handle_client_message")
		return
	server_relay._handle_client_message(packed)
#===================================================================================#

# GETTERS 
#===================================================================================#
func get_server_relay() -> ServerRelay:
	if server_relay == null:
		SweetLogger.error("ServerManager: ServerRelay not found", [], script_name, "get_server_relay")
		return null
	return server_relay

func get_message_router() -> MessageRouter:
	if message_router == null:
		SweetLogger.error("ServerManager: MessageRouter not found", [], script_name, "get_message_router")
		return null
	return message_router
#===================================================================================#

# GNET SIGNALS
#===================================================================================#
func _on_gnet_connection_succeeded() -> void:
	"""Handle connection succeeded. Server loads world for itself and any connected clients."""
	if IS_VERBOSE:
		SweetLogger.info("Connection succeeded, loading GameWorld for server", [], script_name, "_on_gnet_connection_succeeded")

	_load_game_world()

func _on_gnet_peer_connected(peer_id: int) -> void:
	"""Handle peer connection. Only acts if we're the server."""
	if IS_VERBOSE:
		SweetLogger.info("Peer connected: {0}, game_state: {1}", [peer_id, game.state], script_name, "_on_gnet_peer_connected")
	
	_load_game_world([peer_id])

func _on_gnet_peer_disconnected(peer_id: int) -> void:
	"""Host: a remote peer left — remove their character locally and tell other clients to do the same."""
	if not _is_active_server():
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if IS_VERBOSE:
		SweetLogger.info("Peer disconnected: {0}, despawning their player", [peer_id], script_name, "_on_gnet_peer_disconnected")
	
	message_router.notify(
		CommandRegistry.Command.DESPAWN,
		Payload.Despawn.create([{"entity_type": EntityTypeRegistry.EntityType.PLAYER, "data": {"peer_id": peer_id}}]),
		Delivery.Audience.ALL,
	)
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

func _load_game_world(peer_ids: PackedInt32Array = []) -> void:
	if not _is_active_server():
		return
	
	var audience := Delivery.Audience.ALL if peer_ids.is_empty() else Delivery.Audience.TARGETED

	message_router.notify(
		CommandRegistry.Command.SCENE_CHANGE,
		Payload.SceneChange.create("GameWorld"),
		audience,
		peer_ids,
	)
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
# NOT CURRENTLY USED
@rpc("authority", "call_local", "reliable")
func _start_game_for_all() -> void:
	"""RPC called by host to start the game."""
	# Transition from IN_LOBBY (limited area) to PLAYING (full game)
	if game.get_state() != Game.GameState.IDLE:
		push_warning("ServerManager: Can only start game from IN_LOBBY state")
		return

	game.start()

@rpc("authority", "call_local", "reliable")
func _sync_game_state(server_state: int) -> void:
	"""RPC called by server to sync game state to clients."""
	game_state_changed.emit(server_state)
#===================================================================================#

# GAME LAUNCH CONTROL
#===================================================================================#
# NOT CURRENTLY USED
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
