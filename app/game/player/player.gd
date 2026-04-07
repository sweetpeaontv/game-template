extends CharacterBody3D

# SIGNALS
signal alt_interact_hold_duration_changed(duration: float)

# DEBUG
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
var local_player: bool = false

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

# PLAYER STATUS
enum PlayerStatus { LOADING, ESC, PLAYING, DISCONNECTED }
var player_status: PlayerStatus = PlayerStatus.LOADING

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

	local_player = (peer_id == my_id)

	if local_player:
		UIManager.show_ui("Crosshair")
		model.visible = (camera_type == CameraType.THIRD_PERSON)
		nameplate.visible = false

		InputModeManager.set_input_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		model.visible = true
		nameplate.visible = true

	camera_manager.bind_subject(
		local_player,
		camera_anchor_fp,
		camera_anchor_tp,
		CameraManager.RigType.FIRST_PERSON if camera_type == CameraType.FIRST_PERSON else CameraManager.RigType.THIRD_PERSON,
		true
	)

	player_status = PlayerStatus.PLAYING
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	pass
#===================================================================================#

# PLAYER LOOP
#===================================================================================#
func _rollback_tick(_delta, tick, is_fresh):
	if not input:
		push_error("Player: Input node not found!")
		return

	# sync
	focus_sensor._handle_focus_sync()
	_handle_holding_sync()
	_handle_examine_sync()

	# input
	_handle_camera_rotation(_delta)
	_handle_movement(_delta)
	_handle_interactions(tick, is_fresh)
	# maybe comes before interactions? or conditionally? could be a race condition based on input close together
	_handle_other_input(tick, is_fresh)

	# apply
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	# debug
	#_log_collisions()

#===================================================================================#

# LOCOMOTION
# Player-driven walking/sprinting is gated here. Gravity, air physics, and
# move_and_slide still run every tick so external forces and collisions apply.
#===================================================================================#
func _locomotion_input_allowed() -> bool:
	return player_status == PlayerStatus.PLAYING and examining == null

# CAMERA ROTATION
#===================================================================================#
func _handle_camera_rotation(delta: float) -> void:
	if camera_input.camera_basis != _previous_camera_basis:
		_previous_camera_basis = camera_input.camera_basis
		rotate_player_model(delta, camera_input.camera_basis)
#===================================================================================#

# INPUT
#===================================================================================#
func _handle_movement(delta: float) -> void:
	var move_input := input.movement
	if not _locomotion_input_allowed():
		move_input = Vector3.ZERO

	var direction = (camera_input.camera_basis * transform.basis * Vector3(move_input.x, 0, move_input.z)).normalized()

	if input.shift:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	if is_on_floor():
		velocity.y = 0
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.y -= gravity * delta
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

func _handle_interactions(tick: int, is_fresh: bool) -> void:
	if not input:
		push_error("Player: Input node not found!")
		return

	_process_rewindable_action(
		interact_action,
		(input.interact_pressed or input.left_click_pressed) and focus_sensor.focus,
		tick,
		is_fresh,
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
		is_fresh,
		"alt_interact",
		_handle_alt_interact,
		_handle_alt_interact_cancelled
	)

func _handle_other_input(tick: int, is_fresh: bool) -> void:
	if not input:
		push_error("Player: Input node not found!")
		return

	if input.escape_released:
		_handle_escape(tick, is_fresh)
#===================================================================================#

# INTERACT ACTION
#===================================================================================#
func _handle_interact(is_fresh: bool) -> void:
	if not focus_sensor.focus or not focus_sensor.focus is Interactable:
		SweetLogger.error("No focus or focus is not an Interactable for player: {0}", [peer_id], "Player.gd", "_handle_interact")
		return

	var interaction_type = focus_sensor.focus.get_interaction_type()
	match interaction_type:
		InteractionTypes.InteractionType.PICKUPABLE:
			_handle_pickup(is_fresh)
		InteractionTypes.InteractionType.OPERABLE:
			_handle_operate(is_fresh)
		InteractionTypes.InteractionType.EXAMINABLE:
			_handle_examine(is_fresh)
		_:
			SweetLogger.error("Invalid interaction type: {0}", [interaction_type], "Player.gd", "_handle_interact")
	
func _handle_interact_cancelled(_is_fresh: bool) -> void:
	pass
#===================================================================================#

# ALT INTERACT ACTION
#===================================================================================#
# needs to be generalized, as other interactables may have different alt interact data
# currently only works for pickupables
func _handle_alt_interact(_is_fresh: bool) -> void:
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

func _handle_alt_interact_cancelled(_is_fresh: bool) -> void:
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
		return
	if holding_key != 0 and holding == null:
		var new_holding = InteractableRegistries.pickupables.get_entry(holding_key)

		if not new_holding:
			SweetLogger.error("New holding is null for player: {0}, holding key: {1}", [peer_id, holding_key], "Player.gd", "_handle_holding_sync")
			return
		
		holding = new_holding
		holding_key = new_holding.key if new_holding else 0
		if not holding.pickupable_yanked.is_connected(_on_pickupable_yanked):
			holding.pickupable_yanked.connect(_on_pickupable_yanked)

