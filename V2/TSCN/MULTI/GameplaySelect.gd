extends Control

func _on_solo_button_pressed():
	# Go directly to character select for solo play
	GameState.game_mode = "solo"
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_pvp_button_pressed():
	# Go to PVP lobby for multiplayer
	GameState.game_mode = "pvp"
	get_tree().change_scene_to_file("res://scenes/PVPLobby.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
