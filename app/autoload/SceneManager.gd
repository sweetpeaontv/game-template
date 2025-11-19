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
	  GameManager asks for a synchronized scene change.

Typical Flow:
	1. GameManager requests a scene by name.
	2. SceneManager resolves the path and loads it.
	3. SceneManager signals that the new scene is ready.
	4. GameManager or GameWorld performs additional setup
	   (e.g., spawns players, seeds match data, starts countdowns).

This manager keeps scene transitions clean and centralized so the rest
of the project can focus on game logic, networking, or UI without knowing
how scenes are actually loaded.
"""

signal scene_ready(scene_name)

var _scenes := {
	"MainMenu": preload("res://ui/screens/MainMenu.tscn"),
	"GameWorld": preload("res://game/worlds/GameWorld.tscn"),
}

var _pending_scene_name: String = ""

func _ready() -> void:
	# Listen for scene tree changes
	get_tree().tree_changed.connect(_on_tree_changed)

func goto_scene(scene_name: String) -> void:
	if not _scenes.has(scene_name):
		push_warning("Unknown scene: %s" % scene_name)
		return
	_call_change(scene_name)

@rpc("authority", "call_local", "reliable")
func rpc_goto_scene(scene_name: String) -> void:
	goto_scene(scene_name)

func request_scene_change(scene_name: String) -> void:
	# server authoritative
	if multiplayer.is_server():
		# tell everyone (incl. host) - call_local ensures host executes it too
		rpc_goto_scene.rpc(scene_name)
	else:
		push_warning("Only server can change scene")

func _call_change(scene_name: String) -> void:
	var packed: PackedScene = _scenes.get(scene_name)
	if packed == null:
		push_error("Unknown or unloaded scene: %s" % scene_name)
		return

	_pending_scene_name = scene_name
	get_tree().change_scene_to_packed(packed)

func _on_tree_changed() -> void:
	"""Called when the scene tree changes. Waits for the scene's ready signal before emitting scene_ready."""
	if _pending_scene_name != "":
		# Defer to next frame to ensure current_scene is updated
		call_deferred("_check_scene_ready")

func _check_scene_ready() -> void:
	"""Checks if the current scene is ready, or connects to its ready signal."""
	if _pending_scene_name == "":
		return
	
	var current_scene = get_tree().current_scene
	if current_scene:
		if current_scene.is_node_ready():
			# Scene is already ready, emit immediately
			scene_ready.emit(_pending_scene_name)
			_pending_scene_name = ""
		else:
			# Wait for the scene's ready signal
			current_scene.ready.connect(_on_scene_ready, CONNECT_ONE_SHOT)

func _on_scene_ready() -> void:
	"""Called when the new scene is fully ready. Emits scene_ready."""
	if _pending_scene_name != "":
		scene_ready.emit(_pending_scene_name)
		_pending_scene_name = ""
