extends Node3D

# SHOUT OUT TO THIS VIDEO FOR THE CAMERA CODE: https://www.youtube.com/watch?v=A3HLeyaBCq4

var camera_state: CameraManager.CameraState = CameraManager.CameraState.FIRST_PERSON

@onready var camera := $"."
@export var player: CharacterBody3D

# FOV
#===================================================================================#
const BASE_FOV = 75.0
const FOV_MULTIPLIER = 1.5
#===================================================================================#

var peer_id: int = 0

# SETUP
#===================================================================================#
func set_player(curr_player: CharacterBody3D) -> void:
	self.player = curr_player

func set_camera_state(curr_camera_state: CameraManager.CameraState) -> void:
	camera_state = curr_camera_state
#===================================================================================#

# PROCESSING
#===================================================================================#
func _fp_process(delta: float) -> void:	
	var velocity_clamped = clamp(player.velocity.length(), 0.5, player.SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_MULTIPLIER * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _tp_process(_delta: float) -> void:
	pass

func _examine_process(_delta: float) -> void:
	pass

func _transition_process(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	match camera_state:
		CameraManager.CameraState.FIRST_PERSON:
			_fp_process(delta)
		CameraManager.CameraState.THIRD_PERSON:
			_tp_process(delta)
		CameraManager.CameraState.EXAMINE:
			_examine_process(delta)
		CameraManager.CameraState.TRANSITION:
			_transition_process(delta)
#===================================================================================#
