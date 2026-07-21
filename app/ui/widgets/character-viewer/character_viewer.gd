extends Node3D

const character_scene: PackedScene = preload("res://app/game/character/character.tscn")

@onready var world: Node3D = $World
@onready var camera: CustomizerCamera = $World/CustomizerCamera

var character: Node3D

func _ready() -> void:
	pass

func mount_character(config: CharacterConfig) -> void:
	character = character_scene.instantiate()
	character.setup_config(config)
	world.add_child(character)
	camera.setup()

func rotate_character(degrees: float) -> void:
	character.rotate_character(degrees)

func set_view_for_page(page: int) -> void:
	camera.go_to_page(page)
