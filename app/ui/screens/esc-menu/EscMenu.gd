extends Node2D

signal resume_pressed()

@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var disconnect_button: Button = $VBoxContainer/DisconnectButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	disconnect_button.pressed.connect(_on_disconnect_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_resume_button_pressed() -> void:
	resume_pressed.emit()

func _on_settings_button_pressed() -> void:
	pass

func _on_disconnect_button_pressed() -> void:
	ClientManager.disconnect_game()
	UIManager.hide_ui("EscMenu")
	SceneManager.goto_scene("HomeMenu")

func _on_quit_button_pressed() -> void:
	pass
