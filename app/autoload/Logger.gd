extends Node

## Global Logger singleton for consistent logging across the game.
## All logs are prefixed with [peer_id]: to identify which instance is logging.

func _get_peer_id() -> String:
	"""Get the current peer ID, or return a default identifier if not connected."""
	if multiplayer == null:
		return "DISCONNECTED"

	var peer_id = multiplayer.get_unique_id()
	if peer_id == 0:
		return "SERVER"

	return str(peer_id)

func _format_message(message: String, args: Array = []) -> String:
	"""Format message with optional arguments."""
	if args.is_empty():
		return message

	var formatted = message
	for i in range(args.size()):
		formatted = formatted.replace("{" + str(i) + "}", str(args[i]))

	return formatted

func log(message: String, args: Array = []) -> void:
	"""Basic log function with peer_id prefix."""
	var formatted = _format_message(message, args)
	print("[%s]: %s" % [_get_peer_id(), formatted])

func info(message: String, args: Array = []) -> void:
	"""Log an informational message."""
	var formatted = _format_message(message, args)
	print("[%s]: %s" % [_get_peer_id(), formatted])

func warning(message: String, args: Array = []) -> void:
	"""Log a warning message."""
	var formatted = _format_message(message, args)
	print("[%s]: [WARNING] %s" % [_get_peer_id(), formatted])

func error(message: String, args: Array = []) -> void:
	"""Log an error message."""
	var formatted = _format_message(message, args)
	print("[%s]: [ERROR] %s" % [_get_peer_id(), formatted])

func debug(message: String, args: Array = []) -> void:
	"""Log a debug message."""
	var formatted = _format_message(message, args)
	print("[%s]: [DEBUG] %s" % [_get_peer_id(), formatted])

