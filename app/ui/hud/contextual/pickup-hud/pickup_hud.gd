extends Control

@onready var progress_bar = $VBoxContainer/ProgressBar

func update_control_value(new_value: float) -> void:
	progress_bar.value = new_value * 100.0
