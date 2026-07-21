class_name Operable
extends Interactable

signal operated(interactor: Node3D, data: InteractionTypes.OperableData)

const SCRIPT_NAME: String = "operable.gd"
const IS_VERBOSE: bool = false
const STATE_KEY := "state"

@export var default_operate_action: InteractionTypes.OperableData.Action
@export var ordered_states: Array[String] = []
@export var moment_name: StringName = &"Pulse"
@export var moment_return_to: StringName = &"Idle"

@export var operate_context: Dictionary = {}

@onready var animator: OperableAnimator = $Animator

var _sync_state: SyncStateNode = null

# INIT
#===================================================================================#
func _on_ready() -> void:
	RegistryLibrary.operables.add_entry(key, self)

	_sync_state = get_node_or_null("SyncState") as SyncStateNode
	if _sync_state:
		_sync_state.state_applied.connect(_on_sync_state_applied)
		_on_sync_state_applied(_sync_state.state)
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	RegistryLibrary.operables.remove_entry(key)
	super._exit_tree()
#===================================================================================#

# INTERACTION
#===================================================================================#
func _interact(_interactor: Node3D, _data: Variant = null, _rollback_is_fresh: bool = true) -> void:
	if not _data is InteractionTypes.OperableData:
		SweetLogger.error("Invalid data type: {0}", [_data.get_class()], SCRIPT_NAME, "_interact")
		return
	
	if _sync_state != null and not _sync_state.state.get("can_operate", true):
		# By default, we assume the object can be operated on
		# But in cases like a locked door, we can set the can_operate state to false
		# leaving it inoperable until the door has been unlocked
		return
	
	_apply_operate_action(_interactor, _data)

func _apply_operate_action(interactor: Node3D, operable_data: InteractionTypes.OperableData) -> void:
	match operable_data.action:
		InteractionTypes.OperableData.Action.PULSE:
			_apply_moment(operable_data)
		InteractionTypes.OperableData.Action.TOGGLE, \
		InteractionTypes.OperableData.Action.SET_STATE, \
		InteractionTypes.OperableData.Action.NEXT_STATE, \
		InteractionTypes.OperableData.Action.PREV_STATE:
			_apply_persistent(operable_data)
		_:
			SweetLogger.error("Invalid action: {0}", [operable_data.action], SCRIPT_NAME, "_apply_operate_action")
			return

	operated.emit(interactor, operable_data)

func _apply_moment(_operable_data: InteractionTypes.OperableData) -> void:
	if animator == null:
		return
	animator.play_moment(moment_name, moment_return_to)

func _apply_persistent(operable_data: InteractionTypes.OperableData) -> void:
	if _sync_state == null:
		SweetLogger.error("Persistent operate requires SyncStateNode child: {0}", [name], SCRIPT_NAME, "_apply_persistent")
		return

	var target := _resolve_target_state(operable_data)
	if target.is_empty() or target == _current_state():
		return

	_sync_state.update({ STATE_KEY: target })

func _current_state() -> String:
	if _sync_state == null:
		return ""
	return _resolve_state_name(_sync_state.state)

func _resolve_state_name(source: Dictionary) -> String:
	if source.has(STATE_KEY):
		return str(source[STATE_KEY])
	if _sync_state != null:
		if _sync_state.state.has(STATE_KEY):
			return str(_sync_state.state[STATE_KEY])
		if _sync_state.initial_state.has(STATE_KEY):
			return str(_sync_state.initial_state[STATE_KEY])
	if ordered_states.size() > 0:
		return ordered_states[0]
	return ""

func _resolve_target_state(operable_data: InteractionTypes.OperableData) -> String:
	var current := _current_state()
	match operable_data.action:
		InteractionTypes.OperableData.Action.TOGGLE:
			return _next_in_cycle(current)
		InteractionTypes.OperableData.Action.SET_STATE:
			return operable_data.target_state
		InteractionTypes.OperableData.Action.NEXT_STATE:
			return _next_in_cycle(current)
		InteractionTypes.OperableData.Action.PREV_STATE:
			return _prev_in_cycle(current)
	return ""

func _next_in_cycle(current: String) -> String:
	if ordered_states.size() < 2:
		return ""
	var idx := ordered_states.find(current)
	if idx < 0:
		idx = 0
	return ordered_states[(idx + 1) % ordered_states.size()]

func _prev_in_cycle(current: String) -> String:
	if ordered_states.size() < 2:
		return ""
	var idx := ordered_states.find(current)
	if idx < 0:
		idx = 0
	return ordered_states[(idx - 1) % ordered_states.size()]

func _is_local_interactor(interactor: Node3D) -> bool:
	return interactor != null and interactor.get("peer_id") == multiplayer.get_unique_id()
#===================================================================================#

# SYNC
#===================================================================================#
func _on_sync_state_applied(state: Dictionary) -> void:
	if animator == null:
		return
	var state_name := _resolve_state_name(state)
	if state_name.is_empty():
		return
	animator.go_to_state(StringName(state_name))
#===================================================================================#

# PUBLIC API
#===================================================================================#
func get_interaction_type() -> int:
	return InteractionTypes.InteractionType.OPERABLE
#===================================================================================#
