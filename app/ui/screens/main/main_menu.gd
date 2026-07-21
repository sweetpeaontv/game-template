extends Control

@onready var start_game_button = $StartGameButton
@onready var join_game_button  = $JoinGameButton
@onready var character_button  = $CharacterButton
@onready var settings_button   = $SettingsButton
@onready var quit_button       = $QuitButton
@onready var steam_slider      = $SteamCheckButton

func _ready() -> void:
	start_game_button.pressed.connect(_start_game_button_pressed)
	join_game_button.pressed.connect(_join_game_button_pressed)
	character_button.pressed.connect(_character_button_pressed)
	settings_button.pressed.connect(_settings_button_pressed)
	quit_button.pressed.connect(_quit_button_pressed)
	steam_slider.pressed.connect(_steam_slider_pressed)

func _start_game_button_pressed() -> void:
	UIManager.hide_container(UIManager.UIContainer.MENU)
	ClientManager.start_game()

func _join_game_button_pressed() -> void:
	UIManager.hide_container(UIManager.UIContainer.MENU)
	ClientManager.join_game()

func _character_button_pressed() -> void:
	UIManager.hide_ui("MainMenu")
	UIManager.show_ui("MainMenuCustomizer", { "return_ui": "MainMenu" })

func _settings_button_pressed() -> void:
	UIManager.hide_ui("MainMenu")
	UIManager.show_ui("Settings", { "return_ui": "MainMenu" })

func _quit_button_pressed() -> void:
	get_tree().quit()
	return

func _steam_slider_pressed() -> void:
	var adapter = 'enet'
	if steam_slider.button_pressed:
		adapter = 'steam'
	Gnet.use_adapter(adapter)
