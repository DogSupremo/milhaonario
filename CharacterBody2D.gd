extends CharacterBody2D

var tilemap: TileMap
var target_cell = Vector2i()
var speed = 20
var localization = 1
var jump_height = 5
var jump_duration = 0.25
var jump_time = 0.0
var is_moving = false
var flag_disable = false
var local_id  # Variável local para armazenar o ID do jogador
var next_turn
var decisao = false
var turn_player
var resposta = null
var is_sent = false
var nome = ""
var players_list = {}
var players_in_game = {}


var player_name = ""
@onready var game_manager = get_node("/root/GameManager")
var is_my_turn = false

@onready var map_data = preload("res://map.gd").new()
@onready var dict = map_data.dict

@onready var hud = get_node("/root/main/")
@onready var dice_button = hud.get_node("Dice")
@onready var dice_label = hud.get_node("DiceLabel")
@onready var money_label = hud.get_node("P1Money")
@onready var window = hud.get_node("Window")
@onready var window_v = hud.get_node("Victory")
@onready var gain_label = hud.get_node("P1Gain")
@onready var Nome_Label = $Label
@onready var timer = hud.get_node("Timer")
@onready var time_label = hud.get_node("Timer_Label")

@export var money = 500000 

func _ready():
	# Define o local_id do jogador local
	timer.wait_time = 6000.0  # 10 segundos
	timer.start()
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	window = hud.get_node("Window")
	if not hud.get_node("Window/comprar").pressed.is_connected(_on_comprar_pressed):
		hud.get_node("Window/comprar").pressed.connect(_on_comprar_pressed)
	if not hud.get_node("Window/nao_comprar").pressed.is_connected(_on_nao_comprar_pressed):
		hud.get_node("Window/nao_comprar").pressed.connect(_on_nao_comprar_pressed)
	if not hud.get_node("Minigame/shoot_button").pressed.is_connected(_on_shoot_pressed):
		hud.get_node("Minigame/shoot_button").pressed.connect(_on_shoot_pressed)
	local_id = multiplayer.get_unique_id()
	print("Local ID do jogador: ", local_id)
	
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Garante que o parent é um TileMap
	if is_multiplayer_authority():
		pass
	else:
		pass

	game_manager.connect("turn_changed", Callable(self, "_on_turn_changed"))
	tilemap = get_parent() as TileMap
	if not tilemap:
		push_error("Jogador deve ser filho de um TileMap!")
		return
	nome = Nome_Label.text
	# Configura posição inicial
	target_cell = tilemap.local_to_map(global_position)
	global_position = tilemap.map_to_local(target_cell)

	# Configura UI
	if multiplayer.has_multiplayer_peer(): #and is_multiplayer_authority():
		dice_button.visible = true
		dice_button.pressed.connect(_on_dice_pressed)  # Conecta o botão ao método
	else:
		dice_button.visible = false
		
func get_local_id():
	return local_id
	
func buscar_por_posição(posição: Vector2i) -> Dictionary:
	for região in dict:
		for local in dict[região]:
			if dict[região][local]["local"] == posição:
				return dict[região][local].duplicate()  # Retorna cópia para evitar modificação direta
	return {}

func _process(delta):
	if not timer.is_stopped():
		time_label.text = "Tempo restante: " + str(int(timer.time_left)) + "s"
	if flag_disable == true:
		gain_label = hud.get_node("P" + str(player_name) + "Gain")
		money_label = hud.get_node("P" + str(player_name) + "Money")
		
		if str(local_id) == str(next_turn): 
			dice_button.disabled = false
			dice_button.visible = true
		else:
			dice_button.disabled = true
			dice_button.visible = true
		flag_disable = false
	var target_position = tilemap.map_to_local(target_cell)
	global_position = global_position.lerp(target_position, speed * delta)

	if global_position.distance_to(target_position) < 1:
		global_position = target_position
		if jump_time <= 0 and is_moving:
			jump_time = jump_duration
		is_moving = false

	# Adiciona a chamada para a animação de pulo
	handle_jump_animation(delta)

