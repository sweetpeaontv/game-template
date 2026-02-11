extends Interactable
class_name Examinable

# INIT
#===================================================================================#
func _on_ready() -> void:
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
	pass
#===================================================================================#