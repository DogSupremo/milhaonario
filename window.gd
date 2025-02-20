extends Window
var pos
# Adicione no script da sua janela (window.gd)
func _ready():
	call_deferred("center_window")
	
func _process(delta: float):
	var screen_size = DisplayServer.window_get_size()
	var window_size = size
	position = (screen_size - window_size) / 2
	if position != pos:
		center_window()

func center_window():
	var screen_size = DisplayServer.window_get_size()
	var window_size = size
	position = (screen_size - window_size) / 2
	pos = position


func _on_shoot_button_pressed() -> void:
	visible = false
