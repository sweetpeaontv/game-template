extends BaseNetInput
class_name PlayerInput

var movement: Vector3 = Vector3.ZERO
var shift: bool = false

func _ready():
	NetworkTime.before_tick_loop.connect(_gather)

func _gather():
	movement = Vector3(
		Input.get_axis("left", "right"),
		Input.get_action_strength("jump"),
		Input.get_axis("forward", "back"),
	)

	shift = Input.is_action_pressed("shift")

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather)
