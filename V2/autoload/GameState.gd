extends Node

## GameState - AutoLoad Singleton for Game State Management
## Add this to Project > Project Settings > Globals > AutoLoad
## Path: res://autoload/GameState.gd
## Node Name: GameState

# Game mode
var game_mode: String = "solo"  # "solo" or "pvp"

# Player selections
var player1_character: String = ""
var player2_character: String = ""
var player1_name: String = "Player 1"
var player2_name: String = "Player 2"

# Round tracking (best of 3)
var current_round: int = 1
var max_rounds: int = 3
var player1_wins: int = 0
var player2_wins: int = 0

# Match results
var winner: String = ""
var match_stats: Dictionary = {
	"damage_dealt_p1": 0,
	"damage_dealt_p2": 0,
	"attacks_landed_p1": 0,
	"attacks_landed_p2": 0,
	"ultimates_used_p1": 0,
	"ultimates_used_p2": 0
}

## Reset all game state
func reset_game():
	current_round = 1
	player1_wins = 0
	player2_wins = 0
	winner = ""
	match_stats = {
		"damage_dealt_p1": 0,
		"damage_dealt_p2": 0,
		"attacks_landed_p1": 0,
		"attacks_landed_p2": 0,
		"ultimates_used_p1": 0,
		"ultimates_used_p2": 0
	}

## Check if match is over (best of 3)
func is_match_over() -> bool:
	return player1_wins >= 2 or player2_wins >= 2

## Get match winner
func get_match_winner() -> String:
	if player1_wins >= 2:
		return "player1"
	elif player2_wins >= 2:
		return "player2"
	return ""

## Record round winner
func record_round_winner(player: String):
	if player == "player1":
		player1_wins += 1
	elif player == "player2":
		player2_wins += 1
	
	if is_match_over():
		winner = get_match_winner()
	else:
		current_round += 1

## Record attack landed
func record_attack(player: String, damage: float):
	if player == "player1":
		match_stats["attacks_landed_p1"] += 1
		match_stats["damage_dealt_p1"] += damage
	elif player == "player2":
		match_stats["attacks_landed_p2"] += 1
		match_stats["damage_dealt_p2"] += damage

## Record ultimate used
func record_ultimate(player: String):
	if player == "player1":
		match_stats["ultimates_used_p1"] += 1
	elif player == "player2":
		match_stats["ultimates_used_p2"] += 1
