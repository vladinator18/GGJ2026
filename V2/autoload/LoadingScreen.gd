extends Control

@onready var round_label = $CenterContainer/VBoxContainer/RoundLabel
@onready var countdown_label = $CenterContainer/VBoxContainer/CountdownLabel
@onready var countdown_timer = $CountdownTimer

@onready var p1_name_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player1Info/Name
@onready var p1_character_visual = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player1Info/Character
@onready var p1_character_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player1Info/Character/Label
@onready var p1_wins_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player1Info/Wins

@onready var p2_name_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player2Info/Name
@onready var p2_character_visual = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player2Info/Character
@onready var p2_character_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player2Info/Character/Label
@onready var p2_wins_label = $CenterContainer/VBoxContainer/MatchInfo/PlayersContainer/Player2Info/Wins

var countdown: int = 3

var character_data = {
	"blue": {"name": "BLUE", "color": Color(0.3, 0.6, 1, 1)},
	"red": {"name": "RED", "color": Color(1, 0.3, 0.3, 1)},
	"green": {"name": "GREEN", "color": Color(0.3, 1, 0.3, 1)}
}

func _ready():
	var game_state = get_node("/root/GameState")
	
	# Set round info
	round_label.text = "ROUND " + str(game_state.current_round)
	
	# Set player 1 info
	p1_name_label.text = game_state.player1_name
	var p1_char = game_state.player1_character
	if p1_char in character_data:
		p1_character_visual.color = character_data[p1_char]["color"]
		p1_character_label.text = character_data[p1_char]["name"]
	p1_wins_label.text = "Wins: " + str(game_state.player1_wins)
	
	# Set player 2 info
	p2_name_label.text = game_state.player2_name
	var p2_char = game_state.player2_character
	if p2_char in character_data:
		p2_character_visual.color = character_data[p2_char]["color"]
		p2_character_label.text = character_data[p2_char]["name"]
	p2_wins_label.text = "Wins: " + str(game_state.player2_wins)
	
	# Start countdown
	countdown_timer.start()

func _on_countdown_timer_timeout():
	countdown -= 1
	
	if countdown > 0:
		countdown_label.text = str(countdown)
		
		# Pulse effect
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.3, 1.3), 0.2)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3)
	else:
		countdown_label.text = "FIGHT!"
		countdown_label.modulate = Color.YELLOW
		
		# Bigger pulse for FIGHT
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.3)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)
		
		# Wait a moment then load fight scene
		await get_tree().create_timer(1.0).timeout
		
		# For PVP, only host changes scene
		var game_state = get_node("/root/GameState")
		if game_state.game_mode == "pvp":
			var network_manager = get_node("/root/NetworkManager")
			if network_manager.is_server():
				_goto_fight.rpc()
		else:
			# Solo mode, just change scene
			get_tree().change_scene_to_file("res://scenes[]/FightArena.tscn")

@rpc("any_peer", "call_local", "reliable")
func _goto_fight():
	get_tree().change_scene_to_file("res://scenes/FightArena.tscn")
