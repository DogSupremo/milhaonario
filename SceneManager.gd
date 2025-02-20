extends Node2D
var GameManager = preload("res://GameManager.gd")

@export var PlayerScene: PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var index = 0
	for id in GameManager.Players:
		var currentPlayer = PlayerScene.instantiate()
		currentPlayer.name = str(id)
		currentPlayer.set_multiplayer_authority(id) # Importante!
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawn"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
		index += 1
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
