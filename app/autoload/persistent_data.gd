extends Node

const SAVE_FORMAT_VERSION := 1
const SAVE_RELATIVE_PATH := "user://persistent_data.json"

const _KEY_VERSION := "format_version"
const _KEY_CHARACTER := "character"
const _KEY_GAMES_PLAYED := "games_played"

## Serializable character payload (same shape as [method CharacterConfig.to_snapshot]; hydrate before [method CharacterConfig.apply_snapshot]).
var character_snapshot: Dictionary = {}

## Total completed games / runs (wire your session-end hook here later).
var games_played: int = 0

func _ready() -> void:
	load_from_file()

func _exit_tree() -> void:
	save_to_file()

func load_from_file() -> bool:
	if not FileAccess.file_exists(SAVE_RELATIVE_PATH):
		_reset_to_defaults()
		return true

	var file := FileAccess.open(SAVE_RELATIVE_PATH, FileAccess.READ)
	if file == null:
		push_warning(
			"PersistentData: could not open %s — %s"
			% [SAVE_RELATIVE_PATH, error_string(FileAccess.get_open_error())]
		)
		_reset_to_defaults()
		return false

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		_reset_to_defaults()
		return true

	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		push_warning("PersistentData: JSON parse error — %s" % error_string(parse_err))
		_reset_to_defaults()
		return false

	var root: Variant = json.data
	if root is not Dictionary:
		push_warning("PersistentData: root JSON must be a Dictionary")
		_reset_to_defaults()
		return false

	_apply_loaded_document(root as Dictionary)
	return true

func save_to_file() -> bool:
	var document := {
		_KEY_VERSION: SAVE_FORMAT_VERSION,
		_KEY_CHARACTER: character_snapshot,
		_KEY_GAMES_PLAYED: games_played,
	}

	var json_text := JSON.stringify(document, "\t")
	var file := FileAccess.open(SAVE_RELATIVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"PersistentData: could not write %s — %s"
			% [SAVE_RELATIVE_PATH, error_string(FileAccess.get_open_error())]
		)
		return false

	file.store_string(json_text)
	file.close()
	return true

func _reset_to_defaults() -> void:
	character_snapshot = {}
	games_played = 0

func _apply_loaded_document(document: Dictionary) -> void:
	var ver: Variant = document.get(_KEY_VERSION, SAVE_FORMAT_VERSION)
	if ver is int and int(ver) != SAVE_FORMAT_VERSION:
		push_warning("PersistentData: unknown format_version %s — loading compatible fields only" % ver)

	var ch: Variant = document.get(_KEY_CHARACTER, {})
	if ch is Dictionary:
		character_snapshot = ch
	else:
		character_snapshot = {}

	var gp: Variant = document.get(_KEY_GAMES_PLAYED, 0)
	if gp is int or gp is float:
		games_played = int(gp)
	else:
		games_played = 0

# CHARACTER CONFIG
#===================================================================================#
func default_character_snapshot() -> Dictionary:
	var default_colors := ColorSet.new(
		"retro_stan_c2r1_pale_yellow",
		"retro_stan_c0r3_charcoal_blue",
		"retro_stan_c1r3_persimmon",
		"retro_stan_c4r9_deep_purple",
	).serialize()
	return {
		"size": 1.0,
		"HEAD": {
			"mesh_name": "m_head_1",
			"colors": default_colors,
		},
		"GLASSES": {
			"mesh_name": "glass__athletic_1",
			"colors": default_colors,
		},
		"HAIR": {
			"mesh_name": "m_hair__medium_1",
			"colors": default_colors,
		},
		"BEARD": {
			"mesh_name": "m_beard_1_1__beard",
			"colors": default_colors,
		},
		"TORSO": {
			"mesh_name": "m_torso__shirtless_0",
			"colors": default_colors,
		},
		"LEGS": {
			"mesh_name": "m_legs__pantless_0",
			"colors": default_colors,
		},
		"SHOES": {
			"mesh_name": "m_shoes__bare-feet_0",
			"colors": default_colors,
		},
	}

func get_character_snapshot() -> Dictionary:
	if character_snapshot.is_empty():
		return default_character_snapshot()
	return character_snapshot

func commit_character_snapshot(snapshot: Dictionary) -> void:
	character_snapshot = snapshot

func commit_from_config(config: CharacterConfig) -> void:
	commit_character_snapshot(config.to_snapshot())
#===================================================================================#
