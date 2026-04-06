extends ExamineActuator
class_name PressActuator

@export var button_meshes: Dictionary = {}

# Local offset applied during press (e.g. Vector3(0, -0.003, 0) for down).
@export var press_offset: Vector3 = Vector3(0.0, -0.008, 0.0)
# Duration in seconds for each half of the press (down then back up).
@export var press_duration_sec: float = 0.2

func activate(payload: Variant = null) -> void:
	if payload == null or not (payload is Dictionary):
		return
	var id_val = payload.get("id", &"")
	if id_val == &"":
		return
	_play_press_animation(id_val)

func reset() -> void:
	pass

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
