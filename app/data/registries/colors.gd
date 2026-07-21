extends RefCounted
class_name ColorsRegistry

const COLOR_TEXTURE_PATH: String = "res://app/game/character/model/textures/Main_colors.png"

var retro_color_uvs: Dictionary = {
	# RETRO STANDARD
	## ROW 1
	"retro_stan_c0r0_burnt_sienna": Vector2(0.417323, 0.102362),
	"retro_stan_c1r0_terra_cotta": Vector2(0.425197, 0.102362),
	"retro_stan_c2r0_sand": Vector2(0.433071, 0.102362),
	"retro_stan_c3r0_desaturated_cyan": Vector2(0.440945, 0.102362),
	"retro_stan_c4r0_dark_brown": Vector2(0.448819, 0.102362),
	## ROW 2
	"retro_stan_c0r1_indian_red": Vector2(0.417323, 0.110236),
	"retro_stan_c1r1_caramel_orange": Vector2(0.425197, 0.110236),
	"retro_stan_c2r1_pale_yellow": Vector2(0.433071, 0.110236),
	"retro_stan_c3r1_dusty_teal": Vector2(0.440945, 0.110236),
	"retro_stan_c4r1_very_dark_brown": Vector2(0.448819, 0.110236),
	## ROW 3
	"retro_stan_c0r2_dark_brown": Vector2(0.417323, 0.118110),
	"retro_stan_c1r2_rust": Vector2(0.425197, 0.118110),
	"retro_stan_c2r2_light_khaki": Vector2(0.433071, 0.118110),
	"retro_stan_c3r2_vivid_orange": Vector2(0.440945, 0.118110),
	"retro_stan_c4r2_teal": Vector2(0.448819, 0.118110),
	## ROW 4
	"retro_stan_c0r3_charcoal_blue": Vector2(0.417323, 0.125984),
	"retro_stan_c1r3_persimmon": Vector2(0.425197, 0.125984),
	"retro_stan_c2r3_warm_gray": Vector2(0.433071, 0.125984),
	"retro_stan_c3r3_steel_blue": Vector2(0.440945, 0.125984),
	"retro_stan_c4r3_forest_green": Vector2(0.448819, 0.125984),
	## ROW 5
	"retro_stan_c0r4_dark_gray": Vector2(0.417323, 0.133858),
	"retro_stan_c1r4_desaturated_green": Vector2(0.425197, 0.133858),
	"retro_stan_c2r4_tan": Vector2(0.433071, 0.133858),
	"retro_stan_c3r4_copper": Vector2(0.440945, 0.133858),
	"retro_stan_c4r4_burnt_umber": Vector2(0.448819, 0.133858),
	## ROW 6
	"retro_stan_c0r5_dark_gray_blue": Vector2(0.417323, 0.141732),
	"retro_stan_c1r5_muted_teal": Vector2(0.425197, 0.141732),
	"retro_stan_c2r5_light_peach": Vector2(0.433071, 0.141732),
	"retro_stan_c3r5_burnt_orange": Vector2(0.440945, 0.141732),
	"retro_stan_c4r5_oxide_red": Vector2(0.448819, 0.141732),
	## ROW 7
	"retro_stan_c0r6_oxblood": Vector2(0.417323, 0.149606),
	"retro_stan_c1r6_brick_red": Vector2(0.425197, 0.149606),
	"retro_stan_c2r6_khaki": Vector2(0.433071, 0.149606),
	"retro_stan_c3r6_taupe": Vector2(0.440945, 0.149606),
	"retro_stan_c4r6_dark_charcoal": Vector2(0.448819, 0.149606),
	## ROW 8
	"retro_stan_c0r7_desaturated_teal": Vector2(0.417323, 0.157480),
	"retro_stan_c1r7_beige": Vector2(0.425197, 0.157480),
	"retro_stan_c2r7_mustard": Vector2(0.433071, 0.157480),
	"retro_stan_c3r7_burnt_sienna": Vector2(0.440945, 0.157480),
	"retro_stan_c4r7_dark_brown": Vector2(0.448819, 0.157480),
	## ROW 9
	"retro_stan_c0r8_dark_slate": Vector2(0.417323, 0.165354),
	"retro_stan_c1r8_muted_cyan": Vector2(0.425197, 0.165354),
	"retro_stan_c2r8_light_rose": Vector2(0.433071, 0.165354),
	"retro_stan_c3r8_dusty_pink": Vector2(0.440945, 0.165354),
	"retro_stan_c4r8_muted_red_brown": Vector2(0.448819, 0.165354),
	## ROW 10
	"retro_stan_c0r9_sandy_orange": Vector2(0.417323, 0.173228),
	"retro_stan_c1r9_clay_red": Vector2(0.425197, 0.173228),
	"retro_stan_c2r9_muted_red": Vector2(0.433071, 0.173228),
	"retro_stan_c3r9_plum": Vector2(0.440945, 0.173228),
	"retro_stan_c4r9_deep_purple": Vector2(0.448819, 0.173228),
 
	# RETRO PLASTIC
	## ROW 1
	"retro_plast_c0r0_burnt_sienna": Vector2(0.417323, 0.204724),
	"retro_plast_c1r0_terra_cotta": Vector2(0.425197, 0.204724),
	"retro_plast_c2r0_sand": Vector2(0.433071, 0.204724),
	"retro_plast_c3r0_desaturated_cyan": Vector2(0.440945, 0.204724),
	"retro_plast_c4r0_dark_brown": Vector2(0.448819, 0.204724),
	## ROW 2
	"retro_plast_c0r1_indian_red": Vector2(0.417323, 0.212598),
	"retro_plast_c1r1_caramel_orange": Vector2(0.425197, 0.212598),
	"retro_plast_c2r1_pale_yellow": Vector2(0.433071, 0.212598),
	"retro_plast_c3r1_dusty_teal": Vector2(0.440945, 0.212598),
	"retro_plast_c4r1_very_dark_brown": Vector2(0.448819, 0.212598),
	## ROW 3
	"retro_plast_c0r2_dark_brown": Vector2(0.417323, 0.220472),
	"retro_plast_c1r2_rust": Vector2(0.425197, 0.220472),
	"retro_plast_c2r2_light_khaki": Vector2(0.433071, 0.220472),
	"retro_plast_c3r2_vivid_orange": Vector2(0.440945, 0.220472),
	"retro_plast_c4r2_teal": Vector2(0.448819, 0.220472),
	## ROW 4
	"retro_plast_c0r3_charcoal_blue": Vector2(0.417323, 0.228346),
	"retro_plast_c1r3_persimmon": Vector2(0.425197, 0.228346),
	"retro_plast_c2r3_warm_gray": Vector2(0.433071, 0.228346),
	"retro_plast_c3r3_steel_blue": Vector2(0.440945, 0.228346),
	"retro_plast_c4r3_forest_green": Vector2(0.448819, 0.228346),
	## ROW 5
	"retro_plast_c0r4_dark_gray": Vector2(0.417323, 0.236220),
	"retro_plast_c1r4_desaturated_green": Vector2(0.425197, 0.236220),
	"retro_plast_c2r4_tan": Vector2(0.433071, 0.236220),
	"retro_plast_c3r4_copper": Vector2(0.440945, 0.236220),
	"retro_plast_c4r4_burnt_umber": Vector2(0.448819, 0.236220),
	## ROW 6
	"retro_plast_c0r5_dark_gray_blue": Vector2(0.417323, 0.244094),
	"retro_plast_c1r5_muted_teal": Vector2(0.425197, 0.244094),
	"retro_plast_c2r5_light_peach": Vector2(0.433071, 0.244094),
	"retro_plast_c3r5_burnt_orange": Vector2(0.440945, 0.244094),
	"retro_plast_c4r5_oxide_red": Vector2(0.448819, 0.244094),
	## ROW 7
	"retro_plast_c0r6_oxblood": Vector2(0.417323, 0.251969),
	"retro_plast_c1r6_brick_red": Vector2(0.425197, 0.251969),
	"retro_plast_c2r6_khaki": Vector2(0.433071, 0.251969),
	"retro_plast_c3r6_taupe": Vector2(0.440945, 0.251969),
	"retro_plast_c4r6_dark_charcoal": Vector2(0.448819, 0.251969),
	## ROW 8
	"retro_plast_c0r7_desaturated_teal": Vector2(0.417323, 0.259843),
	"retro_plast_c1r7_beige": Vector2(0.425197, 0.259843),
	"retro_plast_c2r7_mustard": Vector2(0.433071, 0.259843),
	"retro_plast_c3r7_burnt_sienna": Vector2(0.440945, 0.259843),
	"retro_plast_c4r7_dark_brown": Vector2(0.448819, 0.259843),
	## ROW 9
	"retro_plast_c0r8_dark_slate": Vector2(0.417323, 0.267717),
	"retro_plast_c1r8_muted_cyan": Vector2(0.425197, 0.267717),
	"retro_plast_c2r8_light_rose": Vector2(0.433071, 0.267717),
	"retro_plast_c3r8_dusty_pink": Vector2(0.440945, 0.267717),
	"retro_plast_c4r8_muted_red_brown": Vector2(0.448819, 0.267717),
	## ROW 10
	"retro_plast_c0r9_sandy_orange": Vector2(0.417323, 0.275591),
	"retro_plast_c1r9_clay_red": Vector2(0.425197, 0.275591),
	"retro_plast_c2r9_muted_red": Vector2(0.433071, 0.275591),
	"retro_plast_c3r9_plum": Vector2(0.440945, 0.275591),
	"retro_plast_c4r9_deep_purple": Vector2(0.448819, 0.275591),
 
	# RETRO METAL
	## ROW 1
	"retro_met_c0r0_burnt_sienna": Vector2(0.417323, 0.307087),
	"retro_met_c1r0_terra_cotta": Vector2(0.425197, 0.307087),
	"retro_met_c2r0_sand": Vector2(0.433071, 0.307087),
	"retro_met_c3r0_desaturated_cyan": Vector2(0.440945, 0.307087),
	"retro_met_c4r0_dark_brown": Vector2(0.448819, 0.307087),
	## ROW 2
	"retro_met_c0r1_indian_red": Vector2(0.417323, 0.314961),
	"retro_met_c1r1_caramel_orange": Vector2(0.425197, 0.314961),
	"retro_met_c2r1_pale_yellow": Vector2(0.433071, 0.314961),
	"retro_met_c3r1_dusty_teal": Vector2(0.440945, 0.314961),
	"retro_met_c4r1_very_dark_brown": Vector2(0.448819, 0.314961),
	## ROW 3
	"retro_met_c0r2_dark_brown": Vector2(0.417323, 0.322835),
	"retro_met_c1r2_rust": Vector2(0.425197, 0.322835),
	"retro_met_c2r2_light_khaki": Vector2(0.433071, 0.322835),
	"retro_met_c3r2_vivid_orange": Vector2(0.440945, 0.322835),
	"retro_met_c4r2_teal": Vector2(0.448819, 0.322835),
	## ROW 4
	"retro_met_c0r3_charcoal_blue": Vector2(0.417323, 0.330709),
	"retro_met_c1r3_persimmon": Vector2(0.425197, 0.330709),
	"retro_met_c2r3_warm_gray": Vector2(0.433071, 0.330709),
	"retro_met_c3r3_steel_blue": Vector2(0.440945, 0.330709),
	"retro_met_c4r3_forest_green": Vector2(0.448819, 0.330709),
	## ROW 5
	"retro_met_c0r4_dark_gray": Vector2(0.417323, 0.338583),
	"retro_met_c1r4_desaturated_green": Vector2(0.425197, 0.338583),
	"retro_met_c2r4_tan": Vector2(0.433071, 0.338583),
	"retro_met_c3r4_copper": Vector2(0.440945, 0.338583),
	"retro_met_c4r4_burnt_umber": Vector2(0.448819, 0.338583),
	## ROW 6
	"retro_met_c0r5_dark_gray_blue": Vector2(0.417323, 0.346457),
	"retro_met_c1r5_muted_teal": Vector2(0.425197, 0.346457),
	"retro_met_c2r5_light_peach": Vector2(0.433071, 0.346457),
	"retro_met_c3r5_burnt_orange": Vector2(0.440945, 0.346457),
	"retro_met_c4r5_oxide_red": Vector2(0.448819, 0.346457),
	## ROW 7
	"retro_met_c0r6_oxblood": Vector2(0.417323, 0.354331),
	"retro_met_c1r6_brick_red": Vector2(0.425197, 0.354331),
	"retro_met_c2r6_khaki": Vector2(0.433071, 0.354331),
	"retro_met_c3r6_taupe": Vector2(0.440945, 0.354331),
	"retro_met_c4r6_dark_charcoal": Vector2(0.448819, 0.354331),
	## ROW 8
	"retro_met_c0r7_desaturated_teal": Vector2(0.417323, 0.362205),
	"retro_met_c1r7_beige": Vector2(0.425197, 0.362205),
	"retro_met_c2r7_mustard": Vector2(0.433071, 0.362205),
	"retro_met_c3r7_burnt_sienna": Vector2(0.440945, 0.362205),
	"retro_met_c4r7_dark_brown": Vector2(0.448819, 0.362205),
	## ROW 9
	"retro_met_c0r8_dark_slate": Vector2(0.417323, 0.370079),
	"retro_met_c1r8_muted_cyan": Vector2(0.425197, 0.370079),
	"retro_met_c2r8_light_rose": Vector2(0.433071, 0.370079),
	"retro_met_c3r8_dusty_pink": Vector2(0.440945, 0.370079),
	"retro_met_c4r8_muted_red_brown": Vector2(0.448819, 0.370079),
	## ROW 10
	"retro_met_c0r9_sandy_orange": Vector2(0.417323, 0.377953),
	"retro_met_c1r9_clay_red": Vector2(0.425197, 0.377953),
	"retro_met_c2r9_muted_red": Vector2(0.433071, 0.377953),
	"retro_met_c3r9_plum": Vector2(0.440945, 0.377953),
	"retro_met_c4r9_deep_purple": Vector2(0.448819, 0.377953),
}

