extends Area3D
class_name Interactable

@onready var label: Label3D = $InteractionLabel

@export var interaction_label_text: String = ""
@export var parent: Node3D = null

func _ready() -> void:
	label.visible = false
	parent = get_parent()
	# haven't found a more elegant way to do this
	if self is Area3D:
		self.collision_layer = LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
	else:
		SweetLogger.error("No focus area found for interactable {0}", [name], "Interactable.gd", "_ready")
	_on_ready()

func _on_ready() -> void:
	''' Override this in subclasses for initialization. Called in _ready() '''
	pass

func _get_interact_key_text() -> String:
	"""Returns the text representation of the interact key, or a fallback if not found."""
	var events = InputMap.action_get_events("interact")
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			var keycode = event.keycode if event.keycode != 0 else event.physical_keycode
			return OS.get_keycode_string(keycode)
	# fallback
	return "error"

func _get_label_text() -> String:
	"""Override this to customize the label text."""
	if interaction_label_text != "":
		return interaction_label_text
	return _get_interact_key_text()

func interact(interactor: Node3D, _data: Variant = null) -> void:
	"""Public method to trigger interaction - can be called by player controller."""
	_interact(interactor, _data)

func _interact(_interactor: Node3D, _data: Variant = null) -> void:
	''' Override this in subclasses for custom interaction logic '''
	SweetLogger.info("{0} Interacting with {1} in _interact", ['Player_%d' % _interactor.peer_id, name])

func _interact_rollback_tick(_delta, _tick):
	''' Override this in subclasses for custom rollback logic '''
	pass

func _interact_physics_rollback_tick(_delta, _tick):
	''' Override this in subclasses for custom physics rollback logic '''
	pass

func on_focus_enter(focuser: Node3D) -> void:
	if not focuser is CharacterBody3D:
		return
	
	var my_id = multiplayer.get_unique_id()
	if focuser.peer_id == my_id:
		label.text = _get_label_text()
		label.visible = true

func on_focus_exit(focuser: Node3D) -> void:
	if not focuser is CharacterBody3D:
		return
	
	var my_id = multiplayer.get_unique_id()
	if focuser.peer_id == my_id:
		label.visible = false
