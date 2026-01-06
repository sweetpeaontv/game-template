extends Node3D

signal focus_hit(hit: Object)

enum AimMode {
	CAMERA_FORWARD,
}

@export var actor: CharacterBody3D
@export var aim_mode: AimMode = AimMode.CAMERA_FORWARD
@export var aim_source: Node3D
@export var max_distance: float = 3.0

var last_hit: Object = null

func _ready() -> void:
	aim_source = get_viewport().get_camera_3d()

# needs to be improved to prevent constant raycasting, should only raycast after camera transform changes etc
func _process(_delta: float) -> void:
	var hit = _query_focus_hit()
	if hit != last_hit:
		if hit:
			focus_hit.emit(hit)
		else:
			focus_hit.emit(null)
		last_hit = hit

func _get_aim_ray() -> Array:
	var origin := aim_source.global_position if aim_source else global_position
	var dir := -aim_source.global_basis.z if aim_source else -global_basis.z
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

	var collider = hit.get("collider")

	return collider
