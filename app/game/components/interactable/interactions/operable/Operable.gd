extends Interactable
class_name Operable

# BY DEFAULT, AN OPERABLE ACTS AS A TOGGLE (LIKE FOR DOOR, LIGHT SWITCH, ETC...)
# YOU CAN OVERRIDE THIS BEHAVIOR BY SETTING THE [ordered_states] AND [default_state] EXPORT VARIABLES
signal state_entered(state_name: StringName)
## Fired after [method _interact] handles a valid [InteractionTypes.OperableData] (any action branch).
## [param rollback_is_fresh] is netfox's step flag; use for one-shot UI/state (e.g. keypad digit) without changing toggle/pulse simulation.
signal operated(interactor: Node3D, data: InteractionTypes.OperableData, rollback_is_fresh: bool)

const IS_VERBOSE := false

enum AnimationPoseKind {
	## [Vector3] euler rotation (radians), [member Node3D.rotation].
	ROTATION,
	## [Vector3] local translation, [member Node3D.position].
	POSITION,
	## [Transform3D] full local [member Node3D.transform].
	TRANSFORM,
}

@export var default_operate_action: InteractionTypes.OperableData.Action

## Cycle order for [method toggle]. If empty, uses [RewindableStateMachine] child order.
@export var ordered_states: Array[StringName] = []
## Initial state when the machine has no state; if empty, uses first entry in the cycle order.
@export var default_state: StringName = &""

@export var default_animation_duration: float = 0.5
@export var default_animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var default_animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# { node: { "poses": Dictionary, "duration": float, "pose_kind": AnimationPoseKind } }
var animation_targets: Dictionary = {}

var _current_tween: Tween

@onready var state_machine: RewindableStateMachine = $RewindableStateMachine

# INIT
#===================================================================================#
func _on_ready() -> void:
	state_machine.on_display_state_changed.connect(_on_display_state_changed)
	if state_machine.state == &"":
		var cycle := _get_cycle_state_names()
		if cycle.size() > 0:
			if default_state != &"" and cycle.has(default_state):
				state_machine.state = default_state
			else:
				state_machine.state = cycle[0]

	InteractableRegistries.operables.add_entry(key, self)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	InteractableRegistries.operables.remove_entry(key)
	super._exit_tree()
#===================================================================================#

# INTERACTION
#===================================================================================#
func _interact(_interactor: Node3D, _data: Variant = null, rollback_is_fresh: bool = true) -> void:
	if not _data is InteractionTypes.OperableData:
		SweetLogger.error("Invalid data type: {0}", [_data.get_class()], "Operable.gd", "_interact")
		return

	var operable_data: InteractionTypes.OperableData = _data
	match operable_data.action:
		InteractionTypes.OperableData.Action.PULSE:
			pulse()
		InteractionTypes.OperableData.Action.TOGGLE:
			toggle()
		InteractionTypes.OperableData.Action.SET_STATE:
			go_to_state(operable_data.target_state)
		InteractionTypes.OperableData.Action.NEXT_STATE:
			next_state()
		InteractionTypes.OperableData.Action.PREV_STATE:
			prev_state()
		_:
			SweetLogger.error("Invalid action: {0}", [operable_data.action], "Operable.gd", "_interact")
			return

	operated.emit(_interactor, operable_data, rollback_is_fresh)

func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.OPERABLE

func pulse() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		if IS_VERBOSE:
			SweetLogger.info("Pulse skipped (need >= 2 states): {0}", [name], "Operable.gd", "pulse")
		return
	
	if not cycle.has(&"Pulse"):
		if IS_VERBOSE:
			SweetLogger.info("Pulse skipped (Pulse state not found): {0}", [name], "Operable.gd", "pulse")
		return

	go_to_state(&"Pulse")

func toggle() -> void:
	SweetLogger.info("Toggling operable: {0}", [name], "Operable.gd", "toggle")
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		return
	var current: StringName = state_machine.state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx + 1) % cycle.size()]
	if IS_VERBOSE:
		SweetLogger.info("Transitioning to: {0}", [target], "Operable.gd", "toggle")
	go_to_state(target)

func go_to_state(target: StringName) -> bool:
	SweetLogger.info("Transitioning to: {0}", [target], "Operable.gd", "go_to_state")
	if state_machine.transition(target):
		NetworkRollback.mutate(self)
		state_entered.emit(target)
		return true
	return false

func next_state() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		return
	var current: StringName = state_machine.state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx + 1) % cycle.size()]
	go_to_state(target)

func prev_state() -> void:
	var cycle := _get_cycle_state_names()
	if cycle.size() < 2:
		return
	var current: StringName = state_machine.state
	var idx: int = cycle.find(current)
	if idx < 0:
		idx = 0
	var target: StringName = cycle[(idx - 1) % cycle.size()]
	go_to_state(target)
#===================================================================================#

# ANIMATION / DISPLAY
#===================================================================================#
func add_animation_target(
	node: Node3D,
	poses_by_state: Dictionary,
	duration: float = -1.0,
	pose_kind: AnimationPoseKind = AnimationPoseKind.ROTATION
) -> void:
	"""Per-state pose; value type must match [param pose_kind]. Missing keys skip that state."""
	animation_targets[node] = {
		"poses": poses_by_state,
		"duration": duration if duration > 0 else default_animation_duration,
		"pose_kind": pose_kind,
	}

func _on_display_state_changed(_old_state: RewindableState, new_state: RewindableState) -> void:
	_animate(new_state.name)

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
	for child in state_machine.get_children():
		if child is RewindableState:
			out.append(child.name)
	return out
#===================================================================================#
