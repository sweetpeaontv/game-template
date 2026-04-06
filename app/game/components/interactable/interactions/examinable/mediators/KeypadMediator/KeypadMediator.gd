extends ExamineMediator
class_name KeypadMediator

## Owns keypad entry requests for routed controls; [KeypadDisplayActuator] only reflects [member keypad_state].

@export var keypad_state: KeypadState


func route_activation(control_id: StringName, payload: Variant = null) -> void:
	if control_id == &"keypad_buttons" and keypad_state and payload is Dictionary:
		var id_val = payload.get("id", &"")
		if id_val != &"":
			keypad_state.request_append(id_val)
	super.route_activation(control_id, payload)


func reset_all() -> void:
	if keypad_state:
		keypad_state.request_reset()
	super.reset_all()
