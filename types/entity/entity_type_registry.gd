class_name EntityTypeRegistry
extends RefCounted

enum EntityType {
	PLAYER,
	NPC,
}

static var _handlers := {
	EntityType.PLAYER: PlayerEntityHandler.new(),
}

static func has_entity_type(entity_type: EntityType) -> bool:
	return _handlers.has(entity_type)

static func get_handler(entity_type: EntityType) -> EntityTypeHandler:
	return _handlers.get(entity_type)
