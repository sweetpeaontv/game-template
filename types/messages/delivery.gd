class_name Delivery
extends RefCounted

enum Audience { ACTOR, OTHERS, ALL, TARGETED }

var message: Message
var audience: Audience
var peers: PackedInt32Array

func _init(p_message: Message, p_audience: Audience, p_peers: PackedInt32Array = []) -> void:
	message = p_message
	audience = p_audience
	peers = p_peers