func handle_jump_animation(delta):
	if jump_time > 0:
		var jump_offset = sin(jump_time * PI) * jump_height
		global_position.y -= jump_offset
		jump_time -= delta

func is_the_id(id_in):
	return str(id_in) == str(local_id)

@rpc("any_peer", "call_local", "reliable")
func move_player(direction, local_id):
	if target_cell == Vector2i(8, 0) and str(local_id) == str(next_turn):
		gain_money.rpc_id(local_id, 500000)
	target_cell += direction
	is_moving = true
	sync_is_moving.rpc(true)  # Sincroniza is_moving
	jump_time = jump_duration
	sync_jump_time.rpc(jump_time)  # Sincroniza jump_time
	update_localization()
	sync_position.rpc(target_cell)  # Sincroniza a posição após o movimento

func _on_dice_pressed():
	if multiplayer.has_multiplayer_peer():
		if str(game_manager.get_current_player_id()) == str(local_id): # Verifica se é o turno do jogador
			roll_dice()
		elif game_manager.current_turn_index == 0:
			roll_dice()
		else:
			pass

# Modifique a função roll_dice para enviar o resultado
func roll_dice():
	if str(local_id) == str(next_turn) and str(nome) == str(turn_player) or next_turn == null:
		print(verificar_monopólio())
		print("Rolando os dados para ", local_id)
		if is_moving: 
			return

		dice_button.disabled = true
		var total_steps = randi_range(1, 6) + randi_range(0, 6)
		
		# Envia o resultado dos dados para o GameManager
		if is_sent == false:
			if multiplayer.is_server():
				game_manager.submit_dice_result.rpc(local_id, total_steps)
			else:
				game_manager.submit_dice_result.rpc_id(1, local_id, total_steps)
			is_sent = true
		
		update_dice_ui.rpc(total_steps)
		if game_manager.turn_count != 0:
			print("O turno atual é ", game_manager.turn_count)
			walk_player.rpc(total_steps, local_id)
		

# --- Movimentação ---
@rpc("any_peer", "call_local", "reliable")
func walk_player(steps, local_id):
	if nome == game_manager.get_current_player_name(): 
		is_moving = true
		sync_is_moving.rpc(true)
		update_dice_ui.rpc(steps)
		for i in range(steps):
			print("Movendo passo: ", i + 1)
			var direction = get_movement_direction()
			move_player(direction, local_id)
			await get_tree().create_timer(0.2).timeout
		print("target: ", target_cell)
		if target_cell == Vector2i(1,1) or target_cell == Vector2i(1,-6) or target_cell == Vector2i(8,-6):
			sync_shoot_visible.rpc()
		if target_cell == Vector2i(1, -3) or target_cell == Vector2i(5, -6) or target_cell == Vector2i(8, -3) or target_cell == Vector2i(5, 1):
			var r = randi_range(0, 1)
			if r==0:
				r = -1
			set_money(int(hud.get_node("P" + str(game_manager.get_current_player_name()) + "Money").text.substr(1)) + (r * 50000), game_manager.get_current_player_name())
		
		var localizacao = buscar_por_posição(target_cell)
		if localizacao:
			print("Comprado? ",localizacao["comprado"])
			if hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text == "nenhum" and (int(hud.get_node("P" + str(GameManager.get_player_name_by_id(local_id)) + "Money").text.substr(1)) - localizacao["valordecompra"]) >= 0:
				var decisao2
				if local_id != 1:
					sync_window_visibility.rpc_id(local_id, true, local_id, "você quer comprar " + str(localizacao["nome"]) + " ?", target_cell, player_name, 0)
				else:
					decisao2 = await decisao_func("você quer comprar " + str(localizacao["nome"]) + " ?")
				print("decidido no turno do " + player_name + ": "+ str(decisao2))
				if decisao2 == true:
					print("tentando comprar")
					comprar_local(target_cell, game_manager.get_current_player_name())
			elif hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text == GameManager.get_player_name_by_id(local_id) and int(hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text)<4:
				var decisao2
				if local_id != 1:
					sync_window_visibility.rpc_id(local_id, true, local_id, "você quer evoluir " + str(localizacao["nome"]) + " para o rank" + str(int(localizacao["nível_de_construção"]) + 1) + "?", target_cell, player_name, 1)
				else:
					decisao2 = await decisao_func("você quer evoluir " + str(localizacao["nome"]) + " para o rank" + str(int(localizacao["nível_de_construção"]) + 1) + "?")
				print("decidido no turno do " + player_name + ": "+ str(decisao2))
				if decisao2 == true:
					print("tentando evoluir")
					construir(target_cell, game_manager.get_current_player_name())
			else:
				var n = hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text
				var a = hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "A").text
				if GameManager.get_player_name_by_id(local_id) != n and n!= "nenhum":
					send_money(GameManager.get_player_name_by_id(local_id), n, int(a.substr(1)))
					if (int(hud.get_node("P" + str(GameManager.get_player_name_by_id(local_id)) + "Money").text.substr(1)) - int(a.substr(1))) <= 0:
						GameManager.remove_player_from_turn_order(local_id)
						falencia.rpc(local_id)
						
						print(local_id, " morreu :(")
		update_dice_ui.rpc("")
		is_moving = false
		sync_is_moving.rpc(false)
		
		# Avança o turno após completar o movimento
		if multiplayer.is_server():
			game_manager.advance_turn()

