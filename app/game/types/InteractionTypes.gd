class_name InteractionTypes
extends RefCounted

enum InteractionType { PICKUPABLE, EXAMINABLE, OPERABLE }

class PickupData extends InteractionTypes:
	enum Action { PICKUP, DROP, THROW }
	var action: Action
	var throw_power: float = 0.0
	var throw_direction: Vector3 = Vector3.ZERO

	func _init(_action: Action, _throw_power: float = 0.0, _throw_direction: Vector3 = Vector3.ZERO):
		action = _action
		throw_power = _throw_power
		throw_direction = _throw_direction

	static func pickup() -> PickupData:
		return PickupData.new(Action.PICKUP)

	static func drop() -> PickupData:
		return PickupData.new(Action.DROP)

	static func throw(power: float = 0.0, direction: Vector3 = Vector3.ZERO) -> PickupData:
		return PickupData.new(Action.THROW, power, direction)

class OperableData extends InteractionTypes:
	enum Action { TOGGLE, SET_STATE, NEXT_STATE, PREV_STATE }
	var action: Action
	var target_state: StringName = &""

	func _init(_action: Action, _target_state: StringName = &""):
		action = _action
		target_state = _target_state

	static func toggle() -> OperableData:
		return OperableData.new(Action.TOGGLE)

	static func set_state(state: StringName) -> OperableData:
		return OperableData.new(Action.SET_STATE, state)

	static func next_state() -> OperableData:
		return OperableData.new(Action.NEXT_STATE)

	static func prev_state() -> OperableData:
		return OperableData.new(Action.PREV_STATE)

class ExaminableData extends InteractionTypes:
	enum Action { EXAMINE, DISENGAGE }
	var action: Action

	func _init(_action: Action):
		action = _action

	static func examine() -> ExaminableData:
		return ExaminableData.new(Action.EXAMINE)

	static func disengage() -> ExaminableData:
		return ExaminableData.new(Action.DISENGAGE)