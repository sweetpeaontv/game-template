class_name ServerRelay
extends Node
"""
Server-side message ingress and egress. Clients submit packed Messages via RPC;
validated handlers apply state and call deliver_message to push results to peers.
"""

const SCRIPT_NAME: String = "ServerRelay"
const IS_VERBOSE: bool = false

signal client_message_received(message: Message)

func _handle_client_message(packed: Dictionary) -> void:
	if not multiplayer.is_server():
		SweetLogger.warning("ServerRelay: not server, skipping message", [], SCRIPT_NAME, "_handle_client_message")
		return

	var message := Message.deserialize(packed)
	if message == null:
		SweetLogger.warning("ServerRelay: failed to unpack client message", [], SCRIPT_NAME, "_handle_client_message")
		return

	client_message_received.emit(message)

func deliver(deliveries: Array[Delivery]) -> void:
	if not multiplayer.is_server():
		return
	for delivery in deliveries:
		if IS_VERBOSE:
			SweetLogger.info("distributing delivery", [], SCRIPT_NAME, "_distribute")
		_distribute(delivery)

func _distribute(delivery: Delivery) -> void:
	var packed := delivery.message.serialize()
	for peer in _resolve_peers(delivery):
		# could potentially use Gnet.execute_or_request here instead of the if/else
		if peer == Gnet.server_peer_id():
			# Deliver locally to host
			ClientManager.client_relay._receive_message(packed)
		else:
			ClientManager.client_relay._receive_message.rpc_id(peer, packed)

func _resolve_peers(delivery: Delivery) -> PackedInt32Array:
	match delivery.audience:
		Delivery.Audience.ACTOR:
			return [delivery.message.actor_peer_id]
		Delivery.Audience.OTHERS:
			var peers := multiplayer.get_peers()
			peers.append(Gnet.server_peer_id())
			peers.erase(delivery.message.actor_peer_id)
			return peers
		Delivery.Audience.ALL:
			var peers := multiplayer.get_peers()
			peers.append(Gnet.server_peer_id())
			return peers
		Delivery.Audience.TARGETED:
			return delivery.peers
	return []