@rpc("any_peer", "call_local", "reliable")
func update_dice_ui(value):
	dice_label.text = str(value)
	if str(value) == "":
		dice_button.disabled = false  # Reabilita o botão após o movimento

func get_movement_direction():
	match localization:
		1: return Vector2i(-1, 0)
		2: return Vector2i(0, -1)
		3: return Vector2i(1, 0)
		4: return Vector2i(0, 1)
	return Vector2i.ZERO

func update_localization():
	var new_loc = localization
	if target_cell == Vector2i(8, 1): new_loc = 1
	elif target_cell == Vector2i(1, 1): new_loc = 2
	elif target_cell == Vector2i(1, -6): new_loc = 3
	elif target_cell == Vector2i(8, -6): new_loc = 4
	
	if new_loc != localization:
		localization = new_loc
		sync_localization.rpc(new_loc)

# --- Sistema de Dinheiro ---
func set_money(value, pname):
	money = value
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		update_money_label(pname)
	sync_money.rpc(value, pname)

@rpc("any_peer", "reliable")
func sync_money(value, pname):
	print("syncando o dinheiro de " + str(pname) + " no id " + str(local_id))
	money = value
	money_label = hud.get_node("P" + str(pname) + "Money")
	money_label.text = "$" + str(value)

func update_money_label(pname):
	money_label = hud.get_node("P" + str(pname) + "Money")
	money_label.text = "$" + str(money)

@rpc("any_peer", "call_local", "reliable")
func gain_money(value):
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		set_money(money + int(value), turn_player)
		
		
@rpc("any_peer", "call_local", "reliable")
func send_money(emissor, receptor, value):
	var receptor_money = int(hud.get_node("P" + str(receptor) + "Money").text.substr(1))
	var emissor_money = int(hud.get_node("P" + str(emissor) + "Money").text.substr(1))
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		print("ok, o " + str(emissor) + " deu pro " + str(receptor))
		set_money(emissor_money - value, emissor)
		set_money(receptor_money + value, receptor)
		
		

@rpc("call_local", "reliable")
func show_gain_effect(value):
	gain_label.text = "+$" + str(value)
	await get_tree().create_timer(1.0).timeout
	gain_label.text = ""

# --- Sincronização ---
@rpc("any_peer", "reliable")
func sync_position(cell_pos):
	target_cell = cell_pos
	global_position = get_parent().map_to_local(target_cell)

@rpc("any_peer", "reliable")
func sync_localization(new_loc):
	localization = new_loc

# --- Configuração Inicial ---
@rpc("any_peer", "reliable")
func setup_player(start_pos: Vector2i, p_name: String):
	global_position = get_parent().map_to_local(start_pos)
	target_cell = start_pos
	player_name = p_name

