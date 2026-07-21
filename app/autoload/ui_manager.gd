# app/autoload/UIManager.gd
extends Node
"""
UIManager - Manages dynamic and contextual UI elements

Purpose:
	Handles all UI/HUD overlay loading, showing, and hiding. This manager
	keeps a registry of available UI scenes and can dynamically instantiate
	and display them as needed. Works similarly to SceneManager but for
	overlay UI elements rather than full scene transitions.

Responsibilities:
	- Maintain a lookup table of UI names → PackedScene paths
	- Show/hide UI elements by name with optional data parameters
	- Track active UI instances
	- Manage modal backdrop layers (blur, dim, etc.) independently of UI screens
	- Emit signals when UI elements are shown/hidden
"""

signal ui_shown(ui_name: String)
signal ui_hidden(ui_name: String)

enum UIContainer { MENU, HUD, BACKDROP, OVERLAY }

# Registry of all available UI scenes
var _ui_scenes := {
	"MainMenu": {
		"scene": preload("res://app/ui/screens/main/main_menu.tscn"),
		"container": UIContainer.MENU,
	},
	"Settings": {
		"scene": preload("res://app/ui/overlays/settings/settings.tscn"),
		"container": UIContainer.OVERLAY,
	},
	"MainMenuCustomizer": {
		"scene": preload("res://app/ui/overlays/customizer/menu/main_menu_customizer.tscn"),
		"container": UIContainer.OVERLAY,
	},
	"InGameCustomizer": {
		"scene": preload("res://app/ui/overlays/customizer/ingame/ingame_customizer.tscn"),
		"container": UIContainer.OVERLAY,
	},
	"EscMenu": {
		"scene": preload("res://app/ui/screens/esc-menu/esc_menu.tscn"),
		"container": UIContainer.OVERLAY,
	},
	"PickupHUD": {
		"scene": preload("res://app/ui/hud/contextual/pickup-hud/pickup_hud.tscn"),
		"container": UIContainer.HUD,
	},
	"Crosshair": {
		"scene": preload("res://app/ui/hud/crosshair/crosshair.tscn"),
		"container": UIContainer.HUD,
	},
}

# Registry of modal backdrop effects, separate from interactive UI screens.
var _backdrops := {
	"world_blur": {
		"scene": preload("res://app/rendering/components/gaussian-blur/gaussian_blur.tscn"),
		"capture": "world_live",
		"sigma": 10.0,
		"fade_duration": 0.1,
	},
}

var _active_ui := {}
var _active_backdrop_instances := {}
var _backdrop_ref_counts := {}

var _ui_containers: Dictionary = {
	UIContainer.MENU: null,
	UIContainer.HUD: null,
	UIContainer.BACKDROP: null,
	UIContainer.OVERLAY: null,
}

# INIT
#===================================================================================#
func _ready() -> void:
	pass
#===================================================================================#

# PUBLIC API
#===================================================================================#
func set_container(container_type: UIContainer, container: Node) -> void:
	_ui_containers[container_type] = container

func show_ui(ui_name: String, data: Dictionary = {}, on_shown: Callable = func(_instance): pass) -> Node:
	if not _ui_scenes.has(ui_name):
		push_warning("UIManager: Unknown UI element: %s" % ui_name)
		return null

	if _active_ui.has(ui_name):
		var existing: Node = _active_ui[ui_name]
		existing.show()
		return existing

	var packed: PackedScene = _ui_scenes[ui_name]["scene"]
	var container_type = _ui_scenes[ui_name]["container"]
	var instance = packed.instantiate()

	if instance.has_method("setup"):
		instance.setup(data)

	_ui_containers[container_type].add_child(instance)
	_active_ui[ui_name] = instance

	ui_shown.emit(ui_name)

	if on_shown.is_valid():
		on_shown.call(instance)

	return instance

func hide_ui(ui_name: String, destroy: bool = true, on_hidden: Callable = func(_instance): pass) -> void:
	if not _active_ui.has(ui_name):
		return

	var instance = _active_ui[ui_name]

	if on_hidden.is_valid():
		on_hidden.call(instance)

	if destroy:
		instance.queue_free()
		_active_ui.erase(ui_name)
	else:
		instance.hide()

	ui_hidden.emit(ui_name)

