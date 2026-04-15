extends BaseNetInput
class_name PlayerInput

# VARIABLES
## In order to add a new variable:
## - Add a pressed, just_pressed, released, and hold_time variable with intended prefix 
## - Add prefix to input_keys array
## - Ensure that the new variables are included in input_properties in the RollbackSynchronizer
#===================================================================================#
var movement: Vector3 = Vector3.ZERO

## Mouse position in visible viewport space: (0,0) top-left, (1,1) bottom-right.
## Synced for rollback so sim matches across peers with different resolutions.
var aim_screen: Vector2 = Vector2(0.5, 0.5)

var shift_pressed: bool = false
var shift_just_pressed: bool = false
var shift_released: bool = false
var shift_hold_time: float = 0.0

var left_click_pressed: bool = false
var left_click_just_pressed: bool = false
var left_click_released: bool = false
var left_click_hold_time: float = 0.0

var right_click_pressed: bool = false
var right_click_just_pressed: bool = false
var right_click_released: bool = false
var right_click_hold_time: float = 0.0

var interact_pressed: bool = false
var interact_just_pressed: bool = false
var interact_released: bool = false
var interact_hold_time: float = 0.0

var alt_interact_pressed: bool = false
var alt_interact_just_pressed: bool = false
var alt_interact_released: bool = false
var alt_interact_hold_time: float = 0.0

var escape_pressed: bool = false
var escape_just_pressed: bool = false
var escape_released: bool = false
var escape_hold_time: float = 0.0

var input_keys: Array[String] = [
	"movement",
	"aim_screen",
	"shift",
	"left_click",
	"right_click",
	"interact",
	"alt_interact",
	"escape",
]

var buffers: Dictionary = {}
#===================================================================================#

# BASE INPUT
#===================================================================================#
class BaseInput:
	var pressed: bool = false
	var just_pressed: bool = false
	var released: bool = false
	var hold_time: float = 0.0

func buffer_input(delta: float, key: String, buffer: BaseInput) -> void:
	if Input.is_action_pressed(key):
		buffer.pressed = true
		buffer.hold_time += delta
	else:
		buffer.pressed = false

	if Input.is_action_just_pressed(key):
		buffer.just_pressed = true
		buffer.hold_time = 0.0

	if Input.is_action_just_released(key):
		buffer.released = true

func apply_buffer_continuous(key: String, buffer: BaseInput) -> void:
	set("%s_pressed" % key, buffer.pressed)
	set("%s_hold_time" % key, buffer.hold_time)

func apply_buffer_one_shot(key: String, buffer: BaseInput) -> void:
	# just pressed
	set("%s_just_pressed" % key, buffer.just_pressed)
	buffer.just_pressed = false

	# released
	set("%s_released" % key, buffer.released)
	buffer.released = false

	# hold time increment/cleanup
	if get("%s_pressed" % key):
		set("%s_hold_time" % key, buffer.hold_time)
	elif get("%s_released" % key):
		set("%s_hold_time" % key, buffer.hold_time)
		buffer.hold_time = 0.0
	else:
		set("%s_hold_time" % key, 0.0)
		buffer.hold_time = 0.0
#===================================================================================#

# MOVEMENT
#===================================================================================#
class MovementBuffer:
	var movement: Vector3 = Vector3.ZERO
	var movement_samples: int = 0

func buffer_movement(input: MovementBuffer) -> void:
	input.movement += Vector3(
		Input.get_axis("left", "right"),
		Input.get_action_strength("jump"),
		Input.get_axis("forward", "back"),
	)
	input.movement_samples += 1

func apply_buffer_movement(input: MovementBuffer) -> void:
	if input.movement_samples > 0:
		movement = input.movement / input.movement_samples
	else:
		movement = Vector3.ZERO

	input.movement = Vector3.ZERO
	input.movement_samples = 0
#===================================================================================#

# AIM SCREEN
#===================================================================================#
class AimScreenBuffer:
	var aim_screen: Vector2 = Vector2.ZERO

func buffer_aim_screen(input: AimScreenBuffer) -> void:
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.x > 0.0 and sz.y > 0.0:
			var raw := vp.get_mouse_position()
			input.aim_screen.x = clampf(raw.x / sz.x, 0.0, 1.0)
			input.aim_screen.y = clampf(raw.y / sz.y, 0.0, 1.0)

func apply_buffer_aim_screen(input: AimScreenBuffer) -> void:
	aim_screen = input.aim_screen
	input.aim_screen = Vector2.ZERO
#===================================================================================#

# INIT
#===================================================================================#
func _ready():
	_setup_buffers_and_slots()
	# Continuous state is sampled once per batch; one-shots run on every
	# before_tick so interact_pressed / click_pressed are not stuck true across
	# multiple network ticks in the same frame (double operable toggle).
	NetworkTime.before_tick_loop.connect(_gather_continuous)
	NetworkTime.before_tick.connect(_gather_one_shots)

func _new_buffer_for_key(key: String) -> Object:
	if key == "movement":
		return MovementBuffer.new()
	elif key == "aim_screen":
		return AimScreenBuffer.new()
	else:
		return BaseInput.new()

func _setup_buffers_and_slots() -> void:
	for key in input_keys:
		buffers[key] = _new_buffer_for_key(key)
	movement = Vector3.ZERO
	aim_screen = Vector2.ZERO
#===================================================================================#

# PROCESS
#===================================================================================#
func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	for key in buffers:
		if buffers[key] is BaseInput:
			buffer_input(delta, key, buffers[key])
		elif buffers[key] is MovementBuffer:
			buffer_movement(buffers[key])
		elif buffers[key] is AimScreenBuffer:
			buffer_aim_screen(buffers[key])
#===================================================================================#

# GATHER
#===================================================================================#
func _gather_continuous() -> void:
	if not is_multiplayer_authority():
		return

	for key in input_keys:
		var buffer = buffers[key]
		if buffer is BaseInput:
			apply_buffer_continuous(key, buffer)
		elif buffer is MovementBuffer:
			apply_buffer_movement(buffer)
		elif buffer is AimScreenBuffer:
			apply_buffer_aim_screen(buffer)

func _gather_one_shots(_delta: float, _tick: int) -> void:
	if not is_multiplayer_authority():
		return

	for key in input_keys:
		var buffer = buffers[key]
		if buffer is BaseInput:
			apply_buffer_one_shot(key, buffer)
#===================================================================================#

# QUEUE INPUTS (outside rollback)
#===================================================================================#
func queue_escape_release() -> void:
	if not is_multiplayer_authority():
		return
	buffers["escape"].released = true
#===================================================================================#

# CLEANUP
#===================================================================================#
func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather_continuous)
	NetworkTime.before_tick.disconnect(_gather_one_shots)
#===================================================================================#
