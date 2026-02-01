extends Control
<<<<<<< Updated upstream

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
	get_tree().change_scene_to_file("res://scenes/GameplaySelect.tscn")

func _on_level_2_button_pressed():
	# You can keep this for direct online access if you want
	# Or make it do something else
	get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")
=======

## Main Menu - Entry point for the game

@onready var error_label = $ErrorLabel if has_node("ErrorLabel") else null
@onready var status_label = $StatusLabel if has_node("StatusLabel") else null

func _ready():
	# Reset game state when returning to main menu
	if is_instance_valid(get_node_or_null("/root/GameState")):
		GameState.reset_game()
	
	# Safety check for NetworkManager before calling functions
	if is_instance_valid(get_node_or_null("/root/NetworkManager")):
		# Use has_method to prevent the "Nonexistent function" crash
		if NetworkManager.has_method("disconnect_from_game"):
			NetworkManager.disconnect_from_game()
		
		# Connect to network signals for error handling
		if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
			NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Hide error/status labels initially
	_hide_ui_messages()

# --- BUTTON HANDLERS ---

## SOLO MODE (Player vs AI)
func _on_solo_button_pressed():
	GameState.game_mode = "solo"
	GameState.reset_game()
	get_tree().change_scene_to_file("res://autoload/Scene/CharacterSelect.tscn")

## HOST MULTIPLAYER GAME
func _on_host_button_pressed():
	GameState.game_mode = "pvp"
	GameState.reset_game()
	
	var player_name = _get_input_text("PlayerNameInput", "Host Player")
	
	if NetworkManager.has_method("host_game") and NetworkManager.host_game(player_name):
		_show_status("Server created! Waiting for opponent...")
		get_tree().change_scene_to_file("res://autoload/Scene/CharacterSelect.tscn")
	else:
		_show_error("Failed to create server! Check NetworkManager script.")

## JOIN MULTIPLAYER GAME
func _on_join_button_pressed():
	GameState.game_mode = "pvp"
	GameState.reset_game()
	
	var ip = _get_input_text("IPInput", "127.0.0.1")
	var player_name = _get_input_text("PlayerNameInput", "Client Player")
	
	if NetworkManager.has_method("join_game") and NetworkManager.join_game(ip, player_name):
		_show_status("Connecting to " + ip + "...")
		# Wait for connection before changing scene
		await get_tree().create_timer(0.5).timeout
		if NetworkManager.multiplayer.multiplayer_peer:
			get_tree().change_scene_to_file("res://autoload/Scene/CharacterSelect.tscn")
	else:
		_show_error("Failed to connect to server!")

## LEGACY BUTTONS
func _on_level_1_button_pressed():
	if ResourceLoader.exists("res://autoload/Scene/GameplaySelect.tscn"):
		get_tree().change_scene_to_file("res://autoload/Scene/GameplaySelect.tscn")
	else:
		_on_solo_button_pressed()

func _on_level_2_button_pressed():
	if ResourceLoader.exists("res://autoload/Scene/PVPLobby.tscn"):
		get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")
	else:
		_on_host_button_pressed()
>>>>>>> Stashed changes

func _on_quit_button_pressed():
	get_tree().quit()
<<<<<<< Updated upstream
=======

# --- HELPERS & ERROR HANDLING ---

func _get_input_text(node_path: String, default: String) -> String:
	if has_node(node_path):
		var t = get_node(node_path).text.strip_edges()
		return t if t != "" else default
	return default

func _on_connection_failed():
	_show_error("Connection failed!")

func _show_error(message: String):
	if error_label:
		error_label.text = message
		error_label.visible = true
		error_label.modulate = Color.RED
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(error_label):
			error_label.visible = false
	else:
		print("ERROR: ", message)

func _show_status(message: String):
	if status_label:
		status_label.text = message
		status_label.visible = true
		status_label.modulate = Color.YELLOW
	else:
		print("STATUS: ", message)

func _hide_ui_messages():
	if error_label: error_label.visible = false
	if status_label: status_label.visible = false

func _exit_tree():
	# Disconnect signals to prevent memory leaks/errors
	if is_instance_valid(get_node_or_null("/root/NetworkManager")):
		if NetworkManager.connection_failed.is_connected(_on_connection_failed):
			NetworkManager.connection_failed.disconnect(_on_connection_failed)
>>>>>>> Stashed changes
