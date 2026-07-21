class_name CharacterConfig
extends Node

const IS_VERBOSE: bool = false
const SNAPSHOT_SIZE_KEY := "size"
const DEFAULT_CHARACTER_SIZE := 1.0

const no_mesh_name: String = "empty_mesh"
## "empty_mesh" [code]mesh_name[/code] means no mesh for this slot (e.g. bald, no glasses). Only these slots may use it.
const CLEARABLE_PARTSLOTS: Array[PartSlot] = [
	PartSlot.GLASSES,
	PartSlot.HAIR,
	PartSlot.BEARD,
]

## [param part_slot] is [code]null[/code] for a full-config change, a single [enum PartSlot],
## or an [code]Array[/code] of [enum PartSlot] after a batch of edits.
# TODO: Combine these into a single signal with a payload object?
signal config_changed(slots: Array[PartSlot])
signal size_changed(new_size: float)

enum PartSlot {
	HEAD,
	GLASSES,
	HAIR,
	BEARD,
	TORSO,
	LEGS,
	SHOES,
}

enum CoreSlot {
	SKIN,
	HAIR,
	SIZE,
}

var core_slot_palette_names: Dictionary = {
	CoreSlot.SKIN: "skin",
	CoreSlot.HAIR: "hair",
	CoreSlot.SIZE: "size",
}

class Part:
	var mesh_name: String
	var colors: ColorSet

	func _init(_mesh_name: String = "", _colors: ColorSet = ColorSet.new()):
		mesh_name = _mesh_name
		colors = _colors

## Use null for [param mesh_name] or [param colors] to leave field unchanged while updating the other.
class UpdateData:
	var slot: PartSlot
	var mesh_name: Variant
	var colors: Variant

	func _init(_slot: PartSlot = PartSlot.HEAD, _mesh_name: Variant = null, _colors: Variant = null):
		slot = _slot
		mesh_name = _mesh_name
		colors = _colors

@onready var skin_color: String = ""
@onready var hair_color: String = ""
@onready var character_size: float = 1.0

# TODO: Refactor this to use 'part slots'/ enum map
var head: Part
var glasses: Part
var hair: Part
var beard: Part
var torso: Part
var legs: Part
var shoes: Part

# INIT
#===================================================================================#
func _init(character_snapshot: Variant) -> void:
	_init_parts()
	ready.connect(
		func() -> void:
			apply_snapshot(character_snapshot),
		CONNECT_ONE_SHOT
	)

func _init_parts() -> void:
	head = Part.new()
	glasses = Part.new()
	hair = Part.new()
	beard = Part.new()
	torso = Part.new()
	legs = Part.new()
	shoes = Part.new()

func _ready() -> void:
	pass
#===================================================================================#

# EXIT
#===================================================================================#
func _exit_tree() -> void:
	pass
#===================================================================================#

# HELPERS
#===================================================================================#
func new_character() -> void:
	var updates: Array[UpdateData] = []
	for slot_name in PartSlot.values():
		# this can come from generator or from a preset
		var new_part := Part.new()
		updates.append(UpdateData.new(slot_name, new_part.mesh_name, new_part.colors))
	update_parts(updates)

func slot_to_property_key(slot: PartSlot) -> String:
	var key: Variant = PartSlot.find_key(slot)
	if key == null:
		return ""
	return String(key).to_lower()

func get_part(slot: PartSlot) -> Part:
	var property_key := slot_to_property_key(slot)
	if property_key.is_empty():
		return null
	return get(property_key)

func get_part_colors(slot: PartSlot) -> ColorSet:
	var part := get_part(slot)
	if part == null:
		return null
	return part.colors

func get_beard_mesh_from_head(head_mesh_name: String) -> String:
	var current := beard.mesh_name
	if current.is_empty() or current == no_mesh_name:
		return current
	var head_re := RegEx.new()
	head_re.compile("^(m_|f_)head_(\\d+)$")
	var head_match := head_re.search(head_mesh_name)
	if head_match == null:
		return current
	var prefix: String = head_match.get_string(1)
	var head_num: String = head_match.get_string(2)
	var beard_re := RegEx.new()
	beard_re.compile("^(m_|f_)beard_(\\d+)(.*)$")
	var beard_match := beard_re.search(current)
	if beard_match == null:
		return current
	var suffix: String = beard_match.get_string(3)
	return "%sbeard_%s%s" % [prefix, head_num, suffix]

