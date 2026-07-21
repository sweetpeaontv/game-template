extends DirectionalLight3D

## Drives the procedural sky shader's `sun_height` uniform (and this light's
## own energy/color) from a single time-of-day value. Attach this script
## directly to your DirectionalLight3D.

@export var sky_material: ShaderMaterial
@export var autoplay: bool = true
@export var day_length_seconds: float = 120.0

## 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
@export_range(0.0, 1.0) var time_of_day: float = 0.3

@export_group("Light response")
@export var noon_energy: float = 1.2
@export var sunset_energy: float = 0.6
@export var night_energy: float = 0.05
@export var noon_color: Color = Color(1.0, 0.98, 0.92)
@export var sunset_color: Color = Color(1.0, 0.6, 0.35)

func _process(delta: float) -> void:
	if autoplay:
		time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	_apply_time_of_day()

func _apply_time_of_day() -> void:
	# Map time_of_day (0-1) to a full rotation, with noon at the top of the arc.
	var angle := time_of_day * TAU
	rotation.x = angle - PI * 0.5

	# Direction the light travels is -Z of its own transform, so the
	# direction TOWARD the sun is +Z. Its height above the horizon is
	# just the y component of that vector.
	var sun_dir := global_transform.basis.z
	var height := sun_dir.y

	if sky_material:
		sky_material.set_shader_parameter("sun_height", height)

	_update_light_intensity(height)

func _update_light_intensity(height: float) -> void:
	# How close we are to the horizon (0 = at horizon, 1 = straight up/down).
	var sunset_amount = 1.0 - clamp(abs(height) / 0.35, 0.0, 1.0)

	if height <= 0.0:
		# Sun is below the horizon: fade toward night, tinting through sunset
		# colors on the way down rather than snapping straight to black.
		var night_amount = clamp(-height / 0.2, 0.0, 1.0)
		light_energy = lerp(sunset_energy, night_energy, night_amount)
		light_color = sunset_color.lerp(noon_color, 0.0).lerp(Color.BLACK, night_amount * 0.5)
	else:
		light_energy = lerp(sunset_energy, noon_energy, 1.0 - sunset_amount)
		light_color = sunset_color.lerp(noon_color, 1.0 - sunset_amount)

## Call this from elsewhere (e.g. a scene manager) to jump straight to a
## specific moment instead of waiting for autoplay to get there.
func set_time_of_day(value: float) -> void:
	time_of_day = clamp(value, 0.0, 1.0)
	_apply_time_of_day()
