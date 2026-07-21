class_name CharacterChangeHandler
extends CommandHandler

const SCRIPT_NAME := "CharacterChangeHandler"
const MAX_SIZE := 1.15
const MIN_SIZE := 0.85

# VALIDATE
#===================================================================================#
func validate(message: Message) -> String:
	# shape has been validated within MessageRouter
	var payload: Payload.CharacterChange = message.payload

	for update in payload.updates:
		var slot: int = update["slot"]
		if not CharacterConfig.PartSlot.values().has(slot):
			return "unknown part slot '%s'" % str(slot)

		if update.has("mesh_name"):
			var mesh_err := _validate_mesh_name(slot, update["mesh_name"])
			if mesh_err != "ok":
				return mesh_err

		if update.has("colors"):
			var colors_err := _validate_colors(slot, update["colors"])
			if colors_err != "ok":
				return colors_err

	if payload.size != null:
		var size := float(payload.size)
		if size < MIN_SIZE or size > MAX_SIZE:
			return "size %s out of range [%s, %s]" % [size, MIN_SIZE, MAX_SIZE]

	return "ok"

## Mesh must exist in the slot's registry, with [code]empty_mesh[/code] allowed only on clearable slots.
func _validate_mesh_name(slot: int, mesh_name: String) -> String:
	if mesh_name.is_empty():
		return "mesh_name for slot '%s' must not be empty" % str(slot)

	if mesh_name == CharacterConfig.no_mesh_name:
		if not CharacterConfig.CLEARABLE_PARTSLOTS.has(slot):
			return "slot '%s' cannot be cleared" % str(slot)
		return "ok"

	if not RegistryLibrary.character_meshes.has_mesh(slot, mesh_name):
		return "unknown mesh '%s' for slot '%s'" % [mesh_name, str(slot)]

	return "ok"

## Each non-empty color key must be a known color in the registry's [code]retro_color_uvs[/code] map.
## TODO: tighten to per-color-type palettes/presets once those are defined.
func _validate_colors(slot: int, colors: Dictionary) -> String:
	var color_set := ColorSet.deserialize(colors)
	for color_type in color_set.colors:
		var key: String = color_set.colors[color_type]
		if key.is_empty():
			continue
		if not RegistryLibrary.colors.retro_color_uvs.has(key):
			return "unknown color '%s' for slot '%s'" % [key, str(slot)]

	return "ok"
#===================================================================================#

# ACCEPT
#===================================================================================#
func accept_response(message: Message) -> Array[Delivery]:
	return [
		Delivery.new(
			Message.new(
				message.actor_peer_id, 
				message.timestamp, 
				Message.MessageType.CONFIRM, 
				message.command, 
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			), 
			Delivery.Audience.ACTOR
		),
		Delivery.new(
			Message.new(
				message.actor_peer_id, 
				message.timestamp, 
				Message.MessageType.NOTIFY, 
				message.command, 
				message.payload,
				message.request_id,
				1, # NEED TO SETUP RESPONSE ID STUFF
			), 
			Delivery.Audience.OTHERS
		),
	]
#===================================================================================#

# REJECT
#===================================================================================#
#func reject_response(message: Message) -> Array[Delivery]:
#	return [
#		
#	]
#===================================================================================#

# APPLY
#===================================================================================#
func apply(message: Message) -> void:
	var payload: Payload.CharacterChange = message.payload
	if payload == null:
		return

	var config: CharacterConfig = PlayerUtils.get_player_config(message.actor_peer_id)
	if config == null:
		SweetLogger.warning(
			"no config for actor {0}; cannot apply character change",
			[message.actor_peer_id],
			SCRIPT_NAME,
			"apply",
		)
		return

	if not payload.updates.is_empty():
		config.apply_remote_updates(payload.updates)

	if payload.size != null:
		config.set_size(float(payload.size))
#===================================================================================#