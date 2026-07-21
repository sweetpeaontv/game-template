extends Node2D

signal resume_pressed()

@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var customizer_button: Button = $VBoxContainer/CustomizerButton
@onready var disconnect_button: Button = $VBoxContainer/DisconnectButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	customizer_button.pressed.connect(_on_customizer_button_pressed)
	disconnect_button.pressed.connect(_on_disconnect_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_resume_button_pressed() -> void:
	UIManager.pop_world_blur()
	UIManager.hide_ui("EscMenu")
	UIManager.show_ui("Crosshair")
	InputModeManager.set_input_mode(Input.MOUSE_MODE_CAPTURED)
	resume_pressed.emit()

func _on_settings_button_pressed() -> void:
	UIManager.hide_ui("EscMenu", false)
	UIManager.show_ui("Settings", { "return_ui": "EscMenu" })

func _on_customizer_button_pressed() -> void:
	UIManager.hide_ui("EscMenu", false)
	UIManager.show_ui("InGameCustomizer", { "return_ui": "EscMenu" })

func _on_disconnect_button_pressed() -> void:
	UIManager.pop_world_blur()
	ClientManager.disconnect_game()
	UIManager.hide_ui("EscMenu")
	SceneManager.goto_scene("MenuWorld")
	UIManager.show_ui("MainMenu")

func _on_quit_button_pressed() -> void:
	ClientManager.disconnect_game()
	get_tree().quit()
