class_name SceneChangeHandler
extends CommandHandler

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	var payload: Payload.SceneChange = message.payload
	if payload == null:
		return "no payload"
	if payload.scene_name.is_empty():
		return "scene name is empty"
	if not SceneManager.has_scene(payload.scene_name):
		return "scene not found: " + payload.scene_name
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
				Message.MessageType.NOTIFY, 
				message.command, 
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			), 
			Delivery.Audience.ACTOR
		),
	]
#===================================================================================#

# REJECT RESPONSE
#===================================================================================#
#func reject_response(message: Message) -> Array[Delivery]:
#	return [
#		
#	]
#===================================================================================#

# APPLY
#===================================================================================#
func apply(message: Message) -> void:
	SceneManager.goto_scene(message.payload.scene_name)
#===================================================================================#