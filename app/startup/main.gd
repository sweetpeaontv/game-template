extends Node

const START_SCENE := "MainMenu"

@onready var world_container: Node = $WorldContainer
@onready var players_container: Node = $Players

# Entry point into the game
func _ready() -> void:
	checkAutoloads()
	# run any setup before main menu

	# go to start scene
	call_deferred("_boot")

func _boot() -> void:
	SceneManager.goto_scene(START_SCENE)

func checkAutoloads() -> void:
	var autoload_list = ["SceneManager", "GameManager", "AudioManager", "SettingsManager", "DebugOverlay", "EventBus", "Gnet"]
	for autoload in autoload_list:
		var path := "/root/%s" % autoload
		if get_tree().root.get_node_or_null(path) == null:
			print('Missing ' + autoload + ' from autoload list...')
			print('Quitting Game')
			get_tree().quit()
			return
