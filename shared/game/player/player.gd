extends CharacterBody3D

# BODY NODES
@onready var nameplate := $Nameplate
@onready var model := $Model
@onready var hold_point: Node3D = $HoldPoint

# NETFOX SYNC NODES
@onready var input: PlayerInput = $Input
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var interact_action: RewindableAction = $InteractAction
@onready var alt_interact_action: RewindableAction = $AltInteractAction

# CAMERA NODES
@onready var first_person_camera: FirstPersonCameraInput = $FirstPersonCameraInput
@onready var third_person_camera: ThirdPersonCameraInput = $ThirdPersonCameraInput
@onready var focus_sensor: Node3D = $FocusSensor

# MULTIPLAYER VALUES/VARIABLES
var peer_id: int = 0

# CAMERA DEFAULT VALUES/VARIABLES
enum CameraType { FIRST_PERSON, THIRD_PERSON }
@onready var camera_type: CameraType = CameraType.FIRST_PERSON
const ROTATION_INTERPOLATE_SPEED := 10
var _previous_camera_basis: Basis = Basis.IDENTITY
var current_camera: Node3D = null

# MOVEMENT DEFAULT VALUES/VARIABLES
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
@export var speed = WALK_SPEED
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# INTERACTION VARIABLES
var focus: Node3D = null
var holding: Node3D = null

func _ready() -> void:
	await get_tree().process_frame

	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	interact_action.set_multiplayer_authority(peer_id)
	alt_interact_action.set_multiplayer_authority(peer_id)

	first_person_camera.set_multiplayer_authority(peer_id)
	third_person_camera.set_multiplayer_authority(peer_id)
	focus_sensor.set_multiplayer_authority(peer_id)

	rollback_synchronizer.enable_input_broadcast = true
	rollback_synchronizer.process_settings()
	_setup()

func _setup() -> void:
	# signal connections
	focus_sensor.focus_hit.connect(_on_focus_hit)

	setNameplate(str(peer_id))

	var my_id = multiplayer.get_unique_id()

	# Local Player setup - hide model and nameplate, set camera current
	if peer_id == my_id:
		if camera_type == CameraType.FIRST_PERSON:
			var camera = get_node_or_null(first_person_camera.get_camera_path())
			if camera:
				camera.current = true
				current_camera = camera
			model.visible = false
			nameplate.visible = false
		elif camera_type == CameraType.THIRD_PERSON:
			var camera = get_node_or_null(third_person_camera.get_camera_path())
			if camera:
				camera.current = true
				current_camera = camera
			model.visible = true
			nameplate.visible = true
	else:
		model.visible = true
		nameplate.visible = true

func _rollback_tick(_delta, tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	var camera_basis = get_camera_basis()

	if camera_basis != _previous_camera_basis:
		_previous_camera_basis = camera_basis
		rotate_player_model(_delta)

	var direction = (camera_basis * transform.basis * Vector3(input.movement.x, 0, input.movement.z)).normalized()

	if input.shift:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	if input.interact and focus:
		interact_action.set_active(true, tick)
		SweetLogger.info("interact RewindableAction.ACTIVE current tick: {0}", [tick], "Player.gd", "_rollback_tick")
	
	match interact_action.get_status(tick):
		RewindableAction.CONFIRMING:
			SweetLogger.info("interact RewindableAction.CONFIRMING current tick: {0}", [tick], "Player.gd", "_rollback_tick")
			_handle_interact()
		RewindableAction.CANCELLING:
			SweetLogger.info("interact RewindableAction.CANCELLING current tick: {0}", [tick], "Player.gd", "_rollback_tick")
			_handle_interact_cancelled()
			interact_action.set_active(false, tick)
		RewindableAction.ACTIVE:
			pass
		RewindableAction.INACTIVE:
			pass

	if holding:
		_update_hold_point()

	if holding and input.alt_interact_released:
		alt_interact_action.set_active(true, tick)
		SweetLogger.info("alt_interact RewindableAction.ACTIVE current tick: {0}", [tick], "Player.gd", "_rollback_tick")
	
	match alt_interact_action.get_status(tick):
		RewindableAction.CONFIRMING:
			SweetLogger.info("alt_interact RewindableAction.CONFIRMING current tick: {0}", [tick], "Player.gd", "_rollback_tick")
			_handle_alt_interact()
		RewindableAction.CANCELLING:
			SweetLogger.info("alt_interact RewindableAction.CANCELLING current tick: {0}", [tick], "Player.gd", "_rollback_tick")
			_handle_alt_interact_cancelled()
			alt_interact_action.set_active(false, tick)
		RewindableAction.ACTIVE:
			pass
		RewindableAction.INACTIVE:
			pass

	if is_on_floor():
		velocity.y = 0
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, _delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, _delta * 7.0)
	else:
		velocity.y -= gravity * _delta
		velocity.x = lerp(velocity.x, direction.x * speed, _delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, _delta * 3.0)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _process(_delta: float) -> void:
	pass

func _handle_interact() -> void:
	if not focus or not focus.interactable:
		return

	focus.interactable.interact(self, InteractionTypes.PickupData.pickup())
	holding = focus

func _handle_interact_cancelled() -> void:
	pass

func _handle_alt_interact() -> void:
	if not holding:
		return
	
	holding.interactable.interact(self, InteractionTypes.PickupData.drop())
	holding = null

func _handle_alt_interact_cancelled() -> void:
	pass

func _update_hold_point() -> void:
	var camera_basis: Basis = get_camera_basis()
	var hold_offset = Vector3(0.0, 0.3, -1.5)
	var camera_position = first_person_camera.global_position
	var rotated_offset = camera_basis * hold_offset
	hold_point.global_position = camera_position + rotated_offset
	hold_point.transform.basis = camera_basis

func get_camera_basis() -> Basis:
	if camera_type == CameraType.FIRST_PERSON:
		return first_person_camera.camera_basis
	elif camera_type == CameraType.THIRD_PERSON:
		return third_person_camera.camera_basis
	return Basis.IDENTITY

func rotate_player_model(delta: float) -> void:
	var camera_basis: Basis = get_camera_basis()

	var head_forward = camera_basis.z
	var target_angle = atan2(head_forward.x, head_forward.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, delta * 10.0)

func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")

# signals
func _on_focus_hit(hit: Object) -> void:
	SweetLogger.info("Player {0}: Focus hit: {1}", [peer_id, hit.name if hit else "null"], "Player.gd", "_on_focus_hit")
	focus = hit
