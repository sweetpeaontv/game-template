# app/autoload/SceneManager.gd
extends Node
"""
SceneManager

Purpose:
	Handles all scene loading, unloading, and transitions for the game. This
	manager keeps a registry of available scenes, performs synchronous or
	asynchronous scene changes, and emits signals when transitions complete.
	It does not enforce game rules or networking logic — it simply moves the
	game between places.

Responsibilities:
	- Maintain a lookup table of scene names → PackedScene paths.
	- Change scenes using get_tree().change_scene_to_packed().
	- Provide a single entry point for switching to menu, lobby, gameplay,
	  or any other scene defined in the registry.
	- Emit scene_ready(name) when the new scene is ready.
	- Support network-aware transitions by exposing request_scene_change()
	  which the server can call to broadcast an authoritative scene switch.

Non-Responsibilities:
	- Does not spawn players or manage gameplay state.
	- Does not manage connection/session flow.
	- Does not keep track of players, rounds, teams, or timers.
	- Does not handle RPCs directly; only receives or relays them if
	  ClientManager asks for a synchronized scene change.

Typical Flow:
	1. ClientManager requests a scene by name.
	2. SceneManager resolves the path and loads it.
	3. SceneManager signals that the new scene is ready.
	4. ClientManager or GameWorld performs additional setup
	   (e.g., spawns players, seeds match data, starts countdowns).

This manager keeps scene transitions clean and centralized so the rest
of the project can focus on game logic, networking, or UI without knowing
how scenes are actually loaded.
"""

signal scene_ready(scene_name)

var _scenes := {
	"MenuWorld": preload("res://app/game/worlds/menu/menu_world.tscn"),
	"GameWorld": preload("res://app/game/worlds/game-world/game_world.tscn"),
}

var current_scene_name: String = ""
var _pending_scene_name: String = ""
var _world_container: Node = null

# INIT
#===================================================================================#
func _ready() -> void:
	call_deferred("_find_world_container")
#===================================================================================#

# PUBLIC API
#===================================================================================#
func has_scene(scene_name: String) -> bool:
	return _scenes.has(scene_name)

func goto_scene(scene_name: String) -> void:
	if not _scenes.has(scene_name):
		push_warning("Unknown scene: %s" % scene_name)
		return

	if not _world_container:
		_find_world_container()

	if _world_container:
		_load_scene_into_container(scene_name)
	else:
		_call_change(scene_name)
#===================================================================================#

# PRIVATE METHODS
#===================================================================================#
func _find_world_container() -> void:
	"""Finds the WorldContainer node in the Main scene."""
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		_world_container = main.get_node_or_null("WorldContainer")
		if not _world_container:
			push_warning("SceneManager: WorldContainer not found in Main scene")
		else:
			# Ensure we have a reference for future scene changes
			pass

func _load_scene_into_container(scene_name: String) -> void:
	"""Loads a scene into the WorldContainer instead of replacing the entire scene tree."""
	var packed: PackedScene = _scenes.get(scene_name)
	if packed == null:
		push_error("Unknown or unloaded scene: %s" % scene_name)
		return

	for child in _world_container.get_children():
		child.queue_free()

	_pending_scene_name = scene_name
	var instance = packed.instantiate()
	_world_container.add_child(instance, true)

	if instance.is_node_ready():
		call_deferred("_emit_scene_ready")
	else:
		instance.ready.connect(_emit_scene_ready, CONNECT_ONE_SHOT)

func _emit_scene_ready() -> void:
	"""Emits the scene_ready signal after loading into container."""
	_finish_scene_load()

func _finish_scene_load() -> void:
	var scene_name := _pending_scene_name
	if scene_name == "":
		return

	_pending_scene_name = ""
	current_scene_name = scene_name
	scene_ready.emit(scene_name)

func _call_change(scene_name: String) -> void:
	"""Fallback method that replaces the entire scene tree (used when WorldContainer not found)."""
	var packed: PackedScene = _scenes.get(scene_name)
	if packed == null:
		push_error("Unknown or unloaded scene: %s" % scene_name)
		return

	_pending_scene_name = scene_name
	get_tree().change_scene_to_packed(packed)

func _check_scene_ready() -> void:
	"""Checks if the current scene is ready, or connects to its ready signal. Only used for fallback method."""
	if _pending_scene_name == "":
		return

	var current_scene = get_tree().current_scene
	if current_scene:
		if current_scene.is_node_ready():
			_finish_scene_load()
		else:
			current_scene.ready.connect(_emit_scene_ready, CONNECT_ONE_SHOT)
#===================================================================================#
