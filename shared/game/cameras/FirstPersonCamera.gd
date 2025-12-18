extends Node3D

# SHOUT OUT TO THIS VIDEO FOR THE CAMERA CODE: https://www.youtube.com/watch?v=A3HLeyaBCq4

@onready var head := $"."
@onready var camera := $Camera3D
@onready var player := $".."

const SENSITIVITY = 0.004
const MIN_PITCH = deg_to_rad(-40)
const MAX_PITCH = deg_to_rad(60)

const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob: float = 0.0

const BASE_FOV = 75.0
const FOV_MULTIPLIER = 1.5

var peer_id: int = 0

func set_peer_id(id: int) -> void:
	peer_id = id

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative)

func rotate_camera(move: Vector2):
	if move != Vector2.ZERO:
		head.rotate_y(-move.x * SENSITIVITY)
		camera.rotate_x(-move.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, MIN_PITCH, MAX_PITCH)

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _process(delta: float) -> void:
	var my_id = multiplayer.get_unique_id()
	if peer_id == my_id:
		t_bob += delta * player.velocity.length() * float(player.is_on_floor())
		var bob_offset = _headbob(t_bob)
		camera.transform.origin = bob_offset

		var velocity_clamped = clamp(player.velocity.length(), 0.5, player.SPRINT_SPEED * 2)
		var target_fov = BASE_FOV + FOV_MULTIPLIER * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
