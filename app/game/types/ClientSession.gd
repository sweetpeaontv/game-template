class_name ClientSession
extends RefCounted

signal session_state_changed(new_state: SessionState)

enum SessionState { LOADING, MAIN_MENU, CONNECTING, IN_GAME }

var state: SessionState = SessionState.MAIN_MENU

func get_state() -> SessionState:
	return state

func set_state(new_state: SessionState) -> void:
	if state == new_state:
		return

	state = new_state
	session_state_changed.emit(state)