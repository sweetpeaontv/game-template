@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_tool_menu_item("Create Interactable collision from selected mesh", _on_menu_clicked)

func _exit_tree() -> void:
	remove_tool_menu_item("Create Interactable collision from selected mesh")

func _on_menu_clicked() -> void:
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() < 2:
		_show_error("Select a MeshInstance3D and a CollisionShape3D.")
		return

	var mesh_instance: MeshInstance3D = null
	var collision_shape: CollisionShape3D = null

	for node in selection:
		if node is MeshInstance3D and mesh_instance == null:
			mesh_instance = node as MeshInstance3D
		elif node is CollisionShape3D and collision_shape == null:
			collision_shape = node as CollisionShape3D

	if mesh_instance == null:
		_show_error("No MeshInstance3D in selection.")
		return
	if collision_shape == null:
		_show_error("No CollisionShape3D in selection.")
		return
	if mesh_instance.mesh == null:
		_show_error("Selected mesh has no Mesh resource.")
		return

	# Convex is good for focus/trigger; use create_trimesh_shape() for exact concave if needed
	var shape: Shape3D = mesh_instance.mesh.create_convex_shape()
	collision_shape.shape = shape
	# Place shape in world at the mesh's position; express in collision shape's parent space
	var parent := collision_shape.get_parent()
	collision_shape.transform = parent.global_transform.affine_inverse() * mesh_instance.global_transform

	get_editor_interface().get_resource_filesystem().scan()
	_show_ok("Collision shape created and assigned to %s." % collision_shape.get_path())

func _show_error(message: String) -> void:
	var d := AcceptDialog.new()
	d.title = "Interactable Collision Tool"
	d.dialog_text = message
	get_editor_interface().get_base_control().add_child(d)
	d.popup_centered()
	d.confirmed.connect(d.queue_free)

func _show_ok(message: String) -> void:
	print_rich("[color=green][Interactable Collision Tool][/color] ", message)