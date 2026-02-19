extends Node3D
class_name ExamineActuator

@export var is_enabled: bool = true:
	set = set_enabled,
	get = get_enabled
@export var actuator_id: StringName = &""

func set_enabled(value: bool) -> void:
	is_enabled = value

func get_enabled() -> bool:
	return is_enabled

## Momentary action (button press, toggle click, “play anim”, etc.)
func activate(payload: Variant = null) -> void:
	# Override in subclasses.
	pass

## Continuous/value action (slider position, knob angle, etc.)
func apply_value(value: Variant, payload: Variant = null) -> void:
	# Override in subclasses.
	pass

## Optional: allow mediator to clear visuals/state on exit examine.
func reset() -> void:
	# Override if you need it.
	pass