const PALETTES := {
	"skin": ["retro_stan_c0r0_burnt_sienna", "retro_stan_c4r0_dark_brown", "retro_stan_c3r1_dusty_teal"],
	"hair": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"hat": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"eyeshadow": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"lips": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"clothing": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"beard": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
	"glasses": ["retro_stan_c0r3_charcoal_blue", "retro_stan_c3r3_steel_blue", "retro_stan_c3r1_dusty_teal"],
}

var _color_cache: Dictionary = {}
var _cache_built: bool = false

func get_color(key: String) -> Color:
	if not _cache_built:
		_build_color_cache()
	return _color_cache.get(key, Color.MAGENTA)

func _build_color_cache() -> void:
	var tex: Texture2D = load(COLOR_TEXTURE_PATH)
	if tex == null:
		push_error("ColorsRegistry: failed to load %s" % COLOR_TEXTURE_PATH)
		_cache_built = true
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("ColorsRegistry: texture has no CPU image")
		_cache_built = true
		return
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	for key in retro_color_uvs:
		var uv: Vector2 = retro_color_uvs[key]
		var px: int = clampi(int(uv.x * w), 0, w - 1)
		var py: int = clampi(int(uv.y * h), 0, h - 1)
		_color_cache[key] = img.get_pixel(px, py)
	_cache_built = true

