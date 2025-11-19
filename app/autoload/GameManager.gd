extends Node
"""
GameManager - Game session state management

Tracks the overall game session state (IDLE, CONNECTING, IN_LOBBY, etc.)
and coordinates between different managers for game flow.
"""

signal session_state_changed(state: SessionState)

enum SessionState { MAIN_MENU, IDLE, CONNECTING, IN_LOBBY, LOADING, PLAYING, ENDING }
var state := SessionState.MAIN_MENU

# Player scene path
const PLAYER_SCENE_PATH := "res://game/player/Player.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect to Gnet signals for connection state
	Gnet.connection_succeeded.connect(_on_gnet_connection_succeeded)
	Gnet.connection_failed.connect(_on_gnet_connection_failed)
	Gnet.peer_connected.connect(_on_gnet_peer_connected)
	Gnet.spawn_requested.connect(_on_spawn_requested)
	
	# Connect to SceneManager for scene ready tracking
	SceneManager.scene_ready.connect(_on_scene_ready)

func _set_state(new_state: SessionState) -> void:
	if state == new_state:
		return
	
	state = new_state
	session_state_changed.emit(state)

func _start_game() -> void:
	# Create lobby with gnet
	# The connection_succeeded signal will trigger loading GameWorld
	Gnet.host_game()

func _join_game() -> void:
	# Join lobby with gnet
	# The connection_succeeded signal will trigger loading GameWorld
	Gnet.join_game("127.0.0.1:7777")

func _on_gnet_connection_succeeded() -> void:
	"""Called when connection to game succeeds."""
	print("GameManager: _on_gnet_connection_succeeded called, is_server: ", multiplayer.is_server())
	# Immediately load GameWorld for all players
	# If we're the host/server, load for everyone via RPC
	if multiplayer.is_server():
		print("GameManager: Host detected, loading GameWorld for all")
		_set_state(SessionState.LOADING)
		_load_gameworld_for_all.rpc()
	else:
		# Client: wait for host to send RPC
		print("GameManager: Client detected, waiting for host RPC")
		_set_state(SessionState.LOADING)

func _on_gnet_peer_connected(peer_id: int) -> void:
	"""Called when a peer connects. If we're host and already in gameworld, load it for them."""
	print("GameManager: _on_gnet_peer_connected called for peer_id: ", peer_id, ", is_server: ", multiplayer.is_server(), ", state: ", state)
	if multiplayer.is_server() and (state == SessionState.IN_LOBBY or state == SessionState.PLAYING):
		# Host is already in gameworld, load it for the new client
		print("GameManager: Host detected late-joining peer, loading GameWorld for peer_id: ", peer_id)
		_load_gameworld_for_peer.rpc_id(peer_id)

func _on_gnet_connection_failed(_reason: String) -> void:
	"""Called when connection fails."""
	_set_state(SessionState.IDLE)

func _on_scene_ready(scene_name: String) -> void:
	"""Called when a scene is ready."""
	if scene_name == "GameWorld":
		# When GameWorld is ready, we're in lobby state (limited area)
		if state == SessionState.LOADING:
			_set_state(SessionState.IN_LOBBY)
			# Spawn all connected players when GameWorld is ready
			# SceneManager already waits for the scene's ready signal
			print("GameManager: GameWorld ready, spawning all players")
			spawn_all_players()
			
			# If we're a late-joining client, notify host that we're ready
			if not multiplayer.is_server():
				_notify_client_ready.rpc_id(1)

func _on_spawn_requested(peer_id: int) -> void:
	"""Called when Gnet requests spawning a late-joining player."""
	if multiplayer.is_server():
		spawn_player(peer_id)

func launch_game() -> void:
	"""
	Host launches the game for all connected players (opens doors, unlocks full game).
	Only the host/server can call this.
	Players are already in GameWorld in limited area, this unlocks the full game.
	"""
	if not multiplayer.has_multiplayer_peer():
		push_warning("GameManager: Cannot launch - no active connection")
		return
	
	if not multiplayer.is_server():
		push_warning("GameManager: Only host can launch game")
		return
	
	if state != SessionState.IN_LOBBY:
		push_warning("GameManager: Can only launch from IN_LOBBY state")
		return
	
	# Unlock game for all clients via RPC (no scene change needed)
	_start_game_for_all.rpc()

@rpc("authority", "call_local", "reliable")
func _load_gameworld_for_all() -> void:
	"""RPC called when connection succeeds - loads GameWorld for all players."""
	if state != SessionState.LOADING:
		_set_state(SessionState.LOADING)
	SceneManager.request_scene_change("GameWorld")

@rpc("authority", "call_remote", "reliable")
func _load_gameworld_for_peer() -> void:
	"""RPC called by host to load GameWorld for a late-joining client."""
	print("GameManager: _load_gameworld_for_peer RPC received on client, loading GameWorld")
	_set_state(SessionState.LOADING)
	# Client should call goto_scene directly, not request_scene_change
	SceneManager.goto_scene("GameWorld")

@rpc("any_peer", "call_remote", "reliable")
func _notify_client_ready() -> void:
	"""RPC called by late-joining client to notify host that they're ready."""
	if multiplayer.is_server():
		var client_peer_id = multiplayer.get_remote_sender_id()
		print("GameManager: Late-joining client ", client_peer_id, " is ready, spawning them")
		# Spawn the late-joining client on the host
		spawn_player(client_peer_id)

@rpc("authority", "call_local", "reliable")
func _start_game_for_all() -> void:
	"""RPC called by host to start the game (unlock doors, full gameplay)."""
	# Transition from IN_LOBBY (limited area) to PLAYING (full game)
	_set_state(SessionState.PLAYING)

## PLAYER SPAWNING ##

