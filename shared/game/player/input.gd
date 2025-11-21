extends BaseNetInput
class_name PlayerInput

var movement: Vector3 = Vector3.ZERO

func _gather():
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
