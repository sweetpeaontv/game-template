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
		examine_camera_anchor.look_at(examine_target.global_position, Vector3.UP)

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
func _interact(_interactor: Node3D, _data: Variant = null) -> void:
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
	label.visible = false
	examiners.append(_interactor)
	examiner_ids.append(_interactor.peer_id)

func disengage(_interactor: Node3D) -> void:
	label.visible = true
	examiners.erase(_interactor)
	examiner_ids.erase(_interactor.peer_id)
#===================================================================================#

# GETTERS
#===================================================================================#
func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.EXAMINABLE
#===================================================================================#
