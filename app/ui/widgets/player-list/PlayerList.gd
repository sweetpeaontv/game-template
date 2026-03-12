extends Node2D

@onready var player_container: VBoxContainer = $PlayerContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for player in Gnet.connected_players:
		add_player(str(player))

func add_player(player_name: String) -> void:
	var new_label: Label = Label.new()
	new_label.name = player_name
	new_label.text = player_name
	player_container.add_child(new_label)
