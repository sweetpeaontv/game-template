extends Node3D

const SCRIPT_NAME: String = "keypad.gd"

@onready var buttons: Node3D = $Buttons
@onready var screen: Node3D = $Screen
@onready var authority: Node = $Authority

@export var _sync_state: SyncStateNode = null
@export var door_sync_state: SyncStateNode = null

# INIT
#===================================================================================#
func _ready() -> void:
	buttons.button_operated.connect(_on_button_operated)

	if _sync_state != null and screen != null:
		_sync_state.state_applied.connect(screen._on_state_changed)
		_sync_state.state_applied.connect(authority._on_state_changed)
	
	authority.keypad_unlocked.connect(_on_unlocked)
#===================================================================================#

# SYNC HOOKS
#===================================================================================#
func _on_button_operated(_interactor: Node3D, _data: InteractionTypes.OperableData, _button_id: StringName) -> void:
	if _sync_state == null:
		return

	var entered: PackedInt32Array = _sync_state.state.get("entered_digits", []).duplicate()
	if entered.size() >= 4:
		return

	entered.append(int(_button_id))

	var patch = { "entered_digits": entered }

	_sync_state.update(patch)
	
func _on_unlocked() -> void:
	SweetLogger.info("Keypad unlocked", [], SCRIPT_NAME, "_on_unlocked")
	var patch = { "state": "Open", "can_operate": true }
	door_sync_state.update(patch)
#===================================================================================#
