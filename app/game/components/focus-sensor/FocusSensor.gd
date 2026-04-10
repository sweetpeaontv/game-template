extends Node3D

@export var actor: CharacterBody3D
@export var camera_manager: Node3D
@export var max_distance: float = 3.0

var focus_key: int = 0
var focus: Interactable = null

# INIT
#===================================================================================#
func _ready() -> void:
	# Match PlayerInput: gather on every tick, not only before_tick_loop.
	# When NetworkTime runs multiple ticks per frame (catch-up), a single
	# before_tick_loop sample leaves focus_key stale for later ticks while
	# interact_pressed can still fire — server replay then disagrees with client prediction.
	NetworkTime.before_tick.connect(_gather)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	NetworkTime.before_tick.disconnect(_gather)
#===================================================================================#

# PER TICK
#===================================================================================#
# may want to collect in process (per frame) instead of per tick?
func _gather(_delta: float, _tick: int) -> void:
	if not actor or multiplayer.get_unique_id() != actor.peer_id:
		return
	var hit = _query_focus_hit()
	focus_key = hit.key if hit and hit is Interactable else 0

func _get_aim_origin() -> Vector3:
	return camera_manager.get_camera().global_position

func _get_aim_dir() -> Vector3:
	return -camera_manager.get_look_basis().z

func _get_mouse_aim_origin() -> Vector3:
	var cam: Camera3D = camera_manager.get_camera()
	return cam.project_ray_origin(get_viewport().get_mouse_position())

func _get_mouse_aim_dir() -> Vector3:
	var cam: Camera3D = camera_manager.get_camera()
	return cam.project_ray_normal(get_viewport().get_mouse_position())

func _query_focus_hit() -> Object:
	if not camera_manager:
		SweetLogger.error('No camera manager present for FocusSensor', [], 'FocusSensor.gd', '_query_focus_hit')
		return

	var origin: Vector3
	var dir: Vector3
	var exclude: Array[RID] = [actor.get_rid()]
	if actor.is_examining():
		origin = _get_mouse_aim_origin()
		dir = _get_mouse_aim_dir()
		exclude.append(actor.get_examining().get_rid())
	else:
		origin = _get_aim_origin()
		dir = _get_aim_dir()

	var to := origin + dir * max_distance

	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
	query.exclude = exclude

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider is Pickupable and (collider as Pickupable).holder == actor:
		return null

	return collider
#===================================================================================#

# SYNC
#===================================================================================#
func _handle_focus_sync() -> void:
	if focus_key == 0 and focus != null:
		focus.on_focus_exit(actor)
		focus = null
	if focus_key != 0 and focus != null and focus.key != focus_key:
		focus.on_focus_exit(actor)
		focus = null
	if focus_key != 0 and focus == null:
		var new_focus = InteractableRegistries.interactables.get_entry(focus_key)
		if new_focus:
			focus = new_focus
			focus.on_focus_enter(actor)
#===================================================================================#

# API
#===================================================================================#
func is_focused() -> bool:
	return focus_key != 0

func get_focus() -> Interactable:
	return focus

func get_focus_key() -> int:
	return focus_key
#===================================================================================#
