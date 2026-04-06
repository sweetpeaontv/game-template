extends Interactable
class_name Operable

# BY DEFAULT, AN OPERABLE ACTS AS A TOGGLE (LIKE FOR DOOR, LIGHT SWITCH, ETC...)
# YOU CAN OVERRIDE THIS BEHAVIOR BY SETTING THE [ordered_states] AND [default_state] EXPORT VARIABLES
signal state_entered(state_name: StringName)

const IS_VERBOSE := false

## Cycle order for [method toggle]. If empty, uses [RewindableStateMachine] child order.
@export var ordered_states: Array[StringName] = []
## Initial state when the machine has no state; if empty, uses first entry in the cycle order.
@export var default_state: StringName = &""

@export var animation_duration: float = 0.5
@export var animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# { node: { "poses": Dictionary state_name -> Vector3, "duration": float } }
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
func _interact(_interactor: Node3D, _data: Variant = null) -> void:
	if not _data is InteractionTypes.OperableData:
		SweetLogger.error("Invalid data type: {0}", [_data.get_class()], "Operable.gd", "_interact")
		return

	match _data.action:
		InteractionTypes.OperableData.Action.PULSE:
			pulse()
		InteractionTypes.OperableData.Action.TOGGLE:
			toggle()
		InteractionTypes.OperableData.Action.SET_STATE:
			go_to_state(_data.target_state)
		InteractionTypes.OperableData.Action.NEXT_STATE:
			next_state()
		InteractionTypes.OperableData.Action.PREV_STATE:
			prev_state()
		_:
			SweetLogger.error("Invalid action: {0}", [_data.action], "Operable.gd", "_interact")

func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.OPERABLE

func pulse() -> void:
	SweetLogger.info("Pulsing operable: {0}", [name], "Operable.gd", "pulse")

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
func add_animation_target(node: Node3D, poses_by_state: Dictionary, duration: float = -1.0) -> void:
	"""poses_by_state: state name -> local rotation. Missing keys skip animation for that state."""
	animation_targets[node] = {
		"poses": poses_by_state,
		"duration": duration if duration > 0 else animation_duration
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
	_current_tween.set_ease(animation_ease)
	_current_tween.set_trans(animation_trans)

	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if not poses.has(state_name):
			continue
		var target_rotation: Vector3 = poses[state_name]
		_current_tween.tween_property(node, "rotation", target_rotation, config["duration"])

func snap_to_state(state_name: StringName) -> void:
	if animation_targets.is_empty():
		return
	for node in animation_targets:
		var config: Dictionary = animation_targets[node]
		var poses: Dictionary = config["poses"]
		if not poses.has(state_name):
			continue
		node.rotation = poses[state_name]
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
