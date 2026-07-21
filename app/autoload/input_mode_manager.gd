extends Node

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func set_input_mode(mode: Input.MouseMode) -> void:
	Input.set_mouse_mode(mode)