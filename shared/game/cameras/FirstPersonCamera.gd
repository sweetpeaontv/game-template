extends Node3D

# SHOUT OUT TO THIS VIDEO FOR THE CAMERA CODE: https://www.youtube.com/watch?v=A3HLeyaBCq4

@onready var camera := $"."
@export var player: CharacterBody3D

const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob: float = 0.0

const BASE_FOV = 75.0
const FOV_MULTIPLIER = 1.5

var peer_id: int = 0

func set_player(curr_player: CharacterBody3D) -> void:
	self.player = curr_player

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _process(delta: float) -> void:
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	var bob_offset = _headbob(t_bob)
	camera.transform.origin = bob_offset

	var velocity_clamped = clamp(player.velocity.length(), 0.5, player.SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_MULTIPLIER * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
