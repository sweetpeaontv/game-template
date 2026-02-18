extends CharacterBody3D

signal alt_interact_hold_duration_changed(duration: float)

const IS_VERBOSE := false

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
@onready var camera_input: Node3D = $CameraInput
@onready var camera_manager: CameraManager = $CameraManager
@onready var camera_anchor_fp: Node3D = $CameraAnchorFP
@onready var camera_anchor_tp: Node3D = $CameraAnchorTP
@onready var focus_sensor: Node3D = $FocusSensor

# MULTIPLAYER VALUES/VARIABLES
var peer_id: int = 0

# CAMERA DEFAULT VALUES/VARIABLES
enum CameraType { FIRST_PERSON, THIRD_PERSON }
@onready var camera_type: CameraType = CameraType.FIRST_PERSON
var _previous_camera_basis: Basis = Basis.IDENTITY

# MOVEMENT DEFAULT VALUES/VARIABLES
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
@export var speed = WALK_SPEED
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# INTERACTION VARIABLES
var holding_key: int = 0
var holding: Interactable = null
var examining_key: int = 0
var examining: Examinable = null

# INIT
#===================================================================================#
func _ready() -> void:
	await get_tree().process_frame

	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	camera_input.set_multiplayer_authority(peer_id)
	interact_action.set_multiplayer_authority(peer_id)
	alt_interact_action.set_multiplayer_authority(peer_id)

	camera_manager.set_multiplayer_authority(peer_id)
	focus_sensor.set_multiplayer_authority(peer_id)

	rollback_synchronizer.enable_input_broadcast = true
	rollback_synchronizer.process_settings()
	_setup()

func _setup() -> void:
	setNameplate(str(peer_id))

	var my_id = multiplayer.get_unique_id()

	var is_local: bool= (peer_id == my_id)

	if is_local:
		UIManager.show_ui("Crosshair")
		model.visible = (camera_type == CameraType.THIRD_PERSON)
		nameplate.visible = false
	else:
		model.visible = true
		nameplate.visible = true

	camera_manager.bind_subject(
		is_local,
		camera_anchor_fp,
		camera_anchor_tp,
		CameraManager.RigType.FIRST_PERSON if camera_type == CameraType.FIRST_PERSON else CameraManager.RigType.THIRD_PERSON,
		true
	)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	pass
#===================================================================================#

