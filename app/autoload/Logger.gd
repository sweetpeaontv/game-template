extends Node

## Global Logger singleton for consistent logging across the game.
## All logs are prefixed with [peer_id]: to identify which instance is logging.
## Uses print_rich with colorized backgrounds for peer IDs and log types.

# ============================================================================
# COLORS
# ============================================================================

## Log type configuration with background color, message background color, and contrast text color
const LOG_TYPES = {
	"log": {
		"bg_color": "#2d2d2d",
		"message_bg_color": "#3d3d3d",
		"text_color": "#ffffff"
	},
	"info": {
		"bg_color": "#2563eb",
		"message_bg_color": "#3b82f6",
		"text_color": "#ffffff"
	},
	"warning": {
		"bg_color": "#fbbf24",
		"message_bg_color": "#fcd34d",
		"text_color": "#000000"
	},
	"error": {
		"bg_color": "#dc2626",
		"message_bg_color": "#ef4444",
		"text_color": "#ffffff"
	},
	"debug": {
		"bg_color": "#7c3aed",
		"message_bg_color": "#a78bfa",
		"text_color": "#ffffff"
	}
}

## Contrast text color that works on all backgrounds
const CONTRAST_TEXT = "#ffffff"

## Predefined colors for special peer IDs
const SPECIAL_PEER_COLORS = {
	"SERVER": {
		"bg_color": "#7c3aed",
		"text_color": "#ffffff"
	},
	"DISCONNECTED": {
		"bg_color": "#6b7280",
		"text_color": "#ffffff"
	}
}

const PEER_COLOR_PALETTE = [
	{"bg_color": "#10b981", "text_color": "#ffffff"},  # emerald green
	{"bg_color": "#8b5cf6", "text_color": "#ffffff"},  # violet purple
	{"bg_color": "#ec4899", "text_color": "#ffffff"},  # fuchsia pink
	{"bg_color": "#f97316", "text_color": "#ffffff"},  # orange
	{"bg_color": "#14b8a6", "text_color": "#ffffff"},  # teal
	{"bg_color": "#84cc16", "text_color": "#000000"},  # lime green
	{"bg_color": "#a855f7", "text_color": "#ffffff"},  # purple
	{"bg_color": "#22c55e", "text_color": "#ffffff"},  # green
	{"bg_color": "#9333ea", "text_color": "#ffffff"},  # deep purple
	{"bg_color": "#d946ef", "text_color": "#ffffff"},  # magenta
]

## Background color for the entire log line
const LOG_LINE_BG_COLOR = "#1a1a1a"

## Background color for the script/function name column
const SCRIPT_FUNCTION_BG_COLOR = "#4a5a6a"

# ============================================================================
# WIDTHS
# ============================================================================

## Column widths for alignment (in characters)
const PEER_ID_COLUMN_WIDTH = 10
const LOG_TYPE_COLUMN_WIDTH = 8
const SCRIPT_FUNCTION_COLUMN_WIDTH = 40

# ============================================================================
# CONFIGURATION
# ============================================================================

## Cache for peer ID colors to ensure consistency
var _peer_color_cache: Dictionary = {}

## Enable/disable showing script name and function name in logs
@export var SHOW_SCRIPT_NAME = true
@export var SHOW_FUNCTION_NAME = true

# ============================================================================
# GETTERS
# ============================================================================

func _get_peer_id() -> String:
	"""Get the current peer ID, or return a default identifier if not connected."""
	if multiplayer == null:
		return "DISCONNECTED"

	# Check if we're the server (server always has ID 1, but we check is_server() for clarity)
	if multiplayer.is_server():
		return "SERVER"

	# Get the unique ID (will be 1 for server, or random positive int > 1 for clients)
	var peer_id = multiplayer.get_unique_id()
	return str(peer_id)

func _get_peer_color_config(peer_id_str: String) -> Dictionary:
	"""Get color configuration for a peer ID string."""
	# Check special peer IDs first
	if SPECIAL_PEER_COLORS.has(peer_id_str):
		return SPECIAL_PEER_COLORS[peer_id_str]

	# Check cache
	if _peer_color_cache.has(peer_id_str):
		return _peer_color_cache[peer_id_str]

	# Generate consistent color based on peer ID
	# Try to parse the peer_id_str as a number
	var peer_id_num = peer_id_str.to_int()
	var color_index: int
	if peer_id_num > 0:
		color_index = peer_id_num % PEER_COLOR_PALETTE.size()
	else:
		# If parsing fails, use hash of the string for consistency
		var hash_value = peer_id_str.hash()
		color_index = abs(hash_value) % PEER_COLOR_PALETTE.size()

	var color_config = PEER_COLOR_PALETTE[color_index].duplicate()
	_peer_color_cache[peer_id_str] = color_config
	return color_config

# ============================================================================
# FORMATTERS
# ============================================================================

func _format_message(message: String, args: Array = []) -> String:
	"""Format message with optional arguments."""
	if args.is_empty():
		return message

	var formatted = message
	for i in range(args.size()):
		formatted = formatted.replace("{" + str(i) + "}", str(args[i]))

	return formatted

