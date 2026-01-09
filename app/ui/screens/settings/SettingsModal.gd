extends Node

@onready var back_button: Button = $BackButton

signal back_button_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	back_button.pressed.connect(_onBackButtonPressed)

func _onBackButtonPressed() -> void:
	back_button_pressed.emit()
