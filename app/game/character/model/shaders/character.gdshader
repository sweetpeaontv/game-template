shader_type spatial;

uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform vec2 skin_uv = vec2(0.0);
uniform vec2 base_uv = vec2(0.0);
uniform vec2 accent_uv = vec2(0.0);
uniform vec2 detail_uv = vec2(0.0);

void fragment() {
	vec2 uv = UV;
	
	uv += skin_uv * COLOR.r;
	uv += base_uv * COLOR.g;
	uv += accent_uv * COLOR.b;
	uv += detail_uv * COLOR.a;
	
	ALBEDO = texture(palette, uv).rgb;
}