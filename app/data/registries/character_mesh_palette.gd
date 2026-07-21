class_name CharacterMeshPaletteRegistry
extends RefCounted

const SLOT_DEFAULTS := {
	CharacterConfig.PartSlot.HEAD: "head",
	CharacterConfig.PartSlot.HAIR: "hair",
	CharacterConfig.PartSlot.BEARD: "beard",
	CharacterConfig.PartSlot.TORSO: "clothing",
	CharacterConfig.PartSlot.LEGS: "clothing",
	CharacterConfig.PartSlot.SHOES: "clothing",
	CharacterConfig.PartSlot.GLASSES: "glasses",
}

const PRESETS := {
	"clothing": [
		{ "color_type": ColorSet.ColorType.BASE, "label": "Main", "palette": "clothing" },
		{ "color_type": ColorSet.ColorType.ACCENT, "label": "Accent", "palette": "clothing" },
		{ "color_type": ColorSet.ColorType.DETAIL, "label": "Detail", "palette": "clothing" },
	],
	"skin": [
		{ "color_type": ColorSet.ColorType.SKIN, "label": "Skin", "palette": "skin" },
	],
	"head": [
		{ "color_type": ColorSet.ColorType.ACCENT, "label": "Eyeshadow", "palette": "eyeshadow" },
		{ "color_type": ColorSet.ColorType.DETAIL, "label": "Lips", "palette": "lips" },
	],
	"hair": [
		{ "color_type": ColorSet.ColorType.BASE, "label": "Hair", "palette": "hair" },
	],
	"hat": [
		{ "color_type": ColorSet.ColorType.BASE, "label": "Hair", "palette": "hair" },
		{ "color_type": ColorSet.ColorType.ACCENT, "label": "Accent", "palette": "hat" },
		{ "color_type": ColorSet.ColorType.DETAIL, "label": "Detail", "palette": "hat" },
	],
	"beard": [
		{ "color_type": ColorSet.ColorType.BASE, "label": "Beard", "palette": "beard" },
	],
	"glasses": [
		{ "color_type": ColorSet.ColorType.BASE, "label": "Glasses", "palette": "glasses" },
	],
}

const MESH_OVERRIDES := {
	"m_torso__shirtless_0": "skin",
	"m_legs__pantless_0": "skin",
	"m_shoes__bare-feet_0": "skin",
}

func get_preset(slot: CharacterConfig.PartSlot, mesh_name: String) -> Array:
	return PRESETS[_resolve_preset_key(slot, mesh_name)]

func _resolve_preset_key(slot: CharacterConfig.PartSlot, mesh_name: String) -> String:
	if MESH_OVERRIDES.has(mesh_name):
		return MESH_OVERRIDES[mesh_name]
	var mesh_type := _mesh_type_token(mesh_name)
	if PRESETS.has(mesh_type):
		return mesh_type
	return SLOT_DEFAULTS[slot]

## First segment after [code]m_[/code]/[code]f_[/code]: [code]m_hat__cap_1[/code] → [code]hat[/code], [code]m_hat_5[/code] → [code]hat[/code].
func _mesh_type_token(mesh_name: String) -> String:
	if mesh_name.is_empty():
		return ""
	var rest := mesh_name
	if rest.begins_with("m_") or rest.begins_with("f_"):
		rest = rest.substr(2)
	var sep := rest.find("__")
	if sep == -1:
		sep = rest.find("_")
	if sep == -1:
		return rest
	return rest.substr(0, sep)
