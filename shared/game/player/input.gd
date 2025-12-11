extends BaseNetInput
class_name PlayerInput

@onready var head: Node3D = $"../CameraHead"
@onready var camera: Camera3D = $"../CameraHead/Camera3D"

var movement: Vector3 = Vector3.ZERO
var mouse_movement: Vector2 = Vector2.ZERO
var mouse_delta: Vector2 = Vector2.ZERO

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		mouse_delta += event.relative

func _gather():
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)

	mouse_movement = mouse_delta
	mouse_delta = Vector2.ZERO
