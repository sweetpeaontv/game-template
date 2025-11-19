# app/autoload/gnet.gd

extends Node
"""
GNet - Simple P2P Multiplayer Setup for Godot 4

Handles adapter switching (Steam P2P vs ENet) and sets up MultiplayerPeer.
Manages player metadata directory (names, Steam IDs, teams) and coordinates
late join spawning. Once connected, use normal Godot RPCs for all game 
communication in other managers/scenes.
"""

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(reason: String)
signal connection_succeeded()
signal players_changed(connected_players: Array[int])
signal friends_lobbies_found(lobbies: Array[Dictionary])
signal player_directory_changed(players: Dictionary)
signal spawn_requested(peer_id: int)

enum Adapter { STEAM, ENET }

var current_adapter: Adapter = Adapter.ENET
var useSteam: bool = false
var multiplayer_peer: MultiplayerPeer
var is_hosting: bool = false

# Steam-specific
var steam
var steam_lobby_id: int = 0
var steam_available: bool = false
var steam_initialized: bool = false

# Connected players tracking
var connected_players: Array[int] = []

# Player metadata directory
# { peer_id: {name: String, steam_id: int, team: int} }
var players: Dictionary = {}
var allow_late_join := true
var autospawn_on_join := true

func _ready():
	# Check Steam availability
	steam_available = Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")
	if steam_available:
		steam = Engine.get_singleton("Steam")
		print("GNet: Steam available, but not initialized. Use toggle to enable.")
	else:
		print("GNet: Steam not available, using ENet")
	
	# Default to ENet for local development
	current_adapter = Adapter.ENET
	useSteam = false
	
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Connect to GameManager for late join spawning
	if Engine.has_singleton("GameManager"):
		GameManager.session_state_changed.connect(_on_game_state_changed)

func _process(_delta):
	if useSteam and steam:
		steam.run_callbacks()

## PUBLIC API ##

func use_adapter(adapter_name: String):
	"""Switch between 'steam' and 'enet' adapters."""
	match adapter_name.to_lower():
		"steam":
			if not steam_available:
				print("GNet: Steam not available, staying with ENet")
				return
			
			# Initialize Steam if not already initialized
			if not steam_initialized:
				_initialize_steam()
			
			# Only switch if initialization succeeded
			if steam_initialized:
				current_adapter = Adapter.STEAM
				useSteam = true
				print("GNet: Switched to Steam adapter")
			else:
				print("GNet: Steam initialization failed, staying with ENet")
		"enet":
			current_adapter = Adapter.ENET
			useSteam = false
			print("GNet: Switched to ENet adapter")
		_:
			print("GNet: Unknown adapter '%s', use 'steam' or 'enet'" % adapter_name)

func host_game(options: Dictionary = {}) -> bool:
	"""
	Host a P2P game. Returns true if successful.
	
	Options:
	- max_players: int (default 4)
	- port: int (ENet only, default 7777)
	- lobby_type: String (Steam only: "public", "friends", "private")
	"""
	print('GNet: Hosting game')
	var max_players = options.get("max_players", 4)
	var port = options.get("port", 7777)
	return _host(max_players, port, options)

func join_game(target) -> bool:
	"""
	Join a P2P game. Target format depends on adapter:
	- Steam: lobby_id (int) or host_steam_id (int)
	- ENet: "ip:port" string or {address: String, port: int}
	"""
	return _join(target)

func disconnect_game():
	"""Disconnect from current game with proper cleanup."""
	_disconnect()
	
	# Common cleanup
	if multiplayer_peer:
		multiplayer.multiplayer_peer = null
		multiplayer_peer = null
	is_hosting = false
	steam_lobby_id = 0
	
	# Clear players list and metadata
	connected_players.clear()
	players.clear()
	players_changed.emit(connected_players)
	player_directory_changed.emit(players)

func get_lobby_id() -> int:
	"""Get current Steam lobby ID (0 if not Steam or not in lobby)."""
	return steam_lobby_id

func get_connected_players() -> Array[int]:
	"""Get array of all connected player IDs."""
	return connected_players.duplicate()

func get_player_count() -> int:
	"""Get number of connected players."""
	return connected_players.size()

func is_player_connected(peer_id: int) -> bool:
	"""Check if a specific player is connected."""
	return connected_players.has(peer_id)

