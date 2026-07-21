class_name SyncStateNode
extends Node

signal state_applied(state: Dictionary)

var state: Dictionary = {}
var is_dirty: bool = false

var key: int = 0
var revision_count: int = 0

@export var initial_state: Dictionary = {}

# INIT
#===================================================================================#
func _ready() -> void:
	if not initial_state.is_empty() and state.is_empty():
		state = initial_state.duplicate(true)
	key = get_path().hash()
	RegistryLibrary.sync_targets.add_entry(key, self)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	RegistryLibrary.sync_targets.remove_entry(key)
#===================================================================================#

# PUBLIC API
#===================================================================================#
func get_wire_state() -> Dictionary:
	return state.duplicate(true)

func update(new_state: Dictionary) -> void:
	_apply_state(new_state)
	if Gnet.is_authority():
		revision_count += 1
		_mark_dirty()

func apply_wire_state(wire_state: Dictionary) -> void:
	_apply_state(wire_state)

func differs_from_initial() -> bool:
	return state != initial_state
#===================================================================================#

# INTERNALS
#===================================================================================#
func _apply_state(new_state: Dictionary) -> void:
	_merge_diff(new_state)
	state_applied.emit(state)

func _merge_diff(diff: Dictionary) -> void:
	for new_key in diff:
		state[new_key] = diff[new_key]

func _mark_dirty() -> void:
	is_dirty = true
#===================================================================================#
