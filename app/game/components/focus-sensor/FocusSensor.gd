extends Node3D

@export var actor: CharacterBody3D
@export var camera_manager: Node3D
@export var max_distance: float = 3.0

var focus_key: int = 0
var focus: Interactable = null

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)

func _exit_tree() -> void:
	NetworkTime.before_tick_loop.disconnect(_gather)

func _gather() -> void:
	if not actor or multiplayer.get_unique_id() != actor.peer_id:
		return
	var hit = _query_focus_hit()
	focus_key = hit.key if hit and hit is Interactable else 0

func _get_aim_origin() -> Vector3:
	return camera_manager.get_camera().global_position

func _get_aim_dir() -> Vector3:
	return -camera_manager.get_look_basis().z

func _query_focus_hit() -> Object:
	if not camera_manager:
		SweetLogger.error('No camera manager present for FocusSensor', [], 'FocusSensor.gd', '_query_focus_hit')
		return
	
	var origin: Vector3 = _get_aim_origin()
	var dir: Vector3 = _get_aim_dir()

	var to := origin + dir * max_distance

	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
	query.exclude = [actor.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider is Pickupable and (collider as Pickupable).holder == actor:
		return null

	return collider

func query_focus_key() -> int:
	var hit := _query_focus_hit()
	if hit is Interactable:
		return (hit as Interactable).key
	return 0

func _handle_focus_sync() -> void:
	if focus_key == 0 and focus != null:
		focus = null
	if focus_key != 0 and focus == null:
		var new_focus = InteractableRegistries.interactables.get_entry(focus_key)
		if new_focus:
			focus = new_focus
