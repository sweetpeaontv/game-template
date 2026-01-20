extends Interactable
class_name Pickupable

const PickupData = InteractionTypes.PickupData

enum PickupState { FREE, HELD }

var parent: Node3D = null
var holder: Node3D = null

var pickup_state: PickupState = PickupState.FREE
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

func _interact(interactor: Node3D, data: Variant = null) -> void:
	if not data is PickupData:
		SweetLogger.error("Invalid data type: {0}", [data.get_class()], "Pickupable.gd", "_interact")
		return

	var action = data.action
	var throw_power = data.throw_power
	match action:
		PickupData.Action.PICKUP:
			_pickup(interactor)
		PickupData.Action.DROP:
			_drop()
		PickupData.Action.THROW:
			_throw(throw_power)
		_:
			SweetLogger.error("Invalid action: {0}", [action], "Pickupable.gd", "_interact")

func _pickup(interactor: Node3D) -> void:
	pickup_state = PickupState.HELD
	holder = interactor

	#if parent is RigidBody3D:
		#parent.collision_layer = 0
		#parent.collision_mask = 0

func _drop() -> void:
	pickup_state = PickupState.FREE
	holder = null

	#if parent is RigidBody3D:
		#parent.collision_layer = original_collision_layer
		#parent.collision_mask = original_collision_mask

func _throw(_throw_power: float = 0.0) -> void:
	pass

func _interact_physics_rollback_tick(_delta, _tick):
	pass

func _integrate_forces_logic(state: PhysicsDirectBodyState3D) -> void:
	if pickup_state == PickupState.HELD and holder:
		state.transform = holder.hold_point.global_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