# PLAYER LOOP
#===================================================================================#
func _rollback_tick(_delta, tick, _is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	_handle_holding_sync()
	_handle_examine_sync()
	
	var camera_basis: Basis = camera_input.camera_basis
	if camera_basis != _previous_camera_basis:
		_previous_camera_basis = camera_basis
		rotate_player_model(_delta, camera_basis)
	
	var direction = (camera_basis * transform.basis * Vector3(input.movement.x, 0, input.movement.z)).normalized()

	if input.shift:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	_process_rewindable_action(
		interact_action,
		input.interact_released and focus_sensor.focus,
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

	if input.escape_released:
		_handle_escape()

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
	#_log_collisions()
#===================================================================================#

# INTERACT ACTION
#===================================================================================#
func _handle_interact() -> void:
	if not focus_sensor.focus or not focus_sensor.focus is Interactable:
		return

	var interaction_type = focus_sensor.focus.get_interaction_type()
	match interaction_type:
		InteractionTypes.InteractionType.PICKUPABLE:
			_handle_pickup()
		InteractionTypes.InteractionType.OPENABLE:
			focus_sensor.focus.interact(self, InteractionTypes.OpenData.toggle())
		InteractionTypes.InteractionType.EXAMINABLE:
			_handle_examine()
		_:
			SweetLogger.error("Invalid interaction type: {0}", [interaction_type], "Player.gd", "_handle_interact")
	
func _handle_interact_cancelled() -> void:
	pass
#===================================================================================#

# ALT INTERACT ACTION
#===================================================================================#
# needs to be generalized, as other interactables may have different alt interact data
# currently only works for pickupables
func _handle_alt_interact() -> void:
	if not holding:
		return
	
	if input.alt_interact_hold_time < 0.2:
		holding.interact(self, InteractionTypes.PickupData.drop())
	else:
		var throw_power = input.alt_interact_hold_time * 10.0
		var throw_direction = -get_camera_basis().z
		holding.interact(self, InteractionTypes.PickupData.throw(throw_power, throw_direction))

	holding_key = 0
	holding.pickupable_yanked.disconnect(_on_pickupable_yanked)
	holding = null
	NetworkRollback.mutate(self)
	# NEED TO DISCONNECT HOLD DURATION SIGNAL WHEN HUD IS HIDDEN
	UIManager.hide_ui("PickupHUD")

func _handle_alt_interact_cancelled() -> void:
	if IS_VERBOSE:
		SweetLogger.info("cancelling alt_interact, setting pickup state to FREE", [], "Player.gd", "_handle_alt_interact_cancelled")
	holding.set_pickup_state(holding.PickupState.FREE)
#===================================================================================#

# PICKUP ACTION
#===================================================================================#
# a bit sloppy but works
func _handle_holding_sync() -> void:
	if holding_key == 0 and holding != null:
		holding = null
	if holding_key != 0 and holding == null:
		var new_holding = InteractableRegistries.pickupables.get_entry(holding_key)
		if new_holding:
			holding = new_holding
			holding_key = new_holding.key if new_holding else 0
			if not holding.pickupable_yanked.is_connected(_on_pickupable_yanked):
				holding.pickupable_yanked.connect(_on_pickupable_yanked)

func _handle_pickup() -> void:
	focus_sensor.focus.interact(self, InteractionTypes.PickupData.pickup())
	focus_sensor.focus.pickupable_yanked.connect(_on_pickupable_yanked)
	holding = focus_sensor.focus
	holding_key = focus_sensor.focus.key

	if multiplayer.get_unique_id() == peer_id:
		#var signal_connections = [
		#	SignalConnections.new(self, alt_interact_hold_duration_changed, )
		#]
		var pickup_hud = UIManager.show_ui("PickupHUD", {})
		# THIS NEEDS TO BE DISCONNECTED WHEN HUD IS HIDDEN OR CONNECTED ONCE IN SETUP		
		alt_interact_hold_duration_changed.connect(pickup_hud.update_control_value)

func _handle_object_yanked() -> void:
	''' Called (outside of rollback loop) when another player takes an object from the player.'''
	SweetLogger.info("Object yanked from player: {0}, setting holding to null", [peer_id], "Player.gd", "_handle_object_yanked")
	holding_key = 0
	holding.pickupable_yanked.disconnect(_on_pickupable_yanked)
	NetworkRollback.mutate(self)
	UIManager.hide_ui("PickupHUD")

func _handle_let_go() -> void:
	if input.alt_interact_hold_time < 0.2:
		holding.interact(self, InteractionTypes.PickupData.drop())
	else:
		var throw_power = input.alt_interact_hold_time * 10.0
		holding.interact(self, InteractionTypes.PickupData.throw(throw_power))

	holding_key = 0
	holding.pickupable_yanked.disconnect(_on_pickupable_yanked)
	NetworkRollback.mutate(self)
	# NEED TO DISCONNECT HOLD DURATION SIGNAL WHEN HUD IS HIDDEN
	UIManager.hide_ui("PickupHUD")
#===================================================================================#

# EXAMINE ACTION
#===================================================================================#
func _handle_examine_sync() -> void:
	if examining_key == 0 and examining != null:
		examining = null
	if examining_key != 0 and examining == null:
		var new_examining = InteractableRegistries.examinables.get_entry(examining_key)
		if new_examining:
			examining = new_examining
			examining_key = new_examining.key if new_examining else 0

func _handle_examine() -> void:
	focus_sensor.focus.interact(self, InteractionTypes.ExaminableData.examine())
	examining = focus_sensor.focus
	examining_key = focus_sensor.focus.key

	if multiplayer.get_unique_id() == peer_id:
		camera_manager.transition_to(CameraManager.RigType.EXAMINE, focus_sensor.focus.examine_camera_anchor)

func _handle_examine_disengage() -> void:
	examining.interact(self, InteractionTypes.ExaminableData.disengage())

	examining = null
	examining_key = 0
	
	if multiplayer.get_unique_id() == peer_id:
		camera_manager.transition_to(CameraManager.RigType.FIRST_PERSON, camera_anchor_fp)
#===================================================================================#

# ESCAPE
#===================================================================================#
func _handle_escape() -> void:
	if examining:
		_handle_examine_disengage()
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
			if IS_VERBOSE:
				SweetLogger.info("{0} RewindableAction.CONFIRMING current tick: {1} for player: {2}", [_action_name, tick, peer_id], "Player.gd", "_rollback_tick")
			on_confirming.call()
		RewindableAction.CANCELLING:
			if IS_VERBOSE:
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
	return camera_input.camera_basis
#===================================================================================#

# HELPERS
#===================================================================================#
func _log_collisions() -> void:
	var count := get_slide_collision_count()
	if count == 0:
		return
	for i in count:
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var collider = collision.get_collider()
		if collider == null:
			continue
		SweetLogger.info(
			"Colliding with: {0} (type: {1})",
			[collider.name, collider.get_class()],
			"Player.gd",
			"_log_collisions"
		)

# quick and dirty solution to update the hold point position and rotation
# could use a spring arm for better results
func _update_hold_point() -> void:
	var camera_basis: Basis = camera_input.camera_basis
	var hold_offset = Vector3(0.0, 0.3, -1.5)

	var camera_position
	if camera_type == CameraType.FIRST_PERSON:
		camera_position = camera_anchor_fp.global_position
	else:
		camera_position = camera_anchor_tp.global_position

	var rotated_offset = camera_basis * hold_offset
	hold_point.global_position = camera_position + rotated_offset
	hold_point.transform.basis = camera_basis

func rotate_player_model(delta: float, camera_basis: Basis) -> void:
	var head_forward = camera_basis.z
	var target_angle = atan2(head_forward.x, head_forward.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_angle, delta * 10.0)
#===================================================================================#

# SIGNALS
#===================================================================================#
func _on_pickupable_yanked() -> void:
	if not holding:
		return
	
	_handle_object_yanked()
#===================================================================================#
