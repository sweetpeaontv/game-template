shader_type spatial;

uniform sampler2D palette : source_color;
uniform vec2 skin_offset = vec2(0.2, 0.2);
uniform vec2 base_offset = vec2(0.1, 0.1);
uniform vec2 accent_offset = vec2(0.3, 0.3);
uniform vec2 detail_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV;
	
	uv += skin_offset * COLOR.r;
	uv += base_offset * COLOR.g;
	uv += accent_offset * COLOR.b;
	uv += detail_offset * COLOR.a;
	
	ALBEDO = texture(palette, uv).rgb;
}