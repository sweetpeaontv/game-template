extends HBoxContainer

const ROTATE_SENSITIVITY := 0.4
const BODY_SIDE_MARGIN := 8

var _logic: CustomizerLogic
var _config: CharacterConfig
var return_ui: String = ""

@onready var wizard: Control = $Wizard
@onready var character_viewer: Node3D = $PreviewRoot/SubViewPortContainer/SubViewport/CharacterViewer

var mouse_over_rotation_region: bool = false

# INIT
#===================================================================================#
func _ready() -> void:
	_logic = CustomizerLogic.new()
	_logic.bind_wizard(wizard, _config)
	_logic.configure()
	character_viewer.mount_character(_config)

	_logic.wizard_page_changed.connect(_on_page_changed)
	_logic.wizard_finished.connect(_on_finished)
	_logic.wizard_cancelled.connect(_on_cancelled)

func setup(data: Dictionary) -> void:
	return_ui = data.get("return_ui", "MainMenu")
	_config = CharacterConfig.new(PersistentData.get_character_snapshot())
#===================================================================================#

# ROTATION
#===================================================================================#
func _on_rotation_region_mouse_entered() -> void:
	mouse_over_rotation_region = true

func _on_rotation_region_mouse_exited() -> void:
	mouse_over_rotation_region = false

func _input(event) -> void:
	if not event is InputEventMouseMotion:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if not mouse_over_rotation_region:
		return
	
	character_viewer.rotate_character(event.relative.x * ROTATE_SENSITIVITY)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_finished() -> void:
	PersistentData.commit_from_config(_config)
	UIManager.hide_ui("MainMenuCustomizer")
	UIManager.show_ui(return_ui)

func _on_cancelled() -> void:
	PersistentData.commit_from_config(_config)
	UIManager.hide_ui("MainMenuCustomizer")
	UIManager.show_ui(return_ui)

func _on_page_changed(page_index: int) -> void:
	character_viewer.set_view_for_page(page_index)
#===================================================================================#
