extends NetworkRigidBody3D

@onready var interactable: Interactable = $Pickupable
@onready var rollback_sync: RollbackSynchronizer = $RollbackSynchronizer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_multiplayer_authority(1)
	rollback_sync.process_settings()

func _physics_rollback_tick(_delta, _tick):
	interactable._interact_physics_rollback_tick(_delta, _tick)
