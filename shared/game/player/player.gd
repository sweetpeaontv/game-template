extends CharacterBody3D

@onready var nameplate := $Nameplate
@onready var input: PlayerInput = $Input
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var head: Node3D = $CameraHead
@onready var camera: Camera3D = $CameraHead/Camera3D

const SENSITIVITY = 0.004
const MIN_PITCH = deg_to_rad(-40)
const MAX_PITCH = deg_to_rad(60)

var peer_id: int = 0

@export var speed = 4.0
@export var gravity: float = 9.8

func _ready() -> void:
	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	rollback_synchronizer.process_settings()

	setNameplate(str(peer_id))

func _rollback_tick(_delta, _tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	if input.mouse_movement != Vector2.ZERO:
		#print('mouse movement', input.mouse_movement)
		head.rotate_y(-input.mouse_movement.x * SENSITIVITY)
		camera.rotate_x(-input.mouse_movement.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, MIN_PITCH, MAX_PITCH)

	var input_dir = input.movement
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()

	#print('direction', direction)
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, _delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, _delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, _delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, _delta * 3.0)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")
