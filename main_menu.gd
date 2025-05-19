extends Control

@onready var slider = $Sound/Setting/Volum
@onready var panel = $Sound/Setting

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$HowToplay.visible = false
	slider.min_value = -40
	slider.max_value = 20
	slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	slider.connect("value_changed", _on_volum_changed)
	panel.visible = false

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")  # 게임 본편으로 이동


func _on_how_to_play_pressed() -> void:
	$HowToplay.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_close_pressed() -> void:
	$HowToplay.visible = false


func _on_sound_button_pressed() -> void:
	panel.visible = not panel.visible


func _on_volum_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), value)
