extends Interactable
class_name Pickupable

const PickupData = InteractionTypes.PickupData

enum PickupState { FREE, HELD }

var parent: Node3D = null
var holder_peer_id: int = 0

var state: PickupState = PickupState.FREE
var original_collision_layer: int = 0
var original_collision_mask: int = 0

func _on_ready() -> void:
	parent = get_parent()
	if not parent:
		SweetLogger.error("Parent node not found! That's not supposed to happen...", [], "Pickupable.gd", "_on_ready")
		return

	if parent is RigidBody3D:
		original_collision_layer = parent.collision_layer
		original_collision_mask = parent.collision_mask

func _interact(interactor_peer_id: int, data: Variant = null) -> void:
	if not data is PickupData:
		SweetLogger.error("Invalid data type: {0}", [data.get_class()], "Pickupable.gd", "_interact")
		return

	var action = data.action
	var throw_power = data.throw_power
	match action:
		PickupData.Action.PICKUP:
			_pickup(interactor_peer_id)
		PickupData.Action.DROP:
			_drop()
		PickupData.Action.THROW:
			_throw(throw_power)
		_:
			SweetLogger.error("Invalid action: {0}", [action], "Pickupable.gd", "_interact")

func _pickup(interactor_peer_id: int) -> void:
	state = PickupState.HELD
	holder_peer_id = interactor_peer_id

	if parent is RigidBody3D:
		parent.freeze = true
		parent.collision_layer = 0
		parent.collision_mask = 0

	NetworkRollback.mutate(self, NetworkTime.tick)
	NetworkRollback.mutate(parent, NetworkTime.tick)

func _drop() -> void:
	state = PickupState.FREE
	holder_peer_id = 0

	if parent is RigidBody3D:
		parent.freeze = false
		parent.collision_layer = original_collision_layer
		parent.collision_mask = original_collision_mask

	NetworkRollback.mutate(self, NetworkTime.tick)
	NetworkRollback.mutate(parent, NetworkTime.tick)

func _throw(throw_power: float = 0.0) -> void:
	pass

func _interact_physics_rollback_tick(_delta, _tick):
	if holder_peer_id != 0:
		var holder = ServerGameManager._find_player(holder_peer_id)
		if holder.has_node("HoldPoint"):
			var hold_point = holder.get_node("HoldPoint")
			parent.global_transform = hold_point.global_transform
		else:
			SweetLogger.error("Holder does not have a HoldPoint! That's not supposed to happen...", [], "Cube.gd", "_physics_rollback_tick")
