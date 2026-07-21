class_name OperableGroup
extends Node

## Emitted when any bound [Operable] fires [signal Operable.operated].
signal child_operated(operable: Operable, interactor: Node3D, data: InteractionTypes.OperableData)

## When non-empty, only these operables are bound. When empty, [member search_root] is scanned.
@export var operables: Array[Operable] = []
@export var search_root: NodePath = NodePath(".")
@export var recursive: bool = true
@export var bind_on_ready: bool = true

var _operables: Array[Operable] = []
var _bound_connections: Dictionary = {}

# INIT
#===================================================================================#
func _ready() -> void:
	if bind_on_ready:
		bind_operables()
#===================================================================================#

# DESTRUCT
#===================================================================================#
func _exit_tree() -> void:
	unbind_operables()
#===================================================================================#

# PUBLIC API
#===================================================================================#
func bind_operables() -> void:
	unbind_operables()

	_operables = _resolve_operables()
	for operable in _operables:
		var bound := _on_operable_operated.bind(operable)
		operable.operated.connect(bound)
		_bound_connections[operable] = bound

func unbind_operables() -> void:
	for operable in _bound_connections:
		var bound: Callable = _bound_connections[operable]
		if is_instance_valid(operable) and operable.operated.is_connected(bound):
			operable.operated.disconnect(bound)
	_bound_connections.clear()
	_operables.clear()

func find_operables(root: Node) -> Array[Operable]:
	var result: Array[Operable] = []
	_collect_operables(root, result)
	return result

func get_operables() -> Array[Operable]:
	return _operables.duplicate()
#===================================================================================#

# INTERNALS
#===================================================================================#
func _resolve_operables() -> Array[Operable]:
	if not operables.is_empty():
		return _filter_valid_operables(operables)

	var root := get_node_or_null(search_root)
	if root == null:
		push_error("OperableGroup: search_root not found: %s" % [search_root])
		return []

	return find_operables(root)

func _filter_valid_operables(candidates: Array[Operable]) -> Array[Operable]:
	var result: Array[Operable] = []
	for operable in candidates:
		if operable != null and is_instance_valid(operable):
			result.append(operable)
	return result

func _collect_operables(node: Node, result: Array[Operable]) -> void:
	for child in node.get_children():
		if child is Operable:
			result.append(child)
		if recursive:
			_collect_operables(child, result)

func _on_operable_operated(
	interactor: Node3D,
	data: InteractionTypes.OperableData,
	operable: Operable,
) -> void:
	child_operated.emit(operable, interactor, data)
	_on_child_operated(operable, interactor, data)

## Override in subclasses to react to child operables (e.g. keypad digit entry).
func _on_child_operated(
	_operable: Operable,
	_interactor: Node3D,
	_data: InteractionTypes.OperableData,
) -> void:
	pass
#===================================================================================#
