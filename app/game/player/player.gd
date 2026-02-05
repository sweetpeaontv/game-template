extends CharacterBody3D

signal alt_interact_hold_duration_changed(duration: float)
signal focused_interactable(interactable: Interactable)
signal unfocused_interactable(interactable: Interactable)

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
const INTERACTION_COOLDOWN := 0.05  # 50ms in seconds
var _last_interact_time: float = 0.0
var focus: Node3D = null
var holding: Node3D = null

# INIT
#===================================================================================#
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
#===================================================================================#

# PLAYER LOOP
#===================================================================================#
func _rollback_tick(_delta, tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	var camera_basis = get_camera_basis()

	if get_camera_basis() != _previous_camera_basis:
		_previous_camera_basis = camera_basis
		rotate_player_model(_delta)

	var direction = (camera_basis * transform.basis * Vector3(input.movement.x, 0, input.movement.z)).normalized()

	if input.shift:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	_process_rewindable_action(
		interact_action,
		input.interact_released and focus,
		tick,
		"interact",
		_handle_interact,
		_handle_interact_cancelled
	)

	if holding:
		_update_hold_point()
	
	# updates pickup hold duration HUD
	if input.alt_interact:
		alt_interact_hold_duration_changed.emit(input._alt_interact_hold_duration)

	_process_rewindable_action(
		alt_interact_action,
		holding and input.alt_interact_released,
		tick,
		"alt_interact",
		_handle_alt_interact,
		_handle_alt_interact_cancelled
	)

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
#===================================================================================#

# INTERACT ACTION
#===================================================================================#
func _handle_interact() -> void:
	if not focus or not focus is Interactable:
		return

	_last_interact_time = NetworkTime.time
	var interaction_type = focus.get_interaction_type()
	match interaction_type:
		InteractionTypes.InteractionType.PICKUPABLE:
			_handle_pickup()
		InteractionTypes.InteractionType.OPENABLE:
			focus.interact(self, InteractionTypes.OpenData.toggle())
		_:
			SweetLogger.error("Invalid interaction type: {0}", [interaction_type], "Player.gd", "_handle_interact")
	
func _handle_interact_cancelled() -> void:
	pass
#===================================================================================#

# ALT INTERACT ACTION
#===================================================================================#
func _handle_alt_interact() -> void:
	if not holding:
		return
	
	if input.alt_interact_hold_time < 0.2:
		holding.interactable.interact(self, InteractionTypes.PickupData.drop())
	else:
		var throw_power = input.alt_interact_hold_time * 10.0
		holding.interactable.interact(self, InteractionTypes.PickupData.throw(throw_power))
	
	holding = null
	UIManager.hide_ui("PickupHUD")

func _handle_alt_interact_cancelled() -> void:
	SweetLogger.info("cancelling alt_interact, setting pickup state to FREE", [], "Player.gd", "_handle_alt_interact_cancelled")
	holding.interactable.set_pickup_state(holding.interactable.PickupState.FREE)
#===================================================================================#

# PICKUP ACTION
#===================================================================================#
func _handle_pickup() -> void:
	focus.interact(self, InteractionTypes.PickupData.pickup())
	holding = focus.parent

	if multiplayer.get_unique_id() == peer_id:
		#var signal_connections = [
		#	SignalConnections.new(self, alt_interact_hold_duration_changed, )
		#]
		var pickup_hud = UIManager.show_ui("PickupHUD", {})
		# THIS NEEDS TO BE DISCONNECTED WHEN HUD IS HIDDEN OR CONNECTED ONCE IN SETUP
		alt_interact_hold_duration_changed.connect(pickup_hud.update_control_value)

func _handle_let_go() -> void:
	if not holding:
		return

	if input.alt_interact_hold_time < 0.2:
		holding.interactable.interact(self, InteractionTypes.PickupData.drop())
	else:
		var throw_power = input.alt_interact_hold_time * 10.0
		holding.interactable.interact(self, InteractionTypes.PickupData.throw(throw_power))

	holding = null
	# NEED TO DISCONNECT HOLD DURATION SIGNAL WHEN HUD IS HIDDEN
	UIManager.hide_ui("PickupHUD")
#===================================================================================#

# PROCESS REWINDABLE ACTION
#===================================================================================#
func _process_rewindable_action(
	action: RewindableAction,
	should_activate: bool,
	tick: int,
	_action_name: String,
	on_confirming: Callable,
	on_cancelling: Callable
) -> void:
	if should_activate:
		action.set_active(true, tick)
		#SweetLogger.info("{0} RewindableAction.ACTIVE current tick: {1}", [_action_name, tick], "Player.gd", "_rollback_tick")
	
	match action.get_status(tick):
		RewindableAction.CONFIRMING:
			SweetLogger.info("{0} RewindableAction.CONFIRMING current tick: {1} for player: {2}", [_action_name, tick, peer_id], "Player.gd", "_rollback_tick")
			on_confirming.call()
		RewindableAction.CANCELLING:
			SweetLogger.info("{0} RewindableAction.CANCELLING current tick: {1} for player: {2}", [_action_name, tick, peer_id], "Player.gd", "_rollback_tick")
			on_cancelling.call()
			action.set_active(false, tick)
		RewindableAction.ACTIVE:
			pass
		RewindableAction.INACTIVE:
			pass
#===================================================================================#
# SETTERS
#===================================================================================#
func setNameplate(player_name: String) -> void:
	if nameplate:
		nameplate.text = player_name
	else:
		push_warning("Player: Cannot set nameplate - nameplate node not initialized")
#===================================================================================#

# GETTERS
#===================================================================================#
func get_camera_basis() -> Basis:
	if camera_type == CameraType.FIRST_PERSON:
		return first_person_camera.camera_basis
	elif camera_type == CameraType.THIRD_PERSON:
		return third_person_camera.camera_basis
	return Basis.IDENTITY
#===================================================================================#

# HELPERS
#===================================================================================#
# quick and dirty solution to update the hold point position and rotation
# could use a spring arm for better results
func _update_hold_point() -> void:
	var camera_basis: Basis = get_camera_basis()
	var hold_offset = Vector3(0.0, 0.3, -1.5)
	var camera_position = first_person_camera.global_position
	var rotated_offset = camera_basis * hold_offset
	hold_point.global_position = camera_position + rotated_offset
	hold_point.transform.basis = camera_basis

func rotate_player_model(delta: float) -> void:
	var camera_basis: Basis = get_camera_basis()

	var head_forward = camera_basis.z
	var target_angle = atan2(head_forward.x, head_forward.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, delta * 10.0)
#===================================================================================#

# SIGNALS
#===================================================================================#
func _on_focus_hit(hit: Object) -> void:
	var new_focus = hit if hit is Interactable else null

	if focus and focus != new_focus:
		unfocused_interactable.emit(focus)
		focus.on_focus_exit(self)

	if new_focus and new_focus != focus:
		focused_interactable.emit(new_focus)
		new_focus.on_focus_enter(self)
	
	focus = new_focus
#===================================================================================#
