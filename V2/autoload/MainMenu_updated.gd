extends Control

func _ready():
	# Reset game state when returning to main menu
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.reset_game()
	
	# Disconnect from network if connected
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		network_manager.disconnect_from_network()

func _on_level_1_button_pressed():
	# This goes to gameplay select (your flow diagram)
	get_tree().change_scene_to_file("res://autoload/Scene/GameplaySelect.tscn")

func _on_level_2_button_pressed():
	# You can keep this for direct online access if you want
	# Or make it do something else
	get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
