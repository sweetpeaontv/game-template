class_name CustomizerCamera
extends Camera3D

const ANCHOR_NAMES: Array[StringName] = [&"CoreAP", &"HeadAP", &"BodyAP"]
const ARRIVAL_DISTANCE := 0.002

@export var transition_speed: float = 8.0

var _active_anchor: Node3D
var _is_transitioning: bool = false
var _look_at_target: Node3D

func set_look_at_target(target: Node3D) -> void:
	_look_at_target = target

func setup() -> void:
	current = true
	go_to_page(0, true)

func go_to_page(page: int, instant: bool = false) -> void:
	var anchor := _get_anchor(page)
	if anchor == null:
		SweetLogger.error("CustomizerCamera.go_to_page: anchor is null for page {0}", [page], "CustomizerCamera.gd", "go_to_page")
		return
	_active_anchor = anchor
	if instant:
		global_transform = anchor.global_transform
		_is_transitioning = false
		_update_facing()
	else:
		_is_transitioning = true

func _get_anchor(page: int) -> Node3D:
	if page < 0 or page >= ANCHOR_NAMES.size():
		return null
	return get_node_or_null(NodePath("../Character/%s" % ANCHOR_NAMES[page])) as Node3D

func _process(delta: float) -> void:
	if _active_anchor == null:
		return
	var t := 1.0 - exp(-transition_speed * delta)
	if _is_transitioning:
		var target_origin := _active_anchor.global_position
		global_position = global_position.lerp(target_origin, t)
		if global_position.distance_to(target_origin) <= ARRIVAL_DISTANCE:
			_is_transitioning = false
			global_position = target_origin
	_update_facing()

func _get_look_at_world_position() -> Vector3:
	if _look_at_target == null or not is_instance_valid(_look_at_target):
		return global_position
	if _look_at_target is MeshInstance3D:
		var mi: MeshInstance3D = _look_at_target
		if mi.mesh != null:
			var aabb: AABB = mi.get_aabb()
			if not aabb.size.is_zero_approx():
				return mi.to_global(aabb.get_center())
	return _look_at_target.global_position

func _update_facing() -> void:
	if _look_at_target == null or not is_instance_valid(_look_at_target):
		return
	var target_pos := _get_look_at_world_position()
	if global_position.is_equal_approx(target_pos):
		return
	look_at(target_pos, Vector3.UP)
