class_name ClientRelay
extends Node
"""
Client-side message transport: submit requests to the server, receive deliveries, forward to MessageBus.
Does not validate or apply authoritative state — ServerRelay and subscribers own that.
"""

const SCRIPT_NAME := "ClientRelay"

var _next_request_id: int = 1
var _pending_requests: Dictionary = {}  # request_id -> Variant rollback snapshot (TODO)

# PUBLIC API
#===================================================================================#
func make_request(command: CommandRegistry.Command, payload: Payload) -> void:
	var message := _build_request_message(command, payload)
	send_message(message)

func send_message(message: Message, rollback_snapshot: Variant = null) -> void:
	if message.type != Message.MessageType.REQUEST:
		SweetLogger.warning("submit_message expects REQUEST", [], SCRIPT_NAME, "submit_message")
		return

	if rollback_snapshot != null:
		_pending_requests[message.request_id] = rollback_snapshot

	var packed := message.serialize()

	Gnet.execute_or_request(
		func(): ServerManager.handle_client_message(packed),
		func(): ServerManager.handle_client_message.rpc_id(Gnet.server_peer_id(), packed),
	)
#===================================================================================#

# INBOUND (server → client)
#===================================================================================#
@rpc("authority", "call_remote", "reliable")
func _receive_message(packed: Dictionary) -> void:
	var message := Message.deserialize(packed)
	if message == null:
		SweetLogger.warning("failed to unpack delivered message", [], SCRIPT_NAME, "_deliver_message")
		return

	_on_message_received(message)
#===================================================================================#

# PRIVATE
#===================================================================================#
func _on_message_received(message: Message) -> void:
	match message.type:
		Message.MessageType.NOTIFY:
			_apply_command(message)
		Message.MessageType.CONFIRM:
			_clear_pending(message.request_id)
		Message.MessageType.REJECT:
			_handle_rejection(message)
		_:
			pass

func _apply_command(message: Message) -> void:
	var handler: CommandHandler = CommandRegistry.get_handler(message.command)
	if handler:
		handler.apply(message)

func _handle_rejection(message: Message) -> void:
	var _rollback_snapshot: Variant = _pending_requests.get(message.request_id)
	_clear_pending(message.request_id)
	# TODO: revert optimistic state using _rollback_snapshot
	SweetLogger.info(
		"request {0} rejected",
		[message.request_id],
		SCRIPT_NAME,
		"_handle_rejection",
	)
#===================================================================================#

# HELPERS
#===================================================================================#
func _build_request_message(command: CommandRegistry.Command, payload: Payload) -> Message:
	var peer_id := _get_local_peer_id()
	return Message.new(
		peer_id,
		Time.get_unix_time_from_system(),
		Message.MessageType.REQUEST,
		command,
		payload,
		_generate_request_id(),
	)

func _clear_pending(request_id: int) -> void:
	_pending_requests.erase(request_id)

func _generate_request_id() -> int:
	var id := _next_request_id
	_next_request_id += 1
	return id

func _get_local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
#===================================================================================#
