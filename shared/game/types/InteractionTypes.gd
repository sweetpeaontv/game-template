class_name InteractionTypes
extends RefCounted

class PickupData extends RefCounted:
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