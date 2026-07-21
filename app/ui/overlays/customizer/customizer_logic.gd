class_name CustomizerLogic
extends RefCounted

enum PageType { CORE, HEAD, BODY }
enum PageSlot { SLOT_LIST, HEADER, BODY }

const Types := preload("res://app/ui/components/wizard/types.gd")

const labeled_h_slider_scene: PackedScene = preload("res://app/ui/widgets/labeled-h-slider/labeled_h_slider.tscn")
const color_palette_selector_scene: PackedScene = preload("res://app/ui/widgets/color-palette/color_palette_selector.tscn")
const character_model_slot_options_scene: PackedScene = preload("res://app/ui/widgets/character-model-slot-options/character_model_slot_options.tscn")

const BODY_SIDE_MARGIN := 8
const MAX_SIZE := 1.15
const MIN_SIZE := 0.85
const SIZE_STEP := 0.01

signal wizard_cancelled
signal wizard_finished
signal wizard_page_changed(page_index: int)

var _wizard: Control
var _character_config: CharacterConfig

var pages: Dictionary= {
	PageType.CORE: {
		PageSlot.SLOT_LIST: [],
		PageSlot.HEADER: Types.HeaderConfig.new(
			"Core", 
			Types.HeaderButtonConfig.new("Back", false), 
			Types.HeaderButtonConfig.new("Next", false)
		),
	},
	PageType.HEAD: {
		PageSlot.SLOT_LIST: [CharacterConfig.PartSlot.HEAD, CharacterConfig.PartSlot.GLASSES, CharacterConfig.PartSlot.HAIR, CharacterConfig.PartSlot.BEARD],
		PageSlot.HEADER: Types.HeaderConfig.new(
			"Head", 
			Types.HeaderButtonConfig.new("Back", false), 
			Types.HeaderButtonConfig.new("Next", false)
		),
	},
	PageType.BODY: {
		PageSlot.SLOT_LIST: [CharacterConfig.PartSlot.TORSO, CharacterConfig.PartSlot.LEGS, CharacterConfig.PartSlot.SHOES],
		PageSlot.HEADER: Types.HeaderConfig.new(
			"Body", 
			Types.HeaderButtonConfig.new("Back", false), 
			Types.HeaderButtonConfig.new("Finish", false)
		),
	}
}

var options_widgets: Dictionary[CharacterConfig.PartSlot, Node] = {}

# PUBLIC API
#===================================================================================#
func bind_wizard(wizard: Control, character_config: CharacterConfig) -> void:
	_wizard = wizard
	_character_config = character_config

func configure() -> void:
	_create_options()
	_configure_wizard()
#===================================================================================#

# WIZARD SETUP
#===================================================================================#
func _create_options() -> void:
	for page_type in PageType.values():	
		var body_vbox := VBoxContainer.new()
		body_vbox.name = "BodyContainer_%s" % [PageType.keys()[page_type]]

		pages[page_type][PageSlot.BODY] = body_vbox

		if page_type == PageType.CORE:
			_create_core_options()
		else:
			_create_page_options(page_type)

func _create_core_options() -> void:
	for slot in _character_config.core_slot_palette_names:
		var new_option: Node = null
		if slot == CharacterConfig.CoreSlot.SIZE:
			new_option = _create_size_slider()
		else:
			var slot_key: String = _character_config.core_slot_palette_names[slot]
			new_option = color_palette_selector_scene.instantiate()
			new_option.name = "ColorPaletteSelector_%s" % slot_key.capitalize()
			new_option.color_type = slot
			new_option.label_text = slot_key.capitalize()
			new_option.palette_key = slot_key
			new_option.button_pressed.connect(
				func(color_type, color_key): _on_core_color_change(slot, color_type, color_key)
			)
		pages[PageType.CORE][PageSlot.BODY].add_child(new_option)

func _create_size_slider() -> Node:
	var slider := labeled_h_slider_scene.instantiate()
	slider.setup("Size", "SizeSlider", MIN_SIZE, MAX_SIZE, SIZE_STEP, _character_config.character_size, _on_size_change)
	return slider

func _create_page_options(page_type: PageType) -> void:
	for part_slot in pages[page_type][PageSlot.SLOT_LIST]:
		var options_widget = character_model_slot_options_scene.instantiate()
		options_widgets[part_slot] = options_widget

		if part_slot == CharacterConfig.PartSlot.BEARD:
			options_widget.set_mesh_names_filter(
				RegistryLibrary.character_meshes.get_beard_mesh_names_for_head(
					_get_current_part_mesh_name(CharacterConfig.PartSlot.HEAD)
				)
			)

		options_widget.setup(part_slot, _get_current_part_mesh_name(part_slot))
		
		options_widget.mesh_button_pressed.connect(_on_mesh_change)
		options_widget.color_button_pressed.connect(_on_color_change)
		pages[page_type][PageSlot.BODY].add_child(options_widget)

