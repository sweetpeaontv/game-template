class_name Payload
extends RefCounted

func _fields() -> Array[String]:
	return []

func serialize() -> Dictionary:
	var data := {}
	for field in _fields():
		var val = get(field)
		if val != null:
			data[field] = val
	return data

static func _deserialize(target: Payload, d: Dictionary) -> Payload:
	for field in target._fields():
		if d.has(field):
			target.set(field, d[field])
	return target

static func deserialize(command: CommandRegistry.Command, d: Dictionary) -> Payload:
	match command:
		CommandRegistry.Command.SCENE_CHANGE:
			return SceneChange.from_dict(d)
		CommandRegistry.Command.CLIENT_READY:
			return ClientReady.from_dict(d)
		CommandRegistry.Command.SPAWN:
			return Spawn.from_dict(d)
		CommandRegistry.Command.DESPAWN:
			return Despawn.from_dict(d)
		CommandRegistry.Command.SYNC_STATE:
			return SyncState.from_dict(d)
		CommandRegistry.Command.CHARACTER_CHANGE:
			return CharacterChange.from_dict(d)
		CommandRegistry.Command.INTERACT:
			return Interact.from_dict(d)
		CommandRegistry.Command.CHAT:
			return Chat.from_dict(d)
	return Payload.new()

## Structural validation of this payload's own fields (types/required/ranges).
## Returns "ok" when well-formed, otherwise a human-readable reason.
## Semantic checks (registry existence, ownership, game state) belong in the CommandHandler.
func validate_shape() -> String:
	return "ok"

# PAYLOAD SUBCLASSES
#===================================================================================#
class SceneChange extends Payload:
	var scene_name: String

	static func create(new_scene_name: String) -> SceneChange:
		var new_payload: SceneChange = SceneChange.new()
		new_payload.scene_name = new_scene_name
		return new_payload

	func _fields() -> Array[String]:
		return ["scene_name"]

	static func from_dict(d: Dictionary) -> SceneChange:
		return Payload._deserialize(SceneChange.new(), d)

class ClientReady extends Payload:
	var snapshot: Dictionary
	var current_scene: String

	static func create(new_snapshot: Dictionary, new_current_scene: String) -> ClientReady:
		var p := ClientReady.new()
		p.snapshot = new_snapshot
		p.current_scene = new_current_scene
		return p

	func _fields() -> Array[String]:
		return ["snapshot", "current_scene"]

	func validate_shape() -> String:
		if snapshot is not Dictionary:
			return "snapshot must be a Dictionary"
		if current_scene is not String:
			return "current_scene must be a String"
		return "ok"

	static func from_dict(d: Dictionary) -> ClientReady:
		return Payload._deserialize(ClientReady.new(), d)

class Spawn extends Payload:
	var spawns: Array # wire dicts { entity: EntityTypeRegistry.EntityType, data: Dictionary }
	# data: { peer_id: int, position: Vector3, snapshot: Dictionary } (for spawning players)

	static func create(new_spawns: Array) -> Spawn:
		var new_payload: Spawn = Spawn.new()
		new_payload.spawns = new_spawns
		return new_payload

	func _fields() -> Array[String]:
		return ["spawns"]

	func validate_shape() -> String:
		if spawns is not Array:
			return "spawns must be an Array"
		for spawn in spawns:
			if spawn is not Dictionary:
				return "each spawn must be a Dictionary"
			if not spawn.has("entity_type"):
				return "spawn missing required field 'kind'"
			if not spawn.has("data"):
				return "spawn missing required field 'data'"
		return "ok"

	static func from_dict(d: Dictionary) -> Spawn:
		return Payload._deserialize(Spawn.new(), d)

class Despawn extends Payload:
	var despawns: Array # wire dicts { entity_type: EntityTypeRegistry.EntityType, data: Dictionary }
	# data: { peer_id: int } (for despawning players)

	static func create(new_despawns: Array) -> Despawn:
		var new_payload: Despawn = Despawn.new()
		new_payload.despawns = new_despawns
		return new_payload

	func _fields() -> Array[String]:
		return ["despawns"]

	func validate_shape() -> String:
		if despawns is not Array:
			return "despawns must be an Array"
		for despawn in despawns:
			if despawn is not Dictionary:
				return "each despawn must be a Dictionary"
			if not despawn.has("entity_type"):
				return "despawn missing required field 'entity_type'"
			if not despawn.has("data"):
				return "despawn missing required field 'data'"
		return "ok"

	static func from_dict(d: Dictionary) -> Despawn:
		return Payload._deserialize(Despawn.new(), d)

