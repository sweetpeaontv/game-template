class_name CameraInput extends BaseNetInput

@export var camera_manager: CameraManager
@export var rollback_synchronizer: RollbackSynchronizer

var camera_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)

func _gather() -> void:
	if not is_multiplayer_authority():
		return
	camera_basis = get_camera_rotation_basis()

func _input(event) -> void:
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)

func _rotate_camera(relative: Vector2) -> void:
	camera_manager.add_look_delta(relative)

func get_camera_rotation_basis() -> Basis:
	return camera_manager.get_look_basis()

func _exit_tree() -> void:
	NetworkTime.before_tick_loop.disconnect(_gather)
