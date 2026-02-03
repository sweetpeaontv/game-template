extends RigidBody3D

@onready var interactable: Node3D = $Interactable

func _ready() -> void:
	set_multiplayer_authority(1)

func _on_interact():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	apply_central_impulse(Vector3.UP * 2.5)