@rpc("any_peer", "call_local", "reliable")
func sync_jump_time(time):
	jump_time = time

@rpc("any_peer", "call_local", "reliable")
func sync_is_moving(moving):
	is_moving = moving

@rpc("any_peer", "reliable")
func sync_window_visibility(visible: bool, id_local, texto, target, p, ocasiao):
	print("todo dia isso :(")
	resposta = null
	print(str(id_local) + " " + str(next_turn))
	if str(id_local) == str(next_turn):
		window.visible = visible
		window.get_node("Label").text = texto

		
		while resposta == null:
			await get_tree().create_timer(0.5).timeout
			if window.get_node("Label").text == "0":
				resposta = false
			elif window.get_node("Label").text == "1":
				resposta = true
		print("respondido ", resposta)
		if resposta:
			if ocasiao == 0:
				print("tentando comprar para ", GameManager.get_player_name_by_id(id_local))
				comprar_local(target, GameManager.get_player_name_by_id(id_local))
			elif ocasiao == 1:
				print("tentando evoluir")
				construir(target, GameManager.get_player_name_by_id(id_local))
				

@rpc("any_peer", "call_local", "reliable")
func sync_window_v_visibility(visible: bool):
	# Cria uma lista de jogadores com seus nomes e valores de dinheiro
	var players_with_money = []

	for player_id in players_list.keys():
		var player_name = players_list[player_id]["name"]
		var money_text = hud.get_node("P" + player_name + "Money").text
		var money_value = int(money_text.substr(1))  # Remove o "$" e converte para inteiro
		players_with_money.append({"name": player_name, "money": money_value})

	# Ordena a lista do maior para o menor valor de dinheiro
	players_with_money.sort_custom(func(a, b): return a["money"] > b["money"])

	# Atualiza os nós da janela com os valores ordenados
	for i in range(players_with_money.size()):
		var player = players_with_money[i]
		var display_text = player["name"] + " $" + str(player["money"])
		window_v.get_node(str(i + 1)).text = display_text
	
	# Exibe a janela
	resposta = null
	window_v.visible = true


@rpc("any_peer", "call_local", "reliable")
func update_turn_display():
	if is_the_id(game_manager.get_current_player_id()):
		dice_button.disabled = false
		dice_button.visible = true
	else:
		dice_button.disabled = true
		dice_button.visible = true
		
@rpc("any_peer", "call_local", "reliable")
func sync_turn(turn, player, pname):
	turn_player = player
	next_turn = turn
	if str(turn) == str(local_id):
		player_name = pname
	flag_disable = true
	
@rpc("any_peer", "call_local", "reliable")
func sync_map(d):
	var caminho
	var dono
	var aluguel
	var nivel
	dict = d
	for região in dict:
		for local in dict[região]:
				caminho = hud.get_node("Map/" + str(dict[região][local]["macro_região"]) + "/")
				dono = caminho.get_node(str(dict[região][local]["nome"]) + "D")
				aluguel = caminho.get_node(str(dict[região][local]["nome"]) + "A")
				nivel = caminho.get_node(str(dict[região][local]["nome"]) + "C")
				if dict[região][local]["dono"] != "":
					dono.text = dict[região][local]["dono"]
					aluguel.text = "$" + str((dict[região][local]["aluguel"] * dict[região][local]["valorização"] * 2) + (dict[região][local]["aluguel"] * dict[região][local]["nível_de_construção"] * 2))
					nivel.text = str(dict[região][local]["nível_de_construção"])
					
func _on_peer_disconnected(id_fal):
	print("[2] Jogador desconectado: ", id_fal)
	var r_id = game_manager.get_current_player_id()
	disconnect_id.rpc(id_fal)
	if str(id_fal) == str(r_id):
		print("passando o turn, já que nós temos: " + " " + str(id_fal) + " " + str(id_fal))
		GameManager.advance_turn()
	
	