class SyncState extends Payload:
	## Batch of authoritative state snapshots. Each entry targets one registered node by [member key].
	## Wire dicts: { "target_key": int, "state": Dictionary }
	##
	## [member state] is opaque to the transport layer — the target node interprets it in
	## [method Node.apply_wire_snapshot]. Server-authored only (via [code]MessageRouter.notify[/code]).
	var updates: Array = []

	static func create(new_updates: Array) -> SyncState:
		var new_payload: SyncState = SyncState.new()
		new_payload.updates = new_updates
		return new_payload

	static func make_update(target_key: int, state: Dictionary) -> Dictionary:
		return { "target_key": target_key, "state": state }

	func _fields() -> Array[String]:
		return ["updates"]

	func validate_shape() -> String:
		if updates is not Array:
			return "updates must be an Array"
		if updates.is_empty():
			return "updates must not be empty"
		for update in updates:
			if update is not Dictionary:
				return "each update must be a Dictionary"
			if not update.has("target_key"):
				return "update missing required field 'target_key'"
			if update["target_key"] is not int:
				return "update 'target_key' must be an int"
			if not update.has("state"):
				return "update missing required field 'state'"
			if update["state"] is not Dictionary:
				return "update 'state' must be a Dictionary"
		return "ok"

	static func from_dict(d: Dictionary) -> SyncState:
		return Payload._deserialize(SyncState.new(), d)

class SessionEnd extends Payload:
	static func create() -> SessionEnd:
		var new_payload: SessionEnd = SessionEnd.new()
		return new_payload

	func _fields() -> Array[String]:
		return []

	static func from_dict(d: Dictionary) -> SessionEnd:
		return Payload._deserialize(SessionEnd.new(), d)

class CharacterChange extends Payload:
	## Array of wire dicts shaped {slot:int, mesh_name?:String, colors?:Dictionary}
	var updates: Array = []
	var size

	static func create(new_updates: Array = [], new_size = null) -> CharacterChange:
		assert(not new_updates.is_empty() or new_size != null,
		"CharacterChange payload must have at least one part update or a size")

		var new_payload: CharacterChange = CharacterChange.new()
		new_payload.updates = new_updates
		new_payload.size = new_size
		return new_payload

	## Builds one transport-safe update dict, serializing a [ColorSet] to a plain Dictionary.
	## [param colors] accepts a [ColorSet], an already-serialized Dictionary, or null.
	static func make_update(slot: int, mesh_name = null, colors = null) -> Dictionary:
		var update: Dictionary = {"slot": slot}
		if mesh_name != null:
			update["mesh_name"] = mesh_name
		if colors != null:
			update["colors"] = colors.serialize() if colors is ColorSet else colors
		return update

	static func parse_update(d: Dictionary) -> Dictionary:
		return {
			"slot": d["slot"],
			"mesh_name": d.get("mesh_name"),
			"colors": ColorSet.deserialize(d["colors"]) if d.has("colors") else null,
		}

	func _fields() -> Array[String]:
		return ["updates", "size"]

	func validate_shape() -> String:
		if updates is not Array:
			return "updates must be an Array"
		if updates.is_empty() and size == null:
			return "must contain at least one update or a size"

		for update in updates:
			if update is not Dictionary:
				return "each update must be a Dictionary"
			if not update.has("slot"):
				return "update missing required field 'slot'"
			if update["slot"] is not int:
				return "update 'slot' must be an int"
			if update.has("mesh_name") and update["mesh_name"] is not String:
				return "update 'mesh_name' must be a String"
			if update.has("colors") and update["colors"] is not Dictionary:
				return "update 'colors' must be a Dictionary"

		if size != null and size is not float and size is not int:
			return "size must be a number"

		return "ok"

	static func from_dict(d: Dictionary) -> CharacterChange:
		return Payload._deserialize(CharacterChange.new(), d)

# TODO: Actually implement this
class Interact extends Payload:
	# interaction type (OPERABLE, EXAMINABLE, PICKUPABLE)
	var interaction_type: InteractionTypes.InteractionType
	var action: int
	var target_key: int
	var data: Dictionary = {}

	static func create(
		new_interaction_type: InteractionTypes.InteractionType, 
		new_action: int, 
		new_target_key: int, 
		new_data: Dictionary = {}
	) -> Interact:
		var new_payload: Interact = Interact.new()
		new_payload.interaction_type = new_interaction_type
		new_payload.action = new_action
		new_payload.target_key = new_target_key
		new_payload.data = new_data
		return new_payload

	# GETTERS
	#===================================================================================#		
	func get_operable_action() -> InteractionTypes.OperableData.Action:
		assert(interaction_type == InteractionTypes.InteractionType.OPERABLE)
		return action as InteractionTypes.OperableData.Action
	
	func get_examinable_action() -> InteractionTypes.ExaminableData.Action:
		assert(interaction_type == InteractionTypes.InteractionType.EXAMINABLE)
		return action as InteractionTypes.ExaminableData.Action

	func get_target_state() -> String:
		return str(data.get("target_state", ""))
	#===================================================================================#

	func _fields() -> Array[String]:
		return ["interaction_type", "action", "target_key", "data"]

	func validate_shape() -> String:
		if interaction_type is not InteractionTypes.InteractionType:
			return "interaction_type must be a InteractionTypes.InteractionType"
		if action is not int:
			return "action must be an int"
		if target_key is not int:
			return "target_key must be an int"
		if data is not Dictionary:
			return "data must be a Dictionary"
		return "ok"

	static func from_dict(d: Dictionary) -> Interact:
		return Payload._deserialize(Interact.new(), d)

# TODO: Actually implement this
class Chat extends Payload:
	var message: String

	func _fields() -> Array[String]:
		return ["message"]

	static func from_dict(d: Dictionary) -> Chat:
		return Payload._deserialize(Chat.new(), d)
#===================================================================================#
