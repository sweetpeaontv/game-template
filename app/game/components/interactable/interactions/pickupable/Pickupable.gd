extends Interactable
class_name Pickupable

signal pickupable_yanked()

const PickupData = InteractionTypes.PickupData

enum PickupState { FREE, HELD, THROWN }

var holder: Node3D = null
var holder_id: int = 0

var pickup_state: PickupState = PickupState.FREE
var pending_throw_velocity: Vector3 = Vector3.ZERO

# default values for _handle_holder_point_forces
@export var spring_k: float = 50.0
@export var damper_b: float = 10.0
@export var drop_distance: float = 4.0

# default angular dampening for parent body
@export var held_parent_angular_damp: float = 5.0
var original_parent_angular_damp: float = 1.0

# INIT
#===================================================================================#
func _on_ready() -> void:
	InteractableRegistries.pickupables.add_entry(key, self)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	InteractableRegistries.pickupables.remove_entry(key)
	super._exit_tree()
#===================================================================================#

# INTERACTION
#===================================================================================#
func _interact(interactor: Node3D, data: Variant = null, _rollback_is_fresh: bool = true) -> void:
	if not data is PickupData:
		SweetLogger.error("Invalid data type: {0}", [data.get_class()], "Pickupable.gd", "_interact")
		return

	var action = data.action
	var throw_power = data.throw_power
	var throw_direction = data.throw_direction
	match action:
		PickupData.Action.PICKUP:
			_pickup(interactor)
		PickupData.Action.DROP:
			_drop()
		PickupData.Action.THROW:
			_throw(throw_power, throw_direction)
		_:
			SweetLogger.error("Invalid action: {0}", [action], "Pickupable.gd", "_interact")

func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.PICKUPABLE

func set_pickup_state(state: PickupState) -> void:
	pickup_state = state

func _pickup(interactor: Node3D) -> void:
	pickup_state = PickupState.HELD
	if holder_id != 0 and holder_id != interactor.peer_id:
		pickupable_yanked.emit()
	holder = interactor
	holder_id = interactor.peer_id

	# dampens rotation when being held
	original_parent_angular_damp = parent.angular_damp
	parent.angular_damp = held_parent_angular_damp

	NetworkRollback.mutate(self)

func _drop() -> void:
	parent.sleeping = false
	pickup_state = PickupState.FREE
	holder = null
	holder_id = 0

	# restores default angular damping
	parent.angular_damp = original_parent_angular_damp

	NetworkRollback.mutate(self)

func _throw(_throw_power: float = 0.0, _throw_direction: Vector3 = Vector3.ZERO) -> void:
	if not holder or not parent:
		return

	pickup_state = PickupState.THROWN
	holder = null
	holder_id = 0

	# restores default angular damping
	parent.angular_damp = original_parent_angular_damp

	pending_throw_velocity = _throw_direction.normalized() * _throw_power
	NetworkRollback.mutate(self)
	# Optional: Add a slight upward component for a more natural throw arc
	# parent.linear_velocity += Vector3.UP * (_throw_power * 0.3)

#===================================================================================#

# ROLLBACK
#===================================================================================#
func _interact_physics_rollback_tick(_delta, _tick):
	_handle_holder_sync()
	#_handle_holder_point_transform()
	_handle_holder_point_forces(_delta)
	_handle_throw_velocty()

func _handle_holder_sync() -> void:
	if holder_id == 0 and holder:
		holder = null
	elif not holder and holder_id != 0:
		var player = PlayerUtils.find_player(holder_id)
		if player:
			holder = player
		else:
			# this is a bit troublesome because when a late joiner connects
			# the player node may not be ready yet, so we could wait for it to be ready...
			SweetLogger.warning("Player {0} not found", [holder_id], "Pickupable.gd", "_handle_holder_sync")

## Snaps the body to the hold point each tick (overrides physics / [member NetworkRigidBody3D.physics_state]).
func _handle_holder_point_transform() -> void:
	if pickup_state == PickupState.HELD and holder:
		var new_state: Array = [
			holder.hold_point.global_transform.origin,
			holder.hold_point.global_transform.basis.get_rotation_quaternion(),
			Vector3.ZERO,
			Vector3.ZERO,
			false
		]
		parent.set_state(new_state)

## Drives the parent [RigidBody3D] toward [member holder]'s hold point with forces so the physics server integrates motion.
func _handle_holder_point_forces(_delta: float) -> void:
	if pickup_state != PickupState.HELD or not holder or not parent:
		return

	var body := parent as RigidBody3D
	if not body:
		return

	var displacement = holder.hold_point.global_position - body.global_position
	var dist = displacement.length()

	if dist > drop_distance:
		pickupable_yanked.emit()
		_drop()
		return

	var spring_force = displacement * spring_k
	var damper_force = -body.linear_velocity * damper_b

	body.apply_central_force(spring_force + damper_force)

func _handle_throw_velocty() -> void:
	if pending_throw_velocity != Vector3.ZERO:
		parent.apply_central_impulse(pending_throw_velocity)
		pending_throw_velocity = Vector3.ZERO
#===================================================================================#
