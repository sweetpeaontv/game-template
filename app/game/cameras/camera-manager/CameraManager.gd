extends Node3D
class_name CameraManager

enum RigType {
	FIRST_PERSON,
	THIRD_PERSON,
	EXAMINE,
}

enum CameraState {
	FIRST_PERSON,
	THIRD_PERSON,
	EXAMINE,
	TRANSITION,
}

enum FollowMode {
	POSITION_ONLY,
	FULL_TRANSFORM,
}

@export var player: CharacterBody3D

@export var follow_speed: float = 20.0
@export var rotate_speed: float = 20.0

var _transition_target: Node3D = null

const TRANSITION_THRESHOLD := 0.025

const FP_SENSITIVITY := 0.004
const FP_PITCH_MIN := deg_to_rad(-60.0)
const FP_PITCH_MAX := deg_to_rad(60.0)

const TP_SENSITIVITY := 0.04
const TP_PITCH_MIN := deg_to_rad(-20.0)
const TP_PITCH_MAX := deg_to_rad(20.0)

var _examine_anchor_stack: Array[Node3D] = []

# CAMERA
@onready var _camera: Camera3D = $Camera3D
@onready var active_rig: RigType = RigType.FIRST_PERSON
@onready var camera_state: CameraState = CameraState.FIRST_PERSON

# LOOK INPUT
var _look_input_enabled: bool = true

# First-person rig refs
@onready var _fp_root: Node3D = $Rigs/FirstPerson/RigRoot
@onready var _fp_yaw: Node3D = $Rigs/FirstPerson/RigRoot/CameraMount
@onready var _fp_pitch: Node3D = $Rigs/FirstPerson/RigRoot/CameraMount/CameraRotation
@onready var _fp_cam_transform: Node3D = $Rigs/FirstPerson/RigRoot/CameraMount/CameraRotation/CameraTransform

# Third-person rig refs
@onready var _tp_root: Node3D = $Rigs/ThirdPerson/RigRoot
@onready var _tp_yaw: Node3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot
@onready var _tp_pitch: Node3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot/PitchPivot
@onready var _tp_cam_transform: Node3D = $Rigs/ThirdPerson/RigRoot/OrbitPivot/PitchPivot/SpringArm3D/CameraTransform

# TP Orbit defaults
@export var tp_default_distance: float = 4.0
@export var tp_orbit_center_offset: Vector3 = Vector3(0.0, 1.6, 0.0)

# Active rig pointers
var _active_player_rig: RigType
var _active_player_rig_root: Node3D
var _active_player_rig_yaw: Node3D
var _active_player_rig_pitch: Node3D
var _active_player_rig_cam_transform: Node3D

# Examine rig refs
#@onready var _examine_root: Node3D = $Rigs/Examine/RigRoot
#@onready var _examine_transform: Node3D = $Rigs/Examine/RigRoot/CameraTransform

var _follow_target: Node3D
var _follow_mode: FollowMode = FollowMode.POSITION_ONLY

var _is_local: bool = false
var _fp_follow_anchor: Node3D
var _tp_follow_anchor: Node3D

# SETUP
#===================================================================================#
func _ready() -> void:
	_fp_cam_transform.set_player(player)
	_camera.set_player(player)

	set_active_rig(RigType.FIRST_PERSON)
	set_camera_state(CameraState.FIRST_PERSON)

func set_active_rig(rig: RigType) -> void:
	active_rig = rig
	
	match rig:
		RigType.FIRST_PERSON:
			_set_active_player_rig(rig)
		RigType.THIRD_PERSON:
			_set_active_player_rig(rig)
		_:
			pass

func set_camera_state(state: CameraState) -> void:
	camera_state = state
	_camera.set_camera_state(camera_state)
	_fp_cam_transform.set_camera_state(camera_state)

