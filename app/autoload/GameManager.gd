extends Node
"""
GameManager - Client-side game state management

Manages client connection state (MAIN_MENU, IDLE, CONNECTING, LOADING)
and receives server-authoritative game state updates (IN_LOBBY, PLAYING, ENDING)
from ServerGameManager for UI display.
"""

signal session_state_changed(state: SessionState)

# Client states (managed locally)
# Server states (IN_LOBBY, PLAYING, ENDING) are received from ServerGameManager via RPC
enum SessionState { MAIN_MENU, IDLE, CONNECTING, IN_LOBBY, LOADING, PLAYING, ENDING }
var state := SessionState.MAIN_MENU

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ServerGameManager:
		ServerGameManager.game_state_changed.connect(_on_server_game_state_changed)
	
	# Connect to Gnet signals for client-side connection state
	Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)
	Gnet.connection_failed.connect(_on_gnet_connection_failed)
	
	# Connect to SceneManager for client scene ready notification
	SceneManager.scene_ready.connect(_on_scene_ready)

func _set_state(new_state: SessionState) -> void:
	if state == new_state:
		return
	
	state = new_state
	session_state_changed.emit(state)

func _start_game() -> void:
	"""Start hosting a game. Delegates to ServerGameManager."""
	if ServerGameManager:
		ServerGameManager.start_server()
	else:
		push_error("GameManager: ServerGameManager not initialized")

func _join_game() -> void:
	# Join lobby with gnet
	# The connection_succeeded signal will trigger loading GameWorld
	Gnet.join_game("127.0.0.1:7777")

func _on_gnet_connection_succeeded() -> void:
	"""Called when connection to game succeeds. Handles client-side state."""
	print("GameManager: _on_gnet_connection_succeeded called, is_server: ", multiplayer.is_server())
	# ServerGameManager handles server-side connection logic
	# Client: wait for host to send RPC
	if not multiplayer.is_server():
		print("GameManager: Client detected, waiting for host RPC")
		_set_state(SessionState.LOADING)

func _on_gnet_connection_failed(_reason: String) -> void:
	"""Called when connection fails."""
	_set_state(SessionState.IDLE)

func _on_scene_ready(scene_name: String) -> void:
	"""Called when a scene is ready. Client notifies server when GameWorld is ready."""
	if scene_name == "GameWorld":
		# Client: notify server that we're ready (ServerGameManager handles server-side)
		if not multiplayer.is_server() and ServerGameManager:
			print("GameManager: Client GameWorld ready, notifying server")
			ServerGameManager._notify_client_ready.rpc_id(1)

func launch_game() -> void:
	"""
	Host launches the game for all connected players (opens doors, unlocks full game).
	Delegates to ServerGameManager.
	"""
	if ServerGameManager:
		ServerGameManager.launch_game()
	else:
		push_warning("GameManager: ServerGameManager not initialized")


func _on_server_game_state_changed(new_state: int) -> void:
	"""Called when server game state changes (for local server/host)."""
	# Map server GameState to SessionState for UI
	match new_state:
		0:  # IN_LOBBY
			_set_state(SessionState.IN_LOBBY)
		1:  # PLAYING
			_set_state(SessionState.PLAYING)
		2:  # ENDING
			_set_state(SessionState.ENDING)
