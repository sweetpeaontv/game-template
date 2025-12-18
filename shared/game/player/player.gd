extends CharacterBody3D

@onready var nameplate := $Nameplate
@onready var model := $Model
@onready var input: PlayerInput = $Input
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var head: Node3D = $CameraHead
@onready var camera: Camera3D = $CameraHead/Camera3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
@export var speed = WALK_SPEED

var peer_id: int = 0

@export var gravity: float = 9.8

func _ready() -> void:
	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	head.set_multiplayer_authority(peer_id)
	head.set_peer_id(peer_id)
	rollback_synchronizer.process_settings()
	_setup()

func _setup() -> void:
	setNameplate(str(peer_id))

	# Hide player model and nameplate for local player
	var my_id = multiplayer.get_unique_id()
	if peer_id == my_id:
		model.visible = false
		nameplate.visible = false
	else:
		model.visible = true
		nameplate.visible = true

func _rollback_tick(_delta, _tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	# this is not properly synced yet
	# TODO: sync the camera head rotation
	var head_forward = -head.transform.basis.z
	var target_angle = atan2(head_forward.x, head_forward.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, _delta * 10.0)

	if input.shift:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	if is_on_floor():
		velocity.y = 0
		if input.direction:
			velocity.x = input.direction.x * speed
			velocity.z = input.direction.z * speed
		else:
			velocity.x = lerp(velocity.x, input.direction.x * speed, _delta * 7.0)
			velocity.z = lerp(velocity.z, input.direction.z * speed, _delta * 7.0)
	else:
		velocity.y -= gravity * _delta
		velocity.x = lerp(velocity.x, input.direction.x * speed, _delta * 3.0)
		velocity.z = lerp(velocity.z, input.direction.z * speed, _delta * 3.0)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _process(_delta: float) -> void:
	pass

func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")
