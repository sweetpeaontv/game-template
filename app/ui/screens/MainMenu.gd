extends Node2D

@onready var startGameButton = $StartGameButton
@onready var joinGameButton  = $JoinGameButton
@onready var settingsButton  = $SettingsButton
@onready var quitButton      = $QuitButton
@onready var steamSlider     = $SteamCheckButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	startGameButton.pressed.connect(_startGameButtonPressed)
	joinGameButton.pressed.connect(_joinGameButtonPressed)
	quitButton.pressed.connect(_quitButtonPressed)
	steamSlider.pressed.connect(_steamSliderPressed)

func _startGameButtonPressed() -> void:
	GameManager._start_game()

func _joinGameButtonPressed() -> void:
	GameManager._join_game()

func _settingsButtonPressed() -> void:
	print('Settings Button Pressed')

func _quitButtonPressed() -> void:
	get_tree().quit()
	return

func _steamSliderPressed() -> void:
	var adapter = 'enet'
	if $SteamCheckButton.button_pressed:
		adapter = 'steam'
	Gnet.use_adapter(adapter)
