class_name SessionEndHandler
extends CommandHandler

const SCRIPT_NAME := "SessionEndHandler"

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	# check if session is active and if actor is the host
	if not Gnet.is_authority():
		return "actor is not the host"
	if not Gnet.is_in_session():
		return "session is not active"
	if not message.actor_peer_id == Gnet.server_peer_id():
		return "actor is not the host"
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
	ClientManager.disconnect_game()
#===================================================================================#