@rpc("any_peer", "call_local", "reliable")
func disconnect_id(id_fal):
	if id_fal!=local_id:
		print("Para o id: " + str(local_id) + " P" + str(GameManager.get_player_name_by_id(id_fal)))
		var name_f = hud.get_node("P" + str(GameManager.get_player_name_by_id(id_fal)))
		name_f.text = str(GameManager.get_player_name_by_id(id_fal)) + " (desconectado)"
		hud.get_node("TileMap/" + str(id_fal)).visible = false
		var n_players = count_players(hud.get_node("TileMap"))
		print("número de joagdores restantes: " + str(n_players))
		players_in_game.erase(id_fal)
		if n_players <= 1:
			("chamada de vitoria")
			sync_window_v_visibility.rpc(true)
		for região in dict:
			for local in dict[região]:
				var localizacao = dict[região][local]
				if hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text == GameManager.get_player_name_by_id(id_fal):
					dict[região][local]["dono"] = "nenhum"
					dict[região][local]["comprado"] = false 
					dict[região][local]["nível_de_construção"] = 0
		sync_map.rpc(dict)
					
@rpc("any_peer", "call_local", "reliable")
func falencia(id_fal):
	var name_f = hud.get_node("P" + str(GameManager.get_player_name_by_id(id_fal)))
	name_f.text = name_f.text + " (falido)"
	hud.get_node("TileMap/" + str(id_fal)).visible = false
	hud.get_node("P" + GameManager.get_player_name_by_id(id_fal) + "Money").text = "$0"
	var n_players = count_players(hud.get_node("TileMap"))
	players_in_game.erase(id_fal)
	print("número de joagdores restantes: " + str(n_players))
	if n_players <= 1:
			("chamada de vitoria")
			sync_window_v_visibility.rpc(true)
	for região in dict:
		for local in dict[região]:
			var localizacao = dict[região][local]
			if hud.get_node("Map/" + str(localizacao["macro_região"]) + "/" + str(localizacao["nome"]) + "D").text == GameManager.get_player_name_by_id(id_fal):
				dict[região][local]["dono"] = "nenhum"
				dict[região][local]["comprado"] = false 
				dict[região][local]["nível_de_construção"] = 0
	sync_map.rpc(dict)
	


func _on_turn_changed():
	sync_turn.rpc(game_manager.get_current_player_id(), game_manager.get_current_player_name(), game_manager.get_player_name_by_id(game_manager.get_current_player_id()))
	print(game_manager.get_current_player_name())
	dice_label.text = ""

class SignalAwaiter:
	var signals: Array
	var awaited_node: Node = null

func decisao_func(texto):
	window.visible = visible
	window.get_node("Label").text = texto

	resposta = null
	
	while resposta == null:
		await get_tree().create_timer(0.5).timeout
		if window.get_node("Label").text == "0":
			resposta = false
		elif window.get_node("Label").text == "1":
			resposta = true
	
	print("respondido ", resposta)
	return resposta
	
func sync_resposta(r):
	resposta = r


func _on_nao_comprar_pressed():
	if str(local_id) == str(self.name):
		window.visible = false
		window.get_node("Label").text = "0"
		print("fecha")
		resposta = false
		sync_resposta(resposta)


func _on_comprar_pressed() -> void:
	if str(local_id) == str(self.name):
		window.visible = false
		window.get_node("Label").text = "1"
		print("sim")
		resposta = true
		sync_resposta(resposta)
		
func comprar_local(posição: Vector2i, nome_jogador: String) -> bool:
	("chegou nessa função de compra")
	for região in dict:
		for local in dict[região]:
			if dict[região][local]["local"] == posição:
				if not dict[região][local]["comprado"]:
					dict[região][local]["comprado"] = true
					dict[região][local]["dono"] = nome_jogador
					set_money(int(hud.get_node("P" + str(nome_jogador) + "Money").text.substr(1)) -dict[região][local]["valordecompra"],nome_jogador)
					sync_map.rpc(dict)
					return true
	return false
	
