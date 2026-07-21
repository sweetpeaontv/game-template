extends Control
class_name GaussianBlur

@export_range(0.1, 16.0) var sigma: float = 2.0:
	set(value):
		sigma = value
		_apply_sigma()

@export var fade_duration: float = 0.25

@onready var _horizontal_material: ShaderMaterial = $HorizontalPass.material
@onready var _vertical_material: ShaderMaterial = $VerticalPass.material

var _blur_strength: float = 1.0
var _fade_tween: Tween
var _live: bool = true

func _ready() -> void:
	_apply_sigma()
	_apply_blur_strength(_blur_strength)
	set_live(_live)

func set_live(enabled: bool) -> void:
	_live = enabled
	if not is_node_ready():
		return

	_horizontal_material.set_shader_parameter("use_screen_texture", enabled)

func set_source(texture: Texture2D) -> void:
	set_live(false)
	_horizontal_material.set_shader_parameter("source_texture", texture)

func set_blur_strength(value: float) -> void:
	_blur_strength = clampf(value, 0.0, 1.0)
	_apply_blur_strength(_blur_strength)

func fade_in(duration: float = -1.0) -> void:
	var time := fade_duration if duration < 0.0 else duration
	_start_fade(_blur_strength, 1.0, time)

func fade_out(duration: float = -1.0) -> void:
	var time := fade_duration if duration < 0.0 else duration
	await _start_fade(_blur_strength, 0.0, time)

func _apply_sigma() -> void:
	if not is_node_ready():
		return

	_horizontal_material.set_shader_parameter("sigma", sigma)
	_vertical_material.set_shader_parameter("sigma", sigma)

func _apply_blur_strength(value: float) -> void:
	if not is_node_ready():
		return

	_horizontal_material.set_shader_parameter("blur_strength", value)
	_vertical_material.set_shader_parameter("blur_strength", value)

func _start_fade(from_strength: float, to_strength: float, duration: float) -> void:
	if _fade_tween:
		_fade_tween.kill()

	if duration <= 0.0:
		set_blur_strength(to_strength)
		return

	_fade_tween = create_tween()
	_fade_tween.tween_method(set_blur_strength, from_strength, to_strength, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished
