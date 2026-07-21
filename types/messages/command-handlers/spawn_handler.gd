class_name SpawnHandler
extends CommandHandler

const SCRIPT_NAME := "SpawnHandler"

# VALIDATE
#===================================================================================#
# message.payload shape: [{ entity_type: EntityTypeRegistry.EntityType, data: Dictionary }]
func validate(message: Message) -> String:
	# could filter out failures and still pass along valid spawns since spawns can be batched
	for spawn in message.payload.spawns:
		if not spawn.has("entity_type"):
			return "spawn missing required field 'entity_type'"
		if not EntityTypeRegistry.has_entity_type(spawn["entity_type"]):
			return "invalid spawn type: " + EntityTypeRegistry.EntityType.keys()[spawn["entity_type"]]
	return "ok"
#===================================================================================#

# ACCEPT
#===================================================================================#
func accept_response(message: Message) -> Array[Delivery]:
	return [
		Delivery.new(
			Message.new(
				message.actor_peer_id, 
				message.timestamp, 
				Message.MessageType.CONFIRM, 
				message.command, 
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			), 
			Delivery.Audience.ACTOR
		),
		Delivery.new(
			Message.new(
				message.actor_peer_id, 
				message.timestamp, 
				Message.MessageType.NOTIFY, 
				message.command, 
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			), 
			Delivery.Audience.OTHERS
		),
	]
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
func apply(message: Message) -> void:
	var payload: Payload.Spawn = message.payload

	for spawn in payload.spawns:
		var entity_type = spawn["entity_type"]
		var entity_data = spawn["data"]
		var entity_handler = EntityTypeRegistry.get_handler(entity_type)

		var result = entity_handler.validate_spawn(entity_data)
		if result != "ok":
			SweetLogger.error("spawn validation failed: {0}", [result], SCRIPT_NAME, "apply")
			continue
		
		entity_handler.apply_spawn(entity_data)
#===================================================================================#
