class_name OperableAnimator
extends Node

const IS_VERBOSE: bool = false
const SCRIPT_NAME: String = "operable-animator.gd"

var operable: Operable = null

enum AnimationPoseKind {
	ROTATION,
	POSITION,
	TRANSFORM,
}
var animation_targets: Dictionary = {}
var _current_tween: Tween
@export var default_animation_duration: float = 0.5
@export var default_animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var default_animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# INIT
#===================================================================================#
func _ready() -> void:
	operable = get_parent() as Operable
#===================================================================================#

# ANIMATION
#===================================================================================#
func add_animation_target(
	node: Node3D,
	poses_by_state: Dictionary,
	duration: float = -1.0,
	pose_kind: AnimationPoseKind = AnimationPoseKind.ROTATION
) -> void:
	animation_targets[node] = {
		"poses": poses_by_state,
		"duration": duration if duration > 0 else default_animation_duration,
		"pose_kind": pose_kind,
	}

func play_moment(moment_name: StringName, return_to: StringName = &"Idle") -> void:
	var duration := _get_pose_duration(moment_name)
	_animate(moment_name)
	if return_to == &"" or duration <= 0.0:
		return
	get_tree().create_timer(duration).timeout.connect(
		func(): _animate(return_to),
		CONNECT_ONE_SHOT,
	)

func go_to_state(state_name: StringName) -> void:
	_animate(state_name)

func _animate(state_name: StringName) -> void:
	if animation_targets.is_empty():
		return

	if _current_tween:
		_current_tween.kill()
	_current_tween = null

	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if not poses.has(state_name):
			continue

		if _current_tween == null:
			_current_tween = create_tween()
			_current_tween.set_parallel(true)
			_current_tween.set_ease(default_animation_ease)
			_current_tween.set_trans(default_animation_trans)

		var pose_value: Variant = poses[state_name]
		var kind: AnimationPoseKind = config.get("pose_kind", AnimationPoseKind.ROTATION)
		match kind:
			AnimationPoseKind.ROTATION:
				_current_tween.tween_property(node, "rotation", pose_value, config["duration"])
			AnimationPoseKind.POSITION:
				_current_tween.tween_property(node, "position", pose_value, config["duration"])
			AnimationPoseKind.TRANSFORM:
				_current_tween.tween_property(node, "transform", pose_value, config["duration"])

func _get_pose_duration(pose_name: StringName) -> float:
	var longest := 0.0
	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if poses.has(pose_name):
			longest = maxf(longest, config["duration"])
	return longest
#===================================================================================#
