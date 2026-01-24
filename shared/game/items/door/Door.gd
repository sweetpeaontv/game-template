extends Node3D

@onready var door_model: Node3D = $"door-model"
@onready var interactable: Interactable = $"door-model/DoorPivot/Openable"
@onready var door_pivot: Node3D = $"door-model/DoorPivot"
@onready var handle_pivot: Node3D = $"door-model/DoorPivot/HandlePivot"

var closed_rotation: Vector3 = Vector3.ZERO
var door_open_rotation: Vector3 = Vector3(0.0, deg_to_rad(100.0), 0.0)
var handle_open_rotation: Vector3 = Vector3(0.0, 0.0, deg_to_rad(25.0))

func _ready() -> void:
	interactable.add_animation_target(door_pivot, door_open_rotation, closed_rotation, 0.5)
	interactable.add_animation_target(handle_pivot, handle_open_rotation, closed_rotation, 0.3)
