@tool
extends EditorPlugin

const MENU_LABEL := "Apply GLB mesh+skin to selected MeshInstance3D"
const DIALOG_TITLE := "Apply GLB Mesh To Skeleton"

func _enter_tree() -> void:
	add_tool_menu_item(MENU_LABEL, _on_menu_clicked)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_LABEL)

func _on_menu_clicked() -> void:
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() < 2:
		_show_error("Select two nodes: a GLB scene node (or MeshInstance3D from it) and a target MeshInstance3D.")
		return

	var target := _find_target_mesh(selection)
	if target == null:
		_show_error("Could not find target MeshInstance3D in selection.")
		return

	var source := _find_source_mesh(selection, target)
	if source == null:
		_show_error("Could not find source MeshInstance3D in selected GLB scene.")
		return

	if source.mesh == null:
		_show_error("Source MeshInstance3D has no mesh.")
		return

	target.mesh = source.mesh
	target.skin = source.skin

	_show_ok("Assigned mesh and skin from %s to %s" % [source.get_path(), target.get_path()])

func _find_target_mesh(nodes: Array) -> MeshInstance3D:
	var meshes: Array[MeshInstance3D] = []
	for node in nodes:
		if node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)

	if meshes.size() == 1:
		return meshes[0]

	if meshes.size() >= 2:
		for mesh in meshes:
			if mesh.skin == null:
				return mesh
		return meshes[0]

	return null

func _find_source_mesh(nodes: Array, target: MeshInstance3D) -> MeshInstance3D:
	for node in nodes:
		if node == target:
			continue

		if node is MeshInstance3D:
			return node as MeshInstance3D

		var nested := _find_first_mesh_instance(node)
		if nested != null:
			return nested

	return null

func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found

	return null

func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = DIALOG_TITLE
	dialog.dialog_text = message
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _show_ok(message: String) -> void:
	print_rich("[color=green][Apply GLB Mesh][/color] ", message)
