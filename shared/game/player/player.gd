extends CharacterBody3D

@onready var nameplate := $Nameplate
@onready var camera := $PlayerCamera
@onready var input: PlayerInput = $Input
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer

var peer_id: int = 0

@export var speed = 4.0
@export var gravity: float = 9.8

func _ready() -> void:
	await get_tree().process_frame

	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	rollback_synchronizer.process_settings()

	setNameplate(str(peer_id))

func _rollback_tick(_delta, _tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= gravity * NetworkTime.ticktime
	else:
		# Reset vertical velocity when on floor (optional: allows for jumping)
		velocity.y = 0.0

	# Apply horizontal movement from input
	var horizontal_movement = input.movement.normalized() * speed
	velocity.x = horizontal_movement.x
	velocity.z = horizontal_movement.z

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")
