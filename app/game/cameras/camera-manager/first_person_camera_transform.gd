extends Node3D

# SHOUT OUT TO THIS VIDEO FOR THE CAMERA CODE: https://www.youtube.com/watch?v=A3HLeyaBCq4

var camera_state: CameraManager.CameraState = CameraManager.CameraState.FIRST_PERSON

@onready var camera_transform := $"."
@export var player: CharacterBody3D

# HEADBOB
#===================================================================================#
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob: float = 0.0
#===================================================================================#

var peer_id: int = 0

# SETUP
#===================================================================================#
func set_player(curr_player: CharacterBody3D) -> void:
	self.player = curr_player

func set_camera_state(curr_camera_state: CameraManager.CameraState) -> void:
	camera_state = curr_camera_state
#===================================================================================#

# FIRST PERSON
#===================================================================================#
# headbob could be extracted into its own node (or perhaps CameraMount) instead of directly applying to the camera
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
#===================================================================================#

# PROCESSING
#===================================================================================#
func _process(delta: float) -> void:
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	#camera_transform.position = _headbob(t_bob)
#===================================================================================#
