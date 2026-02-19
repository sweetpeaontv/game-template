// res://app/game/items/keypad/display/SevenSegDisplay.gdshader
shader_type spatial;
render_mode unshaded;

uniform int digit_count = 4;
uniform int masks[8]; // up to 8 digits (7-bit mask per digit)
uniform float intensity = 3.0;
uniform float glow = 0.5;
uniform float thickness = 0.08;
uniform float gap = 0.12;

float rect_sdf(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float seg(vec2 uv, vec2 center, vec2 half_size, float r) {
	float d = rect_sdf(uv - center, half_size) - r;
	return 1.0 - smoothstep(0.0, 0.01, d);
}

// Segment layout in local digit UV (0..1). a top, b top-right, c bot-right, d bottom, e bot-left, f top-left, g middle
float draw_digit(vec2 duv, int mask) {
	// normalize into -1..1 for nicer sizing
	vec2 p = duv * 2.0 - 1.0;

	float t = thickness;
	float r = t * 0.35;

	float a = seg(p, vec2(0.0, 0.80), vec2(0.60, t), r);
	float d = seg(p, vec2(0.0, -0.80), vec2(0.60, t), r);
	float g = seg(p, vec2(0.0, 0.00), vec2(0.60, t), r);

	float f = seg(p, vec2(-0.70, 0.40), vec2(t, 0.50), r);
	float b = seg(p, vec2(0.70, 0.40), vec2(t, 0.50), r);
	float e = seg(p, vec2(-0.70, -0.40), vec2(t, 0.50), r);
	float c = seg(p, vec2(0.70, -0.40), vec2(t, 0.50), r);

	float outv = 0.0;
	if ((mask & 1) != 0) outv += a;		// bit0: a
	if ((mask & 2) != 0) outv += b;		// bit1: b
	if ((mask & 4) != 0) outv += c;		// bit2: c
	if ((mask & 8) != 0) outv += d;		// bit3: d
	if ((mask & 16) != 0) outv += e;	// bit4: e
	if ((mask & 32) != 0) outv += f;	// bit5: f
	if ((mask & 64) != 0) outv += g;	// bit6: g

	return clamp(outv, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;

	// split UV into digit slots horizontally
	float dc = float(digit_count);
	float slot_w = 1.0 / dc;

	int idx = int(floor(uv.x / slot_w));
	idx = clamp(idx, 0, digit_count - 1);

	// local digit uv
	float x0 = float(idx) * slot_w;
	vec2 duv = vec2((uv.x - x0) / slot_w, uv.y);

	// apply padding (gap) inside each slot
	duv = (duv - 0.5) * (1.0 - gap) + 0.5;

	int mask = masks[idx];
	float v = draw_digit(duv, mask);

	// emissive “LED” look
	vec3 on_col = vec3(1.0, 0.15, 0.05);
	vec3 base = on_col * v * intensity;

	ALBEDO = vec3(0.0);
	EMISSION = base + base * glow * v;
	ALPHA = 1.0;
}