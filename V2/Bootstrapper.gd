extends Node

func _ready():
	# 1. Create and add NetworkManager
	var network_script = load("res://autoload/NetworkManager.gd")
	if network_script:
		var network_instance = network_script.new()
		network_instance.name = "NetworkManager"
		get_tree().root.add_child.call_deferred(network_instance)
	
	# 2. Create and add GameState
	var state_script = load("res://autoload/GameState.gd")
	if state_script:
		var state_instance = state_script.new()
		state_instance.name = "GameState"
		get_tree().root.add_child.call_deferred(state_instance)
	
	# 3. Switch to Main Menu - Using your verified path
	# Check your FileSystem: Is it 'res://scenes/' or 'res://TSCN/MainMenu/'?
	get_tree().change_scene_to_file.call_deferred("res://TSCN/MainMenu/MainMenu.tscn")
