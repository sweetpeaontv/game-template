extends Node

const START_SCENE := "HomeMenu"

@onready var world_container: Node = $WorldContainer
@onready var players_container: Node = $Players

# Entry point into the game
func _ready() -> void:
	checkAutoloads()
	# run any setup before main menu

	# go to start scene
	call_deferred("_boot")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _boot() -> void:
	SceneManager.goto_scene(START_SCENE)

func checkAutoloads() -> void:
	var autoload_list = ["SceneManager", "ClientManager", "AudioManager", "SettingsManager", "DebugOverlay", "EventBus", "Gnet"]
	for autoload in autoload_list:
		var path := "/root/%s" % autoload
		if get_tree().root.get_node_or_null(path) == null:
			SweetLogger.error('Missing Critical Autoload: ' + autoload + ' from autoload list...')
			SweetLogger.error('Quitting Game')
			get_tree().quit()
			return
