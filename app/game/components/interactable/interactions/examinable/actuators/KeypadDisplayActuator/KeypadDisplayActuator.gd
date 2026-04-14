extends Node3D
class_name KeypadDisplayActuator

## Listens to [KeypadState] and updates the label and screen material.

@export var keypad_state: KeypadState
@export var screen_label: Label3D
@export var screen_mesh: MeshInstance3D

var _screen_material: ShaderMaterial

func _ready() -> void:
	if screen_mesh == null:
		screen_mesh = get_parent().get_node_or_null("Screen") as MeshInstance3D
	if screen_mesh and screen_mesh.material_override is ShaderMaterial:
		_screen_material = screen_mesh.material_override as ShaderMaterial
	if keypad_state:
		if not keypad_state.state_changed.is_connected(_on_keypad_state_changed):
			keypad_state.state_changed.connect(_on_keypad_state_changed)
		if not keypad_state.unlocked_changed.is_connected(_on_unlocked_changed):
			keypad_state.unlocked_changed.connect(_on_unlocked_changed)
		if not keypad_state.reject_ticks_remaining_changed.is_connected(_on_reject_ticks_remaining_changed):
			keypad_state.reject_ticks_remaining_changed.connect(_on_reject_ticks_remaining_changed)
	_refresh_label()
	_refresh_screen_mode()

func _exit_tree() -> void:
	if keypad_state:
		if keypad_state.state_changed.is_connected(_on_keypad_state_changed):
			keypad_state.state_changed.disconnect(_on_keypad_state_changed)
		if keypad_state.unlocked_changed.is_connected(_on_unlocked_changed):
			keypad_state.unlocked_changed.disconnect(_on_unlocked_changed)
		if keypad_state.reject_ticks_remaining_changed.is_connected(_on_reject_ticks_remaining_changed):
			keypad_state.reject_ticks_remaining_changed.disconnect(_on_reject_ticks_remaining_changed)

func _on_keypad_state_changed(_entered: Array[int]) -> void:
	_refresh_label()
	_refresh_screen_mode()

func _on_unlocked_changed(_is_unlocked: bool) -> void:
	_refresh_screen_mode()

func _on_reject_ticks_remaining_changed(_remaining: int) -> void:
	_refresh_screen_mode()

func _refresh_label() -> void:
	if keypad_state == null or screen_label == null:
		return
	screen_label.text = ""
	for d in keypad_state.entered_digits:
		screen_label.text += str(d)

func _refresh_screen_mode() -> void:
	if keypad_state == null or _screen_material == null:
		return
	var mode := 0
	if keypad_state.unlocked:
		mode = 2
	elif keypad_state.reject_ticks_remaining > 0:
		mode = 1
	_screen_material.set_shader_parameter("screen_mode", mode)
