extends Node3D

@export var keypad_state: KeypadState

@onready var buttons: Dictionary = {
	"1": $"Button1Pivot/Button1",
	"2": $"Button2Pivot/Button2",
	"3": $"Button3Pivot/Button3",
	"4": $"Button4Pivot/Button4",
	"5": $"Button5Pivot/Button5",
	"6": $"Button6Pivot/Button6",
	"7": $"Button7Pivot/Button7",
	"8": $"Button8Pivot/Button8",
	"9": $"Button9Pivot/Button9",
}

var idle_transform: Vector3 = Vector3.ZERO
var pulse_transform: Vector3 = Vector3(0.0, -0.008, 0.0)

func _ready() -> void:
	if keypad_state == null:
		keypad_state = get_parent().get_node_or_null("KeypadState") as KeypadState

	for button_id in buttons:
		var pivot: Node3D = get_node_or_null("Button%sPivot" % button_id) as Node3D
		if pivot == null:
			continue
		var operable: Operable = pivot.get_node_or_null("Operable") as Operable
		if operable == null:
			continue
		operable.add_animation_target(buttons[button_id], {
			&"Idle": idle_transform,
			&"Pulse": pulse_transform
		}, 0.1, Operable.AnimationPoseKind.POSITION)
		operable.operated.connect(_on_button_operated.bind(StringName(button_id)))

func _on_button_operated(
	_interactor: Node3D,
	_data: InteractionTypes.OperableData,
	rollback_is_fresh: bool,
	button_id: StringName
) -> void:
	# Operable still toggles/pulses every rollback step; digits are rollback state — only count the display step
	# so consecutive CONFIRMING ticks (remote input redundancy) do not double-append.
	if not rollback_is_fresh:
		return
	if keypad_state:
		keypad_state.append_digit(int(button_id))
