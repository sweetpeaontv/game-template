extends CharacterBody3D

@onready var nameplate := $Nameplate
@onready var camera := $PlayerCamera

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	var peer_id = get_multiplayer_authority()
	print("Player: _ready - peer_id: ", peer_id, ", is_server: ", multiplayer.is_server())
	
	# Set nameplate to peer_id
	setNameplate(str(peer_id))
	
	# Only set camera as current for the local player
	if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
		camera.current = true
		print("Player: Set camera as current for peer_id: ", peer_id)

func _physics_process(delta: float) -> void:
	# Only process movement for the player we have authority over
	if not multiplayer.has_multiplayer_peer():
		return
	
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")
