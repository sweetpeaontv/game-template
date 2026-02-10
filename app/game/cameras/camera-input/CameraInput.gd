class_name CameraInput extends BaseNetInput

@export var camera_manager: CameraManager
@export var rollback_synchronizer: RollbackSynchronizer
@export var player: CharacterBody3D

# Third-person defaults
@export var tp_default_distance: float = 4.0
@export var tp_orbit_center_offset: Vector3 = Vector3(0.0, 1.6, 0.0)

var camera_basis: Basis = Basis.IDENTITY

# Per-mode look state (CameraManager also stores per-rig, but we keep local for clamping math)
var _fp_yaw := 0.0
var _fp_pitch := 0.0
var _tp_yaw := 0.0
var _tp_pitch := deg_to_rad(-20.0)

const FP_SENSITIVITY := 0.004
const FP_PITCH_MIN := deg_to_rad(-60.0)
const FP_PITCH_MAX := deg_to_rad(60.0)

const TP_SENSITIVITY := 0.04
const TP_PITCH_MIN := deg_to_rad(-20.0)
const TP_PITCH_MAX := deg_to_rad(20.0)

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)

	# FP follow anchor setup
	var fp_anchor := player.get_node_or_null("CameraAnchorFP") as Node3D
	if fp_anchor != null:
		camera_manager.set_follow(fp_anchor, CameraManager.FollowMode.POSITION_ONLY, true)

	# TP orbit setup (CameraManager keeps TP RigRoot at orbit target position)
	camera_manager.set_third_person_orbit_target(player, tp_orbit_center_offset)
	camera_manager.set_third_person_distance(tp_default_distance)

	# Ensure camera knows its player (your Camera.gd expects this)
	camera_manager.get_camera().set_player(player)

	# Initialize look for whichever rig is currently active
	_apply_current_mode_look(true)

func set_mode(rig: CameraManager.RigType, instant: bool = false) -> void:
	camera_manager.set_active_rig(rig, instant)
	_apply_current_mode_look(true)

func _apply_current_mode_look(apply_to_manager: bool) -> void:
	var rig := camera_manager.active_rig
	if rig == CameraManager.RigType.FIRST_PERSON:
		_fp_pitch = clamp(_fp_pitch, FP_PITCH_MIN, FP_PITCH_MAX)
		if apply_to_manager:
			camera_manager.set_look(_fp_yaw, _fp_pitch)
	else:
		_tp_pitch = clamp(_tp_pitch, TP_PITCH_MIN, TP_PITCH_MAX)
		if apply_to_manager:
			camera_manager.set_look(_tp_yaw, _tp_pitch)

func _gather() -> void:
	if not is_multiplayer_authority():
		return
	camera_basis = get_camera_rotation_basis()

func _input(event) -> void:
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)

func _rotate_camera(relative: Vector2) -> void:
	if relative == Vector2.ZERO:
		return

	var rig := camera_manager.active_rig
	if rig == CameraManager.RigType.FIRST_PERSON:
		var move := relative * FP_SENSITIVITY
		_fp_yaw -= move.x
		_fp_pitch = clamp(_fp_pitch - move.y, FP_PITCH_MIN, FP_PITCH_MAX)
		camera_manager.set_look(_fp_yaw, _fp_pitch)
	else:
		var move := relative * TP_SENSITIVITY
		_tp_yaw -= move.x
		_tp_pitch = clamp(_tp_pitch - move.y, TP_PITCH_MIN, TP_PITCH_MAX)
		camera_manager.set_look(_tp_yaw, _tp_pitch)

func get_camera_rotation_basis() -> Basis:
	return camera_manager.get_look_basis()

func _exit_tree() -> void:
	NetworkTime.before_tick_loop.disconnect(_gather)
