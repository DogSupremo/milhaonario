extends Node

var Players = {}
var player_money = {}  # Dicionário que mapeia o nome do jogador para o dinheiro
var turns = {}
var max_players = 4
var peer = ENetMultiplayerPeer.new()
var local_player_name = ""
var local_id  # Agora é uma variável local para cada instância do GameManager
signal turn_changed
var flag_ordem = false
var hud 

var turn_order = []  # Vetor que armazena a ordem dos jogadores
var current_turn_index = 0  # Índice do jogador atual
var turn_count = 1  # Contador de turnos
var dice_results = {}  # Armazena os resultados dos dados de cada jogador

signal players_updated

func _ready():
	# Obtém o local_id do jogador local
	local_id = multiplayer.get_unique_id()
	print("Local ID do jogador: ", local_id)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Configura o Timer para exibir os jogadores periodicamente
	var timer = Timer.new()
	timer.wait_time = 5  # Intervalo de 5 segundos
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_timer_timeout():
	pass

func host_game(port = 9999):
	var err = peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		print("Servidor hospedado. Unique ID do host: ", multiplayer.get_unique_id())
		add_player(multiplayer.get_unique_id(), local_player_name)
		get_tree().change_scene_to_file("res://Lobby2.tscn")
	else:
		print("Erro ao hospedar: ", err)

func join_game(ip, port = 9999):
	var err = peer.create_client(ip, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		print("Cliente conectado. Unique ID do cliente: ", multiplayer.get_unique_id())
	else:
		print("Erro ao conectar: ", err)

@rpc("any_peer")
func add_player(id, player_name):
	if multiplayer.is_server():
		Players[id] = {
			"name": player_name,
			"ready": false
		}
		# Adiciona o jogador ao dicionário player_money com dinheiro inicial 0
		player_money[player_name] = 0
		sync_players.rpc(Players)

@rpc("call_local", "reliable")
func sync_players(new_players):
	Players = new_players
	players_updated.emit()

func _on_peer_connected(id):
	print("Jogador conectado: ", id)
	request_player_name.rpc_id(id)

@rpc("authority")
func request_player_name():
	submit_player_name.rpc_id(1, local_player_name)

@rpc("any_peer")
func submit_player_name(player_name):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Verifica se o jogador já existe no dicionário
	if not Players.has(sender_id):
		# Se não existir, adiciona o jogador ao dicionário
		Players[sender_id] = {
			"name": player_name,
			"ready": false
		}
		# Adiciona o jogador ao dicionário player_money com dinheiro inicial 0
		player_money[player_name] = 0
	else:
		# Se existir, apenas atualiza o nome
		Players[sender_id].name = player_name
	
	# Sincroniza a lista de jogadores com todos os clientes
	sync_players.rpc(Players)

@rpc("authority", "call_local", "reliable")
func start_game():
	get_tree().change_scene_to_file("res://main.tscn")
	print("Jogo iniciado. Primeiro jogador:", get_current_player_name())

@rpc("authority", "call_local", "reliable")
func spawn_player(id):
	var player_scene = preload("res://character_body_2d.tscn")
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	get_tree().root.add_child(player)

	# Posição inicial baseada no ID
	var start_pos = Vector2i((id % 4) * 100, 0)
	player.global_position = start_pos

func _on_peer_disconnected(id):
	if id == 1:  # ID 1 é sempre o host
		disconnect_to_lobby()

func disconnected(id):
	print("Jogador desconectado: ", id)
	if multiplayer.is_server():
		var player_name = Players[id].name
		Players.erase(id)
		remove_player_from_turn_order(id)
		player_money.erase(player_name)  # Remove o jogador do dicionário player_money
		sync_players.rpc(Players)

func order_players_by_dice(dice_results):
	# Converte o dicionário de resultados em um array de pares [id, valor]
	var results_array = []
	for player_id in dice_results:
		results_array.append([player_id, dice_results[player_id]])
	
	# Ordena o array pelo valor dos dados (em ordem decrescente)
	results_array.sort_custom(func(a, b): return a[1] > b[1])
	
	# Extrai a ordem dos jogadores
	turn_order = []
	for result in results_array:
		turn_order.append(result[0])
	
	print("Ordem dos turnos definida:", turn_order)

func advance_turn():
	if turn_order.is_empty():
		print("Erro: A ordem dos turnos não foi definida.")
		return
	
	# Avança para o próximo jogador
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	
	# Incrementa o contador de turnos se voltar ao primeiro jogador
	if current_turn_index == 0:
		turn_count += 1
	emit_signal("turn_changed")
	print("Turno avançado. Jogador atual:", get_current_player_name())
	
func get_player_id_by_name(player_name: String) -> int:
	# Percorre o dicionário de jogadores
	for player_id in Players:
		if Players[player_id].name == player_name:
			return player_id  # Retorna o ID se o nome for encontrado
	return -1  # Retorna -1 se o nome não for encontrado
	
func get_player_name_by_id(player_id):
	# Percorre o dicionário de jogadores
	for id in Players:
		if id == player_id:
			return Players[id].name # Retorna o ID se o nome for encontrado
	return ""  # Retorna -1 se o nome não for encontrado
	
func get_current_player_name():
	if turn_order.is_empty():
		return "Nenhum jogador"
	
	var current_player_id = turn_order[current_turn_index]
	if Players.has(current_player_id):
		return Players[current_player_id].name
	else:
		return "Jogador desconhecido"

func get_current_player_id():
	if turn_order.is_empty():
		return "Nenhum jogador"
	
	var current_player_id = turn_order[current_turn_index]
	if Players.has(current_player_id):
		return current_player_id
	else:
		return "Jogador desconhecido"

@rpc("any_peer", "call_local", "reliable")
func submit_dice_result(player_id, dice_value):
	if multiplayer.is_server():
		dice_results[player_id] = dice_value
		print(dice_results, " size: ", dice_results.size())
		
		# Se todos os jogadores tiverem enviado seus resultados, ordena os turnos
		if dice_results.size() == Players.size():
			order_players_by_dice(dice_results)
			turn_count = 2
			emit_signal("turn_changed")

# Função para retornar o dicionário player_money
func get_player_money():
	return player_money
	
	
func remove_player_from_turn_order(player_id: int):
	if player_id in turn_order:
		var index_to_remove = turn_order.find(player_id)

		# Ajusta o índice do turno atual se necessário
		if current_turn_index >= index_to_remove:
			current_turn_index = max(0, current_turn_index - 1)

		# Remove o jogador da ordem de turnos
		turn_order.erase(player_id)

		# Atualiza o índice se a lista ficar vazia
		if turn_order.is_empty():
			current_turn_index = 0
			turn_count = 1
		else:
			# Garante que o índice atual não ultrapasse o novo tamanho
			current_turn_index = current_turn_index % turn_order.size()

		print("Jogador ", player_id, " removido da ordem de turnos.")
		emit_signal("turn_changed")
	else:
		print("Jogador ", player_id, " não encontrado na ordem de turnos.")
		
func get_ativos():
	return turn_order.size()

func disconnect_to_lobby():
	if multiplayer.multiplayer_peer != null:
		# Encerra a conexão
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	# Volta para o Lobby 1
	get_tree().change_scene_to_file("res://Lobby1.tscn")
	