func partial_part_colors_change(
	slot: PartSlot, 
	color_type: ColorSet.ColorType, 
	color_key: String
) -> ColorSet:
	var current_colors: ColorSet = get_part_colors(slot)
	if current_colors == null:
		SweetLogger.error("no colors found for slot {0}", [slot], "CharacterConfig.gd", "partial_part_colors_change")
		return null
	var new_colors: ColorSet = current_colors.copy()
	new_colors.colors[color_type] = color_key
	set_part_colors(slot, new_colors)
	return new_colors

func assign_mesh_name(slot: PartSlot, mesh_name: String) -> void:
	var part := get_part(slot)
	if part == null:
		return
	part.mesh_name = mesh_name

func assign_colors(slot: PartSlot, colors: ColorSet) -> void:
	var part := get_part(slot)
	if part == null:
		return
	part.colors = colors

func set_part_mesh(slot: PartSlot, mesh_name: String) -> void:
	var new_updates: Array[UpdateData] = [UpdateData.new(slot, mesh_name, null)]
	if slot == PartSlot.HEAD:
		new_updates.append(UpdateData.new(PartSlot.BEARD, get_beard_mesh_from_head(mesh_name), null))
	update_parts(new_updates)

func set_part_colors(slot: PartSlot, colors: ColorSet) -> void:
	update_parts([UpdateData.new(slot, null, colors)])

func set_core_color(slot: CoreSlot, _color_type: ColorSet.ColorType, color_key: String) -> Array[PartSlot]:
	match slot:
		CoreSlot.SKIN:
			return set_skin_color(color_key)
		CoreSlot.HAIR:
			return set_hair_color(color_key)
		_:
			SweetLogger.error("CharacterConfig.set_core_color: invalid slot {0}", [slot], "CharacterConfig.gd", "set_core_color")
			return []

func set_skin_color(new_color: String) -> Array[PartSlot]:
	if new_color.is_empty():
		return []

	skin_color = new_color

	var changed_slots: Array[PartSlot] = []
	var new_updates: Array[UpdateData] = []
	for slot in PartSlot.values():
		var current_colors: ColorSet = get_part_colors(slot)
		if current_colors == null:
			continue
		var new_colors: ColorSet = current_colors.copy()
		new_colors.skin = skin_color
		new_updates.append(UpdateData.new(slot, null, new_colors))
		changed_slots.append(slot)
	update_parts(new_updates)
	return changed_slots

func set_hair_color(new_color: String) -> Array[PartSlot]:
	if new_color.is_empty():
		return []

	hair_color = new_color

	var changed_slots: Array[PartSlot] = []
	var new_updates: Array[UpdateData] = []
	for slot in [PartSlot.HEAD, PartSlot.HAIR, PartSlot.BEARD]:
		var current_colors: ColorSet = get_part_colors(slot)
		if current_colors == null:
			continue
		var new_colors: ColorSet = current_colors.copy()
		new_colors.base = hair_color
		new_updates.append(UpdateData.new(slot, null, new_colors))
		changed_slots.append(slot)
	update_parts(new_updates)
	return changed_slots

func set_size(new_size: float) -> void:
	character_size = new_size
	size_changed.emit(new_size)
#===================================================================================#

# SNAPSHOT
#===================================================================================#
func slot_to_snapshot_key(slot: PartSlot) -> String:
	var key: Variant = PartSlot.find_key(slot)
	if key == null:
		return ""
	return String(key)

func snapshot_key_to_slot(key: String) -> PartSlot:
	if not PartSlot.has(key):
		SweetLogger.error("CharacterConfig.snapshot_key_to_slot: invalid key {0}", [key], "CharacterConfig.gd", "snapshot_key_to_slot")
		return PartSlot.HEAD
	return PartSlot[key] as PartSlot

func to_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for slot_name in PartSlot.values():
		var part = get_part(slot_name)
		snapshot[slot_to_snapshot_key(slot_name)] = {
			"mesh_name": part.mesh_name,
			"colors": part.colors.serialize(),
		}
	snapshot[SNAPSHOT_SIZE_KEY] = character_size
	return snapshot

