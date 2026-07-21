extends Control

@onready var back_button: Button = $BackButton

var return_ui: String = "MainMenu"

func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)

func setup(data: Dictionary) -> void:
	return_ui = data.get("return_ui", "MainMenu")

func _on_back_button_pressed() -> void:
	UIManager.hide_ui("Settings")
	UIManager.show_ui(return_ui)
