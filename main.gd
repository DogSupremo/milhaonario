extends Node2D

@onready var tilemap = $TileMap
var local_id 

func _ready():
	spawn_players()

func spawn_players():
	var i = 0
	for p in GameManager.Players:
		i = i+1
		
		var Original_Nome_Label = get_node("P" + str(i))
		var Nome_Label = Original_Nome_Label.duplicate()
		Nome_Label.name = "P" + GameManager.Players[p]["name"]  # Defina o novo nome aqui
		Nome_Label.text = GameManager.Players[p]["name"]
		Nome_Label.visible = true
		
		if Original_Nome_Label:
			Original_Nome_Label.queue_free()
		add_child(Nome_Label)
		
		Original_Nome_Label = get_node("P" + str(i) + "Gain")
		Nome_Label = Original_Nome_Label.duplicate()
		Nome_Label.name = "P" + GameManager.Players[p]["name"] + "Gain"  # Defina o novo nome aqui
		Nome_Label.visible = false
		if Original_Nome_Label:
			Original_Nome_Label.queue_free()
		add_child(Nome_Label)
		
		Original_Nome_Label = get_node("P" + str(i) + "Money")
		Nome_Label = Original_Nome_Label.duplicate()
		Nome_Label.name = "P" + GameManager.Players[p]["name"] + "Money"  # Defina o novo nome aqui
		Nome_Label.visible = true
		if Original_Nome_Label:
			Original_Nome_Label.queue_free()
		add_child(Nome_Label)
		
		
		
		var player_scene = preload("res://character_body_2d.tscn")
		var player = player_scene.instantiate()
		
		player.get_node("Label").text = GameManager.Players[p]["name"]
		var id = p
		# Configuração inicial
		player.name = str(id)
		player.update_players_list(GameManager.Players)
		player.position = tilemap.map_to_local(Vector2i(8, 1))  # Posição inicial no grid
		tilemap.add_child(player)  # Adiciona como filho do TileMap
		
		# Define autoridade multiplayer
		print("O id de entrada é ", str(multiplayer.get_unique_id()))
		local_id = multiplayer.get_unique_id()
		if str(id) == str(multiplayer.get_unique_id()):
			player.set_multiplayer_authority(id)

func _on_dice_pressed():
	print("Lançando dados...")
