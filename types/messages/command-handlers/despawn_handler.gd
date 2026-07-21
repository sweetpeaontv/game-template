class_name DespawnHandler
extends CommandHandler

const SCRIPT_NAME := "DespawnHandler"

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	# could filter out failures and still pass along valid despawns since despawns can be batched
	for despawn in message.payload.despawns:
		if not despawn.has("entity_type"):
			return "despawn missing required field 'entity_type'"
		if not EntityTypeRegistry.has_entity_type(despawn["entity_type"]):
			return "invalid despawn type: " + EntityTypeRegistry.EntityType.keys()[despawn["entity_type"]]
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
	SweetLogger.info("applying despawn command", [], SCRIPT_NAME, "apply")

	var payload: Payload.Despawn = message.payload

	for despawn in payload.despawns:
		var entity_type = despawn["entity_type"]
		var entity_data = despawn["data"]
		var entity_handler = EntityTypeRegistry.get_handler(entity_type)

		var result = entity_handler.validate_despawn(entity_data)
		if result != "ok":
			SweetLogger.error("spawn validation failed: {0}", [result], SCRIPT_NAME, "apply")
			continue
		
		entity_handler.apply_despawn(entity_data)
#===================================================================================#