func find_friends_lobbies():
	"""Find lobbies created by Steam friends. Results come via friends_lobbies_found signal."""
	if not steam_available or not steam_initialized:
		friends_lobbies_found.emit([])
		return
	
	print("GNet: Checking friends' game status...")
	var friends_lobbies: Array[Dictionary] = []
	var friend_count = steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)
	var my_app_id = steam.getAppID()
	
	# Check each friend directly
	for i in range(friend_count):
		var friend_steam_id = steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info = steam.getFriendGamePlayed(friend_steam_id)
		
		# Skip if friend is not playing any game
		if game_info.is_empty():
			continue
			
		# Skip if friend is playing a different game
		if game_info.get("id", 0) != my_app_id:
			continue
			
		# Check if friend is in a lobby
		var lobby_id = game_info.get("lobby", 0)
		if lobby_id == 0:
			continue  # Friend is playing our game but not in a lobby
		
		# Friend is in a lobby for our game!
		var friend_name = steam.getFriendPersonaName(friend_steam_id)
		var lobby_data = {
			"lobby_id": lobby_id,
			"owner_steam_id": friend_steam_id,
			"owner_name": friend_name,
			"member_count": steam.getNumLobbyMembers(lobby_id),
			"max_members": steam.getLobbyMemberLimit(lobby_id),
			"game_name": steam.getLobbyData(lobby_id, "game_name")
		}
		friends_lobbies.append(lobby_data)
	
	print("GNet: Found ", friends_lobbies.size(), " friends' lobbies")
	friends_lobbies_found.emit(friends_lobbies)

## STEAM ##
## ------------------------------------------------------------------------ ##

func _initialize_steam():
	"""Initialize Steam API."""
	if not steam:
		print("GNet: Steam singleton not found")
		steam_available = false
		current_adapter = Adapter.ENET
		useSteam = false
		return
	
	# Initialize Steam
	var init_result = steam.steamInit()
	if not init_result:
		print("GNet: Steam initialization failed")
		steam_available = false
		steam_initialized = false
		current_adapter = Adapter.ENET
		useSteam = false
		connection_failed.emit("initial_connect_failed")
		return
	
	steam_initialized = true
	useSteam = true
	print("GNet: Steam initialized successfully")
	print("GNet: Steam User ID: ", steam.getSteamID())

	steam.lobby_created.connect(_on_steam_lobby_created)
	steam.lobby_joined.connect(_on_steam_lobby_joined)

## HOST ##
## ------------------------------------------------------------------------ ##

func create_socket():
	print("create_socket")
	multiplayer_peer = SteamMultiplayerPeer.new()
	multiplayer_peer.create_host(0)
	multiplayer.set_multiplayer_peer(multiplayer_peer)

func _host(max_players: int, port: int, options: Dictionary) -> bool:
	if useSteam:
		return _host_steam_impl(max_players, options)
	else:
		return _host_enet_impl(port, max_players)

func _host_steam_impl(max_players: int, options: Dictionary) -> bool:
	print('GNet: _host (Steam)')
	if not steam_available or not steam_initialized:
		connection_failed.emit("initial_connect_failed")
		return false
	
	# Determine lobby type using Steam constants
	var lobby_type = Steam.LOBBY_TYPE_FRIENDS_ONLY
	match options.get("lobby_type", "friends"):
		"public": lobby_type = Steam.LOBBY_TYPE_PUBLIC
		"private": lobby_type = Steam.LOBBY_TYPE_PRIVATE
		"friends": lobby_type = Steam.LOBBY_TYPE_FRIENDS_ONLY
	
	# Use Steam singleton to create lobby (async call - result comes via callback)
	print('GNet: Creating Steam lobby with type: ', lobby_type, ' and max_players: ', max_players)
	steam.createLobby(lobby_type, max_players)
	print('GNet: createLobby call initiated (async)')
	
	# createLobby is async - we'll get the result in _on_steam_lobby_created callback
	is_hosting = true
	return true  # Just indicates the request was initiated successfully

func _host_enet_impl(port: int, max_players: int) -> bool:
	print('GNet: _host (ENet)')
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	var result = multiplayer_peer.create_server(port, max_players)
	if result != OK:
		connection_failed.emit("Failed to create ENet server on port " + str(port))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_hosting = true
	print("GNet: ENet server started on port ", port)
	print("GNet: multiplayer.is_server() = ", multiplayer.is_server())
	print("GNet: multiplayer.get_unique_id() = ", multiplayer.get_unique_id())
	
	# Add host to connected players immediately
	var host_id = 1  # Host always has ID 1
	if not connected_players.has(host_id):
		connected_players.append(host_id)
		players_changed.emit(connected_players)
	
	# Initialize player directory for host
	_update_player_directory()
	
	print("GNet: Emitting connection_succeeded signal")
	connection_succeeded.emit()
	print("GNet: connection_succeeded signal emitted")
	return true

