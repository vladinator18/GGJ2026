extends Node

func _ready():
	var network_manager = get_node("/root/NetworkManager")
	var game_state = get_node("/root/GameState")
	
	if network_manager:
		print("✅ NetworkManager found!")
	else:
		print("❌ NetworkManager NOT found - AutoLoad not set up!")
	
	if game_state:
		print("✅ GameState found!")
	else:
		print("❌ GameState NOT found - AutoLoad not set up!")