func _configure_wizard() -> void:
	if not _wizard.page_changed.is_connected(_on_wizard_page_changed):
		_wizard.page_changed.connect(_on_wizard_page_changed)
	if not _wizard.wizard_finished.is_connected(_on_wizard_finished):
		_wizard.wizard_finished.connect(_on_wizard_finished)
	if not _wizard.wizard_cancelled.is_connected(_on_wizard_cancelled):
		_wizard.wizard_cancelled.connect(_on_wizard_cancelled)
	
	_wizard.configure_pages(_get_pages())
	_wizard.set_body_margin(BODY_SIDE_MARGIN)
#===================================================================================#

# GETTERS
#===================================================================================#
func _get_pages() -> Array[Types.Page]:
	var new_pages: Array[Types.Page] = []
	for page_type in PageType.values():
		new_pages.append(Types.Page.new(pages[page_type][PageSlot.HEADER], pages[page_type][PageSlot.BODY]))
	return new_pages

func _get_options_widget(part_slot: CharacterConfig.PartSlot) -> Node:
	return options_widgets[part_slot]

func _get_current_part_mesh_name(part_slot: CharacterConfig.PartSlot) -> String:
	var part: CharacterConfig.Part = _character_config.get_part(part_slot)
	if part == null:
		return ""
	return part.mesh_name
#===================================================================================#

# REFRESH
#===================================================================================#
func _refresh_beard_mesh_options(for_head_mesh_name: String) -> void:
	var beard_widget: Node = options_widgets.get(CharacterConfig.PartSlot.BEARD)
	if beard_widget == null:
		return
	var names: Array[String] = RegistryLibrary.character_meshes.get_beard_mesh_names_for_head(for_head_mesh_name)
	beard_widget.rebuild_mesh_options(names)

func _refresh_color_options(mesh_slot: CharacterConfig.PartSlot, mesh_name: String) -> void:
	var color_widget: Node = options_widgets.get(mesh_slot)
	if color_widget == null:
		return
	color_widget.rebuild_color_options(mesh_name)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_mesh_change(mesh_slot: CharacterConfig.PartSlot, mesh_name: String) -> void:
	_character_config.set_part_mesh(mesh_slot, mesh_name)

	var new_updates: Array[Dictionary] = [
		Payload.CharacterChange.make_update(mesh_slot, mesh_name),
	]

	ClientManager.client_relay.make_request(
		CommandRegistry.Command.CHARACTER_CHANGE,
		Payload.CharacterChange.create(new_updates),
	)
	
	if mesh_slot == CharacterConfig.PartSlot.HEAD:
		_refresh_beard_mesh_options(mesh_name)
	_refresh_color_options(mesh_slot, mesh_name)

func _on_color_change(mesh_slot: CharacterConfig.PartSlot, color_type: ColorSet.ColorType, color_key: String) -> void:
	var new_colors := _character_config.partial_part_colors_change(mesh_slot, color_type, color_key)
	
	if new_colors == null:
		SweetLogger.error("failed to get new colors from config", [], "CustomizerLogic.gd", "_on_color_change")
		return
	
	var new_updates: Array[Dictionary] = [
		Payload.CharacterChange.make_update(mesh_slot, null, new_colors),
	]

	ClientManager.client_relay.make_request(
		CommandRegistry.Command.CHARACTER_CHANGE,
		Payload.CharacterChange.create(new_updates)
	)

func _on_core_color_change(core_slot: CharacterConfig.CoreSlot, color_type: ColorSet.ColorType, color_key: String) -> void:
	var changed_slots: Array[CharacterConfig.PartSlot] = _character_config.set_core_color(core_slot, color_type, color_key)

	if changed_slots.is_empty():
		return

	var new_updates: Array[Dictionary] = []
	for slot in changed_slots:
		new_updates.append(Payload.CharacterChange.make_update(slot, null, _character_config.get_part_colors(slot)))

	ClientManager.client_relay.make_request(
		CommandRegistry.Command.CHARACTER_CHANGE,
		Payload.CharacterChange.create(new_updates)
	)

func _on_size_change(new_size: float) -> void:
	_character_config.set_size(new_size)

	ClientManager.client_relay.make_request(
		CommandRegistry.Command.CHARACTER_CHANGE,
		Payload.CharacterChange.create([], new_size)
	)

func _on_wizard_finished() -> void:
	# NEEDS TO COMMIT THE CONFIG SNAPSHOT TO PERSISTENT DATA
	wizard_finished.emit()

func _on_wizard_cancelled() -> void:
	# NEEDS TO COMMIT THE CONFIG SNAPSHOT TO PERSISTENT DATA
	wizard_cancelled.emit()

func _on_wizard_page_changed(page_index: int) -> void:
	wizard_page_changed.emit(page_index)
#===================================================================================#