func _handle_pickup(is_fresh: bool) -> void:
	focus_sensor.focus.interact(self, InteractionTypes.PickupData.pickup())
	focus_sensor.focus.pickupable_yanked.connect(_on_pickupable_yanked)
	holding = focus_sensor.focus
	holding_key = focus_sensor.focus.key

	if local_player and is_fresh:
		#var signal_connections = [
		#	SignalConnections.new(self, alt_interact_hold_duration_changed, )
		#]
		var pickup_hud = UIManager.show_ui("PickupHUD", {})
		# THIS NEEDS TO BE DISCONNECTED WHEN HUD IS HIDDEN OR CONNECTED ONCE IN SETUP		
		alt_interact_hold_duration_changed.connect(pickup_hud.update_control_value)

func _handle_object_released() -> void:
	SweetLogger.info("Object released from player: {0}, setting holding to null", [peer_id], "Player.gd", "_handle_object_released")
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

	_handle_object_released()
#===================================================================================#

# OPERATE ACTION
#===================================================================================#
func _handle_operate(is_fresh: bool) -> void:
	focus_sensor.focus.interact(
		self,
		InteractionTypes.OperableData.new(focus_sensor.focus.default_operate_action),
		is_fresh
	)
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

func _handle_examine(is_fresh: bool) -> void:
	focus_sensor.focus.interact(self, InteractionTypes.ExaminableData.examine())
	examining = focus_sensor.focus
	examining_key = focus_sensor.focus.key

	if local_player and is_fresh:
		InputModeManager.set_input_mode(Input.MOUSE_MODE_CONFINED)
		camera_manager.transition_to(CameraManager.RigType.EXAMINE, focus_sensor.focus.examine_camera_anchor)

func _handle_examine_disengage(is_fresh: bool) -> void:
	examining.interact(self, InteractionTypes.ExaminableData.disengage())

	examining = null
	examining_key = 0
	
	if local_player and is_fresh:
		InputModeManager.set_input_mode(Input.MOUSE_MODE_CAPTURED)
		camera_manager.transition_to(CameraManager.RigType.FIRST_PERSON, camera_anchor_fp)
#===================================================================================#

# ESCAPE
#===================================================================================#
func _handle_escape(tick: int, is_fresh: bool) -> void:
	if examining:
		_handle_examine_disengage(is_fresh)
		return
	
	if player_status == PlayerStatus.ESC:
		player_status = PlayerStatus.PLAYING
		if local_player and is_fresh:
			_handle_resume_local(tick)
		return

	player_status = PlayerStatus.ESC
	if local_player and is_fresh:
		_handle_esc_local(tick)

func _handle_esc_local(_tick: int) -> void:
	var esc_menu: Node = UIManager.show_ui("EscMenu")
	if esc_menu and esc_menu.has_signal("resume_pressed"):
		esc_menu.resume_pressed.connect(_on_esc_menu_resume_pressed, CONNECT_ONE_SHOT)
	InputModeManager.set_input_mode(Input.MOUSE_MODE_VISIBLE)
	camera_manager.set_look_input_enabled(false)

func _handle_resume_local(_tick: int) -> void:
	UIManager.hide_ui("EscMenu")
	InputModeManager.set_input_mode(Input.MOUSE_MODE_CAPTURED)
	camera_manager.set_look_input_enabled(true)

func _on_esc_menu_resume_pressed() -> void:
	if not local_player:
		return
	if player_status != PlayerStatus.ESC:
		return
	# player_status is rollback state: UI callbacks cannot set it reliably (snapshots overwrite it).
	# Resume must go through the same input path as the escape key so ticks record/replay escape_released.
	input.queue_escape_release()
#===================================================================================#

# PROCESS REWINDABLE ACTION
#===================================================================================#
func _process_rewindable_action(
	action: RewindableAction,
	should_activate: bool,
	tick: int,
	is_fresh: bool,
	_action_name: String,
	on_confirming: Callable,
	on_cancelling: Callable
) -> void:
	if should_activate:
		action.set_active(true, tick)
		if IS_VERBOSE:
			SweetLogger.info("{0} RewindableAction.ACTIVE current tick: {1}", [_action_name, tick], "Player.gd", "_rollback_tick")

	match action.get_status(tick):
		RewindableAction.CONFIRMING:
			if IS_VERBOSE:
				SweetLogger.info("{0} RewindableAction.CONFIRMING current tick: {1} for player: {2}", [_action_name, tick, peer_id], "Player.gd", "_rollback_tick")
			on_confirming.call(is_fresh)
		RewindableAction.CANCELLING:
			if IS_VERBOSE:
				SweetLogger.info("{0} RewindableAction.CANCELLING current tick: {1} for player: {2}", [_action_name, tick, peer_id], "Player.gd", "_rollback_tick")
			on_cancelling.call(is_fresh)
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

# API
#===================================================================================#
func is_focused() -> bool:
	return focus_sensor.is_focused()

func get_focus() -> Interactable:
	return focus_sensor.get_focus()

func is_examining() -> bool:
	return examining_key != 0

func get_examining() -> Examinable:
	return examining if examining_key != 0 else null

func is_holding() -> bool:
	return holding_key != 0

func get_holding() -> Pickupable:
	return holding if holding_key != 0 else null
#===================================================================================#

# SIGNALS
#===================================================================================#
func _on_pickupable_yanked() -> void:
	if not holding:
		return
	
	_handle_object_released()
#===================================================================================#