func hide_container(container_type: UIContainer) -> void:
	for ui_name in _active_ui.keys():
		if _ui_scenes[ui_name]["container"] == container_type:
			hide_ui(ui_name)

func get_ui(ui_name: String) -> Node:
	return _active_ui.get(ui_name)

func is_ui_active(ui_name: String) -> bool:
	return _active_ui.has(ui_name)

func hide_all_ui(destroy: bool = true) -> void:
	for ui_name in _active_ui.keys():
		hide_ui(ui_name, destroy)

func toggle_ui(ui_name: String, data: Dictionary = {}) -> void:
	if is_ui_active(ui_name):
		hide_ui(ui_name)
	else:
		show_ui(ui_name, data)

func push_backdrop(backdrop_name: String, settings: Dictionary = {}) -> void:
	if not _backdrops.has(backdrop_name):
		push_warning("UIManager: Unknown backdrop: %s" % backdrop_name)
		return

	var count: int = _backdrop_ref_counts.get(backdrop_name, 0) + 1
	_backdrop_ref_counts[backdrop_name] = count

	if count == 1:
		await _enable_backdrop(backdrop_name, settings)

func pop_backdrop(backdrop_name: String) -> void:
	if not _backdrop_ref_counts.has(backdrop_name):
		return

	_backdrop_ref_counts[backdrop_name] -= 1
	if _backdrop_ref_counts[backdrop_name] > 0:
		return

	_backdrop_ref_counts.erase(backdrop_name)
	await _disable_backdrop(backdrop_name)

func push_world_blur(settings: Dictionary = {}) -> void:
	await push_backdrop("world_blur", settings)

func pop_world_blur() -> void:
	pop_backdrop("world_blur")

func is_backdrop_active(backdrop_name: String) -> bool:
	return _backdrop_ref_counts.get(backdrop_name, 0) > 0
#===================================================================================#

# BACKDROPS
#===================================================================================#
func _enable_backdrop(backdrop_name: String, settings: Dictionary) -> void:
	var entry: Dictionary = _backdrops[backdrop_name]
	var container: Node = _ui_containers[UIContainer.BACKDROP]
	if container == null:
		push_warning("UIManager: Backdrop container not set")
		return

	var instance: Node = entry["scene"].instantiate()
	container.add_child(instance)
	_active_backdrop_instances[backdrop_name] = instance

	_apply_backdrop_settings(instance, entry, settings)

	if settings.has("source") and instance is GaussianBlur:
		instance.set_source(settings["source"])
	else:
		match str(entry.get("capture", "none")):
			"world":
				if instance is GaussianBlur:
					var texture := await _capture_world_texture()
					instance.set_source(texture)
			"world_live":
				if instance is GaussianBlur:
					instance.set_live(true)

	if instance is GaussianBlur:
		instance.set_blur_strength(0.0)
		instance.fade_in(_resolve_fade_duration(entry, settings))

func _disable_backdrop(backdrop_name: String) -> void:
	if not _active_backdrop_instances.has(backdrop_name):
		return

	var instance: Node = _active_backdrop_instances[backdrop_name]
	_active_backdrop_instances.erase(backdrop_name)

	if instance is GaussianBlur:
		await instance.fade_out()

	instance.queue_free()

func _apply_backdrop_settings(instance: Node, entry: Dictionary, overrides: Dictionary) -> void:
	var settings := entry.duplicate()
	settings.merge(overrides, true)
	settings.erase("scene")
	settings.erase("capture")
	settings.erase("source")

	if instance is GaussianBlur:
		if settings.has("sigma"):
			instance.sigma = settings["sigma"]
		if settings.has("fade_duration"):
			instance.fade_duration = settings["fade_duration"]

func _resolve_fade_duration(entry: Dictionary, overrides: Dictionary) -> float:
	if overrides.has("fade_duration"):
		return overrides["fade_duration"]
	return entry.get("fade_duration", -1.0)

func _capture_world_texture() -> ImageTexture:
	_set_world_capture_visibility(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_set_world_capture_visibility(true)
	return ImageTexture.create_from_image(image)

func _set_world_capture_visibility(visible: bool) -> void:
	for container_type in [UIContainer.MENU, UIContainer.HUD, UIContainer.OVERLAY, UIContainer.BACKDROP]:
		var container: Node = _ui_containers.get(container_type)
		if container:
			container.visible = visible
#===================================================================================#
