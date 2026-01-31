extends Control

func _ready():
	pass

func _on_level_1_button_pressed():
	get_tree().change_scene_to_file("res://Level1.tscn")

func _on_level_2_button_pressed():
	get_tree().change_scene_to_file("res://Level2.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
