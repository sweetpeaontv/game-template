extends Node3D
class_name KeypadDisplayActuator

## Listens to [KeypadState] and updates the label.

@export var keypad_state: KeypadState
@export var screen_label: Label3D

func _ready() -> void:
	if keypad_state:
		if not keypad_state.state_changed.is_connected(_on_keypad_state_changed):
			keypad_state.state_changed.connect(_on_keypad_state_changed)
		_refresh_label()

func _exit_tree() -> void:
	if keypad_state and keypad_state.state_changed.is_connected(_on_keypad_state_changed):
		keypad_state.state_changed.disconnect(_on_keypad_state_changed)

func _on_keypad_state_changed(_entered: Array[int]) -> void:
	_refresh_label()

func _refresh_label() -> void:
	if keypad_state == null or screen_label == null:
		return
	screen_label.text = ""
	for d in keypad_state.entered_digits:
		screen_label.text += str(d)
