extends Interactable
class_name OperableNoRoll

# Command-driven operable: same interaction/animation surface as [Operable], but state
# is authoritative on this node (no RewindableStateMachine / NetworkRollback).

signal state_entered(state_name: StringName)
signal operated(interactor: Node3D, data: InteractionTypes.OperableData)

const IS_VERBOSE := true

enum AnimationPoseKind {
	ROTATION,
	POSITION,
	TRANSFORM,
}

@export var default_operate_action: InteractionTypes.OperableData.Action

@export var ordered_states: Array[StringName] = []
@export var default_state: StringName = &""

@export var default_animation_duration: float = 0.5
@export var default_animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var default_animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

## When pulsing, return to this state after [member pulse_duration_sec].
@export var pulse_idle_state: StringName = &"Idle"
@export var pulse_duration_sec: float = 0.2

var state: StringName = &""

# { node: { "poses": Dictionary, "duration": float, "pose_kind": AnimationPoseKind } }
var animation_targets: Dictionary = {}

var _current_tween: Tween
var _pulse_timer: Timer

# INIT
#===================================================================================#
func _on_ready() -> void:
	_setup_pulse_timer()

	var cycle := _get_cycle_state_names()
	if cycle.size() > 0:
		if default_state != &"" and cycle.has(default_state):
			go_to_state(default_state, false)
		else:
			go_to_state(cycle[0], false)

	RegistryLibrary.operables.add_entry(key, self)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	RegistryLibrary.operables.remove_entry(key)
	super._exit_tree()
#===================================================================================#

# INTERACTION
#===================================================================================#
func _interact(_interactor: Node3D, _data: Variant = null, _rollback_is_fresh: bool = true) -> void:
	if not _data is InteractionTypes.OperableData:
		SweetLogger.error("Invalid data type: {0}", [_data.get_class()], "operable-no-roll.gd", "_interact")
		return

	_apply_operate_action(_interactor, _data)

func _apply_operate_action(interactor: Node3D, operable_data: InteractionTypes.OperableData) -> void:
	match operable_data.action:
		InteractionTypes.OperableData.Action.PULSE:
			pulse()
		InteractionTypes.OperableData.Action.TOGGLE:
			SweetLogger.info("Toggling {0}", [name], "operable-no-roll.gd", "_apply_operate_action")
			toggle()
		InteractionTypes.OperableData.Action.SET_STATE:
			go_to_state(operable_data.target_state)
		InteractionTypes.OperableData.Action.NEXT_STATE:
			next_state()
		InteractionTypes.OperableData.Action.PREV_STATE:
			prev_state()
		_:
			SweetLogger.error("Invalid action: {0}", [operable_data.action], "operable-no-roll.gd", "_apply_operate_action")
			return

	operated.emit(interactor, operable_data)

func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.OPERABLE

func pulse() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		if IS_VERBOSE:
			SweetLogger.info("Pulse skipped (need >= 2 states): {0}", [name], "operable-no-roll.gd", "pulse")
		return

	if not cycle.has(&"Pulse"):
		if IS_VERBOSE:
			SweetLogger.info("Pulse skipped (Pulse state not found): {0}", [name], "operable-no-roll.gd", "pulse")
		return

	go_to_state(&"Pulse")

func toggle() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		SweetLogger.info("Toggle skipped (need >= 2 states): {0}", [name], "operable-no-roll.gd", "toggle")
		return
	var current: StringName = state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx + 1) % cycle.size()]
	if IS_VERBOSE:
		SweetLogger.info("Transitioning to: {0}", [target], "operable-no-roll.gd", "toggle")
	go_to_state(target)

func go_to_state(target: StringName, animate: bool = true) -> bool:
	if not transition(target, animate):
		return false
	state_entered.emit(target)
	return true

func next_state() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		return
	var current: StringName = state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx + 1) % cycle.size()]
	go_to_state(target)

func prev_state() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		return
	var current: StringName = state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx - 1) % cycle.size()]
	go_to_state(target)

func transition(target: StringName, animate: bool = true) -> bool:
	if state == target:
		return false

	var cycle := _get_cycle_state_names()
	if cycle.size() > 0 and not cycle.has(target):
		SweetLogger.warning("Unknown operable state: {0}", [target], "operable-no-roll.gd", "transition")
		return false

	state = target

	if animate:
		_animate(target)

	if target == &"Pulse":
		_schedule_pulse_return()

	return true
#===================================================================================#

# ANIMATION / DISPLAY
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

func _animate(state_name: StringName) -> void:
	if animation_targets.is_empty():
		return

	if _current_tween:
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_ease(default_animation_ease)
	_current_tween.set_trans(default_animation_trans)

	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if not poses.has(state_name):
			continue
		var pose_value: Variant = poses[state_name]
		var kind: AnimationPoseKind = config.get("pose_kind", AnimationPoseKind.ROTATION)
		match kind:
			AnimationPoseKind.ROTATION:
				_current_tween.tween_property(node, "rotation", pose_value, config["duration"])
			AnimationPoseKind.POSITION:
				_current_tween.tween_property(node, "position", pose_value, config["duration"])
			AnimationPoseKind.TRANSFORM:
				_current_tween.tween_property(node, "transform", pose_value, config["duration"])

func snap_to_state(state_name: StringName) -> void:
	if animation_targets.is_empty():
		return
	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if not poses.has(state_name):
			continue
		var pose_value: Variant = poses[state_name]
		var kind: AnimationPoseKind = config.get("pose_kind", AnimationPoseKind.ROTATION)
		match kind:
			AnimationPoseKind.ROTATION:
				node.rotation = pose_value
			AnimationPoseKind.POSITION:
				node.position = pose_value
			AnimationPoseKind.TRANSFORM:
				node.transform = pose_value
#===================================================================================#

# HELPERS
#===================================================================================#
func _get_cycle_state_names() -> Array[StringName]:
	if ordered_states.size() > 0:
		return ordered_states
	var out: Array[StringName] = []
	var states_root := get_node_or_null("States")
	if states_root == null:
		return out
	for child in states_root.get_children():
		out.append(child.name)
	return out

func _setup_pulse_timer() -> void:
	_pulse_timer = Timer.new()
	_pulse_timer.one_shot = true
	add_child(_pulse_timer)
	_pulse_timer.timeout.connect(_on_pulse_timeout)

func _schedule_pulse_return() -> void:
	if _pulse_timer == null:
		return
	_pulse_timer.start(pulse_duration_sec)

func _on_pulse_timeout() -> void:
	if state != &"Pulse":
		return
	go_to_state(pulse_idle_state)
#===================================================================================#
