extends Node
"""
GameManager - Client-side game state management

Manages client connection state (MAIN_MENU, IDLE, CONNECTING, LOADING)
and receives server-authoritative game state updates (IN_LOBBY, PLAYING, ENDING)
from ServerManager for UI display.
"""

# Client session (managed locally)
var session: ClientSession = ClientSession.new()

var script_name: String = "GameManager"
var game_scene_name: String = "GameWorld"
var is_verbose: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ServerManager:
		ServerManager.game_state_changed.connect(_on_server_game_state_changed)

	# Connect to Gnet signals for client-side connection state
	Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)
	Gnet.connection_failed.connect(_on_gnet_connection_failed)

	# Connect to SceneManager for client scene ready notification
	SceneManager.scene_ready.connect(_on_scene_ready)

func get_session_state() -> ClientSession.SessionState:
	return session.get_state()

func set_session_state(new_state: ClientSession.SessionState) -> void:
	session.set_state(new_state)

func _start_game() -> void:
	"""Start hosting a game. Delegates to ServerManager."""
	if ServerManager:
		ServerManager.start_server()
	else:
		push_error("GameManager: ServerManager not initialized")

func _join_game() -> void:
	# Join lobby with gnet
	# The connection_succeeded signal will trigger loading GameWorld
	Gnet.join_game("127.0.0.1:7777")

func _on_gnet_connection_succeeded() -> void:
	"""Called when connection to game succeeds. Handles client-side state."""
	if is_verbose:
		SweetLogger.info("_on_gnet_connection_succeeded called, is_server: {0}", [multiplayer.is_server()], script_name, "_on_gnet_connection_succeeded")
	# ServerManager handles server-side connection logic
	# Client: wait for host to send RPC
	if not multiplayer.is_server():
		if is_verbose:
			SweetLogger.info("Client detected, waiting for host RPC", [], script_name, "_on_gnet_connection_succeeded")
		session.set_state(ClientSession.SessionState.LOADING)

func _on_gnet_connection_failed(_reason: String) -> void:
	"""Called when connection fails."""
	session.set_state(ClientSession.SessionState.MAIN_MENU)

func _on_scene_ready(scene_name: String) -> void:
	"""Called when a scene is ready. Client notifies server when GameWorld is ready."""
	if scene_name == "GameWorld":
		# Client: notify server that we're ready (ServerManager handles server-side)
		if not multiplayer.is_server() and ServerManager:
			if is_verbose:
				SweetLogger.info("Client GameWorld ready, notifying server", [], script_name, "_on_scene_ready")
			ServerManager._notify_client_ready.rpc_id(1)

func launch_game() -> void:
	"""
	Host launches the game for all connected players (opens doors, unlocks full game).
	Delegates to ServerManager.
	"""
	if ServerManager:
		ServerManager.launch_game()
	else:
		push_warning("GameManager: ServerManager not initialized")


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

func _disconnect_game() -> void:
	Gnet.disconnect_game()
	session.set_state(ClientSession.SessionState.MAIN_MENU)