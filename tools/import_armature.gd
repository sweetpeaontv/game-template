@tool
extends EditorScenePostImport

var destination = "res://app/game/character/model/armature/"

func _post_import(scene: Node) -> Object:
	var mesh_instance = find_mesh_instance(scene)
	if not mesh_instance:
		print("No MeshInstance3D found!")
		return scene
	
	var save_path = destination + "/skin.res"
	var err = ResourceSaver.save(mesh_instance.skin, save_path)
	if err == OK:
		print("Saved skin: ", save_path)
	else:
		print("Failed to save skin: ", err)
	
	return scene

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = find_mesh_instance(child)
		if result:
			return result
	return null
