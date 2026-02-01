extends Control

## CharacterSelection - Character Selection Screen
## Works with both Solo and PvP modes

# UI Node References
@onready var your_selection_label = $VBoxContainer/SelectionInfo/YourSelection
@onready var opponent_selection_label = $VBoxContainer/SelectionInfo/OpponentSelection
@onready var status_label = $VBoxContainer/StatusLabel
@onready var ready_button = $VBoxContainer/ButtonsContainer/ReadyButton
@onready var back_button = $VBoxContainer/ButtonsContainer/BackButton

# Character selection buttons (add these to your scene)
@onready var blue_button = $VBoxContainer/CharacterButtons/BlueButton if has_node("VBoxContainer/CharacterButtons/BlueButton") else null
@onready var red_button = $VBoxContainer/CharacterButtons/RedButton if has_node("VBoxContainer/CharacterButtons/RedButton") else null
@onready var green_button = $VBoxContainer/CharacterButtons/GreenButton if has_node("VBoxContainer/CharacterButtons/GreenButton") else null

# State Variables
var selected_character: String = ""
var is_ready: bool = false

func _ready():
	# Initialize based on game mode
	if GameState.game_mode == "pvp":
		_setup_pvp_mode()
	else:
		_setup_solo_mode()
	
	# Connect character button signals
	if blue_button:
		blue_button.pressed.connect(func(): _on_character_selected("blue"))
	if red_button:
		red_button.pressed.connect(func(): _on_character_selected("red"))
	if green_button:
		green_button.pressed.connect(func(): _on_character_selected("green"))
	
	# Connect UI button signals
	ready_button.pressed.connect(_on_ready_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	_update_ui()

func _setup_pvp_mode():
	"""Setup UI for PvP mode"""
	opponent_selection_label.visible = true
	ready_button.visible = true
	
	# Connect to NetworkManager signals
	if not NetworkManager.player_connected.is_connected(_on_player_updated):
		NetworkManager.player_connected.connect(_on_player_updated)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.lobby_updated.is_connected(_update_ui):
		NetworkManager.lobby_updated.connect(_update_ui)
	
	status_label.text = "Select your character"
	status_label.modulate = Color.WHITE
	
	print("[CharacterSelection] PvP mode initialized")

func _setup_solo_mode():
	"""Setup UI for Solo mode"""
	opponent_selection_label.visible = false
	ready_button.visible = false
	
	status_label.text = "Select your character to start"
	status_label.modulate = Color.WHITE
	
	print("[CharacterSelection] Solo mode initialized")

# --- Character Selection Logic ---

func _on_character_selected(character: String):
	"""Handle character selection"""
	selected_character = character
	var char_data = GameState.get_character_data(character)
	var display_name = char_data.get("display_name", "Unknown")
	
	your_selection_label.text = "Your Selection: " + display_name
	your_selection_label.modulate = Color.GREEN
	
	# Update button states
	_update_button_states(character)
	
	if GameState.game_mode == "solo":
		# In solo mode, auto-start after selection
		_start_solo_game(character)
	else:
		# In PvP mode, sync selection to network
		NetworkManager.set_player_character(character)
		GameState.set_player1_character(character)
		status_label.text = "Character selected! Click READY when you're ready"
		status_label.modulate = Color.GREEN

func _update_button_states(selected: String):
	"""Update visual state of character buttons"""
	if blue_button:
		blue_button.disabled = false
		blue_button.modulate = Color.WHITE if selected != "blue" else Color.GREEN
	if red_button:
		red_button.disabled = false
		red_button.modulate = Color.WHITE if selected != "red" else Color.GREEN
	if green_button:
		green_button.disabled = false
		green_button.modulate = Color.WHITE if selected != "green" else Color.GREEN

func _start_solo_game(char_key: String):
	"""Start solo game with AI opponent"""
	GameState.player1_character = char_key
	
	# AI randomly picks a different character
	var options = ["blue", "red", "green"]
	options.erase(char_key)
	var ai_choice = options[randi() % options.size()]
	GameState.player2_character = ai_choice
	
	var ai_char_data = GameState.get_character_data(ai_choice)
	status_label.text = "Starting Game vs " + ai_char_data.get("display_name", "AI") + "..."
	status_label.modulate = Color.YELLOW
	
	print("[CharacterSelection] Solo game starting: ", char_key, " vs ", ai_choice)
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://V2/autoload/Scene/LoadingScreen.tscn")

# --- Multiplayer Ready Logic ---

func _on_ready_button_pressed():
	"""Handle ready button press in PvP mode"""
	if selected_character == "":
		status_label.text = "Please select a character first!"
		status_label.modulate = Color.RED
		return
	
	is_ready = true
	ready_button.disabled = true
	ready_button.text = "READY!"
	
	NetworkManager.set_ready(true)
	status_label.text = "Waiting for opponent..."
	status_label.modulate = Color.YELLOW
	
	_check_if_ready_to_start()

func _check_if_ready_to_start():
	"""Check if both players are ready to start"""
	if GameState.game_mode != "pvp":
		return
	
	if NetworkManager.all_players_ready():
		# Host synchronizes final character choices
		if NetworkManager.is_server():
			_sync_final_choices()
			status_label.text = "Both players ready! Starting..."
			status_label.modulate = Color.GREEN
			await get_tree().create_timer(1.5).timeout
			NetworkManager.start_game()

func _sync_final_choices():
	"""Synchronize final character choices (host only)"""
	var player_ids = NetworkManager.get_player_ids()
	player_ids.sort() # Ensure consistent P1/P2 assignment
	
	if player_ids.size() >= 2:
		var p1_data = NetworkManager.get_player_data(player_ids[0])
		var p2_data = NetworkManager.get_player_data(player_ids[1])
		
		GameState.player1_character = p1_data.get("character", "blue")
		GameState.player2_character = p2_data.get("character", "red")
		GameState.player1_name = p1_data.get("name", "Player 1")
		GameState.player2_name = p2_data.get("name", "Player 2")
		
		print("[CharacterSelection] Final choices synced: P1=", GameState.player1_character, " P2=", GameState.player2_character)

# --- UI Update Methods ---

func _on_player_updated(_peer_id: int, _player_data: Dictionary):
	"""Handle player data updates from network"""
	_update_ui()
	_check_if_ready_to_start()

func _update_ui():
	"""Update UI based on current state"""
	if GameState.game_mode != "pvp" or not NetworkManager.is_network_connected():
		return
	
	var player_ids = NetworkManager.get_player_ids()
	var my_id = NetworkManager.get_peer_id()
	
	# Display opponent's selection
	for peer_id in player_ids:
		if peer_id != my_id:
			var opponent_data = NetworkManager.get_player_data(peer_id)
			var opponent_char = opponent_data.get("character", "")
			
			if opponent_char != "":
				var char_data = GameState.get_character_data(opponent_char)
				opponent_selection_label.text = "Opponent: " + char_data.get("display_name", "Unknown")
				opponent_selection_label.modulate = Color.YELLOW
			else:
				opponent_selection_label.text = "Opponent: Selecting..."
				opponent_selection_label.modulate = Color.WHITE
			
			# Show opponent ready state
			var opponent_ready = opponent_data.get("ready", false)
			if opponent_ready:
				opponent_selection_label.text += " ✓"
				opponent_selection_label.modulate = Color.GREEN

func _on_game_started():
	"""Handle game start signal from NetworkManager"""
	print("[CharacterSelection] Game started signal received")
	get_tree().change_scene_to_file("res://V2/autoload/Scene/LoadingScreen.tscn")

func _on_back_button_pressed():
	"""Handle back button press"""
	if GameState.game_mode == "pvp":
		NetworkManager.disconnect_from_network()
	
	# Reset selections
	selected_character = ""
	is_ready = false
	
	get_tree().change_scene_to_file("res://V2/TSCN/MainMenu/MainMenu.tscn")