func _set_active_player_rig(rig: RigType) -> void:
	match rig:
		RigType.FIRST_PERSON:
			_active_player_rig = RigType.FIRST_PERSON
			_active_player_rig_root = _fp_root
			_active_player_rig_yaw = _fp_yaw
			_active_player_rig_pitch = _fp_pitch
			_active_player_rig_cam_transform = _fp_cam_transform
		RigType.THIRD_PERSON:
			_active_player_rig = RigType.THIRD_PERSON
			_active_player_rig_root = _tp_root
			_active_player_rig_yaw = _tp_yaw
			_active_player_rig_pitch = _tp_pitch
			_active_player_rig_cam_transform = _tp_cam_transform
#===================================================================================#

# GETTERS
#===================================================================================#
func get_camera() -> Camera3D:
	return _camera

func get_look_basis() -> Basis:
	return _camera.transform.basis

func get_active_player_rig() -> RigType:
	return _active_player_rig

func get_state_from_rig(rig: RigType) -> CameraState:
	match rig:
		RigType.FIRST_PERSON:
			return CameraState.FIRST_PERSON
		RigType.THIRD_PERSON:
			return CameraState.THIRD_PERSON
		RigType.EXAMINE:
			return CameraState.EXAMINE
		_:
			return CameraState.FIRST_PERSON

## Viewport pixels [0, size] → world-space ray from the active [Camera3D]. Direction is normalized.
func get_world_ray_from_screen_px(screen_px: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_px)
	var direction := _camera.project_ray_normal(screen_px)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	return {"origin": origin, "direction": direction}

## Intersection of a world ray with a [Plane]. Returns null if parallel or t is below [param min_t].
func intersect_ray_with_plane(origin: Vector3, direction: Vector3, plane: Plane, min_t: float = 0.0) -> Variant:
	var plane_n := plane.normal
	var plane_d := plane.d
	var denom := plane_n.dot(direction)
	if abs(denom) <= 1e-6:
		return null
	var t := (plane_d - plane_n.dot(origin)) / denom
	if t < min_t:
		return null
	return origin + direction * t

## Convenience: screen pixel → ray → first hit on [param plane] in front of the ray origin.
func intersect_screen_ray_with_plane(screen_px: Vector2, plane: Plane, min_t: float = 0.0) -> Variant:
	var ray := get_world_ray_from_screen_px(screen_px)
	return intersect_ray_with_plane(ray["origin"], ray["direction"], plane, min_t)
#===================================================================================#

# SETTERS
#===================================================================================#
func set_look_input_enabled(enabled: bool) -> void:
	_look_input_enabled = enabled
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
		_camera.current = false
		set_process(false)
		set_physics_process(false)
		return

	# Local: manager runs, and active rig camera becomes current
	_camera.current = true
	_camera.set_camera_state(get_state_from_rig(active_rig))
	set_process(true)
	set_physics_process(false)

	set_active_rig(active_rig)

func set_mode(rig: RigType, instant: bool = false) -> void:
	set_active_rig(rig)

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

	if not instant and _follow_target == null:
		return

	match active_rig:
		RigType.FIRST_PERSON:
			_fp_root.global_transform = _follow_target.global_transform
		RigType.THIRD_PERSON:
			_tp_root.global_transform = _follow_target.global_transform
		RigType.EXAMINE:
			pass

func add_look_delta(relative: Vector2) -> void:
	if not _look_input_enabled or camera_state == CameraState.TRANSITION:
		return

	if relative == Vector2.ZERO:
		return

	match active_rig:
		RigType.FIRST_PERSON:
			set_look(relative, FP_SENSITIVITY, FP_PITCH_MIN, FP_PITCH_MAX)
		RigType.THIRD_PERSON:
			set_look(relative, TP_SENSITIVITY, TP_PITCH_MIN, TP_PITCH_MAX)
		RigType.EXAMINE:
			pass

