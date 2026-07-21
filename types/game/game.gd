class_name Game
extends RefCounted

signal game_started()
signal game_ended()
signal game_state_changed(new_state: GameState)

var on_start: Callable = func(): pass
var end_condition: Callable = func(): return false

var state: GameState = GameState.IDLE

enum GameState {
	IDLE,
	RUNNING,
	ENDING,
}

func _init(start_func: Callable, end_func: Callable) -> void:
	on_start = start_func
	end_condition = end_func

func start() -> void:
	if state == GameState.RUNNING:
		return
	state = GameState.RUNNING
	game_started.emit()
	on_start.call()

func end(success: bool = false) -> void:
	if state != GameState.RUNNING:
		return
	state = GameState.ENDING
	game_ended.emit(success)

func get_state() -> GameState:
	return state

func set_state(new_state: GameState) -> void:
	if state == new_state:
		return
	state = new_state
	game_state_changed.emit(state)

