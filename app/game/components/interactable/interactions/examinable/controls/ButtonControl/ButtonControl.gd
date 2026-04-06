extends ExamineControl
class_name ButtonArrayControl

# List of button entries (id + Area3D path). No scripts needed on the buttons.
# Payload emitted on click includes:
#	{
#		"id": <StringName>,
#		"world_pos": <Vector3>
#	}
@export var buttons: Array[ButtonEntry] = []

@export var mouse_button_index: int = MOUSE_BUTTON_LEFT
@export var require_press_down: bool = true

var _areas: Array[Area3D] = []
var _area_id_to_button_id: Dictionary = {} # int(instance_id) -> StringName

func _ready() -> void:
	_rebuild_cache_and_connections()

func _rebuild_cache_and_connections() -> void:
	_disconnect_area_signals()
	_cache_areas()
	_connect_area_signals()

func _cache_areas() -> void:
	_areas.clear()
	_area_id_to_button_id.clear()

	for i in buttons.size():
		var entry = buttons[i]
		if not (entry is ButtonEntry):
			push_warning("ButtonArrayControl: buttons[%d] is not a ButtonEntry resource." % i)
			continue

		var id: StringName = entry.id
		var p: NodePath = entry.area_path

		if id == &"":
			push_warning("ButtonArrayControl: ButtonEntry id is empty at index %d" % i)
			continue
		if p == NodePath():
			push_warning("ButtonArrayControl: ButtonEntry area_path is empty (id=%s, index=%d)" % [String(id), i])
			continue

		var n := get_node_or_null(p)
		if n == null:
			push_warning("ButtonArrayControl: Missing Area3D at %s (id=%s, index=%d)" % [String(p), String(id), i])
			continue
		if not (n is Area3D):
			push_warning("ButtonArrayControl: Node at %s is not Area3D (%s) (id=%s, index=%d)" % [String(p), n.get_class(), String(id), i])
			continue

		var a: Area3D = n
		_areas.append(a)
		_area_id_to_button_id[a.get_instance_id()] = id

func _connect_area_signals() -> void:
	for a in _areas:
		# Bind the emitting Area3D so we don't need get_signal_sender().
		# This is robust across Godot versions and avoids ambiguity.
		var cb := Callable(self, "_on_area_input_event").bind(a)
		if not a.input_event.is_connected(cb):
			a.input_event.connect(cb)

func _disconnect_area_signals() -> void:
	# Best-effort disconnect to avoid duplicate callbacks when rebuilding.
	for a in _areas:
		var cb := Callable(self, "_on_area_input_event").bind(a)
		if a.input_event.is_connected(cb):
			a.input_event.disconnect(cb)

func _on_area_input_event(_camera: Camera3D, event: InputEvent, curr_position: Vector3, _normal: Vector3, _shape_idx: int, area: Area3D) -> void:
	if not is_enabled:
		return
	if not (event is InputEventMouseButton):
		return

	var mbe: InputEventMouseButton = event
	if mbe.button_index != mouse_button_index:
		return
	if require_press_down and not mbe.pressed:
		return

	var id: StringName = _area_id_to_button_id.get(area.get_instance_id(), &"")
	if id == &"":
		return
	
	# SweetLogger.info('Button pressed: {0}', [id], 'ButtonControl.gd', '_on_area_input_event')

	emit_activated({
		"id": id,
		"world_pos": curr_position
	})

# Call this if you change button entries at runtime.
func rebuild() -> void:
	_rebuild_cache_and_connections()
