extends Node3D

# THIS COULD PROBABLY BE REWORKED TO USE ROLLBACKSYNCHRONIZER
# SHOULD IT?
# The input itself for camera_basis is already synced, so maybe not necessary
signal focus_hit(hit: Object)

@export var actor: CharacterBody3D
@export var max_distance: float = 3.0

var last_hit: Object = null

# needs to be improved to prevent constant raycasting, should only raycast after camera transform changes etc
func _process(_delta: float) -> void:
	if not actor:
		return

	var hit = _query_focus_hit()
	if hit != last_hit:
		focus_hit.emit(hit if hit else null)
		last_hit = hit

func _get_aim_ray() -> Array:
	# Always use synced camera_basis for determinism
	var camera_input = actor.get_node("FirstPersonCameraInput")
	var camera_basis = camera_input.camera_basis
	
	# Camera position relative to player (from Player.tscn)
	var origin = camera_input.global_position
	var dir = -camera_basis.z
	
	return [origin, dir.normalized()]

func _query_focus_hit() -> Object:
	var origin_dir := _get_aim_ray()
	var origin: Vector3 = origin_dir[0]
	var dir: Vector3 = origin_dir[1]

	var to := origin + dir * max_distance

	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
	query.exclude = [actor.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	return hit.get("collider")
