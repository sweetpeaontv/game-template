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
	- Emit signals when UI elements are shown/hidden
	- Manage UI layers and visibility
"""

signal ui_shown(ui_name: String)
signal ui_hidden(ui_name: String)

# Registry of all available UI scenes
var _ui_scenes := {
	"EscMenu": preload("res://app/ui/screens/esc-menu/EscMenu.tscn"),
	"PickupHUD": preload("res://app/ui/hud/contextual/pickup-hud/PickupHUD.tscn"),
	"Crosshair": preload("res://app/ui/hud/crosshair/Crosshair.tscn")
}

# Dictionary to track currently active UI instances
# Key: ui_name, Value: { node: Node, signal_connections: Array[SignalConnection] }
# undecided if signal_connections is needed, maybe if you only wanted certain ones disconnected when hiding?
var _active_ui := {}

# Container reference (will be set to a CanvasLayer or Control node)
var _ui_container: Node = null

# INIT
#===================================================================================#
func _ready() -> void:
	# Create a default container for UI if none is specified
	_ui_container = CanvasLayer.new()
	_ui_container.name = "UIManagerLayer"
	_ui_container.layer = 100
	add_child(_ui_container)
#===================================================================================#

# PUBLIC API
#===================================================================================#
func set_container(container: Node) -> void:
	"""Set a custom container for UI elements."""
	_ui_container = container

func show_ui(ui_name: String, data: Dictionary = {}, signal_connections: Array[SignalConnections] = []) -> Node:
	"""
	Shows a UI element by name. Returns the instantiated node.
	If the UI is already shown, returns the existing instance.
	
	Args:
		ui_name: Name of the UI element from the registry
		data: Optional dictionary of parameters to pass to the UI
	"""
	if not _ui_scenes.has(ui_name):
		push_warning("UIManager: Unknown UI element: %s" % ui_name)
		return null
	
	if _active_ui.has(ui_name):
		return _active_ui[ui_name]["node"]
	
	var packed: PackedScene = _ui_scenes[ui_name]
	var instance = packed.instantiate()
	
	# Pass data to the UI if it has a setup method
	if instance.has_method("setup"):
		instance.setup(data)
	
	_ui_container.add_child(instance)
	_active_ui[ui_name] = { "node": instance, "signal_connections": signal_connections }
	
	ui_shown.emit(ui_name)
	return instance

func hide_ui(ui_name: String, destroy: bool = true) -> void:
	"""
	Hides a UI element by name.
	
	Args:
		ui_name: Name of the UI element to hide
		destroy: If true, removes the node. If false, just hides it.
	"""
	if not _active_ui.has(ui_name):
		return

	var instance = _active_ui[ui_name]["node"]
	var signal_connections = _active_ui[ui_name]["signal_connections"]
	
	for connection in signal_connections:
		connection.disconnect_signal()
	
	if destroy:
		instance.queue_free()
		_active_ui.erase(ui_name)
	else:
		instance.hide()
	
	ui_hidden.emit(ui_name)

func get_ui(ui_name: String) -> Node:
	"""Returns the active instance of a UI element, or null if not active."""
	return _active_ui.get(ui_name)

func is_ui_active(ui_name: String) -> bool:
	"""Returns true if the UI element is currently active."""
	return _active_ui.has(ui_name)

func hide_all_ui(destroy: bool = true) -> void:
	"""Hides all active UI elements."""
	for ui_name in _active_ui.keys():
		hide_ui(ui_name, destroy)

func toggle_ui(ui_name: String, data: Dictionary = {}) -> void:
	"""Toggles a UI element on/off."""
	if is_ui_active(ui_name):
		hide_ui(ui_name)
	else:
		show_ui(ui_name, data)
#===================================================================================#