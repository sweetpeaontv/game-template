extends Node
"""
SpawnManager - Defines spawn locations for the game

Autoload singleton that manages spawn points.
Set spawn_points to an array of Vector3 positions.
"""

# Array of spawn positions (Vector3)
var spawn_points: Array[Vector3] = [Vector3(0, 2, 0)]

func get_spawn_point(index: int) -> Vector3:
	"""Get spawn point at index, wrapping around if index exceeds array size."""
	if spawn_points.is_empty():
		push_warning("SpawnManager: No spawn points defined!")
		return Vector3.ZERO
	
	return spawn_points[index % spawn_points.size()]

func get_spawn_count() -> int:
	"""Get number of available spawn points."""
	return spawn_points.size()
