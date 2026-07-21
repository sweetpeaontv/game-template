extends Node3D
class_name KeypadState

## How many digit positions the UI window represents (e.g. 4 for a 4-digit code). Used for game logic;
## display uses [member entered_digits].

@export var solution: Array[int] = [1, 2, 3, 4]
@export var digit_count: int = 4

## Authority counts this down on each [signal NetworkTime.before_tick] while > 0; at 0, [member entered_digits] clears.
@export var reject_duration_ticks: int = 36

## Authoritative entry history (synced by netfox [StateSynchronizer]). Do not assign directly; use
## [method append_from_button_id], [method request_append], or [method reset] / [method request_reset].
var _entered_digits: Array[int] = []

var _unlocked: bool = false
var _reject_ticks_remaining: int = 0
## Authority only: skip one advance tick right after a wrong code so the same frame does not eat a tick.
var _reject_skip_next_advance: bool = false

## Synced: true after a correct full entry matching [member solution].
var unlocked: bool:
	get:
		return _unlocked
	set(value):
		if _unlocked == value:
			return
		_unlocked = value
		unlocked_changed.emit(_unlocked)

## Synced: while > 0, wrong-code reject is in progress; authority decrements each tick until digits clear.
var reject_ticks_remaining: int:
	get:
		return _reject_ticks_remaining
	set(value):
		var next := maxi(0, value)
		if next == _reject_ticks_remaining:
			return
		_reject_ticks_remaining = next
		reject_ticks_remaining_changed.emit(_reject_ticks_remaining)

## Synced property: when netfox applies a snapshot, the setter runs and [signal state_changed] fires.
## Skips emit when the new value equals the current one — [StateSynchronizer] reapplies every tick.
var entered_digits: Array[int]:
	get:
		return _entered_digits
	set(value):
		var next: Array[int] = []
		if value is Array:
			for item in value:
				next.append(int(item))
		else:
			next = []
		if _digit_arrays_equal(_entered_digits, next):
			return
		_entered_digits = next
		check_solution()
		state_changed.emit(_entered_digits)

signal state_changed(entered_digits: Array[int])
signal unlocked_changed(is_unlocked: bool)
signal reject_ticks_remaining_changed(remaining: int)

func _ready() -> void:
	reset()

func _enter_tree() -> void:
	set_multiplayer_authority(1)
	var sync := get_parent().get_node_or_null("StateSynchronizer")
	if sync:
		sync.set_multiplayer_authority(1)
	if not NetworkTime.before_tick.is_connected(_on_network_before_tick):
		NetworkTime.before_tick.connect(_on_network_before_tick)

func _exit_tree() -> void:
	if NetworkTime.before_tick.is_connected(_on_network_before_tick):
		NetworkTime.before_tick.disconnect(_on_network_before_tick)

func _on_network_before_tick(_delta: float, _tick: int) -> void:
	_advance_reject_one_tick_if_authority()

func _advance_reject_one_tick_if_authority() -> void:
	if not is_multiplayer_authority():
		return
	if reject_ticks_remaining <= 0:
		return
	if _reject_skip_next_advance:
		_reject_skip_next_advance = false
		return
	reject_ticks_remaining -= 1
	if reject_ticks_remaining == 0:
		entered_digits = []
	NetworkRollback.mutate(self)

func get_digit_count() -> int:
	return digit_count

func _digit_arrays_equal(a: Array[int], b: Array[int]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func append_digit(digit: int) -> void:
	if _unlocked or _reject_ticks_remaining > 0:
		return
	var next: Array[int] = _entered_digits.duplicate()
	next.append(digit)
	entered_digits = next
	NetworkRollback.mutate(self)

## Call only on the multiplayer authority (server) or in single-player.
func append_from_button_id(button_id: StringName) -> void:
	if _unlocked or _reject_ticks_remaining > 0:
		return
	var digit := _button_id_to_digit(button_id)
	if digit < 0:
		return
	var next: Array[int] = _entered_digits.duplicate()
	next.append(digit)
	entered_digits = next

func reset() -> void:
	_reject_skip_next_advance = false
	unlocked = false
	reject_ticks_remaining = 0
	entered_digits = []

func _button_id_to_digit(button_id: StringName) -> int:
	var s := String(button_id)
	if s.length() != 1:
		return -1
	var c := s[0]
	if c >= "0" and c <= "9":
		return int(c) - int("0")
	return -1

func check_solution() -> void:
	if _entered_digits.size() != solution.size():
		return
	if _digit_arrays_equal(_entered_digits, solution):
		unlocked = true
		reject_ticks_remaining = 0
	else:
		reject_ticks_remaining = reject_duration_ticks
		if is_multiplayer_authority():
			_reject_skip_next_advance = true
	NetworkRollback.mutate(self)
