extends NetworkRigidBody3D

@onready var interactable: Node3D = $Interactable

var _should_apply_impulse: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_multiplayer_authority(1)
	$RollbackSynchronizer.process_settings()

func _on_interact():
	# Set flag instead of applying directly
	SweetLogger.info("Interacting with {0} in _on_interact", [name])
	_should_apply_impulse = true

func _physics_rollback_tick(delta, tick):
	if _should_apply_impulse:
		apply_central_impulse(Vector3.UP * 1.5)

		_should_apply_impulse = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
