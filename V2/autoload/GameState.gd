extends Node

## GameState - AutoLoad Singleton for Global Game State
## Path: res://autoload/GameState.gd

# Signals for state changes
signal game_mode_changed(mode: String)
signal round_ended(winner: String)
signal match_ended(winner: String)
signal character_selected(player: String, character: String)
signal health_changed(player: String, new_health: float)

# Game Mode
var game_mode: String = "solo" # "solo" or "pvp"

# Character Selection
var player1_character: String = ""
var player2_character: String = ""
var player1_name: String = "Player 1"
var player2_name: String = "Player 2"

# Match State
var current_round: int = 1
var max_rounds: int = 3 # Best of 3
var player1_wins: int = 0
var player2_wins: int = 0
var winner: String = "" # "player1", "player2", or ""

# Round Timer
var round_time_limit: float = 99.0 # 99 seconds per round
var current_round_time: float = 99.0
var round_active: bool = false

# Match Statistics
var match_stats: Dictionary = {
	"damage_dealt_p1": 0.0,
	"damage_dealt_p2": 0.0,
	"attacks_landed_p1": 0,
	"attacks_landed_p2": 0,
	"ultimates_used_p1": 0,
	"ultimates_used_p2": 0,
	"combo_count_p1": 0,
	"combo_count_p2": 0,
	"perfect_round": false
}

# Player Health (cached for UI updates)
var player1_health: float = 100.0
var player2_health: float = 100.0

# Character Data Repository
const CHARACTER_DATA = {
	"blue": {
		"display_name": "Blue Fighter",
		"description": "Balanced fighter with average stats",
		"color": Color(0.3, 0.5, 1.0),
		"max_health": 100.0,
		"walk_speed": 200.0,
		"run_speed": 350.0,
		"icon_path": "res://assets/characters/blue/icon.png"
	},
	"red": {
		"display_name": "Red Brawler",
		"description": "Tank character with high health but slower",
		"color": Color(1.0, 0.3, 0.3),
		"max_health": 120.0,
		"walk_speed": 180.0,
		"run_speed": 320.0,
		"icon_path": "res://assets/characters/red/icon.png"
	},
	"green": {
		"display_name": "Green Speedster",
		"description": "Fast character with lower health",
		"color": Color(0.3, 1.0, 0.3),
		"max_health": 80.0,
		"walk_speed": 220.0,
		"run_speed": 380.0,
		"icon_path": "res://assets/characters/green/icon.png"
	}
}

func _ready():
	print("[GameState] Initialized")

# --- Game Flow Methods ---

func reset_game():
	"""Reset all game state for a new match"""
	current_round = 1
	player1_wins = 0
	player2_wins = 0
	winner = ""
	round_active = false
	current_round_time = round_time_limit
	
	# Reset stats
	for key in match_stats.keys():
		if typeof(match_stats[key]) == TYPE_FLOAT:
			match_stats[key] = 0.0
		elif typeof(match_stats[key]) == TYPE_INT:
			match_stats[key] = 0
		elif typeof(match_stats[key]) == TYPE_BOOL:
			match_stats[key] = false
	
	print("[GameState] Game reset")

func reset_round():
	"""Reset state for a new round (keeps round wins)"""
	current_round_time = round_time_limit
	round_active = false
	match_stats["perfect_round"] = false
	print("[GameState] Round ", current_round, " reset")

func start_round():
	"""Start the current round"""
	round_active = true
	current_round_time = round_time_limit
	print("[GameState] Round ", current_round, " started")

func end_round(round_winner: String):
	"""End the current round and update wins"""
	round_active = false
	
	if round_winner == "player1":
		player1_wins += 1
	elif round_winner == "player2":
		player2_wins += 1
	
	round_ended.emit(round_winner)
	
	# Check if match is over
	if player1_wins >= 2:
		end_match("player1")
	elif player2_wins >= 2:
		end_match("player2")
	else:
		current_round += 1
	
	print("[GameState] Round ended. Winner: ", round_winner, " | P1 Wins: ", player1_wins, " | P2 Wins: ", player2_wins)

