extends Node3D
## Stand-in for [code]character.gd[/code] when proprietary mesh packs are absent.
## Keeps the same player-facing API so [code]player.gd[/code] does not need template branches.

const PLACEHOLDER_MODEL: PackedScene = preload("res://app/game/character/placeholder-character/models/char.glb")
const PLACEHOLDER_ALBEDO: Texture2D = preload(
	"res://app/game/character/placeholder-character/models/char_material_base_color.png"
)

enum LocomotionAnimation { IDLE, WALK, RUN }

func _ready() -> void:
	if get_node_or_null("Model") == null:
		_build_visual()
	if get_node_or_null("CoreAP") == null:
		_build_anchors()

func _build_visual() -> void:
	var model: Node3D = PLACEHOLDER_MODEL.instantiate()
	model.name = "Model"
	_apply_albedo(model)
	add_child(model)

func _build_anchors() -> void:
	# Rough stand-ins for character.tscn attachment points (customizer / examine cam).
	var core_ap := Marker3D.new()
	core_ap.name = "CoreAP"
	core_ap.position = Vector3(0.0, 0.9, 0.0)
	add_child(core_ap)

func _apply_albedo(root: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PLACEHOLDER_ALBEDO
	for child in root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = mat

func set_locomotion_animation(_anim: LocomotionAnimation) -> void:
	# Placeholder GLB may not include Idle/Walk/Run clips.
	pass

func rotate_toward_camera(delta: float, camera_basis: Basis) -> void:
	var head_forward := camera_basis.z
	var target_angle := atan2(head_forward.x, head_forward.z)
	rotation.y = lerp_angle(rotation.y, target_angle, delta * 10.0)