func _on_steam_lobby_created(_result: int, _lobby_id: int):
	print('_on_steam_lobby_created')
	if _result == 1:  # Steam.RESULT_OK
		print("GNet: Steam lobby created with ID: ", _lobby_id)
		
		create_socket()
		
		# Add host to connected players for Steam (like ENet does)
		var host_id = 1  # Host always has ID 1
		if not connected_players.has(host_id):
			connected_players.append(host_id)
			players_changed.emit(connected_players)
		
		connection_succeeded.emit()
	else:
		connection_failed.emit("Steam lobby creation failed: " + str(_result))

## ------------------------------------------------------------------------ ##
## end HOST ##

## JOIN ##
## ------------------------------------------------------------------------ ##

func connect_socket(steam_id: int):
	multiplayer_peer = SteamMultiplayerPeer.new()
	multiplayer_peer.create_client(steam_id, 0)
	multiplayer.set_multiplayer_peer(multiplayer_peer)

func _join(target) -> bool:
	if useSteam:
		return _join_steam_impl(target)
	else:
		return _join_enet_impl(target)

func _join_steam_impl(lobby_id: int) -> bool:
	print('GNet: _join (Steam)')
	if not steam_available or not steam_initialized:
		connection_failed.emit("initial_connect_failed")
		return false
	
	# Use Steam singleton to join lobby (async call)
	print('GNet: Joining Steam lobby: ', lobby_id)
	steam.joinLobby(lobby_id)
	print('GNet: joinLobby call initiated (async)')
	
	return true  # Just indicates the request was initiated

func _join_enet_impl(target) -> bool:
	print('GNet: _join (ENet)')
	var address: String
	var port: int
	
	# Parse target
	if typeof(target) == TYPE_STRING:
		var parts = target.split(":")
		address = parts[0]
		port = int(parts[1]) if parts.size() > 1 else 7777
	elif typeof(target) == TYPE_DICTIONARY:
		address = target.get("address", "127.0.0.1")
		port = target.get("port", 7777)
	else:
		connection_failed.emit("Invalid ENet target format")
		return false
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	var result = multiplayer_peer.create_client(address, port)
	if result != OK:
		connection_failed.emit("Failed to connect to " + address + ":" + str(port))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	print("GNet: Connecting to ", address, ":", port)
	return true

func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int):
	print('_on_steam_lobby_joined')
	print('lobby_id: ', lobby_id, ' response: ', response)
	
	if response == 1:  # Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS
		steam_lobby_id = lobby_id
		print("GNet: Successfully joined Steam lobby: ", lobby_id)

		if not is_hosting:
			print("GNet: Attempting P2P connection to lobby owner")
			var lobby_owner_steam_id = steam.getLobbyOwner(lobby_id)
			connect_socket(lobby_owner_steam_id)
	else:
		connection_failed.emit("Failed to join Steam lobby: " + str(response))

## ------------------------------------------------------------------------ ##
## end JOIN ##

## SIGNAL HANDLERS ##
## ------------------------------------------------------------------------ ##

func _on_peer_connected(peer_id: int):
	print("GNet: Peer connected: ", peer_id)
	
	if not connected_players.has(peer_id):
		connected_players.append(peer_id)
		players_changed.emit(connected_players)
	
	# Update player directory
	_update_player_directory()
	
	# Handle late join spawning if we're already playing
	# Check ServerGameManager state if available, otherwise check GameManager
	var is_playing := false
	if Engine.has_singleton("ServerGameManager"):
		# Check server game state (GameState.PLAYING = 1)
		var server_state = ServerGameManager.get_game_state()
		is_playing = server_state == 1  # PLAYING
	elif Engine.has_singleton("GameManager"):
		# Fallback to GameManager state
		is_playing = GameManager.state == GameManager.SessionState.PLAYING
	
	if is_playing and allow_late_join and autospawn_on_join:
		spawn_requested.emit(peer_id)
	
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int):
	print("GNet: Peer disconnected: ", peer_id)
	
	connected_players.erase(peer_id)
	if players.has(peer_id):
		players.erase(peer_id)
		player_directory_changed.emit(players)
	
	players_changed.emit(connected_players)
	
	peer_disconnected.emit(peer_id)

func _on_connection_failed():
	print("GNet: Connection failed")
	# Clear players on failed connection
	connected_players.clear()
	players.clear()
	players_changed.emit(connected_players)
	player_directory_changed.emit(players)
	connection_failed.emit("Connection failed")

