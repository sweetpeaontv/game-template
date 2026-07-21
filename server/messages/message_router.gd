class_name MessageRouter
extends Node

const SCRIPT_NAME := "MessageRouter"
const IS_VERBOSE := true

var _server_relay: ServerRelay

# INIT
#===================================================================================#
func setup(server_relay_ref: ServerRelay) -> void:
	_server_relay = server_relay_ref
	_server_relay.client_message_received.connect(route)
#===================================================================================#

# PROCESS
#===================================================================================#
func process() -> void:
	flush_dirty_sync_states()
#===================================================================================#

# ROUTING
#===================================================================================#
func route(message: Message) -> void:
	var shape_err := message.payload.validate_shape()
	if shape_err != "ok":
		if IS_VERBOSE:
			SweetLogger.warning("message payload invalid", [message.command, shape_err], SCRIPT_NAME, "route")
		_reject(message, shape_err)
		return

	var handler: CommandHandler = CommandRegistry.get_handler(message.command)
	if handler == null:
		_reject(message, "command not present in command registry")
		return

	var sem_err := handler.validate(message)
	if sem_err != "ok":
		_reject(message, sem_err, handler)
		return

	var deliveries: Array[Delivery] = handler.accept_response(message)
	_server_relay.deliver(deliveries)

func notify(command: CommandRegistry.Command, payload: Payload, audience: Delivery.Audience, peers: PackedInt32Array = []) -> void:
	var new_message: Message = Message.new(
		Gnet.server_peer_id(),
		int(Time.get_unix_time_from_system()),
		Message.MessageType.NOTIFY,
		command,
		payload,
	)
	_server_relay.deliver([Delivery.new(new_message, audience, peers)])

func _reject(request: Message, reason: String, handler: CommandHandler = null) -> void:
	if IS_VERBOSE:
		SweetLogger.warning("rejecting {0} — {1}",
			[CommandRegistry.Command.keys()[request.command], reason], SCRIPT_NAME, "_reject")

	if handler != null:
		var reject_deliveries: Array[Delivery] = handler.reject_response(request, reason)
		_server_relay.deliver(reject_deliveries)
		return
	
	# TODO: carry `reason` in a payload so the client can show/log it
	var reject := _build_response(request, Message.MessageType.REJECT, null)
	_server_relay.deliver([Delivery.new(reject, Delivery.Audience.ACTOR)])
#===================================================================================#

# HELPERS
#===================================================================================#
func _build_response(request: Message, type: Message.MessageType, payload: Payload) -> Message:
	return Message.new(
		multiplayer.get_unique_id(),
		int(Time.get_unix_time_from_system()),
		type,
		request.command,
		payload,
		request.actor_peer_id,
		request.request_id,
	)
#===================================================================================#

# SYNC STATE
#===================================================================================#
func flush_dirty_sync_states() -> void:
	if not Gnet.is_authority():
		return

	var updates: Array = RegistryLibrary.sync_targets.collect_dirty_sync_targets()
	for update in updates:
		var node: SyncStateNode = RegistryLibrary.sync_targets.get_entry(update["target_key"]) as SyncStateNode
		if node != null:
			node.is_dirty = false

	if updates.is_empty():
		return

	notify(
		CommandRegistry.Command.SYNC_STATE,
		Payload.SyncState.create(updates),
		Delivery.Audience.OTHERS,
	)
#===================================================================================#
