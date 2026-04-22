extends Interactable
class_name Examinable

@export var examine_camera_anchor: Node3D
@export var examine_target: Node3D

var examiners: Array[Node3D] = []
var examiner_ids: Array[int] = []

# INIT
#===================================================================================#
func _on_ready() -> void:
	if examine_camera_anchor and examine_target:
		examine_camera_anchor.look_at(_get_examine_target_position(), Vector3.UP)

	InteractableRegistries.examinables.add_entry(key, self)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	InteractableRegistries.examinables.remove_entry(key)
	super._exit_tree()
#===================================================================================#

# INTERACTION
#===================================================================================#
func _interact(_interactor: Node3D, _data: Variant = null, _rollback_is_fresh: bool = true) -> void:
	if not _data is InteractionTypes.ExaminableData:
		SweetLogger.error("Invalid data type: {0}", [_data.get_class()], "Examinable.gd", "_interact")
		return

	var action = _data.action
	match action:
		InteractionTypes.ExaminableData.Action.EXAMINE:
			examine(_interactor)
		InteractionTypes.ExaminableData.Action.DISENGAGE:
			disengage(_interactor)

func examine(_interactor: Node3D) -> void:
	examiners.append(_interactor)
	examiner_ids.append(_interactor.peer_id)

	if _interactor.peer_id == multiplayer.get_unique_id():
		label.visible = false

func disengage(_interactor: Node3D) -> void:
	examiners.erase(_interactor)
	examiner_ids.erase(_interactor.peer_id)

	if _interactor.peer_id == multiplayer.get_unique_id():
		label.visible = true
#===================================================================================#

# GETTERS
#===================================================================================#
func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.EXAMINABLE
#===================================================================================#

# HELPERS
#===================================================================================#
func _get_examine_target_position() -> Vector3:
	if examine_target is CollisionShape3D:
		var collision_shape := examine_target as CollisionShape3D
		if collision_shape.shape:
			var debug_mesh := collision_shape.shape.get_debug_mesh()
			var local_center := debug_mesh.get_aabb().get_center()
			return collision_shape.global_transform * local_center

	if examine_target is MeshInstance3D:
		var mesh_instance := examine_target as MeshInstance3D
		if mesh_instance.mesh:
			var local_center := mesh_instance.mesh.get_aabb().get_center()
			return mesh_instance.global_transform * local_center

	return examine_target.global_position
#===================================================================================#

# ROLLBACK
#===================================================================================#
func _interact_rollback_tick(_delta, _tick):
	_handle_examiner_sync()

# can basically copy pickupable _handle_holder_sync logic
func _handle_examiner_sync() -> void:
	pass
#===================================================================================#
