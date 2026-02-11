extends RefCounted
class_name Registry

# In order to keep keys deterministic between clients -
# nodes that are placed manually in the scene will provide a hashed key based on their path
# nodes that are spawned will require an id to be provided by the server and distributed to clients as part of the spawn flow

var _data: Dictionary = {}

func _init() -> void:
	pass

func add_entry(key: int, value: Variant) -> void:
	_data[key] = value

func get_entry(key: int) -> Variant:
	return _data.get(key)

func remove_entry(key: int) -> void:
	_data.erase(key)