extends Node
class_name PlayerSpawner

const PLAYER_SCENE_PATH := "res://app/game/player/Player.tscn"
const SCRIPT_NAME: String = "PlayerSpawner"
const IS_VERBOSE: bool = false

func _ready() -> void:
	name = "PlayerSpawner"
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

func spawn_players(players: Array, target_peer_ids: Array = []) -> void:
	"""
	Unified function to spawn players on server and send RPCs to clients.

	Args:
		players: Array of dictionaries with 'peer_id' (int) and 'position' (Vector3)
		target_peer_ids: Array of peer IDs to send RPCs to. Empty array = broadcast to all clients.

	Example:
		# Initial spawn - broadcast to all
		spawn_players([{peer_id: 1, position: Vector3(0, 0, 0)}], [])

		# Late join - send all existing players to new client
		spawn_players(all_players, [new_client_id])
	"""
	if not multiplayer.is_server():
		push_warning("PlayerSpawner: spawn_players called on client")
		return

	if not multiplayer.has_multiplayer_peer():
		if IS_VERBOSE:
			SweetLogger.warning("spawn_players - no multiplayer peer", [], SCRIPT_NAME, "spawn_players")
		return

	if players.is_empty():
		if IS_VERBOSE:
			SweetLogger.warning("spawn_players - no players to spawn", [], SCRIPT_NAME, "spawn_players")
		return

	if IS_VERBOSE:
		SweetLogger.info("spawn_players called with {0} players: {1}, targets: {2}", [players.size(), players, target_peer_ids], SCRIPT_NAME, "spawn_players")

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
			_spawn_players_rpc.rpc(players)
			if IS_VERBOSE:
				SweetLogger.info("Sent spawn RPC for {0} players to all clients", [remaining_clients.size()], SCRIPT_NAME, "spawn_players")
		else:
			if IS_VERBOSE:
				SweetLogger.info("No connected clients to send spawn RPC to (server-only)", [], SCRIPT_NAME, "spawn_players")
	else:
		for target_peer_id in target_peer_ids:
			if connected_clients.has(target_peer_id) and target_peer_id != 1:
				_spawn_players_rpc.rpc_id(target_peer_id, players)
				if IS_VERBOSE:
					SweetLogger.info("Sent spawn RPC for {0} players to client {1}", [players.size(), target_peer_id], SCRIPT_NAME, "spawn_players")
			elif target_peer_id != 1:
				if IS_VERBOSE:
					SweetLogger.warning("Target client {0} is not connected, skipping spawn RPC", [target_peer_id], SCRIPT_NAME, "spawn_players")

func spawn_late_joiner(client_peer_id: int) -> void:
	"""
	Spawn the new client's player on server and existing peers, then send all
	existing players (including the new one) to the late-joining client.
	Call from server when a late-joining client notifies that they're ready.
	"""
	if not multiplayer.is_server():
		return
	if not SpawnManager:
		push_error("PlayerSpawner: SpawnManager autoload not found!")
		return
	
	var new_player_position: Vector3 = SpawnManager.get_spawn_point(0)
	var new_player_data = [{"peer_id": client_peer_id, "position": new_player_position}]
	var all_connected = Gnet.get_connected_players() if Gnet else []
	var existing_peers = all_connected.filter(func(p): return p != client_peer_id)
	
	if IS_VERBOSE:
		SweetLogger.info("Spawning new player {0} to existing clients {1}", [new_player_data, existing_peers], SCRIPT_NAME, "spawn_late_joiner")
	await spawn_players(new_player_data, existing_peers)

	var all_players_data = get_existing_players_data()
	if not all_players_data.is_empty():
		if IS_VERBOSE:
			SweetLogger.info("Spawning existing players {0} to new client {1}", [all_players_data, client_peer_id], SCRIPT_NAME, "spawn_late_joiner")
		await spawn_players(all_players_data, [client_peer_id])

