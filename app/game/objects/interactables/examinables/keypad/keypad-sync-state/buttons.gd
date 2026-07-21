extends Node3D

signal button_operated(_interactor: Node3D, _data: InteractionTypes.OperableData, _button_id: StringName)

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
	for button_id in buttons:
		var pivot: Node3D = self.get_node_or_null("Button%sPivot" % button_id) as Node3D
		if pivot == null:
			SweetLogger.error("Pivot not found for button %s", [button_id], "buttons.gd", "_ready")
			continue

		var operable: Operable = pivot.get_node_or_null("Operable") as Operable
		if operable == null:
			SweetLogger.error("Operable not found for button %s", [button_id], "buttons.gd", "_ready")
			continue

		operable.animator.add_animation_target(buttons[button_id], {
			&"Idle": idle_transform,
			&"Pulse": pulse_transform,
		}, 0.1, OperableAnimator.AnimationPoseKind.POSITION)
		operable.operated.connect(_on_button_operated.bind(StringName(button_id)))

func _on_button_operated(
	_interactor: Node3D, 
	_data: InteractionTypes.OperableData, 
	button_id: StringName
) -> void:
	button_operated.emit(_interactor, _data, button_id)
