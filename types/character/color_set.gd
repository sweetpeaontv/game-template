class_name ColorSet
extends RefCounted

enum ColorType {
	SKIN,
	BASE,
	ACCENT,
	DETAIL,
}

var colors: Dictionary = {
	ColorType.SKIN: "",
	ColorType.BASE: "",
	ColorType.ACCENT: "",
	ColorType.DETAIL: "",
}

var skin: String:
	get:
		return colors[ColorType.SKIN]
	set(value):
		colors[ColorType.SKIN] = value

var base: String:
	get:
		return colors[ColorType.BASE]
	set(value):
		colors[ColorType.BASE] = value

var accent: String:
	get:
		return colors[ColorType.ACCENT]
	set(value):
		colors[ColorType.ACCENT] = value

var detail: String:
	get:
		return colors[ColorType.DETAIL]
	set(value):
		colors[ColorType.DETAIL] = value

func _init(p_skin: String = "", p_base: String = "", p_accent: String = "", p_detail: String = ""):
	skin = p_skin
	base = p_base
	accent = p_accent
	detail = p_detail

func equals(other: ColorSet) -> bool:
	return (skin == other.skin 
		and base == other.base 
		and accent == other.accent 
		and detail == other.detail)

func copy() -> ColorSet:
	var out := ColorSet.new()
	out.colors = colors.duplicate()
	return out

func serialize() -> Dictionary:
	return {
		"skin": skin,
		"base": base,
		"accent": accent,
		"detail": detail,
	}

static func deserialize(d: Dictionary) -> ColorSet:
	return ColorSet.new(
		str(d.get("skin", "")),
		str(d.get("base", "")),
		str(d.get("accent", "")),
		str(d.get("detail", "")),
	)