func set_look(relative: Vector2, sensitivity: float, pitch_min: float, pitch_max: float) -> void:
	var move := relative * sensitivity
	_active_player_rig_yaw.rotation.y -= move.x
	_active_player_rig_pitch.rotation.x = clamp(_active_player_rig_pitch.rotation.x - move.y, pitch_min, pitch_max)

func set_third_person_distance(distance: float) -> void:
	# Guard in case you ever restructure paths or temporarily remove the arm
	var arm := _tp_cam_transform.get_parent() as SpringArm3D
	if arm != null:
		arm.spring_length = distance
#===================================================================================#

# APPLICATION
#===================================================================================#
func transition_to(target_rig: RigType = RigType.EXAMINE, anchor: Node3D = null) -> void:
	#SweetLogger.info("Transitioning to rig: {0}, anchor: {1}", [target_rig, anchor], "CameraManager.gd", "transition_to")
	match target_rig:
		RigType.EXAMINE:
			if anchor != null:
				_examine_anchor_stack.append(anchor)
				_transition_target = anchor
			if anchor == null:
				_transition_target = _examine_anchor_stack.pop_back()
		RigType.FIRST_PERSON:
			_transition_target = _fp_cam_transform
		RigType.THIRD_PERSON:
			_transition_target = _tp_cam_transform

	set_camera_state(CameraState.TRANSITION)
	set_active_rig(target_rig)

func _update_player_rig_to_follow(delta: float) -> void:
	if _follow_target == null:
		return

	var t_pos := 1.0 - exp(-follow_speed * delta)
	var t_rot := 1.0 - exp(-rotate_speed * delta)

	var from := _active_player_rig_root.global_transform
	var to := _follow_target.global_transform

	from.origin = from.origin.lerp(to.origin, t_pos)

	if _follow_mode == FollowMode.FULL_TRANSFORM:
		var q_from := from.basis.get_rotation_quaternion()
		var q_to := to.basis.get_rotation_quaternion()
		var q := q_from.slerp(q_to, t_rot)
		from.basis = Basis(q)

	_active_player_rig_root.global_transform = from

func _player_camera_process(delta: float) -> void:
	'''Follow the player's FP/TP camera anchor.'''
	_update_player_rig_to_follow(delta)
	_camera.global_transform = _active_player_rig_cam_transform.global_transform

func _examine_process(_delta: float) -> void:
	#_camera.global_transform = _examine_transform.global_transform
	pass

func _transition_process(delta: float) -> void:
	if active_rig == RigType.FIRST_PERSON or active_rig == RigType.THIRD_PERSON:
		_update_player_rig_to_follow(delta)
	#var t_pos := 1.0 - exp(-follow_speed * delta)
	#var t_rot := 1.0 - exp(-rotate_speed * delta)
	var t_pos := clampf(follow_speed * delta, 0.0, 1.0)
	var t_rot := clampf(rotate_speed * delta, 0.0, 1.0)

	var from := _camera.global_transform
	# temp fix, looking for better solution
	var to: Transform3D = _transition_target.global_transform
	var target_origin: Vector3 = _transition_target.global_position

	from.origin = from.origin.lerp(to.origin, t_pos)
	var q_from := from.basis.get_rotation_quaternion()
	var q_to := to.basis.get_rotation_quaternion()
	if q_from.dot(q_to) < 0.0:
		q_to = Quaternion(-q_to.x, -q_to.y, -q_to.z, -q_to.w)
	from.basis = Basis(q_from.slerp(q_to, t_rot))

	_camera.global_transform = from

	var dist := _camera.global_position.distance_to(target_origin)
	if dist < TRANSITION_THRESHOLD:
		set_camera_state(get_state_from_rig(active_rig))
		_transition_target = null
		return

func _process(delta: float) -> void:
	match camera_state:
		CameraState.EXAMINE:
			_examine_process(delta)
		CameraState.TRANSITION:
			_transition_process(delta)
		_:
			_player_camera_process(delta)
#===================================================================================#
