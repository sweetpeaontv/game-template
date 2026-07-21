class_name EntityTypeHandler
extends RefCounted

const SCRIPT_NAME := "EntityTypeHandler"

func validate_spawn(_data: Dictionary) -> String:
	SweetLogger.warning("validate_spawn called on default class {0}", [SCRIPT_NAME], SCRIPT_NAME, "apply")
	return "ok"

func validate_despawn(_data: Dictionary) -> String:
	SweetLogger.warning("validate_despawn called on default class {0}", [SCRIPT_NAME], SCRIPT_NAME, "apply")
	return "ok"

func apply_spawn(_data: Dictionary) -> void:
	SweetLogger.error("apply_spawn called on default class {0}", [SCRIPT_NAME], SCRIPT_NAME, "apply")
	return

func apply_despawn(_data: Dictionary) -> void:
	SweetLogger.error("apply_despawn called on default class {0}", [SCRIPT_NAME], SCRIPT_NAME, "apply")
	return