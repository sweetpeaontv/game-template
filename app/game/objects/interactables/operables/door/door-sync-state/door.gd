extends Node3D

@onready var interactable: Operable = $"door-model/DoorPivot/Operable"
@onready var door_pivot: Node3D = $"door-model/DoorPivot"
@onready var handle_pivot: Node3D = $"door-model/DoorPivot/HandlePivot"
@onready var door_collision: CollisionShape3D = $"door-model/DoorCollision/CollisionShape3D"

var closed_rotation: Vector3 = Vector3.ZERO
var door_open_rotation: Vector3 = Vector3(0.0, deg_to_rad(100.0), 0.0)
var handle_open_rotation: Vector3 = Vector3(0.0, 0.0, deg_to_rad(25.0))

func _ready() -> void:
	interactable.animator.add_animation_target(door_pivot, {
		&"Closed": closed_rotation,
		&"Open": door_open_rotation,
	}, 0.5)
	interactable.animator.add_animation_target(door_collision, {
		&"Closed": closed_rotation,
		&"Open": door_open_rotation,
	}, 0.5)
	interactable.animator.add_animation_target(handle_pivot, {
		&"Closed": closed_rotation,
		&"Open": handle_open_rotation,
	}, 0.3)