func spawn_all_players() -> void:
	"""Spawn all connected players in the current scene."""
	if not multiplayer.has_multiplayer_peer():
		print("GameManager: spawn_all_players - no multiplayer peer")
		return
	
	var connected_peers = Gnet.get_connected_players()
	print("GameManager: spawn_all_players - connected peers: ", connected_peers)
	
	if connected_peers.is_empty():
		print("GameManager: spawn_all_players - no connected peers, spawning host manually")
		# If no peers in list yet, spawn host (peer_id 1) manually
		if multiplayer.is_server():
			spawn_player(1)
		return
	
	for peer_id in connected_peers:
		print("GameManager: spawn_all_players - spawning peer_id: ", peer_id)
		spawn_player(peer_id)

func spawn_player(peer_id: int) -> void:
	"""
	Spawn a player for the given peer_id.
	Finds SpawnManager in current scene and uses spawn points.
	"""
	print("GameManager: spawn_player called for peer_id: ", peer_id)
	
	if not multiplayer.has_multiplayer_peer():
		push_warning("GameManager: Cannot spawn - no active connection")
		return
	
	# Check if player already exists
	if _find_player(peer_id):
		print("GameManager: Player ", peer_id, " already spawned, skipping")
		return
	
	# Find SpawnManager in current scene
	print("GameManager: Looking for SpawnManager...")
	var spawn_manager = _find_spawn_manager()
	if not spawn_manager:
		push_warning("GameManager: No SpawnManager found in current scene!")
		var current_scene = get_tree().current_scene
		if current_scene:
			print("GameManager: Current scene root: ", current_scene.name)
			print("GameManager: Scene root children: ", current_scene.get_children())
		return
	
	print("GameManager: Found SpawnManager: ", spawn_manager)
	
	# Get spawn point for this peer (use peer_id as index)
	var spawn_index = peer_id - 1  # peer_id 1 = index 0
	var spawn_position = spawn_manager.get_spawn_point(spawn_index)
	print("GameManager: Spawn position: ", spawn_position)
	
	# Load and instantiate player scene
	print("GameManager: Loading player scene: ", PLAYER_SCENE_PATH)
	var player_scene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("GameManager: Failed to load player scene: " + PLAYER_SCENE_PATH)
		return
	
	print("GameManager: Instantiating player scene...")
	var player = player_scene.instantiate()
	if not player:
		push_error("GameManager: Failed to instantiate player scene")
		return
	
	print("GameManager: Player instantiated: ", player.name)
	
	# Set position and multiplayer authority
	player.global_position = spawn_position
	player.set_multiplayer_authority(peer_id)
	print("GameManager: Set position and authority for player")
	
	# Add to scene tree first (so @onready vars are initialized)
	var scene_root = get_tree().current_scene
	
	# If current_scene is null, try to find GameWorld in the scene tree
	if not scene_root:
		# Try to find GameWorld by name in root's children
		for child in get_tree().root.get_children():
			if child.name == "GameWorld":
				scene_root = child
				break
	
	print("GameManager: Current scene root: ", scene_root.name if scene_root else "null")
	if scene_root:
		scene_root.add_child(player)
		print("GameManager: Added player to scene tree. Player children count: ", player.get_child_count())
		
		# Set player name from Gnet metadata (after adding to tree so @onready vars are ready)
		if Gnet.players.has(peer_id):
			var player_name = Gnet.get_player_name(peer_id)
			if player.has_method("setNameplate"):
				player.setNameplate(player_name)
		
		print("GameManager: Spawned player ", peer_id, " at ", spawn_position)
		print("GameManager: Scene root now has ", scene_root.get_child_count(), " children")
	else:
		push_error("GameManager: No current scene root found")

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
	"""Recursively search for player node with matching peer_id."""
	# Check if this node is a player with matching authority
	if node.get_multiplayer_authority() == peer_id:
		if node.has_method("setNameplate") or node is CharacterBody3D:
			return node
	
	# Search children
	for child in node.get_children():
		var result = _find_player_recursive(child, peer_id)
		if result:
			return result
	
	return null

func _find_spawn_manager() -> Node:
	"""Find SpawnManager node in the current scene tree."""
	var scene_root = get_tree().current_scene
	
	# If current_scene is null, try to find GameWorld in the scene tree
	if not scene_root:
		print("GameManager: _find_spawn_manager - current_scene is null, searching for GameWorld")
		print("GameManager: Root children: ", get_tree().root.get_children())
		
		# Try to find GameWorld by name in root's children
		for child in get_tree().root.get_children():
			if child.name == "GameWorld":
				scene_root = child
				break
		
		if not scene_root:
			print("GameManager: _find_spawn_manager - GameWorld not found in scene tree")
			return null
	
	print("GameManager: _find_spawn_manager - scene root: ", scene_root.name)
	print("GameManager: _find_spawn_manager - scene root children: ", scene_root.get_children())
	
	# Look for SpawnManager node (could be anywhere in tree)
	var spawn_manager = scene_root.find_child("SpawnManager", true, false)
	print("GameManager: _find_spawn_manager - find_child result: ", spawn_manager)
	
	if spawn_manager:
		print("GameManager: _find_spawn_manager - spawn_manager name: ", spawn_manager.name)
		print("GameManager: _find_spawn_manager - has get_spawn_point: ", spawn_manager.has_method("get_spawn_point"))
		if spawn_manager.has_method("get_spawn_point"):
			return spawn_manager
	
	# If not found, check if root itself is a SpawnManager
	if scene_root.has_method("get_spawn_point"):
		print("GameManager: _find_spawn_manager - root is SpawnManager")
		return scene_root
	
	print("GameManager: _find_spawn_manager - SpawnManager not found")
	return null