func end_match(match_winner: String):
	"""End the entire match"""
	winner = match_winner
	round_active = false
	match_ended.emit(match_winner)
	print("[GameState] Match ended. Winner: ", match_winner)

# --- Character Selection Methods ---

func set_player1_character(char_key: String):
	if CHARACTER_DATA.has(char_key):
		player1_character = char_key
		character_selected.emit("player1", char_key)
		print("[GameState] Player 1 selected: ", char_key)

func set_player2_character(char_key: String):
	if CHARACTER_DATA.has(char_key):
		player2_character = char_key
		character_selected.emit("player2", char_key)
		print("[GameState] Player 2 selected: ", char_key)

func get_character_data(char_key: String) -> Dictionary:
	return CHARACTER_DATA.get(char_key, {})

func get_character_display_name(char_key: String) -> String:
	var data = get_character_data(char_key)
	return data.get("display_name", "Unknown")

# --- Stats Tracking Methods ---

func record_attack(player_id: String, damage: float):
	"""Record an attack landing"""
	var suffix = "_p1" if player_id == "player1" else "_p2"
	match_stats["attacks_landed" + suffix] += 1
	match_stats["damage_dealt" + suffix] += damage
	print("[GameState] Attack recorded: ", player_id, " dealt ", damage, " damage")

func record_ultimate(player_id: String):
	"""Record an ultimate being used"""
	var suffix = "_p1" if player_id == "player1" else "_p2"
	match_stats["ultimates_used" + suffix] += 1
	print("[GameState] Ultimate used by: ", player_id)

func record_combo(player_id: String):
	"""Record a combo achievement"""
	var suffix = "_p1" if player_id == "player1" else "_p2"
	match_stats["combo_count" + suffix] += 1

func update_player_health(player_id: String, new_health: float):
	"""Update cached health values"""
	if player_id == "player1":
		player1_health = new_health
	elif player_id == "player2":
		player2_health = new_health
	
	health_changed.emit(player_id, new_health)

func check_perfect_round(losing_player_id: String):
	"""Check if this was a perfect round (winner took no damage)"""
	if losing_player_id == "player1" and player2_health >= get_character_data(player2_character).get("max_health", 100.0):
		match_stats["perfect_round"] = true
	elif losing_player_id == "player2" and player1_health >= get_character_data(player1_character).get("max_health", 100.0):
		match_stats["perfect_round"] = true

# --- Timer Methods ---

func update_round_timer(delta: float):
	"""Update the round timer (call from game scene)"""
	if round_active:
		current_round_time -= delta
		if current_round_time <= 0:
			current_round_time = 0
			_handle_timeout()

func _handle_timeout():
	"""Handle round timeout - player with more health wins"""
	if player1_health > player2_health:
		end_round("player1")
	elif player2_health > player1_health:
		end_round("player2")
	else:
		end_round("draw")

# --- Getters ---

func get_round_time_remaining() -> float:
	return current_round_time

func is_match_over() -> bool:
	return winner != ""

func get_winner() -> String:
	return winner

func get_stats_summary() -> Dictionary:
	"""Get formatted stats for display"""
	return {
		"p1_damage": match_stats["damage_dealt_p1"],
		"p2_damage": match_stats["damage_dealt_p2"],
		"p1_attacks": match_stats["attacks_landed_p1"],
		"p2_attacks": match_stats["attacks_landed_p2"],
		"p1_ultimates": match_stats["ultimates_used_p1"],
		"p2_ultimates": match_stats["ultimates_used_p2"],
		"p1_combos": match_stats["combo_count_p1"],
		"p2_combos": match_stats["combo_count_p2"],
		"perfect": match_stats["perfect_round"]
	}

# --- Debug Methods ---

func print_state():
	"""Debug: Print current game state"""
	print("=== GameState Debug ===")
	print("Mode: ", game_mode)
	print("Round: ", current_round, "/", max_rounds)
	print("P1: ", player1_name, " (", player1_character, ") - Wins: ", player1_wins)
	print("P2: ", player2_name, " (", player2_character, ") - Wins: ", player2_wins)
	print("Winner: ", winner if winner != "" else "None")
	print("======================")
