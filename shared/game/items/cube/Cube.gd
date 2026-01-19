extends NetworkRigidBody3D

@onready var interactable: Interactable = $Pickupable
@onready var rollback_sync: RollbackSynchronizer = $RollbackSynchronizer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_multiplayer_authority(1)
	rollback_sync.process_settings()

func _physics_rollback_tick(_delta, _tick):
	interactable._interact_physics_rollback_tick(_delta, _tick)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if interactable.holder_peer_id != 0:
		var holder = ServerGameManager._find_player(interactable.holder_peer_id)
		if holder and holder.has_node("HoldPoint"):
			var hold_point = holder.get_node("HoldPoint")
			
			state.transform = hold_point.global_transform
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
