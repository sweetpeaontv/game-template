extends Node3D

@export var label_text: String
@onready var label: Label3D = $Label3D

func _ready() -> void:
	label.text = label_text

func _on_area_3d_mouse_entered() -> void:
	SweetLogger.info('Mouse entered', [], 'KeypadButton.gd', '_on_area_3d_mouse_entered')

func _on_area_3d_mouse_exited() -> void:
	SweetLogger.info('Mouse exited', [], 'KeypadButton.gd', '_on_area_3d_mouse_entered')
