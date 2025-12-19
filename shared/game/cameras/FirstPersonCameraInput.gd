class_name FirstPersonCameraInput extends BaseNetInput

@export var camera_mount : Node3D
@export var camera_rot : Node3D
@export var camera_3D : Camera3D
@export var rollback_synchronizer : RollbackSynchronizer
@export var player : CharacterBody3D

var camera_basis : Basis = Basis.IDENTITY

const SENSITIVITY = 0.04
const CAMERA_X_ROT_MIN = deg_to_rad(-40)
const CAMERA_X_ROT_MAX = deg_to_rad(60)

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)
	camera_3D.set_player(player)

func _gather() -> void:
	camera_basis = get_camera_rotation_basis()

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative * SENSITIVITY)

func rotate_camera(move: Vector2):
	if move != Vector2.ZERO:
		camera_mount.rotate_y(-move.x * SENSITIVITY)
		camera_rot.rotate_x(-move.y * SENSITIVITY)
		camera_rot.rotation.x = clamp(camera_rot.rotation.x, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)

func get_camera_rotation_basis() -> Basis:
	return camera_mount.global_transform.basis

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather)