func apply_snapshot(snapshot: Dictionary) -> void:
	var snapshot_err := validate_snapshot(snapshot)
	if not snapshot_err.is_empty():
		SweetLogger.error(
			"CharacterConfig.apply_snapshot: invalid snapshot — {0}",
			[snapshot_err],
			"CharacterConfig.gd",
			"apply_snapshot",
		)
		return
	
	var updates: Array[UpdateData] = []
	for slot_name in PartSlot.values():
		var slot_key := slot_to_snapshot_key(slot_name)
		var slot_data: Dictionary = snapshot[slot_key]
		updates.append(
			UpdateData.new(
				slot_name,
				slot_data.get("mesh_name"),
				ColorSet.deserialize(slot_data.get("colors", {}))
			)
		)
	update_parts(updates)
	set_size(float(snapshot.get(SNAPSHOT_SIZE_KEY, DEFAULT_CHARACTER_SIZE)))
#===================================================================================#

# VALIDATION
#===================================================================================#
func validate_snapshot(snapshot: Dictionary) -> String:
	for slot_name in PartSlot.values():
		var slot_key := slot_to_snapshot_key(slot_name)
		if slot_key.is_empty():
			return "cannot resolve snapshot key for slot enum value %s" % str(slot_name)

		if not snapshot.has(slot_key):
			return "missing slot '%s'" % slot_key

		var slot_dict: Variant = snapshot[slot_key]
		if slot_dict is not Dictionary:
			return "slot '%s' must be a Dictionary (got %s)" % [slot_key, type_string(typeof(slot_dict))]

		var slot_data: Dictionary = slot_dict
		if not slot_data.has("mesh_name"):
			return "slot '%s' missing required field 'mesh_name'" % slot_key

		var mesh_val: Variant = slot_data["mesh_name"]
		if mesh_val is not String:
			return "slot '%s' field 'mesh_name' must be String (got %s)" % [slot_key, type_string(typeof(mesh_val))]

		if not slot_data.has("colors"):
			return "slot '%s' missing required field 'colors'" % slot_key

		var colors_val: Variant = slot_data["colors"]
		if colors_val is not Dictionary:
			return "slot '%s' field 'colors' must be Dictionary (got %s)" % [slot_key, type_string(typeof(colors_val))]

	if snapshot.has(SNAPSHOT_SIZE_KEY):
		var size_val: Variant = snapshot[SNAPSHOT_SIZE_KEY]
		if size_val is not float and size_val is not int:
			return "field '%s' must be a number (got %s)" % [SNAPSHOT_SIZE_KEY, type_string(typeof(size_val))]

	return ""

func validate_mesh_name(slot: PartSlot, part: Part, mesh_name: Variant) -> bool:
	if mesh_name == null:
		return false
	if mesh_name is not String:
		return false
	if (mesh_name as String).is_empty():
		return false
	if mesh_name == no_mesh_name:
		return CLEARABLE_PARTSLOTS.has(slot)
	if mesh_name == part.mesh_name:
		return false
	if not RegistryLibrary.character_meshes.has_mesh(slot, mesh_name as String):
		return false
	
	return true

func validate_colors(part: Part, colors: Variant) -> bool:
	if colors == null:
		return false
	if colors is not ColorSet:
		return false
	if colors.equals(part.colors):
		return false
	return true
#===================================================================================#

# M & P
#===================================================================================#
func apply_remote_updates(remote_updates: Array) -> void:
	var updates: Array[UpdateData] = []
	for d in remote_updates:
		var colors: Variant = ColorSet.deserialize(d["colors"]) if d.has("colors") else null
		updates.append(UpdateData.new(d["slot"], d.get("mesh_name"), colors))
	update_parts(updates)

func update_parts(data: Array[UpdateData]) -> void:
	var changed_slots: Array[PartSlot] = []

	for update_data in data:
		var current_part = get_part(update_data.slot)
		if current_part == null:
			SweetLogger.error("CharacterConfig.update_parts: no part found for slot {0}", [update_data.slot], "CharacterConfig.gd", "update_parts")
			continue
		var did_change := false

		if validate_mesh_name(update_data.slot, current_part, update_data.mesh_name):
			assign_mesh_name(update_data.slot, update_data.mesh_name)
			did_change = true
		
		if validate_colors(current_part, update_data.colors):
			assign_colors(update_data.slot, update_data.colors)
			did_change = true
		
		if did_change:
			changed_slots.append(update_data.slot)

	if not changed_slots.is_empty():
		if IS_VERBOSE:
			SweetLogger.info("CharacterConfig.update_parts: emitting changed signal for slots {0}", [changed_slots], "CharacterConfig.gd", "update_parts")
		config_changed.emit(changed_slots)
#===================================================================================#
