extends Node3D
class_name Interactable

@onready var label: Label3D = $InteractionLabel
@export var interaction_label_text: String = ""

func _ready() -> void:
	label.visible = false
	# haven't found a more elegant way to do this
	get_parent().collision_layer |= LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]
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

func interact(interactor_peer_id: int, _data: Variant = null) -> void:
	"""Public method to trigger interaction - can be called by player controller."""
	_interact(interactor_peer_id, _data)

func _interact(_interactor_peer_id: int, _data: Variant = null) -> void:
	''' Override this in subclasses for custom interaction logic '''
	SweetLogger.info("{0} Interacting with {1} in _interact", ['Player_%d' % _interactor_peer_id, name])

func _interact_rollback_tick(_delta, _tick):
	''' Override this in subclasses for custom rollback logic '''
	pass

func _interact_physics_rollback_tick(_delta, _tick):
	''' Override this in subclasses for custom physics rollback logic '''
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	var my_id = multiplayer.get_unique_id()
	if body.peer_id == my_id:
		label.text = _get_interact_key_text()
		label.visible = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	var my_id = multiplayer.get_unique_id()
	if body.peer_id == my_id:
		label.visible = false
