shader_type spatial;
render_mode unshaded, cull_disabled;

// 0 = idle (typing), 1 = wrong code / reject countdown, 2 = unlocked
uniform int screen_mode = 0;

uniform vec4 color_idle : source_color = vec4(0.02, 0.06, 0.02, 1.0);
uniform vec4 color_reject : source_color = vec4(0.9, 0.08, 0.08, 1.0);
uniform vec4 color_success : source_color = vec4(0.1, 0.85, 0.2, 1.0);
uniform float emissive_strength = 3.0;

void fragment() {
	vec4 c = color_idle;
	if (screen_mode == 1) {
		c = color_reject;
	} else if (screen_mode == 2) {
		c = color_success;
	}
	ALBEDO = c.rgb;
	EMISSION = c.rgb * emissive_strength;
	ALPHA = c.a;
}
