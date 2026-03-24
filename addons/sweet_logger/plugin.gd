@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SweetLogger"
const AUTOLOAD_PATH := "res://addons/sweet_logger/SweetLogger.gd"

func _enter_tree() -> void:
	var key := "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
