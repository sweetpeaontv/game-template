shader_type canvas_item;

uniform sampler2D source_texture : filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform bool use_screen_texture = false;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform float sigma : hint_range(0.1, 16.0) = 2.0;
uniform float blur_strength : hint_range(0.0, 1.0) = 1.0;
uniform int radius : hint_range(0, 32) = 0;

const int MAX_RADIUS = 32;

vec4 sample_tex(sampler2D tex, vec2 sample_uv) {
	if (use_screen_texture) {
		return texture(SCREEN_TEXTURE, sample_uv);
	}

	return texture(tex, sample_uv);
}

vec4 gaussian_blur_pass(sampler2D tex, vec2 uv, vec2 pixel_step, float blur_sigma, int blur_radius) {
	vec4 color = vec4(0.0);
	float weight_sum = 0.0;

	for (int i = -MAX_RADIUS; i <= MAX_RADIUS; i++) {
		if (abs(i) > blur_radius) {
			continue;
		}

		float offset = float(i);
		float weight = exp(-(offset * offset) / (2.0 * blur_sigma * blur_sigma));
		vec2 sample_uv = uv + pixel_step * offset;

		color += sample_tex(tex, sample_uv) * weight;
		weight_sum += weight;
	}

	return color / weight_sum;
}

void fragment() {
	vec2 uv = use_screen_texture ? SCREEN_UV : UV;
	vec2 texel_size = use_screen_texture
		? vec2(1.0) / vec2(textureSize(SCREEN_TEXTURE, 0))
		: vec2(1.0) / vec2(textureSize(source_texture, 0));
	vec2 pixel_step = blur_direction * texel_size;
	float effective_sigma = max(sigma * blur_strength, 0.001);
	int blur_radius = radius > 0 ? radius : int(ceil(effective_sigma * 3.0));
	blur_radius = min(blur_radius, MAX_RADIUS);

	COLOR = gaussian_blur_pass(source_texture, uv, pixel_step, effective_sigma, blur_radius);
}
