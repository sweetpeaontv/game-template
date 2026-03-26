extends Area3D
class_name Interactable

@onready var label: Label3D = $InteractionLabel

@export var interaction_label_text: String = ""
@export var parent: Node3D = null
@export var key: int = 0

# INIT
#===================================================================================#
func _ready() -> void:
	label.visible = false
	parent = get_parent()
	key = get_path().hash()
	InteractableRegistries.interactables.add_entry(key, self)
	# haven't found a more elegant way to do this
	if self is Area3D:
		self.collision_layer = LayerDefs.PHYSICS_LAYERS_3D["WORLD"] | LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
	else:
		SweetLogger.error("No focus area found for interactable {0}", [name], "Interactable.gd", "_ready")
	_on_ready()
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	InteractableRegistries.interactables.remove_entry(key)
#===================================================================================#

# VIRTUAL METHODS
#===================================================================================#
## Override this in subclasses for initialization. Called in _ready()
func _on_ready() -> void:
	pass

## Public method to trigger interaction - can be called by player controller.
func interact(interactor: Node3D, _data: Variant = null) -> void:
	_interact(interactor, _data)

## Override this in subclasses for custom interaction logic
func _interact(_interactor: Node3D, _data: Variant = null) -> void:
	SweetLogger.info("{0} Interacting with {1} in _interact", ['Player_%d' % _interactor.peer_id, name])

## Override this in subclasses for custom rollback logic
func _interact_rollback_tick(_delta, _tick):
	pass

## Override this in subclasses for custom physics rollback logic
func _interact_physics_rollback_tick(_delta, _tick):
	pass
#===================================================================================#

# FOCUS CHANGE
#===================================================================================#
func should_show_focus_label(focuser: Node3D) -> bool:
	if not focuser is CharacterBody3D:
		return false
	
	var my_id = multiplayer.get_unique_id()
	if focuser.peer_id == my_id and not focuser.is_examining():
		return true
	return false

func on_focus_enter(focuser: Node3D) -> void:
	if not focuser is CharacterBody3D:
		return
	
	if should_show_focus_label(focuser):
		label.text = _get_label_text()
		label.visible = true

func on_focus_exit(focuser: Node3D) -> void:
	if not focuser is CharacterBody3D:
		return
	
	var my_id = multiplayer.get_unique_id()
	if focuser.peer_id == my_id:
		label.visible = false

## Call when focus stays on this interactable but per-player state (e.g. examining) changes.
func refresh_focus_label(focuser: Node3D) -> void:
	if not focuser is CharacterBody3D:
		return
	var my_id = multiplayer.get_unique_id()
	if focuser.peer_id != my_id:
		return
	if should_show_focus_label(focuser):
		label.text = _get_label_text()
		label.visible = true
	else:
		label.visible = false
#===================================================================================#

# GETTERS
#===================================================================================#
## Returns the text representation of the interact key, or a fallback if not found.
func _get_interact_key_text() -> String:
	var events = InputMap.action_get_events("interact")
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			var keycode = event.keycode if event.keycode != 0 else event.physical_keycode
			return OS.get_keycode_string(keycode)
	# fallback
	return "error"

## Override this in subclasses to return the InteractionType enum value
func get_interaction_type() -> int:
	SweetLogger.error("Function must be overridden in subclass", [], "Interactable.gd", "get_interaction_type")
	return -1

## Override this to customize the label text.
func _get_label_text() -> String:
	if interaction_label_text != "":
		return interaction_label_text
	return _get_interact_key_text()
#===================================================================================#
