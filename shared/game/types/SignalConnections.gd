class_name SignalConnections
extends RefCounted

var signal_source: Node = null
var signal_callable: Callable = func(): pass
var target_method: Callable = func(): pass

func _init(new_signal_source: Node, new_signal_callable: Callable, new_target_method: Callable):
	signal_source = new_signal_source
	signal_callable = new_signal_callable
	target_method = new_target_method

func connect_signal() -> void:
	signal_source.signal_callable.connect(target_method)

func disconnect_signal() -> void:
	signal_source.signal_callable.disconnect(target_method)

func is_signal_connected() -> bool:
	return signal_source.signal_callable.is_connected(target_method)

func get_signal_source() -> Node:
	return signal_source