var color_slots: Dictionary = {
	ColorSet.ColorType.SKIN: [
		"retro_stan_c2r1_pale_yellow",
		"retro_stan_c1r7_beige",
		"retro_stan_c2r4_tan",
		"retro_stan_c2r2_light_khaki",
		"retro_stan_c2r6_khaki",
		"retro_plast_c2r5_light_peach",
		"retro_plast_c2r8_light_rose",
		"retro_plast_c1r7_beige",
		"retro_plast_c2r4_tan",
		"retro_plast_c2r2_light_khaki",
		"retro_met_c2r5_light_peach",
		"retro_met_c2r8_light_rose",
		"retro_met_c1r7_beige",
		"retro_met_c2r4_tan",
		"retro_met_c2r2_light_khaki",
		"retro_stan_c1r1_caramel_orange",
		"retro_plast_c1r1_caramel_orange",
		"retro_met_c1r1_caramel_orange",
		"retro_stan_c0r1_indian_red",
		"retro_plast_c0r1_indian_red",
	],
	ColorSet.ColorType.BASE: [
		"retro_stan_c0r3_charcoal_blue",
		"retro_stan_c3r3_steel_blue",
		"retro_stan_c3r1_dusty_teal",
		"retro_stan_c1r4_desaturated_green",
		"retro_stan_c4r3_forest_green",
		"retro_plast_c0r3_charcoal_blue",
		"retro_plast_c3r3_steel_blue",
		"retro_plast_c3r1_dusty_teal",
		"retro_plast_c1r4_desaturated_green",
		"retro_plast_c4r3_forest_green",
		"retro_met_c0r3_charcoal_blue",
		"retro_met_c3r3_steel_blue",
		"retro_met_c3r1_dusty_teal",
		"retro_met_c1r4_desaturated_green",
		"retro_met_c4r3_forest_green",
		"retro_stan_c0r8_dark_slate",
		"retro_plast_c0r8_dark_slate",
		"retro_met_c0r8_dark_slate",
		"retro_stan_c1r8_muted_cyan",
		"retro_met_c1r8_muted_cyan",
	],
	ColorSet.ColorType.ACCENT: [
		"retro_stan_c1r3_persimmon",
		"retro_stan_c1r2_rust",
		"retro_stan_c3r2_vivid_orange",
		"retro_stan_c3r5_burnt_orange",
		"retro_stan_c3r4_copper",
		"retro_plast_c1r3_persimmon",
		"retro_plast_c1r2_rust",
		"retro_plast_c3r2_vivid_orange",
		"retro_plast_c3r5_burnt_orange",
		"retro_plast_c3r4_copper",
		"retro_met_c1r3_persimmon",
		"retro_met_c1r2_rust",
		"retro_met_c3r2_vivid_orange",
		"retro_met_c3r5_burnt_orange",
		"retro_met_c3r4_copper",
		"retro_stan_c0r0_burnt_sienna",
		"retro_plast_c0r0_burnt_sienna",
		"retro_met_c0r0_burnt_sienna",
		"retro_stan_c1r0_terra_cotta",
		"retro_met_c1r0_terra_cotta",
	],
	ColorSet.ColorType.DETAIL: [
		"retro_stan_c4r9_deep_purple",
		"retro_stan_c3r9_plum",
		"retro_stan_c0r6_oxblood",
		"retro_stan_c4r6_dark_charcoal",
		"retro_stan_c4r1_very_dark_brown",
		"retro_plast_c4r9_deep_purple",
		"retro_plast_c3r9_plum",
		"retro_plast_c0r6_oxblood",
		"retro_plast_c4r6_dark_charcoal",
		"retro_plast_c4r1_very_dark_brown",
		"retro_met_c4r9_deep_purple",
		"retro_met_c3r9_plum",
		"retro_met_c0r6_oxblood",
		"retro_met_c4r6_dark_charcoal",
		"retro_met_c4r1_very_dark_brown",
		"retro_stan_c4r2_teal",
		"retro_plast_c4r2_teal",
		"retro_met_c4r2_teal",
		"retro_stan_c4r5_oxide_red",
		"retro_met_c4r5_oxide_red",
	],
}