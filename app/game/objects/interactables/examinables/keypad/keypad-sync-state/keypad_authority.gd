extends Node

signal keypad_unlocked()
# TODO: GENERALIZE THIS FOR OTHER OBJECTS, NOT JUST KEYPAD
const SCRIPT_NAME: String = "keypad_authority.gd"

## Server/host rules for the keypad. Present on every peer; logic only runs on authority.
## Owns the secret solution and writes public SyncState outcomes (unlocked, screen mode).
## Timed reset uses a local SceneTreeTimer on authority only — not replicated tick counters.

@export var sync_state: SyncStateNode = null

# rather than initialize this solution, we could pass it in as a parameter so it isn't present on every peer
@export var solution: PackedInt32Array = [1, 2, 3, 4]
@export var digit_count: int = 4
@export var reject_duration_sec: float = 0.8
@export var unlock_duration_sec: float = 0.0 ## 0 = stay unlocked; >0 = timed re-lock
var _reset_timer_token: int = 0

enum ScreenMode { IDLE = 0, REJECT = 1, SUCCESS = 2 }

# INIT
#===================================================================================#
func _ready() -> void:
	pass
#===================================================================================#

# SYNC HOOK
#===================================================================================#
func _on_state_changed(_state: Dictionary) -> void:
	_evaluate_solution()
#===================================================================================#

# RULES
#===================================================================================#
func _evaluate_solution() -> void:
	if not Gnet.is_authority() or sync_state == null:
		return

	var state := sync_state.state
	if state.get("unlocked", false):
		return
	if int(state.get("screen_mode", ScreenMode.IDLE)) == ScreenMode.REJECT:
		return

	var entered: PackedInt32Array = state.get("entered_digits", [])
	if entered.size() < digit_count:
		return

	if _matches_solution(entered):
		_apply_success()
	else:
		_apply_reject()
#===================================================================================#

# OUTCOMES
#===================================================================================#
func _apply_success() -> void:
	sync_state.update({
		"unlocked": true,
		"screen_mode": int(ScreenMode.SUCCESS),
	})

	if unlock_duration_sec > 0.0:
		_start_reset_timer(unlock_duration_sec, _on_unlock_timer_finished)

	keypad_unlocked.emit()

func _apply_reject() -> void:
	sync_state.update({
		"screen_mode": int(ScreenMode.REJECT),
	})

	_start_reset_timer(reject_duration_sec, _on_reject_timer_finished)
#===================================================================================#

# TIMERS (authority only)
#===================================================================================#
func _start_reset_timer(duration_sec: float, on_finished: Callable) -> void:
	_reset_timer_token += 1
	var token := _reset_timer_token
	await get_tree().create_timer(duration_sec).timeout
	if token != _reset_timer_token:
		return
	on_finished.call()

func _on_reject_timer_finished() -> void:
	if not Gnet.is_authority() or sync_state == null:
		return
	sync_state.update({
		"entered_digits": PackedInt32Array(),
		"screen_mode": int(ScreenMode.IDLE),
	})

func _on_unlock_timer_finished() -> void:
	if not Gnet.is_authority() or sync_state == null:
		return
	sync_state.update({
		"unlocked": false,
		"entered_digits": PackedInt32Array(),
		"screen_mode": int(ScreenMode.IDLE),
	})
#===================================================================================#

# HELPERS
#===================================================================================#
func _matches_solution(entered: PackedInt32Array) -> bool:
	if entered.size() != solution.size():
		return false
	for i in range(entered.size()):
		if int(entered[i]) != int(solution[i]):
			return false
	return true
#===================================================================================#
