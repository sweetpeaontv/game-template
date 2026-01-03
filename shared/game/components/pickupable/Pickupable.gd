extends Node

enum PickupState { FREE, HELD }

@export var hold_offset: Transform3D = Transform3D.IDENTITY

var state: PickupState = PickupState.FREE
var holder: Node3D = null

func set_held(new_holder: Node3D) -> void:
	holder = new_holder
	state = PickupState.HELD

func set_free() -> void:
	state = PickupState.FREE
	holder = null
