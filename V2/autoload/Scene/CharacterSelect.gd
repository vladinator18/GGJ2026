extends Control

## Character Selection - Multiplayer & Solo Support
@onready var your_selection_label = $VBoxContainer/SelectionInfo/YourSelection
@onready var opponent_selection_label = $VBoxContainer/SelectionInfo/OpponentSelection
@onready var status_label = $VBoxContainer/StatusLabel
@onready var ready_button = $VBoxContainer/ButtonsContainer/ReadyButton
@onready var back_button = $VBoxContainer/ButtonsContainer/BackButton

var selected_character: String = ""
var is_ready: bool = false

var character_names = {
	"blue": "Blue Fighter",
	"red": "Red Fighter",
	"green": "Green Fighter"
}

func _ready():
	# Check if multiplayer mode is active via GameState
	if GameState.game_mode == "pvp":
		if opponent_selection_label: opponent_selection_label.visible = true
		if ready_button: ready_button.visible = true
		
		# Connect to NetworkManager signals for real-time updates
		NetworkManager.player_connected.connect(_on_player_updated)
		NetworkManager.game_started.connect(_on_game_started)
		
		_update_ui()

func _on_character_selected(character: String):
	selected_character = character
	
	# Safe assignment to prevent 'null instance' error
	if your_selection_label:
		your_selection_label.text = "Your Selection: " + character_names[character]
		your_selection_label.modulate = Color.GREEN
	
	if GameState.game_mode == "solo":
		GameState.player1_character = character
		_handle_solo_ai_setup(character)
	else:
		NetworkManager.set_player_character(character)
	
	if status_label:
		status_label.text = "Selected! " + ("Click READY" if GameState.game_mode == "pvp" else "Starting...")
		status_label.modulate = Color.GREEN

func _handle_solo_ai_setup(player_char: String):
	var options = ["blue", "red", "green"]
	options.erase(player_char)
	GameState.player2_character = options[randi() % options.size()]
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://autoload/Scene/LoadingScreen.tscn")

func _on_ready_button_pressed():
	if selected_character == "":
		if status_label: status_label.text = "Select a character first!"
		return
	
	is_ready = true
	ready_button.disabled = true
	NetworkManager.set_ready(true)
	_check_start_conditions()

func _on_player_updated(_id: int, _data: Dictionary):
	_update_ui()
	_check_start_conditions()

func _update_ui():
	var ids = NetworkManager.get_player_ids()
	var my_id = NetworkManager.get_peer_id()
	
	for id in ids:
		if id != my_id:
			var data = NetworkManager.get_player_data(id)
			var char_key = data.get("character", "")
			if opponent_selection_label and char_key != "":
				opponent_selection_label.text = "Opponent: " + character_names.get(char_key, "Thinking...")

func _check_start_conditions():
	if NetworkManager.all_players_ready() and NetworkManager.is_server():
		# Sync final data to GameState before transition
		var ids = NetworkManager.get_player_ids()
		ids.sort()
		var p1 = NetworkManager.get_player_data(ids[0])
		var p2 = NetworkManager.get_player_data(ids[1])
		
		GameState.player1_character = p1.get("character", "blue")
		GameState.player2_character = p2.get("character", "red")
		
		_goto_loading.rpc()

@rpc("authority", "call_local", "reliable")
func _goto_loading():
	get_tree().change_scene_to_file("res://autoload/Scene/LoadingScreen.tscn")

func _on_game_started():
	get_tree().change_scene_to_file("res://autoload/Scene/LoadingScreen.tscn")
