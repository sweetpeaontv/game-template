extends Node3D
class_name ExamineControl

# A `Control` is responsible for detecting user input and emitting signals when it happens.

signal activated(control: ExamineControl, payload: Variant)
signal value_changed(control: ExamineControl, value: Variant, payload: Variant)
signal hover_changed(control: ExamineControl, is_hovered: bool)

@export var is_enabled: bool = true:
	set = set_enabled,
	get = get_enabled

@export var control_id: StringName = &""

var _is_hovered: bool = false

func set_enabled(value: bool) -> void:
	is_enabled = value
	if not is_enabled:
		_set_hovered(false)

func get_enabled() -> bool:
	return is_enabled

## Call from your concrete control when it decides a press happened.
func emit_activated(payload: Variant = null) -> void:
	if not is_enabled:
		return
	activated.emit(self, payload)

## Call from your concrete control when it updates a value (float/bool/etc).
func emit_value(value: Variant, payload: Variant = null) -> void:
	if not is_enabled:
		return
	value_changed.emit(self, value, payload)

## Concrete controls can use this to drive highlight states, cursors, etc.
func _set_hovered(value: bool) -> void:
	if _is_hovered == value:
		return
	_is_hovered = value
	hover_changed.emit(self, _is_hovered)

## Optional hook for mediator to hard-reset a control between examine sessions.
func reset() -> void:
	_set_hovered(false)

## ---- Virtual-ish hooks (override in subclasses) ----------------------------
## I’m not forcing an input strategy here (raycasts vs input_event). Your
## concrete controls can implement either and call emit_* above.

func can_interact() -> bool:
	return is_enabled