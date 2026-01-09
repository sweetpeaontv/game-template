extends Node

@onready var MainMenu: Node2D = $MainMenu
@onready var SettingsModal: Node2D = $SettingsModal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MainMenu.visible = true
	MainMenu.settings_button_pressed.connect(_onSettingsButtonPressed)
	
	SettingsModal.visible = false
	SettingsModal.back_button_pressed.connect(_onBackButtonPressed)

func _onSettingsButtonPressed() -> void:
	MainMenu.visible = false
	SettingsModal.visible = true

func _onBackButtonPressed() -> void:
	SettingsModal.visible = false
	MainMenu.visible = true
