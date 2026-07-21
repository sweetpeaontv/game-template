class_name Message
extends RefCounted

enum MessageType {
	REQUEST,		## Client -> server: proposes a state change; not authoritative until confirmed.
	CONFIRM,		## Server -> peers: change accepted; payload is the authoritative state.
	REJECT,			## Server -> sender only: change denied; shared world state is unchanged.
	NOTIFY,			## Server -> peers: pushes state without a prior client request.
}

var actor_peer_id: int
var timestamp: int
var type: MessageType
var command: CommandRegistry.Command
var payload: Payload
var request_id: int
var response_id: int

func _init(
	p_actor_peer_id: int,
	p_timestamp: int,
	p_type: MessageType, 
	p_command: CommandRegistry.Command,
	p_payload: Payload = null, 
	p_request_id: int = -1, 
	p_response_id: int = -1,
) -> void:
	if p_actor_peer_id == 0:
		SweetLogger.error("Message: Actor peer ID cannot be 0")
		return
	
	type = p_type
	command = p_command
	payload = p_payload
	actor_peer_id = p_actor_peer_id
	request_id = p_request_id
	response_id = p_response_id
	timestamp = p_timestamp

func serialize() -> Dictionary:
	return {
		"actor_peer_id": actor_peer_id,
		"timestamp": timestamp,
		"type": type,
		"command": command,
		"payload": payload.serialize() if payload else {},
		"request_id": request_id,
		"response_id": response_id,
	}

static func deserialize(d: Dictionary) -> Message:
	return Message.new(
		d["actor_peer_id"],
		d["timestamp"],
		d["type"],
		d["command"],
		Payload.deserialize(d["command"], d["payload"]),
		d["request_id"],
		d["response_id"],
	)
