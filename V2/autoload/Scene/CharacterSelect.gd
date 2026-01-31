extends Control

@onready var your_selection_label = $VBoxContainer/SelectionInfo/YourSelection
@onready var opponent_selection_label = $VBoxContainer/SelectionInfo/OpponentSelection
@onready var status_label = $VBoxContainer/StatusLabel
@onready var ready_button = $VBoxContainer/ButtonsContainer/ReadyButton
@onready var back_button = $VBoxContainer/ButtonsContainer/BackButton

@onready var select_button_1 = $VBoxContainer/CharactersContainer/Character1/SelectButton1
@onready var select_button_2 = $VBoxContainer/CharactersContainer/Character2/SelectButton2
@onready var select_button_3 = $VBoxContainer/CharactersContainer/Character3/SelectButton3

var selected_character: String = ""
var is_ready: bool = false
var network_manager
var game_state

var character_names = {
	"blue": "Blue Fighter",
	"red": "Red Fighter",
	"green": "Green Fighter"
}

func _ready():
	game_state = get_node("/root/GameState")
	
	# Check if multiplayer
	if GameState.game_mode == "pvp":
		network_manager = get_node("/root/NetworkManager")
		opponent_selection_label.visible = true
		ready_button.visible = true
		
		# Connect to network signals
		network_manager.player_connected.connect(_on_player_updated)
		network_manager.game_started.connect(_on_game_started)
		
		# Update UI with existing selections
		_update_ui()

func _on_character_selected(character: String):
	selected_character = character
	your_selection_label.text = "Your Selection: " + character_names[character]
	your_selection_label.modulate = Color.GREEN
	
	# Store in GameState
	if GameState.game_mode == "solo":
		GameState.player1_character = character
	elif GameState.game_mode == "pvp" and network_manager:
		network_manager.set_player_character(character)
	
	status_label.text = "Character selected! " + ("Click READY" if GameState.game_mode == "pvp" else "Click BACK to start")
	status_label.modulate = Color.GREEN
	
	# In solo mode, go directly to loading
	if GameState.game_mode == "solo":
		# Set AI character (random different from player)
		var ai_characters = ["blue", "red", "green"]
		ai_characters.erase(character)
		GameState.player2_character = ai_characters[randi() % ai_characters.size()]
		
		# Small delay then go to loading
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")

func _on_ready_button_pressed():
	if selected_character == "":
		status_label.text = "Please select a character first!"
		status_label.modulate = Color.RED
		return
	
	is_ready = true
	ready_button.disabled = true
	status_label.text = "Waiting for opponent..."
	status_label.modulate = Color.YELLOW
	
	# Tell network we're ready
	if network_manager:
		network_manager.set_ready(true)
		
		# Check if both ready
		_check_if_ready_to_start()

func _on_back_button_pressed():
	if GameState.game_mode == "pvp" and network_manager:
		network_manager.disconnect_from_network()
		get_tree().change_scene_to_file("res://scenes/PVPLobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/GameplaySelect.tscn")

func _on_player_updated(peer_id: int, player_data: Dictionary):
	_update_ui()
	_check_if_ready_to_start()

func _update_ui():
	if not network_manager:
		return
	
	var player_ids = network_manager.get_player_ids()
	var my_id = network_manager.get_peer_id()
	
	# Find opponent
	for peer_id in player_ids:
		if peer_id != my_id:
			var opponent_data = network_manager.get_player_data(peer_id)
			var opponent_char = opponent_data.get("character", "")
			
			if opponent_char != "":
				opponent_selection_label.text = "Opponent Selection: " + character_names.get(opponent_char, "Unknown")
				opponent_selection_label.modulate = Color.YELLOW
			else:
				opponent_selection_label.text = "Opponent Selection: None"
				opponent_selection_label.modulate = Color.WHITE

func _check_if_ready_to_start():
	if not network_manager:
		return
	
	if network_manager.all_players_ready():
		# Both players ready, start the game
		status_label.text = "Both players ready! Starting..."
		status_label.modulate = Color.GREEN
		
		# Store character selections in GameState
		var player_ids = network_manager.get_player_ids()
		player_ids.sort()
		
		if player_ids.size() >= 2:
			var p1_data = network_manager.get_player_data(player_ids[0])
			var p2_data = network_manager.get_player_data(player_ids[1])
			
			GameState.player1_character = p1_data.get("character", "blue")
			GameState.player2_character = p2_data.get("character", "red")
			GameState.player1_name = p1_data.get("name", "Player 1")
			GameState.player2_name = p2_data.get("name", "Player 2")
		
		# Host starts the game
		if network_manager.is_server():
			await get_tree().create_timer(1.0).timeout
			_goto_loading.rpc()

@rpc("any_peer", "call_local", "reliable")
func _goto_loading():
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")

func _on_game_started():
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")
