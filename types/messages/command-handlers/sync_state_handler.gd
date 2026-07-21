class_name SyncStateHandler
extends CommandHandler

const SCRIPT_NAME := "SyncStateHandler"

# VALIDATE
#===================================================================================#
func validate(_message: Message) -> String:
	return "ok"
#===================================================================================#

# ACCEPT
#===================================================================================#
func accept_response(_message: Message) -> Array[Delivery]:
	return [
		
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
	var payload: Payload.SyncState = message.payload
	for update in payload.updates:
		var target = RegistryLibrary.sync_targets.get_entry(update.target_key)
		if target == null: 
			SweetLogger.error("sync target not found: {0}", [update.target_key], SCRIPT_NAME, "apply")
			continue
		target.apply_wire_state(update.state)
#===================================================================================#
