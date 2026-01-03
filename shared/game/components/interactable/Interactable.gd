extends Node3D

@onready var label: Label3D = $InteractionLabel

func _ready() -> void:
	label.visible = false

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
