extends Node

# PLAYER GETTERS
#===================================================================================#
func find_player(peer_id: int) -> Node:
	"""Find existing player node for peer_id in PlayersContainer."""
	var players_container = get_players_container()
	if not players_container:
		return null

	# Players are direct children named "Player_%d"
	return players_container.get_node_or_null("Player_%d" % peer_id)

func get_players_container() -> Node:
	"""Gets the Players node from the Main scene."""
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("Players")
	return null

func despawn_all_players() -> void:
	"""Remove all player nodes from Main/Players. They persist across WorldContainer scene swaps."""
	var container = get_players_container()
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func despawn_player(peer_id: int) -> void:
	"""Remove a single player by peer id (server or client copy)."""
	var p = find_player(peer_id)
	if p:
		p.queue_free()

func find_all_players(players_container: Node) -> Array:
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
	var players_container = get_players_container()
	if not players_container:
		return []
	var result: Array = []
	for player_data in find_all_players(players_container):
		var player = player_data.player
		var player_peer_id = player_data.peer_id
		if player_peer_id != 0:
			result.append({"peer_id": player_peer_id, "position": player.global_position})
	return result
#===================================================================================#
