extends VBoxContainer

signal mesh_button_pressed(mesh_slot: CharacterConfig.PartSlot, mesh_name: String)
signal color_button_pressed(mesh_slot: CharacterConfig.PartSlot, color_type: ColorSet.ColorType, color_key: String)

@export var mesh_part_slot: CharacterConfig.PartSlot
@onready var title: Label = $Title

var palette_selector_scene = preload("res://app/ui/widgets/color-palette/color_palette_selector.tscn")

## When active, mesh buttons use only [member mesh_names_allowlist] (may be empty). Otherwise the full registry list for [member mesh_part_slot].
var mesh_names_allowlist: Array[String] = []
var _mesh_names_allowlist_active: bool = false

# INIT
#===================================================================================#
func _ready() -> void:
	title.text = String(CharacterConfig.PartSlot.find_key(mesh_part_slot)).capitalize()

func set_mesh_names_filter(mesh_names: Array[String]) -> void:
	mesh_names_allowlist.assign(mesh_names)
	_mesh_names_allowlist_active = true

func setup(part_slot: CharacterConfig.PartSlot, mesh_name: String) -> void:
	mesh_part_slot = part_slot
	name = "%s_%s" % [str(part_slot), name]

	_add_mesh_options()
	_add_color_options(mesh_name)
#===================================================================================#

# REBUILD
#===================================================================================#
func rebuild_mesh_options(mesh_names: Array[String]) -> void:
	set_mesh_names_filter(mesh_names)
	_clear_mesh_option_buttons()
	_add_mesh_options()

func _clear_mesh_option_buttons() -> void:
	var mesh_options := _get_mesh_options()
	while mesh_options.get_child_count() > 0:
		var child: Node = mesh_options.get_child(0)
		mesh_options.remove_child(child)
		child.free()

func rebuild_color_options(mesh_name: String) -> void:
	_clear_color_option_buttons()
	_add_color_options(mesh_name)

func _clear_color_option_buttons() -> void:
	var color_options := _get_color_options()
	while color_options.get_child_count() > 0:
		var child: Node = color_options.get_child(0)
		color_options.remove_child(child)
		child.free()
#===================================================================================#

# ADD MESH OPTIONS
#===================================================================================#
func _add_mesh_options() -> void:
	var names: Array[String]
	if _mesh_names_allowlist_active:
		names = mesh_names_allowlist
	else:
		names = RegistryLibrary.character_meshes.get_mesh_names(mesh_part_slot)
	_include_empty_mesh_option()
	for mesh_name in names:
		_add_mesh_option(mesh_name)

func _add_mesh_option(mesh_name: String) -> void:
	var button: Button = Button.new()
	button.text = RegistryLibrary.character_meshes.get_display_name(mesh_name)
	button.pressed.connect(mesh_button_pressed.emit.bind(mesh_part_slot, mesh_name))
	_get_mesh_options().add_child(button)

func _include_empty_mesh_option() -> void:
	if not CharacterConfig.CLEARABLE_PARTSLOTS.has(mesh_part_slot):
		return
	
	var button: Button = Button.new()
	button.text = "None"
	button.pressed.connect(mesh_button_pressed.emit.bind(mesh_part_slot, CharacterConfig.no_mesh_name))
	_get_mesh_options().add_child(button)
#===================================================================================#

# NODE ACCESS
#===================================================================================#
func _get_mesh_options() -> HFlowContainer:
	return $MeshOptions

func _get_color_options() -> VBoxContainer:
	return $ColorOptions
#===================================================================================#

# ADD COLOR OPTIONS
#===================================================================================#
func _add_color_options(mesh_name: String) -> void:
	var preset: Array = RegistryLibrary.character_mesh_palettes.get_preset(mesh_part_slot, mesh_name)
	for preset_item in preset:
		_add_color_option(preset_item["color_type"], preset_item["label"], preset_item["palette"])

func _add_color_option(color_type: ColorSet.ColorType, label_text: String, palette_key: String) -> void:
	var palette_selector = palette_selector_scene.instantiate()
	palette_selector.color_type = color_type
	palette_selector.label_text = label_text
	palette_selector.palette_key = palette_key
	palette_selector.button_pressed.connect(_on_palette_button_pressed)
	_get_color_options().add_child(palette_selector)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_palette_button_pressed(color_type: ColorSet.ColorType, color_key: String) -> void:
	SweetLogger.info("CharacterModelSlotOptions._on_palette_button_pressed: palette button pressed", [color_type, color_key], "CharacterModelSlotOptions.gd", "_on_palette_button_pressed")
	color_button_pressed.emit(mesh_part_slot, color_type, color_key)
#===================================================================================#
