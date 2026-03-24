extends Node3D

@export var label_text: String
@onready var label: Label3D = $Label3D

func _ready() -> void:
	label.text = label_text
