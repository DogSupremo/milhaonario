extends Control

@onready var name_input = $Name
@onready var ip_input = $IPAddress

func _ready():
	$HostButton.pressed.connect(_on_host_pressed)
	$JoinButton.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	if $Name.text.strip_edges() == "":
		return
	
	GameManager.local_player_name = $Name.text
	GameManager.host_game()

func _on_join_pressed():
	if $Name.text.strip_edges() == "":
		return
	
	GameManager.local_player_name = $Name.text
	GameManager.join_game($IPAddress.text)
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://Lobby2.tscn")
