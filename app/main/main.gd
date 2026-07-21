extends Node

const START_SCENE := "MenuWorld"

@onready var world_container: Node = $WorldContainer
@onready var players_container: Node = $Players
@onready var ui_container: Node = $UI
@onready var menu_container: Node = $UI/Menu
@onready var hud_container: Node = $UI/HUD
@onready var backdrop_container: Node = $UI/Backdrop
@onready var overlay_container: Node = $UI/Overlay

# Entry point into the game
func _ready() -> void:
	checkAutoloads()
	# run any setup before main menu
	_setup_ui()
	# go to start scene
	call_deferred("_boot")
	
	InputModeManager.set_input_mode(Input.MOUSE_MODE_VISIBLE)

func _boot() -> void:
	SceneManager.goto_scene(START_SCENE)
	UIManager.show_ui("MainMenu")

func _setup_ui() -> void:
	UIManager.set_container(UIManager.UIContainer.MENU, menu_container)
	UIManager.set_container(UIManager.UIContainer.HUD, hud_container)
	UIManager.set_container(UIManager.UIContainer.BACKDROP, backdrop_container)
	UIManager.set_container(UIManager.UIContainer.OVERLAY, overlay_container)

func checkAutoloads() -> void:
	var autoload_list = ["SceneManager", "ClientManager", "AudioManager", "SettingsManager", "DebugOverlay", "EventBus", "Gnet"]
	for autoload in autoload_list:
		var path := "/root/%s" % autoload
		if get_tree().root.get_node_or_null(path) == null:
			SweetLogger.error('Missing Critical Autoload: ' + autoload + ' from autoload list...')
			SweetLogger.error('Quitting Game')
			get_tree().quit()
			return
