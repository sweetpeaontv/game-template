class_name Examinable
extends Interactable

@export var examine_camera_anchor: Node3D
@export var examine_target: Node3D

var _sync_state: SyncStateNode = null

# INIT
#===================================================================================#
func _on_ready() -> void:
	if examine_camera_anchor and examine_target:
		examine_camera_anchor.look_at(_get_examine_target_position(), Vector3.UP)

	RegistryLibrary.examinables.add_entry(key, self)

	_sync_state = get_node_or_null("SyncState") as SyncStateNode
	if _sync_state:
		_sync_state.state_applied.connect(_on_sync_state_applied)
		_on_sync_state_applied(_sync_state.state)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	RegistryLibrary.examinables.remove_entry(key)
	super._exit_tree()
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
	var examiner_id_list: Array = _sync_state.state.get("examiner_ids", []).duplicate()

	if _interactor.peer_id not in examiner_id_list:
		examiner_id_list.append(_interactor.peer_id)

	_sync_state.update({ "examiner_ids": examiner_id_list })

	if _interactor.peer_id == multiplayer.get_unique_id():
		label.visible = false

func disengage(_interactor: Node3D) -> void:
	var examiner_id_list: Array = _sync_state.state.get("examiner_ids", []).duplicate()

	examiner_id_list.erase(_interactor.peer_id)

	_sync_state.update({ "examiner_ids": examiner_id_list })

	if _interactor.peer_id == multiplayer.get_unique_id():
		label.visible = true
#===================================================================================#

# SYNC
#===================================================================================#
func _on_sync_state_applied(_state: Dictionary) -> void:
	pass
	# Could do something here to show/hide the label based on the examiner_ids
	# or animate something based on the examiner_ids
#===================================================================================#
