extends Node3D

const SCRIPT_NAME: String = "keypad_screen.gd"

@export var screen_label: Label3D
@export var screen_mesh: MeshInstance3D

var _screen_material: ShaderMaterial

# INIT
#===================================================================================#
func _ready() -> void:
	if screen_mesh != null and screen_mesh.material_override is ShaderMaterial:
		_screen_material = screen_mesh.material_override as ShaderMaterial
#===================================================================================#

# SYNC HOOK
#===================================================================================#
func _on_state_changed(new_state: Dictionary) -> void:
	_refresh_screen_mode(new_state.get("screen_mode", 0))
	_refresh_label(new_state.get("entered_digits", []))
#===================================================================================#

# REFRESH
#===================================================================================#
func _refresh_screen_mode(mode: int) -> void:
	if _screen_material == null:
		SweetLogger.error("Screen material not found", [], SCRIPT_NAME, "_refresh_screen_mode")
		return
	
	if _screen_material.get_shader_parameter("screen_mode") == mode:
		return
	
	_screen_material.set_shader_parameter("screen_mode", mode)

func _refresh_label(entered_digits: Array[int]) -> void:
	if screen_label == null:
		SweetLogger.error("Screen label not found", [], SCRIPT_NAME, "_refresh_label")
		return

	var next_text := ""
	for d in entered_digits:
		next_text += str(d)
	
	if screen_label.text == next_text:
		return
	
	screen_label.text = next_text
#===================================================================================#
