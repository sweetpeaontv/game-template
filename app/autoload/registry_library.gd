extends Node

var interactables: Registry = Registry.new()
var operables: Registry = Registry.new()
var pickupables: Registry = Registry.new()
var examinables: Registry = Registry.new()

var sync_targets: SyncTargetRegistry = SyncTargetRegistry.new()

var character_meshes: CharacterMeshRegistry = CharacterMeshRegistry.new()
var character_mesh_palettes: CharacterMeshPaletteRegistry = CharacterMeshPaletteRegistry.new()
var colors: ColorsRegistry = ColorsRegistry.new()
