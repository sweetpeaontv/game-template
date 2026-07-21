extends HBoxContainer

signal exit_customizer()

var _logic: CustomizerLogic
var _config: CharacterConfig
var return_ui: String = ""

@onready var wizard: Control = $Wizard

func _ready() -> void:
	_logic = CustomizerLogic.new()
	_logic.bind_wizard(wizard, _config)
	_logic.configure()

	_logic.wizard_page_changed.connect(_on_page_changed)
	_logic.wizard_finished.connect(_on_finished)
	_logic.wizard_cancelled.connect(_on_cancelled)

func setup(data: Dictionary) -> void:
	return_ui = data.get("return_ui", "EscMenu")
	_config = PlayerUtils.get_local_player_config()

# SIGNAL HANDLERS
#===================================================================================#
func _on_finished() -> void:
	PersistentData.commit_from_config(_config)
	UIManager.hide_ui("InGameCustomizer")
	UIManager.show_ui(return_ui)
	exit_customizer.emit()

func _on_cancelled() -> void:
	PersistentData.commit_from_config(_config)
	UIManager.hide_ui("InGameCustomizer")
	UIManager.show_ui(return_ui)
	exit_customizer.emit()

func _on_page_changed(page_index: int) -> void:
	pass
	# camera transition with camera manager
#===================================================================================#
