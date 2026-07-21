class_name CharacterMeshRegistry
extends RefCounted

const SLOT_DIRS := {
	CharacterConfig.PartSlot.HEAD: "res://app/game/character/model/parts/heads",
	CharacterConfig.PartSlot.GLASSES: "res://app/game/character/model/parts/glasses",
	CharacterConfig.PartSlot.HAIR: "res://app/game/character/model/parts/hair",
	CharacterConfig.PartSlot.BEARD: "res://app/game/character/model/parts/beard",
	CharacterConfig.PartSlot.TORSO: "res://app/game/character/model/parts/torsos",
	CharacterConfig.PartSlot.LEGS: "res://app/game/character/model/parts/legs",
	CharacterConfig.PartSlot.SHOES: "res://app/game/character/model/parts/shoes",
}
const DISPLAY_SEP := "__"

# Shape: { CharacterConfig.PartSlot: { String(mesh_name): String(mesh_resource_path) } }
var _character_meshes: Dictionary = {}
var _mesh_display_names: Dictionary = {}

func _init() -> void:
	rebuild()

func rebuild() -> void:
	_character_meshes.clear()
	_mesh_display_names.clear()
	for slot in SLOT_DIRS.keys():
		var result = _scan_slot_dir(SLOT_DIRS[slot])
		_character_meshes[slot] = result["meshes"]
		_mesh_display_names[slot] = result["display_names"]

func get_mesh_names(slot: CharacterConfig.PartSlot) -> Array[String]:
	var slot_meshes := _character_meshes.get(slot, {}) as Dictionary
	var mesh_names: Array[String] = []
	for mesh_name in slot_meshes.keys():
		mesh_names.append(String(mesh_name))
	return mesh_names

## Beards use [code]m_beard_<head_index>_<variant_index>[/code] (same [code]m_|f_[/code] prefix as the head).
## Only names whose head index matches [param head_mesh_name] are returned, ordered by variant index.
func get_beard_mesh_names_for_head(head_mesh_name: String) -> Array[String]:
	if head_mesh_name.is_empty():
		return []
	var head_re := RegEx.new()
	head_re.compile("^(m_|f_)head_(\\d+)$")
	var head_match := head_re.search(head_mesh_name)
	if head_match == null:
		return []
	var prefix: String = head_match.get_string(1)
	var head_index: String = head_match.get_string(2)
	var beard_re := RegEx.new()
	beard_re.compile("^(m_|f_)beard_(\\d+)_(\\d+)(__.*)?$")
	var slot_meshes := _character_meshes.get(CharacterConfig.PartSlot.BEARD, {}) as Dictionary
	var beard_mesh_names: Array[String] = []
	for mesh_name in slot_meshes.keys():
		var mesh_str := String(mesh_name)
		var beard_match := beard_re.search(mesh_str)
		if beard_match == null:
			continue
		if beard_match.get_string(1) != prefix or beard_match.get_string(2) != head_index:
			continue
		beard_mesh_names.append(mesh_str)
	beard_mesh_names.sort_custom(func(a: String, b: String) -> bool:
		var ma := beard_re.search(a)
		var mb := beard_re.search(b)
		return int(ma.get_string(3)) < int(mb.get_string(3))
	)
	return beard_mesh_names

func get_display_name(mesh_name: String) -> String:
	return parse_display_name(mesh_name)

func parse_display_name(mesh_name: String) -> String:
	var base: String
	var has_override := false
	var idx := mesh_name.find(DISPLAY_SEP)
	if idx != -1:
		base = mesh_name.substr(idx + DISPLAY_SEP.length())
		has_override = true
	else:
		base = mesh_name
		if base.begins_with("f_") or base.begins_with("m_"):
			base = base.substr(2)
	if has_override:
		base = _strip_trailing_variant(base)
	return base.capitalize().replace("_", " ")

func _strip_trailing_variant(s: String) -> String:
	while s.length() > 0 and (s.right(1) == "_" or s.right(1).is_valid_int()):
		s = s.substr(0, s.length() - 1)
	return s

func has_mesh(slot: CharacterConfig.PartSlot, mesh_name: String) -> bool:
	var slot_meshes := _character_meshes.get(slot, {}) as Dictionary
	return slot_meshes.has(mesh_name)

func get_mesh_path(slot: CharacterConfig.PartSlot, mesh_name: String) -> String:
	var slot_meshes := _character_meshes.get(slot, {}) as Dictionary
	return slot_meshes.get(mesh_name, "") as String

func _scan_slot_dir(dir_path: String) -> Dictionary:
	var meshes := {}
	var display_names := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("MeshRegistry: missing mesh directory %s" % dir_path)
		return meshes

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".res"):
			var mesh_name := file_name.get_basename()
			if meshes.has(mesh_name):
				push_warning("MeshRegistry: duplicate mesh name %s in %s" % [mesh_name, dir_path])
			meshes[mesh_name] = "%s/%s" % [dir_path, file_name]
			display_names[mesh_name] = parse_display_name(mesh_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return { "meshes": meshes, "display_names": display_names }
