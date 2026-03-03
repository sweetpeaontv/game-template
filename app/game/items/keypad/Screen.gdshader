shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int digit_count = 4;
uniform float display_aspect = 3.0; // width / height of the whole display area
uniform float digit_spacing = 0.08; // fraction of a digit cell width
uniform float segment_thickness = 0.14; // fraction of digit cell height
uniform float segment_softness = 0.02; // anti-alias softness in UV space

uniform vec4 on_color : source_color = vec4(0.1, 1.0, 0.2, 1.0);
uniform vec4 off_color : source_color = vec4(0.02, 0.06, 0.02, 1.0);
uniform float emissive_strength = 6.0;

// Digits, left->right. Max 16 here; adjust if you need more.
uniform int digits[16];

float rect_mask(vec2 p, vec2 half_size, float softness) {
	// p is centered at rect center
	vec2 d = abs(p) - half_size;
	float outside = length(max(d, vec2(0.0)));
	// inside if d.x<=0 and d.y<=0; outside > 0
	return 1.0 - smoothstep(0.0, softness, outside);
}

float fit_rect_masked(vec2 uv, float target_aspect, out vec2 uv_fit, out vec2 fit_size) {
	// Fits a rect with aspect target_aspect into [0,1]x[0,1] while preserving aspect.
	// Returns mask (1 inside fitted rect, 0 outside), and uv_fit mapped into fitted rect 0..1.
	float container_aspect = 1.0; // UV assumed square domain; mesh UVs define container
	// We fit inside UV space. If your mesh UVs aren’t 0..1, fix that first.

	vec2 size = vec2(1.0, 1.0);
	vec2 fit = size;

	// If target is wider, height-limited; else width-limited.
	if (target_aspect > container_aspect) {
		fit.y = size.x / target_aspect;
	} else {
		fit.x = size.y * target_aspect;
	}

	vec2 offset = (size - fit) * 0.5;
	vec2 local = (uv - offset) / fit;

	uv_fit = local;
	fit_size = fit;

	// Mask: inside 0..1 in local space
	float m = step(0.0, local.x) * step(0.0, local.y) * step(local.x, 1.0) * step(local.y, 1.0);
	return m;
}

// 7-seg indexing we’ll use:
// 0 = top, 1 = upper-right, 2 = lower-right, 3 = bottom, 4 = lower-left, 5 = upper-left, 6 = middle
int seg_bits_for_digit(int d) {
	// Bitmask of segments on. 1<<seg_index
	// 0: top,1:ur,2:lr,3:bottom,4:ll,5:ul,6:mid
	// Standard 7-seg mapping.
	if (d == 0) return (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5);
	if (d == 1) return (1<<1)|(1<<2);
	if (d == 2) return (1<<0)|(1<<1)|(1<<6)|(1<<4)|(1<<3);
	if (d == 3) return (1<<0)|(1<<1)|(1<<6)|(1<<2)|(1<<3);
	if (d == 4) return (1<<5)|(1<<6)|(1<<1)|(1<<2);
	if (d == 5) return (1<<0)|(1<<5)|(1<<6)|(1<<2)|(1<<3);
	if (d == 6) return (1<<0)|(1<<5)|(1<<6)|(1<<2)|(1<<3)|(1<<4);
	if (d == 7) return (1<<0)|(1<<1)|(1<<2);
	if (d == 8) return (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6);
	if (d == 9) return (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<5)|(1<<6);
	return 0;
}

float segment_mask(vec2 p, vec2 a, vec2 b, float half_thick, float softness) {
	// Capsule-ish line segment from a to b with thickness.
	// p, a, b in digit-local space.
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	float dist = length(pa - ba * h);
	return 1.0 - smoothstep(half_thick, half_thick + softness, dist);
}

