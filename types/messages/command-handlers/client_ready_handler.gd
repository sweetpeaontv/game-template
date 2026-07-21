class_name ClientReadyHandler
extends CommandHandler

const SCRIPT_NAME := "ClientReadyHandler"

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	var payload: Payload.ClientReady = message.payload
	if payload == null:
		return "no payload"
	if payload.current_scene != SceneManager.current_scene_name:
		return "peer is not in the correct scene"
	if not SceneManager.has_scene(payload.current_scene):
		return "scene not found: " + payload.current_scene
	if not Gnet.is_peer_connected(message.actor_peer_id):
		return "peer is not in connected"
	return "ok"
#===================================================================================#

# ACCEPT
#===================================================================================#
func accept_response(message: Message) -> Array[Delivery]:
	var deliveries: Array[Delivery] = []
	var actor_peer_id = message.actor_peer_id
	var payload: Payload.ClientReady = message.payload

	# NEWLY JOINED PEER:
	## ADD EXISTING PLAYERS
	var existing_player_data = PlayerUtils.get_existing_players_data()
	var new_spawns: Array[Dictionary] = []

	for player_data in existing_player_data:
		var spawn_data = {
			"entity_type": EntityTypeRegistry.EntityType.PLAYER,
			"data": player_data,
		}
		new_spawns.append(spawn_data)

	if new_spawns.size() > 0:
		var new_spawn_payload: Payload.Spawn = Payload.Spawn.create(new_spawns)

		deliveries.append(
			Delivery.new(
				Message.new(
					actor_peer_id,
					message.timestamp,
					Message.MessageType.NOTIFY,
					CommandRegistry.Command.SPAWN,
					new_spawn_payload,
					message.request_id,
					1,
				),
				Delivery.Audience.ACTOR,
			))

	# SEND WORLD STATE SNAPSHOT HERE TO ACTOR (NEWLY JOINED PEER)
	var updates = RegistryLibrary.sync_targets.collect_sync_target_snapshot()

	if not updates.is_empty():
		deliveries.append(
			Delivery.new(
				Message.new(
					actor_peer_id,
					message.timestamp,
					Message.MessageType.NOTIFY,
					CommandRegistry.Command.SYNC_STATE,
					Payload.SyncState.create(updates),
					message.request_id,
					1,
				),
				Delivery.Audience.ACTOR,
			))
	
	# ADD NEW PLAYER TO ALL PEERS:
	var existing_peers_payload: Payload.Spawn = Payload.Spawn.create(
		[{
			"entity_type": EntityTypeRegistry.EntityType.PLAYER,
			"data": {
				"peer_id": actor_peer_id,
				"position": Vector3.ZERO,
				"snapshot": payload.snapshot,
			},
		}]
	)
	
	deliveries.append(
		Delivery.new(
			Message.new(
				actor_peer_id,
				message.timestamp,
				Message.MessageType.NOTIFY,
				CommandRegistry.Command.SPAWN,
				existing_peers_payload,
				message.request_id,
				1,
			),
			Delivery.Audience.ALL,
		))

	return deliveries
#===================================================================================#

# REJECT
#===================================================================================#
#func reject_response(message: Message) -> Array[Delivery]:
#	return [
#		
#	]
#===================================================================================#

# APPLY
#===================================================================================#
func apply(_message: Message) -> void:
	return
#===================================================================================#
