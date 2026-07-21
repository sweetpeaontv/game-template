extends Node3D
class_name ExamineActuator

# An `Actuator` is responsible for performing the action when the control is activated.

@export var is_enabled: bool = true:
	set = set_enabled,
	get = get_enabled
@export var actuator_id: StringName = &""

func set_enabled(value: bool) -> void:
	is_enabled = value

func get_enabled() -> bool:
	return is_enabled

## Momentary action (button press, toggle click, “play anim”, etc.)
func activate(_payload: Variant = null) -> void:
	# Override in subclasses.
	pass

## Continuous/value action (slider position, knob angle, etc.)
func apply_value(_value: Variant, _payload: Variant = null) -> void:
	# Override in subclasses.
	pass

## Optional: allow mediator to clear visuals/state on exit examine.
func reset() -> void:
	# Override in subclasses.
	pass