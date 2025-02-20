extends TileMap

enum layers{
	level0 = 0,
	level1 = 1,
	level2 = 2,
}

const green_block_atlas_pos = Vector2i(2, 0)
const blue_block_atlas_pos = Vector2i(0, 0)
const boundary_atlas_pos = Vector2i(0, 1)
const main_source = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#self.set_cell(1, Vector2i(6, 0),0,Vector2i(2,0),0)
	place_boundaries()
	spawn_players()
	
	

func spawn_players():
	pass
	
func place_boundaries():
	var offsets = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(-1, 0),
	]
	var used = get_used_cells(layers.level0)
	for spot in used:
		for offset in offsets:
			var current_spot = spot + offset
			#this spot is empty
			if get_cell_source_id(layers.level0, current_spot) == -1:
				set_cell(layers.level0, current_spot, main_source, boundary_atlas_pos)
	

func place_platform():
	for y in range(3):
		for x in range(3):
			set_cell(layers.level0, Vector2i(2 + x, 2 + y), main_source, green_block_atlas_pos)
	
	#set_cell(layers.level1, Vector2i(2, 2), main_source, blue_block_atlas_pos)
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_dice_pressed() -> void:
	pass # Replace with function body.


func disconnect_to_lobby():
	if multiplayer.multiplayer_peer != null:
		# Encerra a conexão
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	# Volta para o Lobby 1
	get_tree().change_scene_to_file("res://Lobby1.tscn")
	
func _on_disconnect_button_pressed():
	print("desconectado")
	get_node("/root/GameManager").disconnect_to_lobby()
