extends Node3D

@onready var label: Label3D = $InteractionLabel

func _ready() -> void:
	label.visible = false
	# haven't found a more elegant way to do this
	get_parent().collision_layer |= LayerDefs.PHYSICS_LAYERS_3D["INTERACTABLE"]

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

func _interact():
	Logger.info("Interacting with {0}", [get_parent().name])

	# If the parent is not the multiplayer authority, send RPC to server
	if not get_parent().is_multiplayer_authority():
		_interact_on_server.rpc_id(1)
		return

	# If we are the authority, perform the interaction
	_perform_interaction()

@rpc("any_peer", "call_remote", "reliable")
func _interact_on_server():
	# Verify we're on the server
	if not get_parent().is_multiplayer_authority():
		return

	_perform_interaction()

func _perform_interaction():
	var parent = get_parent()
	if parent.has_method("_on_interact"):
		parent._on_interact()
	else:
		Logger.warn("Parent {0} has no _on_interact method", [parent.name])

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
