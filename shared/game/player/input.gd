extends BaseNetInput
class_name PlayerInput

@onready var head: Node3D = $"../CameraHead"
@onready var camera: Camera3D = $"../CameraHead/Camera3D"
@onready var player:= $".."

var movement: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var shift: bool = false

func _gather():
	movement = Vector3(
		Input.get_axis("left", "right"),
		Input.get_action_strength("jump"),
		Input.get_axis("forward", "back"),
	)

	shift = Input.is_action_pressed("shift")

	direction = (head.transform.basis * player.transform.basis * Vector3(movement.x, 0, movement.z)).normalized()