float seven_seg(vec2 uv_digit, int digit, float thick, float soft) {
	// uv_digit: 0..1 inside the digit cell (after spacing inset)
	// Define segment endpoints in this space.
	// Keep some margins so segments don’t touch edges.
	float m = 0.12;
	vec2 minp = vec2(m, m);
	vec2 maxp = vec2(1.0 - m, 1.0 - m);

	float y_top = maxp.y;
	float y_mid = 0.5;
	float y_bot = minp.y;

	float x_l = minp.x;
	float x_r = maxp.x;

	float half_thick = thick * 0.5;

	// Segment endpoints
	vec2 A0 = vec2(x_l, y_top); vec2 B0 = vec2(x_r, y_top); // top
	vec2 A6 = vec2(x_l, y_mid); vec2 B6 = vec2(x_r, y_mid); // middle
	vec2 A3 = vec2(x_l, y_bot); vec2 B3 = vec2(x_r, y_bot); // bottom

	vec2 A5 = vec2(x_l, y_mid); vec2 B5 = vec2(x_l, y_top); // upper-left
	vec2 A1 = vec2(x_r, y_mid); vec2 B1 = vec2(x_r, y_top); // upper-right
	vec2 A4 = vec2(x_l, y_bot); vec2 B4 = vec2(x_l, y_mid); // lower-left
	vec2 A2 = vec2(x_r, y_bot); vec2 B2 = vec2(x_r, y_mid); // lower-right

	int bits = seg_bits_for_digit(digit);

	float s = 0.0;
	if ((bits & (1<<0)) != 0) s = max(s, segment_mask(uv_digit, A0, B0, half_thick, soft));
	if ((bits & (1<<1)) != 0) s = max(s, segment_mask(uv_digit, A1, B1, half_thick, soft));
	if ((bits & (1<<2)) != 0) s = max(s, segment_mask(uv_digit, A2, B2, half_thick, soft));
	if ((bits & (1<<3)) != 0) s = max(s, segment_mask(uv_digit, A3, B3, half_thick, soft));
	if ((bits & (1<<4)) != 0) s = max(s, segment_mask(uv_digit, A4, B4, half_thick, soft));
	if ((bits & (1<<5)) != 0) s = max(s, segment_mask(uv_digit, A5, B5, half_thick, soft));
	if ((bits & (1<<6)) != 0) s = max(s, segment_mask(uv_digit, A6, B6, half_thick, soft));

	return s;
}

void fragment() {
	vec2 uv = UV;

	vec2 uv_fit;
	//vec2 fit_size;
	//float in_display = fit_rect_masked(uv, display_aspect, uv_fit, fit_size);
	float in_display = 1.0;

	// Build color assuming "off" by default, then overwrite via masks.
	vec3 col = off_color.rgb;
	float emit = 0.0;

	// Only evaluate digits when inside the fitted display rect
	if (in_display > 0.5) {
		float dc = float(max(digit_count, 1));
		float cell_w = 1.0 / dc;

		float x = uv_fit.x;
		int idx = int(floor(x / cell_w));
		idx = clamp(idx, 0, digit_count - 1);

		float lx = (x - float(idx) * cell_w) / cell_w;
		vec2 uv_cell = vec2(lx, uv_fit.y);

		float inset = digit_spacing * 0.5;
		vec2 uv_digit = (uv_cell - vec2(inset, 0.0)) / vec2(1.0 - digit_spacing, 1.0);

		float in_digit = step(0.0, uv_digit.x) * step(uv_digit.x, 1.0) * step(0.0, uv_digit.y) * step(uv_digit.y, 1.0);

		int d = digits[idx];
		d = clamp(d, 0, 9);

		float seg = 0.0;
		if (in_digit > 0.5) {
			seg = seven_seg(uv_digit, d, segment_thickness, segment_softness);
		}
		
		seg *= in_digit;
		seg = clamp(seg, 0.0, 1.0);

		col = mix(off_color.rgb, on_color.rgb, seg);
		emit = emissive_strength * seg;
	}

	ALBEDO = col;
	EMISSION = on_color.rgb * emit;
	ALPHA = 1.0;
}