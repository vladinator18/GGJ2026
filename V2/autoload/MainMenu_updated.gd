extends Control
## Main Menu - Entry point for the game

@onready var error_label = $ErrorLabel if has_node("ErrorLabel") else null
@onready var status_label = $StatusLabel if has_node("StatusLabel") else null

func _ready():
	# Reset game state when returning to main menu
	if GameState:
		GameState.reset_game()
	
	# Disconnect from network if connected
	if NetworkManager:
		NetworkManager.disconnect_from_game()
	
	# Hide error/status labels initially
	if error_label:
		error_label.visible = false
	if status_label:
		status_label.visible = false
	
	# Connect to network signals for error handling
	if NetworkManager:
		if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
			NetworkManager.connection_failed.connect(_on_connection_failed)

## SOLO MODE (Player vs AI)
func _on_solo_button_pressed():
	GameState.game_mode = "solo"
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/CharacterSelection.tscn")

## HOST MULTIPLAYER GAME
func _on_host_button_pressed():
	GameState.game_mode = "pvp"
	GameState.reset_game()
	
	var player_name = "Host Player"
	if has_node("PlayerNameInput"):
		player_name = $PlayerNameInput.text
		if player_name.strip_edges() == "":
			player_name = "Host Player"
	
	if NetworkManager.host_game(player_name):
		_show_status("Server created! Waiting for opponent...")
		get_tree().change_scene_to_file("res://scenes/CharacterSelection.tscn")
	else:
		_show_error("Failed to create server!")

## JOIN MULTIPLAYER GAME
func _on_join_button_pressed():
	GameState.game_mode = "pvp"
	GameState.reset_game()
	
	var ip = "127.0.0.1"
	if has_node("IPInput"):
		ip = $IPInput.text
		if ip.strip_edges() == "":
			ip = "127.0.0.1"
	
	var player_name = "Client Player"
	if has_node("PlayerNameInput"):
		player_name = $PlayerNameInput.text
		if player_name.strip_edges() == "":
			player_name = "Client Player"
	
	if NetworkManager.join_game(ip, player_name):
		_show_status("Connecting to " + ip + "...")
		# Wait for connection before changing scene
		await get_tree().create_timer(0.5).timeout
		if NetworkManager.multiplayer.multiplayer_peer:
			get_tree().change_scene_to_file("res://scenes/CharacterSelection.tscn")
	else:
		_show_error("Failed to connect to server!")

## LEGACY BUTTONS (from your original menu)
func _on_level_1_button_pressed():
	# Gameplay Select screen (if you have one)
	if ResourceLoader.exists("res://scenes/GameplaySelect.tscn"):
		get_tree().change_scene_to_file("res://scenes/GameplaySelect.tscn")
	else:
		# Fallback to solo mode
		_on_solo_button_pressed()

func _on_level_2_button_pressed():
	# PVP Lobby (if you have a separate lobby system)
	if ResourceLoader.exists("res://autoload/Scene/PVPLobby.tscn"):
		get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")
	else:
		# Fallback to host game
		_on_host_button_pressed()

## QUIT GAME
func _on_quit_button_pressed():
	get_tree().quit()

## ERROR HANDLING
func _on_connection_failed():
	_show_error("Connection failed!")

func _show_error(message: String):
	if error_label:
		error_label.text = message
		error_label.visible = true
		error_label.modulate = Color.RED
		
		# Hide after 3 seconds
		await get_tree().create_timer(3.0).timeout
		if error_label:
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

## Cleanup
func _exit_tree():
	# Disconnect signals
	if NetworkManager and NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