func _on_connection_succeeded():
	print("GNet: Connected successfully")
	var my_id = multiplayer.get_unique_id()
	print("GNet: My ID is: ", my_id)
	print("GNet: Is hosting: ", is_hosting)
	
	if not connected_players.has(my_id):
		connected_players.append(my_id)
		print("GNet: Added myself to connected_players: ", connected_players)
	
	# Initialize player directory
	_update_player_directory()
	
	players_changed.emit(connected_players)
	print("GNet: Emitted players_changed with: ", connected_players)

func _on_server_disconnected():
	"""Called when clients lose connection to the host/server."""
	print("GNet: Server disconnected")
	
	# Clear all players since server is gone
	connected_players.clear()
	players.clear()
	players_changed.emit(connected_players)
	player_directory_changed.emit(players)
	
	# Emit connection failed to notify UI
	connection_failed.emit("Server disconnected")

## DISCONNECT ##
## ------------------------------------------------------------------------ ##

func _disconnect():
	"""Disconnect from current game with proper cleanup."""
	if not multiplayer_peer:
		return
	
	if useSteam:
		_disconnect_steam_impl()
	else:
		_disconnect_enet_impl()

func _disconnect_steam_impl():
	"""Steam-specific disconnect with lobby cleanup."""
	if is_hosting and steam_lobby_id > 0:
		if steam_available:
			steam.leaveLobby(steam_lobby_id)
		print("GNet: Steam lobby closed: ", steam_lobby_id)
	
	# Close the multiplayer peer connection
	multiplayer_peer.close()

func _disconnect_enet_impl():
	"""ENet-specific disconnect with proper peer cleanup."""
	if is_hosting:
		# As host, we need to notify all clients before shutting down
		print("GNet: ENet server shutting down")
		# The close() method should handle notifying clients
	else:
		print("GNet: ENet client disconnecting")
	
	# Close the multiplayer peer connection
	multiplayer_peer.close()

## ------------------------------------------------------------------------ ##
## end DISCONNECT ##

## ------------------------------------------------------------------------ ##
## end SIGNAL HANDLERS ##

## PLAYER METADATA ##
## ------------------------------------------------------------------------ ##

func _update_player_directory() -> void:
	"""Update player directory based on connected players list."""
	var updated_players = {}
	
	# Build player directory from connected peers
	for peer_id in connected_players:
		if players.has(peer_id):
			# Keep existing player data
			updated_players[peer_id] = players[peer_id]
		else:
			# Create new player entry
			var player_data = {
				"name": "Player " + str(peer_id),
				"steam_id": 0,
				"team": 0
			}
			
			# Try to get Steam ID if using Steam
			if steam_available and steam:
				# Get Steam ID for this peer (if possible)
				# Note: This might need adjustment based on your Steam setup
				player_data["steam_id"] = 0  # Placeholder - implement based on your needs
			
			updated_players[peer_id] = player_data
	
	players = updated_players
	player_directory_changed.emit(players)

func _on_game_state_changed(new_state) -> void:
	"""Called when game session state changes."""
	# Clear players when returning to IDLE (client state)
	# IDLE = 1 in SessionState enum
	if new_state == 1:  # IDLE
		players.clear()
		player_directory_changed.emit(players)

func set_player_name(peer_id: int, player_name: String) -> void:
	"""Set player name (host only, or local player)."""
	if not players.has(peer_id):
		return
	
	if multiplayer.is_server() or peer_id == multiplayer.get_unique_id():
		players[peer_id]["name"] = player_name
		player_directory_changed.emit(players)
		
		# Sync name across network
		if multiplayer.is_server():
			_sync_player_name.rpc(peer_id, player_name)

@rpc("authority", "call_remote", "reliable")
func _sync_player_name(peer_id: int, player_name: String) -> void:
	"""Sync player name from host."""
	if players.has(peer_id):
		players[peer_id]["name"] = player_name
		player_directory_changed.emit(players)

func get_player_name(peer_id: int) -> String:
	"""Get player name, or default if not found."""
	if players.has(peer_id):
		return players[peer_id].get("name", "Player " + str(peer_id))
	return "Player " + str(peer_id)

## ------------------------------------------------------------------------ ##
## end PLAYER METADATA ##

func _exit_tree():
	"""Clean up multiplayer connection and Steam on exit."""
	# Disconnect from any active multiplayer session
	if multiplayer.has_multiplayer_peer():
		print("GNet: Cleaning up multiplayer connection on exit...")
		disconnect_game()
	
	# Clean up Steam
	if steam_initialized:
		if steam:
			steam.steamShutdown()
		steam_initialized = false
