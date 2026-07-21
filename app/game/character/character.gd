extends Node3D

var config: CharacterConfig
var builder: CharacterBuilder
@onready var armature: Node3D = $Armature

# INIT
#===================================================================================#
# config referenced must be added to the scene before builder is created
func _ready() -> void:
	_create_builder()
	self.add_child(builder)
	if config != null:
		apply_size(config.character_size)

func setup_config(injected_config: CharacterConfig) -> void:
	config = injected_config
	config.name = "Config"
	if not config.size_changed.is_connected(_on_config_size_changed):
		config.size_changed.connect(_on_config_size_changed)
	add_child(config)

func get_config() -> CharacterConfig:
	return config

func _create_builder() -> void:
	var new_builder: CharacterBuilder = CharacterBuilder.new()
	new_builder.setup(config, armature)
	builder = new_builder
#===================================================================================#

# CHARACTER CONTROL
#===================================================================================#
func rotate_character(degrees: float) -> void:
	armature.rotation.y += deg_to_rad(degrees)

func apply_size(size: float) -> void:
	if armature == null:
		return
	armature.scale = Vector3.ONE * size
#===================================================================================#

# PUBLIC API
#===================================================================================#
enum LocomotionAnimation { IDLE, WALK, RUN }

const LOCOMOTION_ANIMATION_NAMES := {
	LocomotionAnimation.IDLE: "Idle",
	LocomotionAnimation.WALK: "Walk_1",
	LocomotionAnimation.RUN: "Run_1",
}

func set_visibility(vis: bool) -> void:
	visible = vis

func set_locomotion_animation(anim: LocomotionAnimation) -> void:
	if armature:
		armature.play_animation(LOCOMOTION_ANIMATION_NAMES[anim])

func rotate_toward_camera(delta: float, camera_basis: Basis) -> void:
	var head_forward = camera_basis.z
	var target_angle = atan2(head_forward.x, head_forward.z)
	rotation.y = lerp_angle(rotation.y, target_angle, delta * 10.0)
#===================================================================================#

# SIGNAL HANDLERS
#===================================================================================#
func _on_config_size_changed(new_size: float) -> void:
	apply_size(new_size)
#===================================================================================#
