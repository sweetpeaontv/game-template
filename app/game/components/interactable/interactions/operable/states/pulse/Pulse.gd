@tool
extends RewindableState

@export var idle_state: StringName
@export var pulse_duration_sec: float = 0.2

var _pulse_start_tick: int = 0

func enter(_previous_state: RewindableState, sim_tick: int) -> void:
	_pulse_start_tick = sim_tick

func tick(_delta: float, sim_tick: int, _is_fresh: bool) -> void:
	if NetworkTime.seconds_between(_pulse_start_tick, sim_tick) >= pulse_duration_sec:
		state_machine.transition(idle_state)
