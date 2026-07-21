extends Node3D

@onready var animation_player = $AnimationPlayer
# perhaps worth refactoring to use a dictionary of slots
# unifying all of the character stuff to be accessed via CharacterConfig.PartSlot enum
@onready var head_slot: MeshInstance3D = $rig/Skeleton3D/HeadSlot
@onready var hair_slot: MeshInstance3D = $rig/Skeleton3D/HairSlot
@onready var beard_slot: MeshInstance3D = $rig/Skeleton3D/BeardSlot
@onready var glasses_slot: MeshInstance3D = $rig/Skeleton3D/GlassesSlot
@onready var torso_slot: MeshInstance3D = $rig/Skeleton3D/TorsoSlot
@onready var legs_slot: MeshInstance3D = $rig/Skeleton3D/LegsSlot
@onready var shoes_slot: MeshInstance3D = $rig/Skeleton3D/ShoesSlot

@onready var slots: Array[MeshInstance3D] = [head_slot, hair_slot, beard_slot, glasses_slot, torso_slot, legs_slot, shoes_slot]

@onready var skin: Skin #= preload("res://app/game/character/model/armature/skin.res")
@onready var character_shader: Shader = preload("res://app/game/character/model/shaders/character.gdshader")
const PALETTE_TEXTURE: Texture2D = null #= preload("res://app/game/character/model/textures/Main_colors.png")

# INIT
#===================================================================================#
var _current_animation: StringName = &""

func _ready() -> void:
	_setup()
	play_animation("Idle")

func _setup() -> void:
	for slot in slots:
		if not _validate_slots(slot):
			SweetLogger.error("Armature._setup: slot is null", [], "Armature.gd", "_setup")
			continue
		_setup_skin(slot)
		_setup_material(slot)

func _validate_slots(slot) -> bool:
	if slot == null:
		SweetLogger.error("Armature._validate_slots: slot is null", [], "Armature.gd", "_validate_slots")
		return false
	
	return true

func _setup_skin(slot: MeshInstance3D) -> void:
	if skin:
		slot.skin = skin

func _setup_material(slot: MeshInstance3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = character_shader
	if PALETTE_TEXTURE:
		mat.set_shader_parameter("palette", PALETTE_TEXTURE)
	slot.material_override = mat
#===================================================================================#

# EXIT
#===================================================================================#
func _exit_tree() -> void:
	pass
#===================================================================================#

# PUBLIC API
#===================================================================================#
func play_animation(anim_name: String) -> void:
	if _current_animation == anim_name and animation_player.is_playing():
		return

	var anim: Animation = animation_player.get_animation(anim_name)
	if anim == null:
		SweetLogger.error("Armature.play_animation: animation {0} not found", [anim_name], "Armature.gd", "play_animation")
		return

	anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(anim_name)
	_current_animation = anim_name

func apply_part(slot: CharacterConfig.PartSlot, mesh: Variant, uniforms: Dictionary) -> void:
	var slot_instance := _get_slot(slot)
	if slot_instance == null:
		SweetLogger.error("Armature.apply_part: no slot instance found for slot {0}", [slot], "Armature.gd", "apply_part")
		return
	
	apply_mesh(slot, slot_instance, mesh)
	apply_colors(slot_instance, uniforms)

func apply_mesh(slot: CharacterConfig.PartSlot, slot_instance: MeshInstance3D, mesh: Variant) -> void:
	if mesh == null and CharacterConfig.CLEARABLE_PARTSLOTS.has(slot):
		slot_instance.mesh = null
		return
	if mesh is not Mesh:
		SweetLogger.error("Armature.apply_mesh: mesh is not a Mesh", [], "Armature.gd", "apply_mesh")
		return

	if slot_instance.material_override == null:
		_setup_material(slot_instance)
	slot_instance.mesh = mesh

func apply_colors(slot_instance: MeshInstance3D, uniforms: Dictionary) -> void:
	if uniforms.is_empty():
		SweetLogger.error("Armature.apply_colors: uniforms are empty", [], "Armature.gd", "apply_colors")
		return
	
	var mat := slot_instance.material_override as ShaderMaterial
	if mat == null:
		SweetLogger.error("Armature.apply_colors: no material found for slot {0}", [slot_instance.name], "Armature.gd", "apply_colors")
		return
	
	mat.set_shader_parameter("skin_uv", uniforms.get("skin_uv", Vector2.ZERO))
	mat.set_shader_parameter("base_uv", uniforms.get("base_uv", Vector2.ZERO))
	mat.set_shader_parameter("accent_uv", uniforms.get("accent_uv", Vector2.ZERO))
	mat.set_shader_parameter("detail_uv", uniforms.get("detail_uv", Vector2.ZERO))
#===================================================================================#

# PRIVATE METHODS
#===================================================================================#
func _get_slot(slot: CharacterConfig.PartSlot) -> MeshInstance3D:
	match slot:
		CharacterConfig.PartSlot.HEAD:
			return head_slot
		CharacterConfig.PartSlot.HAIR:
			return hair_slot
		CharacterConfig.PartSlot.BEARD:
			return beard_slot
		CharacterConfig.PartSlot.GLASSES:
			return glasses_slot
		CharacterConfig.PartSlot.TORSO:
			return torso_slot
		CharacterConfig.PartSlot.LEGS:
			return legs_slot
		CharacterConfig.PartSlot.SHOES:
			return shoes_slot
		_:
			return null
#===================================================================================#