func _format_rich_text(text: String, bg_color: String, text_color: String) -> String:
	"""Format text with background and text colors using BBCode."""
	return "[bgcolor=%s][color=%s]%s[/color][/bgcolor]" % [bg_color, text_color, text]

func _format_space_with_bg(bg_color: String) -> String:
	"""Format a space character with a background color."""
	return "[bgcolor=%s] [/bgcolor]" % bg_color

func _get_padding(text_length: int, width: int) -> String:
	"""Get padding string for a given text length and target width."""
	if text_length >= width:
		return ""
	var padding = ""
	for i in range(width - text_length):
		padding += " "
	return padding

func _pad_text(text: String, width: int) -> String:
	"""Pad text to a specific width for column alignment."""
	return text + _get_padding(text.length(), width)

func _truncate_text(text: String, max_length: int) -> String:
	"""Truncate text to a maximum length."""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length)

# ============================================================================
# PRINT
# ============================================================================

func _print_rich_log(peer_id_str: String, log_type: String, message: String, script_name: String = "", function_name: String = "") -> void:
	"""Print a rich formatted log with peer ID and log type colors."""
	var peer_color = _get_peer_color_config(peer_id_str)
	var log_config = LOG_TYPES.get(log_type, LOG_TYPES["log"])

	# Use peer ID directly without "Peer" prefix
	var peer_label = peer_id_str
	var log_type_label = log_type.to_upper()

	# Pad peer ID column for alignment
	var peer_padded = _pad_text(peer_label, PEER_ID_COLUMN_WIDTH)

	# Format peer ID with its background color
	var peer_formatted = _format_rich_text(peer_padded, peer_color.bg_color, peer_color.text_color)

	# Format log type with its background color
	var log_type_padded = _pad_text(log_type_label, LOG_TYPE_COLUMN_WIDTH)
	var log_type_formatted = _format_rich_text(log_type_padded, log_config.bg_color, log_config.text_color)

	# Build the context string (script name and function name) combined in one column
	var context_string = ""
	var script_function_parts: Array[String] = []

	if SHOW_SCRIPT_NAME and script_name != "":
		var script_truncated = _truncate_text(script_name, 18)
		script_function_parts.append(script_truncated)

	if SHOW_FUNCTION_NAME and function_name != "":
		var function_truncated = _truncate_text(function_name, 20)
		script_function_parts.append(function_truncated)

	if not script_function_parts.is_empty():
		# Combine script and function names with a separator
		var combined = "::".join(script_function_parts)
		# Pad, then format with custom background color (so whitespace has background too)
		var combined_padded = _pad_text(combined, SCRIPT_FUNCTION_COLUMN_WIDTH)
		var combined_formatted = _format_rich_text(combined_padded, SCRIPT_FUNCTION_BG_COLOR, log_config.text_color)
		context_string = combined_formatted

	# Format message with text color only (no background)
	var message_formatted = "[color=%s]%s[/color]" % [log_config.text_color, message]

	# Format spaces with peer ID background color
	var peer_space = _format_space_with_bg(peer_color.bg_color)

	# Combine log type, context, and message with peer-colored spaces
	var log_and_message = log_type_formatted
	if context_string != "":
		log_and_message += peer_space + context_string
	log_and_message += peer_space + message_formatted

	# Create the full log line with peer-colored space between peer ID and log type+message
	var log_line = peer_formatted + peer_space + log_and_message
	var wrapped_line = "[bgcolor=%s]%s[/bgcolor]" % [LOG_LINE_BG_COLOR, log_line]

	print_rich(wrapped_line)

# ============================================================================
# CALLERS
# ============================================================================

func log(message: String, args: Array = [], script_name: String = "", function_name: String = "") -> void:
	"""Basic log function with peer_id prefix."""
	var formatted = _format_message(message, args)
	var peer_id_str = _get_peer_id()
	_print_rich_log(peer_id_str, "log", formatted, script_name, function_name)

func info(message: String, args: Array = [], script_name: String = "", function_name: String = "") -> void:
	"""Log an informational message."""
	var formatted = _format_message(message, args)
	var peer_id_str = _get_peer_id()
	_print_rich_log(peer_id_str, "info", formatted, script_name, function_name)

func warning(message: String, args: Array = [], script_name: String = "", function_name: String = "") -> void:
	"""Log a warning message."""
	var formatted = _format_message(message, args)
	var peer_id_str = _get_peer_id()
	_print_rich_log(peer_id_str, "warning", formatted, script_name, function_name)

func error(message: String, args: Array = [], script_name: String = "", function_name: String = "") -> void:
	"""Log an error message."""
	var formatted = _format_message(message, args)
	var peer_id_str = _get_peer_id()
	_print_rich_log(peer_id_str, "error", formatted, script_name, function_name)

func debug(message: String, args: Array = [], script_name: String = "", function_name: String = "") -> void:
	"""Log a debug message."""
	var formatted = _format_message(message, args)
	var peer_id_str = _get_peer_id()
	_print_rich_log(peer_id_str, "debug", formatted, script_name, function_name)
