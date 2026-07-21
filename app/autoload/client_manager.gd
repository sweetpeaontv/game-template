extends Node
"""
ClientManager - Client-side game state management

Manages client connection state (MAIN_MENU, IDLE, CONNECTING, LOADING)
and receives server-authoritative game state updates (IN_LOBBY, PLAYING, ENDING)
from ServerManager for UI display.
"""

const SCRIPT_NAME: String = "ClientManager"
const IS_VERBOSE: bool = false

var session: ClientSession = ClientSession.new()
var client_relay: ClientRelay
var game_scene_name: String = "GameWorld"

# INIT
#===================================================================================#
func _ready() -> void:
	_create_client_relay()
	
	if ServerManager:
		ServerManager.game_state_changed.connect(_on_server_game_state_changed)

	Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)
	Gnet.connection_failed.connect(_on_gnet_connection_failed)

	SceneManager.scene_ready.connect(_on_scene_ready)

func _create_client_relay() -> void:
	client_relay = ClientRelay.new()
	client_relay.name = "ClientRelay"
	add_child(client_relay)
#===================================================================================#

# PUBLIC API
#===================================================================================#
func get_session_state() -> ClientSession.SessionState:
	return session.get_state()

func set_session_state(new_state: ClientSession.SessionState) -> void:
	session.set_state(new_state)

func start_game() -> void:
	"""Start hosting a game. Delegates to ServerManager."""
	if ServerManager:
		ServerManager.start_server()
	else:
		SweetLogger.warning("ServerManager not initialized", [], SCRIPT_NAME, "start_game")

func join_game() -> void:
	# if using steam, lobby id int is the arg
	# if using enet, "ip:port" string is the arg
	Gnet.join_game("127.0.0.1:7777")

# not currently used - would be used if there was a lobby stage before starting the game
# for example: the airport lobby in Peak
func launch_game() -> void:
	"""
	Host launches the game for all connected players.
	Delegates to ServerManager.
	"""
	if ServerManager:
		ServerManager.launch_game()
	else:
		SweetLogger.warning("ServerManager not initialized", [], SCRIPT_NAME, "launch_game")

func _cleanup_local_session() -> void:
	"""Clear persistent gameplay nodes and overlays when leaving a multiplayer session."""
	PlayerUtils.despawn_all_players()
	UIManager.hide_container(UIManager.UIContainer.HUD)
	UIManager.hide_container(UIManager.UIContainer.OVERLAY)
	SceneManager.call_deferred("goto_scene", "MenuWorld")
	UIManager.show_ui("MainMenu")
	InputModeManager.set_input_mode(Input.MOUSE_MODE_VISIBLE)

func disconnect_game() -> void:
	if NetworkTime:
		# Stop netfox before clearing the peer, or NetworkTimeSynchronizer._loop keeps running and errors.
		NetworkTime.stop()
	
	if Gnet.is_authority():
		# send session end command to all clients
		client_relay.make_request(
			CommandRegistry.Command.SESSION_END,
			Payload.SessionEnd.create(),
		)
		ServerManager.stop_host_session()
	
	_cleanup_local_session()
	session.set_state(ClientSession.SessionState.MAIN_MENU)
	Gnet.disconnect_game()
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_gnet_connection_succeeded() -> void:
	"""Called when connection to game succeeds. Handles client-side state."""
	if IS_VERBOSE:
		SweetLogger.info("_on_gnet_connection_succeeded called, is_server: {0}", [multiplayer.is_server()], SCRIPT_NAME, "_on_gnet_connection_succeeded")
	# ServerManager handles server-side connection logic
	# Client: wait for host to send RPC
	if not multiplayer.is_server():
		if IS_VERBOSE:
			SweetLogger.info("Client detected, waiting for host RPC", [], SCRIPT_NAME, "_on_gnet_connection_succeeded")
		session.set_state(ClientSession.SessionState.LOADING)

func _on_gnet_connection_failed(_reason: String) -> void:
	"""Called when connection fails or the host disconnects (clients lose the server)."""
	SweetLogger.info("Connection failed, disconnecting game", [], SCRIPT_NAME, "_on_gnet_connection_failed")
	if NetworkTime:
		NetworkTime.stop()
	_cleanup_local_session()
	session.set_state(ClientSession.SessionState.MAIN_MENU)
	if SceneManager:
		SceneManager.call_deferred("goto_scene", "MenuWorld")

func _on_scene_ready(scene_name: String) -> void:
	"""Called when a scene is ready. Client notifies server when GameWorld is ready."""
	if not Gnet.is_in_session():
		return

	client_relay.make_request(
		CommandRegistry.Command.CLIENT_READY,
		Payload.ClientReady.create(PersistentData.get_character_snapshot(), scene_name)
	)

func _on_server_game_state_changed(new_state: int) -> void:
	"""Called when server game state changes (for local server/host)."""
	# Map server GameState to SessionState for UI
	match new_state:
		Game.GameState.IDLE:
			session.set_state(ClientSession.SessionState.MAIN_MENU)
		Game.GameState.RUNNING:
			session.set_state(ClientSession.SessionState.IN_GAME)
		Game.GameState.ENDING:
			session.set_state(ClientSession.SessionState.MAIN_MENU)
#===================================================================================#
