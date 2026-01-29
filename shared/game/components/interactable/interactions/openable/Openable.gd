extends Interactable
class_name Openable

signal opened()
signal closed()

enum OpenState { CLOSED, OPEN }

@export var open_state: OpenState = OpenState.CLOSED
@export var animation_duration: float = 0.5
@export var animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# Dictionary structure: { node: { "open": Vector3, "closed": Vector3, "duration": float } }
var animation_targets: Dictionary = {}

var _current_tween: Tween

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
	open_state = OpenState.OPEN if open_state == OpenState.CLOSED else OpenState.CLOSED
	_animate()

	#if open_state == OpenState.OPEN:
	#	opened.emit()
	#else:
	#	closed.emit()

func open() -> void:
	if open_state == OpenState.CLOSED:
		open_state = OpenState.OPEN
		_animate()
		opened.emit()

func close() -> void:
	if open_state == OpenState.OPEN:
		open_state = OpenState.CLOSED
		_animate()
		closed.emit()

func add_animation_target(node: Node3D, open_rotation: Vector3, closed_rotation: Vector3, duration: float = -1.0) -> void:
	"""Add a node to be animated when opening/closing. 
	If duration is -1, uses the default animation_duration."""
	animation_targets[node] = {
		"open": open_rotation,
		"closed": closed_rotation,
		"duration": duration if duration > 0 else animation_duration
	}

func _animate() -> void:
	if animation_targets.is_empty():
		return
	
	# Kill existing tween if running
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_ease(animation_ease)
	_current_tween.set_trans(animation_trans)
	
	# Animate all registered targets
	for node in animation_targets:
		var config = animation_targets[node]
		var target_rotation = config["open"] if open_state == OpenState.OPEN else config["closed"]
		_current_tween.tween_property(node, "rotation", target_rotation, config["duration"])
