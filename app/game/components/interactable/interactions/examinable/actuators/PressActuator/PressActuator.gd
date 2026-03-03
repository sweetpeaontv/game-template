extends ExamineActuator
class_name PressActuator


@export var screen: MeshInstance3D
@export var screen_label: Label3D
@export var button_meshes: Dictionary = {}

# Local offset applied during press (e.g. Vector3(0, -0.003, 0) for down).
@export var press_offset: Vector3 = Vector3(0.0, -0.008, 0.0)
# Duration in seconds for each half of the press (down then back up).
@export var press_duration_sec: float = 0.2
# Number of digits shown on screen; must match shader digit_count.
@export var digit_count: int = 4

# 7-segment masks: a=1, b=2, c=4, d=8, e=16, f=32, g=64
var _digit_masks: PackedInt32Array

func _get_digit_masks() -> PackedInt32Array:
	if _digit_masks.size() == 0:
		_digit_masks = PackedInt32Array([
			63, 6, 91, 79, 102, 109, 125, 7, 127, 111
		])
	return _digit_masks

var _digit_buffer: PackedInt32Array = PackedInt32Array()

func _ready() -> void:
	_digit_buffer.resize(digit_count)
	_clear_digit_buffer()

func activate(payload: Variant = null) -> void:
	if payload == null or not (payload is Dictionary):
		return
	var id_val = payload.get("id", &"")
	if id_val == &"":
		return

	_play_press_animation(id_val)
	_append_digit_to_screen(id_val)
	_append_digit_to_label(id_val)

func reset() -> void:
	_clear_digit_buffer()
	_apply_masks_to_screen()

func _play_press_animation(button_id: StringName) -> void:
	var path = button_meshes.get(button_id)
	var pivot = get_node_or_null(path)
	if pivot == null:
		return

	var start_pos: Vector3 = pivot.position
	var down_pos: Vector3 = start_pos + press_offset

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pivot, "position", down_pos, press_duration_sec)
	tween.tween_property(pivot, "position", start_pos, press_duration_sec)

func _append_digit_to_screen(button_id: StringName) -> void:
	var digit := _button_id_to_digit(button_id)
	SweetLogger.info('digit: {0}', [digit], 'PressActuator.gd', '_append_digit_to_screen')
	if digit < 0:
		return

	# Shift left and add new digit at end
	for i in range(digit_count - 1):
		_digit_buffer[i] = _digit_buffer[i + 1]
	_digit_buffer[digit_count - 1] = _get_digit_masks()[digit]
	_apply_masks_to_screen()

func _button_id_to_digit(button_id: StringName) -> int:
	var s := String(button_id)
	if s.length() != 1:
		return -1
	var c := s[0]
	if c >= "0" and c <= "9":
		return int(c) - int("0")
	return -1

func _clear_digit_buffer() -> void:
	for i in range(digit_count):
		_digit_buffer[i] = 0

func _apply_masks_to_screen() -> void:
	if screen == null:
		return
	var mat := screen.get_material_override()
	if not (mat is ShaderMaterial):
		SweetLogger.error('mat is not a ShaderMaterial', [], 'PressActuator.gd', '_apply_masks_to_screen')
		return
	mat.set_shader_parameter("masks", _digit_buffer)
	
func _append_digit_to_label(button_id: StringName) -> void:
	if screen_label == null:
		return
	
	var digit := _button_id_to_digit(button_id)
	if digit < 0:
		return
	
	screen_label.text += str(digit)
	
