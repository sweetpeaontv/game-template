extends Interactable
class_name Openable

signal opened()
signal closed()

@export var is_open: bool = false
@export var animation_duration: float = 0.5
@export var animation_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# Dictionary structure: { node: { "open": Vector3, "closed": Vector3, "duration": float } }
var animation_targets: Dictionary = {}

var _current_tween: Tween

func _interact(interactor: Node3D, data: Variant = null) -> void:
	toggle()

func toggle() -> void:
	is_open = !is_open
	_animate()
	
	if is_open:
		opened.emit()
	else:
		closed.emit()

func open() -> void:
	if not is_open:
		is_open = true
		_animate()
		opened.emit()

func close() -> void:
	if is_open:
		is_open = false
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
		var target_rotation = config["open"] if is_open else config["closed"]
		_current_tween.tween_property(node, "rotation", target_rotation, config["duration"])