func construir(posição: Vector2i, nome_jogador: String) -> bool:
	for região in dict:
		for local in dict[região]:
			if dict[região][local]["local"] == posição:
				if dict[região][local]["nível_de_construção"] < 4:
					dict[região][local]["nível_de_construção"] += 1
					set_money(int(hud.get_node("P" + str(nome_jogador) + "Money").text.substr(1)) -dict[região][local]["preco_de_upagrade" + str(dict[região][local]["nível_de_construção"])],nome_jogador)
					sync_map.rpc(dict)
					return true
	return false


func verificar_monopólio() -> Array:
	var monopólios = []
	# Verifica monopólios existentes
	for região in dict:
		var dono = ""
		var todos_comprados = true
		# Verifica se todos os locais da região pertencem ao mesmo jogador
		for local in dict[região]:
			var d = hud.get_node("Map/" + str(dict[região][local]["macro_região"]) + "/" + str(dict[região][local]["nome"]) + "D").text
			if d == "nenhum":
				todos_comprados = false
				break
			if dono == "":
				dono = d
			elif dono != d:
				todos_comprados = false
				break
		if todos_comprados:
			monopólios.append({"região": região, "dono": dono})

	# Verifica condições de vitória
	var jogadores_monopolios = {}

	# Agrupa monopólios por jogador
	for m in monopólios:
		var jogador = m["dono"]
		if not jogador in jogadores_monopolios:
			jogadores_monopolios[jogador] = []
		jogadores_monopolios[jogador].append(m["região"])

	# Verifica cada jogador
	for jogador in jogadores_monopolios:
		var regioes = jogadores_monopolios[jogador]

		# Condição 1: Mais de 3 monopólios
		if regioes.size() > 3:
			print(jogador + " venceu!")
			continue

		# Condição 2: Pares específicos ou R7
		var tem_vitoria = false
		var pares_vitoria = [
			["R1", "R2"],
			["R3", "R4"],
			["R5", "R6"],
			["R7", "R8"],
		]
		
		# Verifica pares
		for par in pares_vitoria:
			if regioes.has(par[0]) and regioes.has(par[1]):
				tem_vitoria = true
				break
		
		if tem_vitoria:
			print(jogador + " venceu!")
			sync_window_v_visibility.rpc(true)

	return monopólios
	
func count_players(tilemap: TileMap):
	var total_bodies = 0
	var visiveis = 0

	# Itera por todos os nós filhos do TileMap
	for child in tilemap.get_children():
		# Verifica se o nó é do tipo Body2D
		if child is CharacterBody2D:
			total_bodies += 1
			
			# Verifica se o body está visível
			if child.visible:
				visiveis += 1

	return visiveis
	
# Função para atualizar a lista de jogadores
func update_players_list(new_players):
	players_list = new_players
	players_in_game = new_players
	print("Lista de jogadores atualizada no jogador ", name, ": ", players_list)
	
@rpc("any_peer", "call_local", "reliable")
func sync_shoot_visible():
	print("id do jogador: ", local_id)
	print("turno: ", players_in_game)
	print(local_id in players_in_game)

	if local_id in players_in_game:
		hud.get_node("Minigame").visible = true
	
@rpc("any_peer", "call_local", "reliable")
func sync_shoot_winner_visible(winner):
	hud.get_node("Minigame_Winner/Label").text = "O vencedor foi: " + str(winner)
	hud.get_node("Minigame_Winner").visible = true	

func _on_shoot_pressed():
	if str(local_id) == str(self.name):
		print("shoot pressionado")
		sync_shoot.rpc(GameManager.get_player_name_by_id(local_id))

@rpc("any_peer", "call_local", "reliable")
func sync_shoot(nome_vencedor):
	print("esse cara ganhou: ", nome_vencedor)
	hud.get_node("Minigame").visible = false
	sync_shoot_winner_visible.rpc(nome_vencedor)
	if GameManager.get_player_name_by_id(local_id) == str(nome_vencedor):
		set_money(int(hud.get_node("P" + str(nome_vencedor) + "Money").text.substr(1)) + 100000, nome_vencedor)
		
func _on_timer_timeout():
	time_label.text = "Tempo acabou!"
	sync_window_v_visibility.rpc(true)
	
