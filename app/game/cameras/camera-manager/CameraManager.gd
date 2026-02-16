extends Node3D
class_name CameraManager

enum RigType {
	FIRST_PERSON,
	THIRD_PERSON,
	EXAMINE,
	TRANSITION,
}

enum FollowMode {
	POSITION_ONLY,
	FULL_TRANSFORM,
}

@export var follow_speed: float = 12.0
@export var rotate_speed: float = 12.0
@export var active_rig: RigType = RigType.FIRST_PERSON

var _previous_rig: RigType = active_rig
var _transition_target: Node3D = null
var _target_rig: RigType = RigType.EXAMINE
var _transition_use_stored_transform := false
var _transition_stored_transform := Transform3D()
const EXAMINE_TRANSITION_THRESHOLD := 0.005

# First-person rig refs
@onready var _fp_root: Node3D = $Rigs/FirstPerson/RigRoot
@onready var _fp_yaw: Node3D = $Rigs/FirstPerson/RigRoot/CameraMount
@onready var _fp_pitch: Node3D = $Rigs/FirstPerson/RigRoot/CameraMount/CameraRotation
@onready var _fp_cam: Camera3D = $Rigs/FirstPerson/RigRoot/CameraMount/CameraRotation/SpringArm3D/Camera3D

# Third-person rig refs
@onready var _tp_root: Node3D = $Rigs/ThirdPerson/RigRoot
@onready var _tp_yaw: Node3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot
@onready var _tp_pitch: Node3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot/PitchPivot
@onready var _tp_cam: Camera3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot/PitchPivot/SpringArm3D/Camera3D

# Examine rig refs
@onready var _examine_root: Node3D = $Rigs/Examine/RigRoot
@onready var _examine_cam: Camera3D = $Rigs/Examine/RigRoot/Camera3D

# Transition rig refs
@onready var _transition_root: Node3D = $Rigs/Transition/RigRoot
@onready var _transition_cam: Camera3D = $Rigs/Transition/RigRoot/Camera3D

# Active rig pointers
var _active_root: Node3D
var _active_yaw: Node3D
var _active_pitch: Node3D
var _active_cam: Camera3D

var _follow_target: Node3D
var _follow_mode: FollowMode = FollowMode.POSITION_ONLY

var _fp_yaw_val := 0.0
var _fp_pitch_val := 0.0

var _tp_yaw_val := 0.0
var _tp_pitch_val := 0.0
var _tp_orbit_target: Node3D
var _tp_orbit_offset: Vector3 = Vector3.ZERO

var _is_local: bool = false
var _fp_follow_anchor: Node3D
var _tp_follow_anchor: Node3D

# SETUP
#===================================================================================#
func _ready() -> void:
	set_active_rig(active_rig, true)

func set_active_rig(rig: RigType, instant: bool = false) -> void:
	active_rig = rig

	match rig:
		RigType.FIRST_PERSON:
			_active_root = _fp_root
			_active_yaw = _fp_yaw
			_active_pitch = _fp_pitch
			_active_cam = _fp_cam
		RigType.THIRD_PERSON:
			_active_root = _tp_root
			_active_yaw = _tp_yaw
			_active_pitch = _tp_pitch
			_active_cam = _tp_cam
		RigType.EXAMINE:
			_active_root = _examine_root
			_active_yaw = _examine_root
			_active_pitch = _examine_root
			_active_cam = _examine_cam
		RigType.TRANSITION:
			_active_root = _transition_root
			_active_yaw = _transition_root
			_active_pitch = _transition_root
			_active_cam = _transition_cam

	if _is_local:
		_fp_cam.current = (rig == RigType.FIRST_PERSON)
		_tp_cam.current = (rig == RigType.THIRD_PERSON)
		_examine_cam.current = (rig == RigType.EXAMINE)
		_transition_cam.current = (rig == RigType.TRANSITION)

	_apply_active_look()

	if (rig == RigType.FIRST_PERSON or rig == RigType.THIRD_PERSON) and instant and _follow_target != null:
		_active_root.global_transform = _follow_target.global_transform

func _apply_active_look() -> void:
	match active_rig:
		RigType.FIRST_PERSON:
			_active_yaw.rotation.y = _fp_yaw_val
			_active_pitch.rotation.x = _fp_pitch_val
		RigType.THIRD_PERSON:
			_active_yaw.rotation.y = _tp_yaw_val
			_active_pitch.rotation.x = _tp_pitch_val
#===================================================================================#

# API
#===================================================================================#
func bind_subject(
	is_local: bool,
	fp_anchor: Node3D,
	tp_anchor: Node3D,
	start_rig: RigType,
	instant: bool = true
) -> void:
	_is_local = is_local
	_fp_follow_anchor = fp_anchor
	_tp_follow_anchor = tp_anchor

	set_local_enabled(_is_local)
	set_mode(start_rig, instant)

func set_local_enabled(is_local: bool) -> void:
	_is_local = is_local

	# Disable all camera ownership if not local
	if not _is_local:
		_fp_cam.current = false
		_tp_cam.current = false
		_examine_cam.current = false
		set_process(false)
		set_physics_process(false)
		return

	# Local: manager runs, and active rig camera becomes current
	set_process(true)
	set_physics_process(false)

	# `set_active_rig` will set the correct `current` camera
	set_active_rig(active_rig, true)

func set_mode(rig: RigType, instant: bool = false) -> void:
	set_active_rig(rig, instant)

	match rig:
		RigType.FIRST_PERSON:
			if _fp_follow_anchor != null:
				set_follow(_fp_follow_anchor, FollowMode.POSITION_ONLY, instant)
		RigType.THIRD_PERSON:
			if _tp_follow_anchor != null:
				# If your TP follow anchor is an orbit-center anchor, FULL_TRANSFORM is usually wrong.
				# Use POSITION_ONLY unless you specifically authored a rotation to follow.
				set_follow(_tp_follow_anchor, FollowMode.POSITION_ONLY, instant)

