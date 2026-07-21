class_name PlayerEntityHandler
extends EntityTypeHandler

const LOCAL_SCRIPT_NAME := "PlayerEntityHandler"
const PLAYER_SCENE_PATH := "res://app/game/player/Player.tscn"

# SPAWN
#===================================================================================#
func validate_spawn(_data: Dictionary) -> String:
	var existing_player = PlayerUtils.find_player(_data["peer_id"])
	if existing_player:
		return "player already exists"
	# validate position
	if not _data.has("position"):
		return "position is required"
	# validate snapshot
	if not _data.has("snapshot"):
		return "snapshot is required"
	if not _data["snapshot"] is Dictionary:
		return "snapshot must be a Dictionary"
	return "ok"

func apply_spawn(_data: Dictionary) -> void:
	var peer_id = _data["peer_id"]
	var position = _data["position"]
	var snapshot = _data["snapshot"]

	var player_scene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("PlayerSpawnHandler: Failed to load player scene: " + PLAYER_SCENE_PATH)
		return

	var new_player = player_scene.instantiate()
	if not new_player:
		push_error("PlayerSpawnHandler: Failed to instantiate player scene")
		return

	new_player.on_init(peer_id, snapshot)

	PlayerUtils.add_player(new_player)

	new_player.global_position = position
#===================================================================================#

# DESPAWN
#===================================================================================#
func validate_despawn(_data: Dictionary) -> String:
	var existing_player = PlayerUtils.find_player(_data["peer_id"])
	if not existing_player:
		return "player does not exist"
	return "ok"

func apply_despawn(_data: Dictionary) -> void:
	PlayerUtils.remove_player(_data["peer_id"])
#===================================================================================#