extends Control

@onready var player_slots = [
	$Slot1,
	$Slot2,
	$Slot3,
	$Slot4
]

func _ready():
	GameManager.players_updated.connect(update_ui)
	await(2)
	update_ui()
	
	# Exibe o nome do jogador local imediatamente
	update_slot(0, GameManager.local_player_name)
	
	if multiplayer.is_server():
		$Start.visible = true
		$Start.pressed.connect(_on_start_button_pressed)  # Conecta o botão

func update_ui():
	# Limpa slots
	for slot in player_slots:
		slot.text = ""
	
	# Preenche slots
	var index = 0
	for player in GameManager.Players.values():
		if index < 4:
			player_slots[index].text = player.name
			index += 1
	
	# Atualiza status do botão
	if multiplayer.is_server():
		$Start.disabled = GameManager.Players.size() < 1

func _on_start_button_pressed():
	GameManager.start_game.rpc()  # Inicia o jogo para todos

func update_slot(slot_index, text):
	get_node("Slot" + str(slot_index + 1)).text = text