func set_follow(target_anchor: Node3D, mode: FollowMode, instant: bool = false) -> void:
	_follow_target = target_anchor
	_follow_mode = mode
	if instant and _follow_target != null:
		_active_root.global_transform = _follow_target.global_transform

func set_look(yaw: float, pitch: float) -> void:
	match active_rig:
		RigType.FIRST_PERSON:
			_fp_yaw_val = yaw
			_fp_pitch_val = pitch
			_active_yaw.rotation.y = _fp_yaw_val
			_active_pitch.rotation.x = _fp_pitch_val
		RigType.THIRD_PERSON:
			_tp_yaw_val = yaw
			_tp_pitch_val = pitch
			_active_yaw.rotation.y = _tp_yaw_val
			_active_pitch.rotation.x = _tp_pitch_val

func get_look_basis() -> Basis:
	return _active_pitch.global_transform.basis

func get_camera() -> Camera3D:
	return _active_cam

func set_third_person_orbit_target(target: Node3D, offset: Vector3) -> void:
	_tp_orbit_target = target
	_tp_orbit_offset = offset

func set_third_person_distance(distance: float) -> void:
	# Guard in case you ever restructure paths or temporarily remove the arm
	var arm := _tp_cam.get_parent() as SpringArm3D
	if arm != null:
		arm.spring_length = distance
#===================================================================================#

# APPLICATION
#===================================================================================#
func transition_to(target_rig: RigType = RigType.EXAMINE, anchor: Node3D = null) -> void:
	_previous_rig = active_rig
	_transition_target = anchor
	_target_rig = target_rig
	# temp fix, looking for better solution
	_transition_use_stored_transform = false

	# this is still wrong. we need to find out why we aren't getting exact matches
	match target_rig:
		RigType.FIRST_PERSON:
			_transition_use_stored_transform = true
			_fp_root.global_transform = _fp_follow_anchor.global_transform
			_fp_yaw.rotation.y = _fp_yaw_val
			_fp_pitch.rotation.x = _fp_pitch_val
			_transition_stored_transform = _fp_cam.global_transform
			_transition_target = null
		RigType.THIRD_PERSON:
			_transition_use_stored_transform = true
			_tp_root.global_transform = _tp_follow_anchor.global_transform
			_tp_yaw.rotation.y = _tp_yaw_val
			_tp_pitch.rotation.x = _tp_pitch_val
			_transition_stored_transform = _tp_cam.global_transform
			_transition_target = null
		_:
			_transition_target = anchor

	if target_rig == RigType.EXAMINE:
		_examine_root.global_transform = anchor.global_transform
	
	_transition_root.global_transform = _active_cam.global_transform

	set_active_rig(RigType.TRANSITION, false)

func _apply_target_transform(_t: float) -> void:
	if _follow_target == null:
		return
	_active_root.global_transform = _follow_target.global_transform

func _player_camera_process(delta: float) -> void:
	'''Follow the player's FP/TP camera anchor.'''
	if _tp_orbit_target != null:
		_tp_root.global_position = _tp_orbit_target.global_position + _tp_orbit_offset
	
	if _follow_target == null:
		return

	var t_pos := 1.0 - exp(-follow_speed * delta)
	var t_rot := 1.0 - exp(-rotate_speed * delta)

	var from := _active_root.global_transform
	var to := _follow_target.global_transform

	from.origin = from.origin.lerp(to.origin, t_pos)

	if _follow_mode == FollowMode.FULL_TRANSFORM:
		var q_from := from.basis.get_rotation_quaternion()
		var q_to := to.basis.get_rotation_quaternion()
		var q := q_from.slerp(q_to, t_rot)
		from.basis = Basis(q)

	_active_root.global_transform = from

func _examine_process(delta: float) -> void:
	pass

func _transition_process(delta: float) -> void:
	#var t_pos := 1.0 - exp(-follow_speed * delta)
	#var t_rot := 1.0 - exp(-rotate_speed * delta)
	var t_pos := clampf(follow_speed * delta, 0.0, 1.0)
	var t_rot := clampf(rotate_speed * delta, 0.0, 1.0)

	var from := _transition_root.global_transform
	var to: Transform3D
	var target_origin: Vector3
	# temp fix, looking for better solution
	if _transition_use_stored_transform:
		to = _transition_stored_transform
		target_origin = _transition_stored_transform.origin
	else:
		to = _transition_target.global_transform
		target_origin = _transition_target.global_position

	from.origin = from.origin.lerp(to.origin, t_pos)
	var q_from := from.basis.get_rotation_quaternion()
	var q_to := to.basis.get_rotation_quaternion()
	if q_from.dot(q_to) < 0.0:
		q_to = Quaternion(-q_to.x, -q_to.y, -q_to.z, -q_to.w)
	from.basis = Basis(q_from.slerp(q_to, t_rot))

	_transition_root.global_transform = from

	var dist := _transition_root.global_position.distance_to(target_origin)
	if dist < EXAMINE_TRANSITION_THRESHOLD:
		set_active_rig(_target_rig, true)
		_transition_target = null
		_transition_use_stored_transform = false

func _process(delta: float) -> void:
	match active_rig:
		RigType.EXAMINE:
			_examine_process(delta)
		RigType.TRANSITION:
			_transition_process(delta)
		_:
			_player_camera_process(delta)
#===================================================================================#
