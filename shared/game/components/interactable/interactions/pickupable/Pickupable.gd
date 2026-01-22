extends Interactable
class_name Pickupable

const PickupData = InteractionTypes.PickupData

enum PickupState { FREE, HELD, THROWN }

var parent: Node3D = null
var holder: Node3D = null

var pickup_state: PickupState = PickupState.FREE
var original_collision_layer: int = 0
var original_collision_mask: int = 0
var pending_throw_velocity: Vector3 = Vector3.ZERO

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

func set_pickup_state(state: PickupState) -> void:
	pickup_state = state

func _pickup(interactor: Node3D) -> void:
	pickup_state = PickupState.HELD
	holder = interactor

func _drop() -> void:
	pickup_state = PickupState.FREE
	holder = null

func _throw(_throw_power: float = 0.0) -> void:
	if not holder or not parent:
		return

	# pretty rudamentary solution to throw the item in the direction the player is looking
	var throw_direction = Vector3.ZERO
	if holder.has_method("get_camera_basis"):
		var camera_basis = holder.get_camera_basis()
		throw_direction = -camera_basis.z

	pickup_state = PickupState.THROWN
	holder = null

	if parent is RigidBody3D:
		# Re-enable collisions
		parent.collision_layer = original_collision_layer
		parent.collision_mask = original_collision_mask
		
		pending_throw_velocity = throw_direction.normalized() * _throw_power
		NetworkRollback.mutate(self)
		# Optional: Add a slight upward component for a more natural throw arc
		# parent.linear_velocity += Vector3.UP * (_throw_power * 0.3)

func _interact_physics_rollback_tick(_delta, _tick):
	if pickup_state == PickupState.HELD and holder:
		var test: Array = [
			holder.hold_point.global_transform.origin,
			holder.hold_point.global_transform.basis.get_rotation_quaternion(),
			Vector3.ZERO, 
			Vector3.ZERO, 
			false
		]
		parent.set_state(test)
	elif pending_throw_velocity != Vector3.ZERO:
		parent.apply_central_impulse(pending_throw_velocity)
		pending_throw_velocity = Vector3.ZERO
