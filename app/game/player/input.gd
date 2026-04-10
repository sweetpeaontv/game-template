extends BaseNetInput
class_name PlayerInput

# MOVEMENT
var movement: Vector3 = Vector3.ZERO
var _movement_buffer: Vector3 = Vector3.ZERO
var _movement_samples: int = 0
var shift: bool = false

# MOUSE (left_click / right_click = held; *_pressed / *_released = one-shot per tick;
# *_hold_time = seconds held this press, live while held, final value on release frame)
var left_click: bool = false
var left_click_released: bool = false
var left_click_pressed: bool = false
var left_click_hold_time: float = 0.0
var _left_click_pressed_buffer: bool = false
var _left_click_buffer: bool = false
var _left_click_release_buffer: bool = false
var _left_click_hold_duration: float = 0.0

var right_click: bool = false
var right_click_released: bool = false
var right_click_pressed: bool = false
var right_click_hold_time: float = 0.0
var _right_click_pressed_buffer: bool = false
var _right_click_buffer: bool = false
var _right_click_release_buffer: bool = false
var _right_click_hold_duration: float = 0.0

# INTERACT
var interact_pressed: bool = false
var interact: bool = false
var interact_hold_time: float = 0.0

var _interact_pressed_buffer: bool = false
var _interact_buffer: bool = false
var _interact_hold_duration: float = 0.0

# ALT INTERACT
var alt_interact_released: bool = false
var alt_interact: bool = false
var alt_interact_hold_time: float = 0.0

var _alt_interact_release_buffer: bool = false
var _alt_interact_buffer: bool = false
var _alt_interact_hold_duration: float = 0.0

# ESCAPE
var escape_released: bool = false
var _escape_release_buffer: bool = false

func _ready():
	# Continuous state is sampled once per batch; one-shots run on every
	# before_tick so interact_pressed / click_pressed are not stuck true across
	# multiple network ticks in the same frame (double operable toggle).
	NetworkTime.before_tick_loop.connect(_gather_continuous)
	NetworkTime.before_tick.connect(_gather_edges)

func _process(delta: float) -> void:
	# MOVEMENT
	#===================================================================================#
	_movement_buffer += Vector3(
		Input.get_axis("left", "right"),
		Input.get_action_strength("jump"),
		Input.get_axis("forward", "back"),
	)
	_movement_samples += 1
	#===================================================================================#

	# MOUSE
	#===================================================================================#
	if Input.is_action_pressed("left_click"):
		_left_click_buffer = true
		_left_click_hold_duration += delta
	else:
		_left_click_buffer = false

	if Input.is_action_just_pressed("left_click"):
		_left_click_pressed_buffer = true

	if Input.is_action_just_released("left_click"):
		_left_click_release_buffer = true

	if Input.is_action_pressed("right_click"):
		_right_click_buffer = true
		_right_click_hold_duration += delta
	else:
		_right_click_buffer = false

	if Input.is_action_just_pressed("right_click"):
		_right_click_pressed_buffer = true

	if Input.is_action_just_released("right_click"):
		_right_click_release_buffer = true
	#===================================================================================#

	# INTERACT
	#===================================================================================#
	if Input.is_action_pressed("interact"):
		_interact_buffer = true
		_interact_hold_duration += delta
	else:
		_interact_buffer = false

	if Input.is_action_just_pressed("interact"):
		_interact_pressed_buffer = true
	#===================================================================================#

	# ALT INTERACT
	#===================================================================================#
	if Input.is_action_pressed("alt_interact"):
		_alt_interact_buffer = true
		_alt_interact_hold_duration += delta
	else:
		_alt_interact_buffer = false

	if Input.is_action_just_released("alt_interact"):
		_alt_interact_release_buffer = true
	#===================================================================================#

	# ESCAPE
	#===================================================================================#
	if Input.is_action_just_released("escape"):
		_escape_release_buffer = true
	#===================================================================================#

func _gather_continuous() -> void:
	if not is_multiplayer_authority():
		return

	# MOVEMENT
	#===================================================================================#
	if _movement_samples > 0:
		movement = _movement_buffer / _movement_samples
	else:
		movement = Vector3.ZERO

	_movement_buffer = Vector3.ZERO
	_movement_samples = 0

	shift = Input.is_action_pressed("shift")
	#===================================================================================#

	# MOUSE (held only; edges in _gather_edges)
	#===================================================================================#
	left_click = _left_click_buffer
	right_click = _right_click_buffer
	#===================================================================================#

	# INTERACT / ALT (held only)
	#===================================================================================#
	interact = _interact_buffer
	alt_interact = _alt_interact_buffer
	#===================================================================================#


func _gather_edges(_delta: float, _tick: int) -> void:
	if not is_multiplayer_authority():
		return

	# MOUSE one-shots + hold times
	#===================================================================================#
	left_click_released = _left_click_release_buffer
	_left_click_release_buffer = false

	left_click_pressed = _left_click_pressed_buffer
	_left_click_pressed_buffer = false

	if left_click:
		left_click_hold_time = _left_click_hold_duration
	elif left_click_released:
		left_click_hold_time = _left_click_hold_duration
		_left_click_hold_duration = 0.0
	else:
		left_click_hold_time = 0.0
		_left_click_hold_duration = 0.0

	right_click_released = _right_click_release_buffer
	_right_click_release_buffer = false

	right_click_pressed = _right_click_pressed_buffer
	_right_click_pressed_buffer = false

	if right_click:
		right_click_hold_time = _right_click_hold_duration
	elif right_click_released:
		right_click_hold_time = _right_click_hold_duration
		_right_click_hold_duration = 0.0
	else:
		right_click_hold_time = 0.0
		_right_click_hold_duration = 0.0
	#===================================================================================#

	# Interact one-shot + hold time
	#===================================================================================#
	interact_pressed = _interact_pressed_buffer
	_interact_pressed_buffer = false

	if interact_pressed:
		interact_hold_time = _interact_hold_duration
		_interact_hold_duration = 0.0
	elif not interact:
		interact_hold_time = 0.0
	#===================================================================================#

	# Alt interact release + hold time
	#===================================================================================#
	alt_interact_released = _alt_interact_release_buffer
	_alt_interact_release_buffer = false

	if alt_interact_released:
		alt_interact_hold_time = _alt_interact_hold_duration
		_alt_interact_hold_duration = 0.0
	elif not alt_interact:
		alt_interact_hold_time = 0.0
	#===================================================================================#

	# Escape
	#===================================================================================#
	escape_released = _escape_release_buffer
	_escape_release_buffer = false
	#===================================================================================#

func queue_escape_release() -> void:
	if not is_multiplayer_authority():
		return
	_escape_release_buffer = true

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather_continuous)
	NetworkTime.before_tick.disconnect(_gather_edges)
