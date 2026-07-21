class_name CommandRegistry
extends RefCounted

enum Command {
	# Connection
	CLIENT_READY,
	SESSION_PLAYERS_CHANGE,
	SESSION_END,
	# In Game
	SPAWN,
	DESPAWN,
	SYNC_STATE,
	SCENE_CHANGE,
	CHARACTER_CHANGE,
	INTERACT,
	CHAT,
}

static var _command_handlers := {
	Command.SCENE_CHANGE: SceneChangeHandler.new(),
	Command.CLIENT_READY: ClientReadyHandler.new(),
	Command.SESSION_END: SessionEndHandler.new(),
	Command.SPAWN: SpawnHandler.new(),
	Command.DESPAWN: DespawnHandler.new(),
	Command.SYNC_STATE: SyncStateHandler.new(),
	Command.CHARACTER_CHANGE: CharacterChangeHandler.new(),
	Command.INTERACT: InteractHandler.new(),
}

static func get_handler(command: CommandRegistry.Command) -> CommandHandler:
	return _command_handlers.get(command)