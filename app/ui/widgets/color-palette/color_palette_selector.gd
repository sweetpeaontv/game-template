extends VBoxContainer

signal button_pressed(color_type: ColorSet.ColorType, color_key: String)

@export var color_type: ColorSet.ColorType
@export var palette_key: String
@export var label_text: String
@onready var label: Label = $Label
@onready var button_container: HFlowContainer = $ButtonContainer
@onready var button_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	label.text = label_text
	populate_button_set()

func add_button(color_key: String) -> void:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.button_group = button_group
	button.custom_minimum_size = Vector2(32, 32)

	var swatch_color: Color = RegistryLibrary.colors.get_color(color_key)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = swatch_color
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", sb)

	button.pressed.connect(button_pressed.emit.bind(color_type, color_key))
	button_container.add_child(button)

func populate_button_set() -> void:
	if not palette_key.is_empty():
		populate_from_palette()
		return

	populate_from_registry()

func populate_from_registry() -> void:
	for color_key in RegistryLibrary.colors.color_slots.get(color_type, []):
		add_button(color_key)

func populate_from_palette() -> void:
	for color_key in RegistryLibrary.colors.PALETTES.get(palette_key, []):
		add_button(color_key)
