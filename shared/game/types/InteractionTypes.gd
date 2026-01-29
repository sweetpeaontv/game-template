class_name InteractionTypes
extends RefCounted

enum InteractionType { PICKUPABLE, OPENABLE }

class PickupData extends InteractionTypes:
	enum Action { PICKUP, DROP, THROW }
	var action: Action
	var throw_power: float = 0.0

	func _init(_action: Action, _throw_power: float = 0.0):
		action = _action
		throw_power = _throw_power

	static func pickup() -> PickupData:
		return PickupData.new(Action.PICKUP)

	static func drop() -> PickupData:
		return PickupData.new(Action.DROP)

	static func throw(power: float = 0.0) -> PickupData:
		return PickupData.new(Action.THROW, power)

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