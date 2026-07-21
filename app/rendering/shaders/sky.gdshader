shader_type sky;

// ---------------------------------------------------------
// Color uniforms — day and sunset variants, blended by sun height
// ---------------------------------------------------------
uniform vec3 sky_color_day : source_color = vec3(0.25, 0.55, 0.95);
uniform vec3 horizon_color_day : source_color = vec3(0.7, 0.85, 1.0);
uniform vec3 sky_color_sunset : source_color = vec3(0.25, 0.15, 0.45);
uniform vec3 horizon_color_sunset : source_color = vec3(1.0, 0.55, 0.35);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.8, 0.5);

uniform float sun_height : hint_range(-1.0, 1.0) = 0.5;
uniform float horizon_sharpness : hint_range(1.0, 12.0) = 4.0;

// ---------------------------------------------------------
// Cloud uniforms
// ---------------------------------------------------------
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.35;
uniform float cloud_scale : hint_range(0.5, 8.0) = 1.8;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.02;
uniform float cloud_height : hint_range(0.0, 1.0) = 0.2;
uniform vec3 cloud_color_day : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_color_sunset : source_color = vec3(1.0, 0.65, 0.55);
uniform vec3 cloud_shadow_color : source_color = vec3(0.55, 0.55, 0.65);

// ---------------------------------------------------------
// 3D gradient noise — organic blobs, no cubic lattice facets
// ---------------------------------------------------------
vec3 hash3(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	return mix(
		mix(
			mix(dot(hash3(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)),
				dot(hash3(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x),
			mix(dot(hash3(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)),
				dot(hash3(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x),
			u.y
		),
		mix(
			mix(dot(hash3(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)),
				dot(hash3(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x),
			mix(dot(hash3(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)),
				dot(hash3(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x),
			u.y
		),
		u.z
	);
}

// Few octaves — large soft shapes. Axis shuffle instead of mat3 (Godot
// only accepts mat3(vec3, vec3, vec3), not 9 floats).
float fbm3(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise3(p);
		p = p.yzx * 2.03 + vec3(1.7, 3.1, 2.3);
		amplitude *= 0.5;
	}
	return value * 0.5 + 0.5;
}

void sky() {
	float sunset_factor = 1.0 - smoothstep(0.0, 0.35, abs(sun_height));

	vec3 sky_col = mix(sky_color_day, sky_color_sunset, sunset_factor);
	vec3 horizon_col = mix(horizon_color_day, horizon_color_sunset, sunset_factor);

	float horizon_blend = pow(clamp(1.0 - abs(EYEDIR.y), 0.0, 1.0), horizon_sharpness);
	vec3 base_color = mix(sky_col, horizon_col, horizon_blend);

	float sun_amount = clamp(dot(EYEDIR, LIGHT0_DIRECTION * -1.0), 0.0, 1.0);
	vec3 col = base_color + sun_glow_color * pow(sun_amount, 64.0) * 1.5;
	col += sun_glow_color * pow(sun_amount, 8.0) * 0.15 * (0.5 + sunset_factor);

	if (EYEDIR.y > 0.0) {
		vec3 drift = vec3(TIME * cloud_speed, 0.0, TIME * cloud_speed * 0.55);
		vec3 cloud_p = EYEDIR * cloud_scale + drift;

		vec3 warp = vec3(
			noise3(cloud_p + vec3(0.0, 4.2, 1.1)),
			noise3(cloud_p + vec3(2.7, 0.0, 5.3)),
			noise3(cloud_p + vec3(1.4, 3.8, 0.0))
		);
		cloud_p += warp * 0.35;

		float density = fbm3(cloud_p);
		float density2 = fbm3(cloud_p * 0.92 + vec3(0.0, 0.15, 0.0));
		density = mix(density, density * density2, 0.35);

		float threshold = 1.0 - cloud_coverage;
		float cloud_mask = smoothstep(threshold - cloud_softness, threshold + cloud_softness, density);

		float altitude_fade = smoothstep(0.0, cloud_height, EYEDIR.y);
		altitude_fade *= altitude_fade;
		cloud_mask *= altitude_fade;

		vec3 cloud_col = mix(cloud_color_day, cloud_color_sunset, sunset_factor);
		float lit = smoothstep(0.35, 0.75, density2);
		cloud_col = mix(cloud_shadow_color, cloud_col, lit);
		cloud_col += sun_glow_color * pow(sun_amount, 4.0) * 0.12 * cloud_mask;

		col = mix(col, cloud_col, cloud_mask * 0.92);
	}

	COLOR = col;
}
