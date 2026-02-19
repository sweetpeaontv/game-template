extends Node
class_name ExamineMediator

@export var control_paths: Array[NodePath] = []
@export var actuator_paths: Array[NodePath] = []

# control_id -> Array[actuator_id]
# Example:
#	{
#		"digit_7": ["press_7", "screen"],
#		"clear": ["screen", "buzzer"]
#	}
@export var routing_map: Dictionary = {}

# If true: missing route targets log as errors (loud).
# If false: missing route targets log as warnings (quiet).
@export var fail_fast_on_missing_routes: bool = true

# Helpful while wiring scenes; turn off when stable.
@export var log_routes_on_ready: bool = false

var _controls: Array[ExamineControl] = []
var _actuators: Array[ExamineActuator] = []

var _actuators_by_id: Dictionary = {}	# StringName -> ExamineActuator
var _routes: Dictionary = {}			# StringName -> Array[StringName]

func _ready() -> void:
	_cache_nodes_from_paths()
	_build_routes_from_routing_map()
	_validate_setup()
	_connect_controls()
	if log_routes_on_ready:
		_log_route_summary()

func _cache_nodes_from_paths() -> void:
	_controls.clear()
	_actuators.clear()
	_actuators_by_id.clear()

	for p in control_paths:
		var n := get_node_or_null(p)
		if n is ExamineControl:
			_controls.append(n)
		elif n != null:
			push_warning("ExamineMediator: Node at %s is not ExamineControl (%s)" % [String(p), n.get_class()])
		else:
			push_warning("ExamineMediator: Missing control node at %s" % String(p))

	for p in actuator_paths:
		var a := get_node_or_null(p)
		if a is ExamineActuator:
			_actuators.append(a)
		elif a != null:
			push_warning("ExamineMediator: Node at %s is not ExamineActuator (%s)" % [String(p), a.get_class()])
		else:
			push_warning("ExamineMediator: Missing actuator node at %s" % String(p))

	for a in _actuators:
		if a.actuator_id == &"":
			push_warning("ExamineMediator: Actuator missing actuator_id at path: %s" % a.get_path())
			continue

		if _actuators_by_id.has(a.actuator_id):
			push_error("ExamineMediator: Duplicate actuator_id: %s (path: %s)" % [String(a.actuator_id), a.get_path()])
			continue

		_actuators_by_id[a.actuator_id] = a

func _build_routes_from_routing_map() -> void:
	_routes.clear()

	for key in routing_map.keys():
		var control_id := StringName(String(key))

		var raw_targets = routing_map[key]
		var targets: Array[StringName] = []

		if raw_targets is Array:
			for t in raw_targets:
				if t == null:
					continue
				targets.append(StringName(String(t)))
		elif raw_targets != null:
			# Allow shorthand: "digit_1": "screen"
			targets.append(StringName(String(raw_targets)))

		_routes[control_id] = targets

func _validate_setup() -> void:
	# Controls with no ID aren't inherently invalid (you might route some other way),
	# but for ID-based routing they are almost always a mistake.
	for c in _controls:
		if c.control_id == &"":
			push_warning("ExamineMediator: Control missing control_id at path: %s" % c.get_path())

	# Validate routing targets exist.
	for control_id in _routes.keys():
		var targets: Array = _routes[control_id]
		if targets.is_empty():
			push_warning("ExamineMediator: control_id has empty route list: %s" % String(control_id))
			continue

		for actuator_id_any in targets:
			var actuator_id: StringName = actuator_id_any
			if not _actuators_by_id.has(actuator_id):
				var msg := "ExamineMediator: Route target missing. control_id=%s -> actuator_id=%s" % [String(control_id), String(actuator_id)]
				if fail_fast_on_missing_routes:
					push_error(msg)
				else:
					push_warning(msg)

func _connect_controls() -> void:
	for c in _controls:
		if not c.activated.is_connected(_on_control_activated):
			c.activated.connect(_on_control_activated)
		if not c.value_changed.is_connected(_on_control_value_changed):
			c.value_changed.connect(_on_control_value_changed)

func set_enabled(enabled: bool) -> void:
	for c in _controls:
		c.set_enabled(enabled)
	for a in _actuators:
		a.set_enabled(enabled)

func reset_all() -> void:
	for c in _controls:
		c.reset()
	for a in _actuators:
		a.reset()

func _on_control_activated(control: ExamineControl, payload: Variant) -> void:
	route_activation(control.control_id, payload)

func _on_control_value_changed(control: ExamineControl, value: Variant, payload: Variant) -> void:
	route_value(control.control_id, value, payload)

func route_activation(control_id: StringName, payload: Variant = null) -> void:
	if control_id == &"":
		return

	var targets: Array = _routes.get(control_id, [])
	if targets.is_empty():
		return

	for actuator_id_any in targets:
		var actuator_id: StringName = actuator_id_any
		var a: ExamineActuator = _actuators_by_id.get(actuator_id, null)
		if a and a.is_enabled:
			a.activate(payload)

func route_value(control_id: StringName, value: Variant, payload: Variant = null) -> void:
	if control_id == &"":
		return

	var targets: Array = _routes.get(control_id, [])
	if targets.is_empty():
		return

	for actuator_id_any in targets:
		var actuator_id: StringName = actuator_id_any
		var a: ExamineActuator = _actuators_by_id.get(actuator_id, null)
		if a and a.is_enabled:
			a.apply_value(value, payload)

func _log_route_summary() -> void:
	print("ExamineMediator routes:")
	for control_id in _routes.keys():
		var targets: Array = _routes[control_id]
		var target_strings: Array[String] = []
		for t in targets:
			target_strings.append(String(t))
		print("\t%s -> [%s]" % [String(control_id), ", ".join(target_strings)])