func _spawn_player_impl(peer_id: int, spawn_position: Vector3) -> void:
	"""
	Internal helper function to actually spawn a player node.
	Used by both server (directly) and clients (via RPC).
	"""
	# Check if player already exists
	var existing_player = _find_player(peer_id)
	if existing_player:
		if IS_VERBOSE:
			SweetLogger.info("Player {0} already exists, updating position", [peer_id], SCRIPT_NAME, "_spawn_player_impl")
		existing_player.global_position = spawn_position
		return

	# Load and instantiate player scene
	var player_scene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("PlayerSpawner: Failed to load player scene: " + PLAYER_SCENE_PATH)
		return

	var player = player_scene.instantiate()
	if not player:
		push_error("PlayerSpawner: Failed to instantiate player scene")
		return

	if IS_VERBOSE:
		SweetLogger.info("Player instantiated: {0} for peer_id: {1}", [player.name, peer_id], SCRIPT_NAME, "_spawn_player_impl")

	player.peer_id = peer_id

	# Give player a unique name based on peer_id for multiplayer path resolution
	player.name = "Player_%d" % peer_id

	var players_container = _get_players_container()
	if not players_container:
		push_error("PlayerSpawner: Players container not found")
		return

	# Use force_readable_name=true for multiplayer replication
	players_container.add_child(player, true)

	# Wait for the player to be fully ready - prevents a big tick catch up after connection
	await get_tree().process_frame
	if not player.is_node_ready():
		await player.ready

	# Wait a frame for RollbackSynchronizer initialization
	await get_tree().process_frame

	# Set position AFTER RollbackSynchronizer is initialized to avoid visual jumps
	player.global_position = spawn_position

	if IS_VERBOSE:
		SweetLogger.info("Spawned player {0} at {1}", [peer_id, spawn_position], SCRIPT_NAME, "_spawn_player_impl")

@rpc("authority", "call_remote", "reliable")
func _spawn_players_rpc(players_data: Array) -> void:
	"""
	RPC to spawn multiple players on clients.
	Used for both initial spawning and late-joining clients.
	Takes an array of dictionaries with 'peer_id' (int) and 'position' (Vector3).
	"""
	if multiplayer.is_server():
		return

	var my_id = multiplayer.get_unique_id()
	if IS_VERBOSE:
		SweetLogger.info("Client (unique_id: {0}) received _spawn_players_rpc for {1} players :: {2}", [my_id, players_data.size(), players_data], SCRIPT_NAME, "_spawn_players_rpc")

	# Spawn each player
	for player_data in players_data:
		var peer_id = player_data.get("peer_id", 0)
		var position = player_data.get("position", Vector3.ZERO)

		if peer_id == 0:
			continue

		if IS_VERBOSE:
			SweetLogger.info("Spawning player {0} on client", [peer_id], SCRIPT_NAME, "_spawn_players_rpc")
			SweetLogger.info("This client should {0} this player's input", ["control" if peer_id == my_id else "NOT control"], SCRIPT_NAME, "_spawn_players_rpc")

		# Spawn the player and wait for it to complete
		await _spawn_player_impl(peer_id, position)

		# Wait a frame for initialization
		await get_tree().process_frame

# PLAYER GETTERS
#===================================================================================#
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

func _find_all_players(players_container: Node) -> Array:
	"""
	Find all player nodes in PlayersContainer.
	Returns array of dictionaries with 'player' (CharacterBody3D) and 'peer_id'.
	"""
	var players = []
	for child in players_container.get_children():
		var peer_id = child.peer_id
		if peer_id != 0:
			players.append({"player": child, "peer_id": peer_id})
	return players

func get_existing_players_data() -> Array:
	"""Returns array of {peer_id, position} for all existing players (for late-join sync)."""
	var players_container = _get_players_container()
	if not players_container:
		return []
	var result: Array = []
	for player_data in _find_all_players(players_container):
		var player = player_data.player
		var player_peer_id = player_data.peer_id
		if player_peer_id != 0:
			result.append({"peer_id": player_peer_id, "position": player.global_position})
	return result
#===================================================================================#