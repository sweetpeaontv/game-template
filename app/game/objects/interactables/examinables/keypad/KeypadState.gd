extends Node3D
class_name KeypadState

## How many digit positions the UI window represents (e.g. 4 for a 4-digit code). Used for game logic;
## display uses [member entered_digits].

@export var digit_count: int = 4

## Authoritative entry history (synced by netfox [StateSynchronizer]). Do not assign directly; use
## [method append_from_button_id], [method request_append], or [method reset] / [method request_reset].
var _entered_digits: Array[int] = []

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
		state_changed.emit(_entered_digits)

signal state_changed(entered_digits: Array[int])

func _ready() -> void:
	reset()

func _enter_tree() -> void:
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(1)
		var sync := get_parent().get_node_or_null("StateSynchronizer")
		if sync:
			sync.set_multiplayer_authority(1)

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
	var next: Array[int] = _entered_digits.duplicate()
	next.append(digit)
	entered_digits = next
	NetworkRollback.mutate(self)

## Call only on the multiplayer authority (server) or in single-player.
func append_from_button_id(button_id: StringName) -> void:
	var digit := _button_id_to_digit(button_id)
	if digit < 0:
		return
	var next: Array[int] = _entered_digits.duplicate()
	next.append(digit)
	entered_digits = next

func reset() -> void:
	entered_digits = []

func _button_id_to_digit(button_id: StringName) -> int:
	var s := String(button_id)
	if s.length() != 1:
		return -1
	var c := s[0]
	if c >= "0" and c <= "9":
		return int(c) - int("0")
	return -1
