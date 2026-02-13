extends BaseNetInput
class_name PlayerInput

var movement: Vector3 = Vector3.ZERO
var shift: bool = false

# INTERACT
var interact_released: bool = false
var interact: bool = false
var interact_hold_time: float = 0.0

var _interact_release_buffer: bool = false
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
	NetworkTime.before_tick_loop.connect(_gather)

func _process(delta: float) -> void:
	if Input.is_action_pressed("interact"):
		_interact_buffer = true
		_interact_hold_duration += delta
	else:
		_interact_buffer = false

	if Input.is_action_just_released("interact"):
		_interact_release_buffer = true

	if Input.is_action_pressed("alt_interact"):
		_alt_interact_buffer = true
		_alt_interact_hold_duration += delta
	else:
		_alt_interact_buffer = false

	if Input.is_action_just_released("alt_interact"):
		_alt_interact_release_buffer = true

	if Input.is_action_just_released("escape"):
		_escape_release_buffer = true

func _gather():
	if not is_multiplayer_authority():
		return

	movement = Vector3(
		Input.get_axis("left", "right"),
		Input.get_action_strength("jump"),
		Input.get_axis("forward", "back"),
	)

	shift = Input.is_action_pressed("shift")

	# Interact Hold + One off release
	interact = _interact_buffer
	interact_released = _interact_release_buffer

	if interact_released:
		interact_hold_time = _interact_hold_duration
		_interact_hold_duration = 0.0
	elif not interact:
		interact_hold_time = 0.0

	_interact_release_buffer = false

	# Alt Interact Hold + One off release
	alt_interact = _alt_interact_buffer
	alt_interact_released = _alt_interact_release_buffer

	if alt_interact_released:
		alt_interact_hold_time = _alt_interact_hold_duration
		_alt_interact_hold_duration = 0.0
	elif not alt_interact:
		alt_interact_hold_time = 0.0

	_alt_interact_release_buffer = false

	# Escape
	escape_released = _escape_release_buffer

	_escape_release_buffer = false

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather)
