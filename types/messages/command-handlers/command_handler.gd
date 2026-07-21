# server/messages/handlers/command_handler.gd
class_name CommandHandler
extends RefCounted

## Semantic validation: registry existence, ownership, ranges, game state.
## Returns "" (or a Result) when allowed, else a reason. Runs AFTER payload.validate_shape().
func validate(_message: Message) -> String:
	return ""

## Build the deliveries to deliver the confirm response to the clients.
func accept_response(_message: Message) -> Array[Delivery]:
	return []

## Build the deliveries to deliver the rejection response to the clients.
func reject_response(_message: Message, _reason: String) -> Array[Delivery]:
	var reject = Message.new(
		Gnet.server_peer_id(),
		int(Time.get_unix_time_from_system()),
		Message.MessageType.REJECT,
		_message.command,
		_message.payload,
		_message.actor_peer_id,
		_message.request_id,
	)
	return [Delivery.new(reject, Delivery.Audience.ACTOR)]

## Mutate authoritative state and return the response Message to deliver (CONFIRM/NOTIFY),
## or null to fall back to a generic confirm.
func apply(_message: Message) -> void:
	return

func _build_response(request: Message, type: Message.MessageType, payload: Payload) -> Message:
	return Message.new(
		request.actor_peer_id,
		int(Time.get_unix_time_from_system()),
		type,
		request.command,
		payload,
		request.request_id,
		1,
	)