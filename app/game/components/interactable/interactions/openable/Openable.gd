extends Interactable
class_name Openable

signal opened()
signal closed()

const IS_VERBOSE := false

@export var animation_duration: float = 0.5
@export var animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# Dictionary structure: { node: { "open": Vector3, "closed": Vector3, "duration": float } }
var animation_targets: Dictionary = {}

var _current_tween: Tween

@onready var state_machine: RewindableStateMachine = $RewindableStateMachine

func _on_ready() -> void:
	state_machine.on_display_state_changed.connect(_on_display_state_changed)
	if state_machine.state == &"":
		state_machine.state = &"Close"

func _interact(interactor: Node3D, data: Variant = null) -> void:
	if not data is InteractionTypes.OpenData:
		SweetLogger.error("Invalid data type: {0}", [data.get_class()], "Openable.gd", "_interact")
		return

	var action = data.action
	match action:
		InteractionTypes.OpenData.Action.TOGGLE:
			toggle()
		InteractionTypes.OpenData.Action.OPEN:
			open()
		InteractionTypes.OpenData.Action.CLOSE:
			close()
		_:
			SweetLogger.error("Invalid action: {0}", [action], "Openable.gd", "_interact")

func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.OPENABLE

func toggle() -> void:
	var target: StringName = &"Open" if state_machine.state == &"Close" else &"Close"
	if IS_VERBOSE:
		SweetLogger.info("Transitioning to: {0}", [target], "Openable.gd", "toggle")
	if state_machine.transition(target):
		NetworkRollback.mutate(self)

func open() -> void:
	if state_machine.transition(&"Open"):
		NetworkRollback.mutate(self)
		opened.emit()

func close() -> void:
	if state_machine.transition(&"Close"):
		NetworkRollback.mutate(self)
		closed.emit()

func add_animation_target(node: Node3D, open_rotation: Vector3, closed_rotation: Vector3, duration: float = -1.0) -> void:
	"""Add a node to be animated when opening/closing.
	If duration is -1, uses the default animation_duration."""
	animation_targets[node] = {
		"open": open_rotation,
		"closed": closed_rotation,
		"duration": duration if duration > 0 else animation_duration
	}

func _on_display_state_changed(_old_state: RewindableState, new_state: RewindableState) -> void:
	var to_open: bool = new_state.name == "Open"
	_animate(to_open)

func _animate(to_open: bool) -> void:
	if animation_targets.is_empty():
		return

	if _current_tween:
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_ease(animation_ease)
	_current_tween.set_trans(animation_trans)

	for node in animation_targets:
		var config = animation_targets[node]
		var target_rotation: Vector3 = config["open"] if to_open else config["closed"]
		_current_tween.tween_property(node, "rotation", target_rotation, config["duration"])

func _snap_to_state(to_open: bool) -> void:
	"""Apply target rotations immediately (e.g. for late joiners or rollback correction)."""
	if animation_targets.is_empty():
		return
	for node in animation_targets:
		var config = animation_targets[node]
		var target_rotation: Vector3 = config["open"] if to_open else config["closed"]
		node.rotation = target_rotation
