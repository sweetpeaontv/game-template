shader_type spatial;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
