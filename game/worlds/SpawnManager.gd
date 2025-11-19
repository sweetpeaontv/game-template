extends Node3D
"""
SpawnManager - Defines spawn locations for a scene

Add this node to any scene that needs player spawn points.
Set spawn_points to an array of Vector3 positions, or add child
Marker3D nodes with the name "SpawnPoint" to define spawn locations.
"""

# Array of spawn positions (Vector3)
# If empty, will use child Marker3D nodes named "SpawnPoint"
var spawn_points: Array[Vector3] = [Vector3(0, 2, 0)]

func _ready() -> void:
	# If spawn_points is empty, look for child Marker3D nodes
	if spawn_points.is_empty():
		_find_spawn_markers()

func _find_spawn_markers() -> void:
	"""Find all child Marker3D nodes named 'SpawnPoint' and use their positions."""
	for child in get_children():
		if child is Marker3D and child.name.contains("SpawnPoint"):
			spawn_points.append(child.global_position)

func get_spawn_point(index: int) -> Vector3:
	"""Get spawn point at index, wrapping around if index exceeds array size."""
	if spawn_points.is_empty():
		push_warning("SpawnManager: No spawn points defined!")
		return Vector3.ZERO
	
	return spawn_points[index % spawn_points.size()]

func get_spawn_count() -> int:
	"""Get number of available spawn points."""
	return spawn_points.size()
