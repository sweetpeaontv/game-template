class_name CharacterBuilder
extends Node

const ColorsRegistryScript := preload("res://app/data/registries/colors.gd")

const ALL_SLOTS: Array[CharacterConfig.PartSlot] = [
	CharacterConfig.PartSlot.HEAD,
	CharacterConfig.PartSlot.GLASSES,
	CharacterConfig.PartSlot.HAIR,
	CharacterConfig.PartSlot.BEARD,
	CharacterConfig.PartSlot.TORSO,
	CharacterConfig.PartSlot.LEGS,
	CharacterConfig.PartSlot.SHOES,
]

@export_node_path("CharacterConfig") var config_path: NodePath
@export var armature_path: NodePath

var _config: CharacterConfig
var _colors_registry: RefCounted
var _armature: Node3D

# INIT
#===================================================================================#
func setup(config: CharacterConfig, armature: Node3D) -> void:
	self.name = "Builder"
	_config = config
	_armature = armature
	_colors_registry = ColorsRegistryScript.new()
	if _config and not _config.config_changed.is_connected(_on_config_changed):
		_config.config_changed.connect(_on_config_changed)
	_sync_all_slots()

func _ready() -> void:
	pass
#===================================================================================#

# EXIT
#===================================================================================#
func _exit_tree() -> void:
	if _config and _config.config_changed.is_connected(_on_config_changed):
		_config.config_changed.disconnect(_on_config_changed)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_config_changed(part_slots: Array[CharacterConfig.PartSlot]) -> void:
	SweetLogger.info("CharacterBuilder._on_config_changed: config changed", [], "CharacterBuilder.gd", "_on_config_changed")
	for part_slot in part_slots:
		sync_slot(part_slot as CharacterConfig.PartSlot)
#===================================================================================#

# SYNC
#===================================================================================#
func _sync_all_slots() -> void:
	for slot in ALL_SLOTS:
		sync_slot(slot)

## Resolve one slot from config and send mesh + colors to the armature.
func sync_slot(slot: CharacterConfig.PartSlot) -> void:
	if _config == null or _armature == null:
		SweetLogger.error("CharacterBuilder.sync_slot: no config or armature found", [], "CharacterBuilder.gd", "sync_slot")
		return
	
	var part := _config.get_part(slot)
	if part == null:
		SweetLogger.error("CharacterBuilder.sync_slot: no part found for slot {0}", [slot], "CharacterBuilder.gd", "sync_slot")
		return
	
	var mesh := _resolve_mesh(slot, part.mesh_name)
	var uniforms := _resolve_color_uniforms(part.colors)

	if mesh == null and uniforms == null:
		SweetLogger.error("CharacterBuilder.sync_slot: no mesh and uniforms found for slot {0}", [slot], "CharacterBuilder.gd", "sync_slot")
		return

	if _armature.has_method("apply_part"):
		_armature.call("apply_part", slot, mesh, uniforms)

func _resolve_mesh(slot: CharacterConfig.PartSlot, mesh_name: String) -> Mesh:
	if mesh_name.is_empty():
		return null

	if not RegistryLibrary.character_meshes.has_mesh(slot, mesh_name):
		return null

	var mesh_path := RegistryLibrary.character_meshes.get_mesh_path(slot, mesh_name)
	if mesh_path.is_empty():
		return null

	return load(mesh_path) as Mesh

## Maps ColorSet string IDs to atlas UVs (or other shader inputs) from the colors registry.
func _resolve_color_uniforms(colors: ColorSet) -> Dictionary:
	if colors == null:
		return {}
	var uv_table: Dictionary = _colors_registry.retro_color_uvs
	return {
		"skin_uv": uv_table.get(colors.skin, Vector2.ZERO),
		"base_uv": uv_table.get(colors.base, Vector2.ZERO),
		"accent_uv": uv_table.get(colors.accent, Vector2.ZERO),
		"detail_uv": uv_table.get(colors.detail, Vector2.ZERO),
	} as Dictionary
#===================================================================================#
