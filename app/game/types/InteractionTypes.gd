class_name InteractionTypes
extends RefCounted

enum InteractionType { PICKUPABLE, OPENABLE, EXAMINABLE }

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

class OpenData extends InteractionTypes:
	enum Action { TOGGLE, OPEN, CLOSE }
	var action: Action

	func _init(_action: Action):
		action = _action

	static func toggle() -> OpenData:
		return OpenData.new(Action.TOGGLE)

	static func open() -> OpenData:
		return OpenData.new(Action.OPEN)

	static func close() -> OpenData:
		return OpenData.new(Action.CLOSE)

class ExaminableData extends InteractionTypes:
	enum Action { EXAMINE, DISENGAGE }
	var action: Action

	func _init(_action: Action):
		action = _action

	static func examine() -> ExaminableData:
		return ExaminableData.new(Action.EXAMINE)

	static func disengage() -> ExaminableData:
		return ExaminableData.new(Action.DISENGAGE)