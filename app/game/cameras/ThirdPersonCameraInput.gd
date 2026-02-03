class_name ThirdPersonCameraInput extends BaseNetInput

@export var orbit_pivot : Node3D
@export var pitch_pivot : Node3D
@export var spring_arm : SpringArm3D
@export var camera_3D : Camera3D
@export var rollback_synchronizer : RollbackSynchronizer
@export var player : CharacterBody3D

# DEFAULTS
const DEFAULT_DISTANCE := 4.0
const DEFAULT_YAW := 0.0
const DEFAULT_PITCH := deg_to_rad(-20.0)
const ORBIT_CENTER_OFFSET := Vector3(0.0, 1.6, 0.0)

var camera_basis : Basis = Basis.IDENTITY
var camera_yaw : float = 0.0
var camera_pitch : float = 0.0

const SENSITIVITY = 0.04
const CAMERA_X_ROT_MIN = deg_to_rad(-20)
const CAMERA_X_ROT_MAX = deg_to_rad(20)

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)

	camera_yaw = DEFAULT_YAW
	camera_pitch = DEFAULT_PITCH

	orbit_pivot.global_position = player.global_position + ORBIT_CENTER_OFFSET

	orbit_pivot.rotation.y = camera_yaw
	pitch_pivot.rotation.x = camera_pitch

	if spring_arm != null:
		spring_arm.spring_length = DEFAULT_DISTANCE

func get_camera_path() -> String:
	return "ThirdPersonCameraInput/OrbitPivot/PitchPivot/SpringArm3D/Camera3D"

func _gather() -> void:
	camera_basis = get_camera_rotation_basis()

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative * SENSITIVITY)

func rotate_camera(move: Vector2):
	if move == Vector2.ZERO:
		return

	camera_yaw -= move.x
	camera_pitch = clamp(camera_pitch - move.y, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)

	orbit_pivot.rotation.y = camera_yaw
	pitch_pivot.rotation.x = camera_pitch

func get_camera_rotation_basis() -> Basis:
	return orbit_pivot.global_transform.basis

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather)
