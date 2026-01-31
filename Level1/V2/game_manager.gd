extends Node
class_name FightManager

# Character references
@export var player: CharacterBody2D
@export var enemy: CharacterBody2D

# UI references
@export var player_health_bar: HealthBar
@export var enemy_health_bar: HealthBar
@export var round_label: Label
@export var winner_label: Label
@export var match_status_label: Label

# Match settings
@export var rounds_to_win: int = 2
@export var round_restart_delay: float = 2.0

# Match state
var player_wins: int = 0
var enemy_wins: int = 0
var current_round: int = 1
var match_active: bool = false
var round_active: bool = false

# Signals
signal round_started(round_number: int)
signal round_ended(winner: String)
signal match_ended(winner: String, player_score: int, enemy_score: int)

func _ready():
	print("[FightManager] Initializing...")
	
	# Verify references
	if not player:
		print("[FightManager] ERROR: Player reference not set!")
		return
	if not enemy:
		print("[FightManager] ERROR: Enemy reference not set!")
		return
	
	# Connect to character death signals
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
		print("[FightManager] Connected to player death signal")
	
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
		print("[FightManager] Connected to enemy death signal")
	
	# Start the match
	start_match()

func _process(delta: float):
	# Press R to restart match
	if Input.is_action_just_pressed("ui_accept") and not match_active:
		restart_match()

func start_match():
	print("[FightManager] ========== STARTING MATCH ==========")
	player_wins = 0
	enemy_wins = 0
	current_round = 1
	match_active = true
	
	update_ui()
	start_round()

func start_round():
	print("[FightManager] ===== ROUND %d START =====" % current_round)
	round_active = true
	
	# Reset characters
	if player.has_method("reset"):
		player.reset()
	if enemy.has_method("reset"):
		enemy.reset()
	
	# Reset health bars
	if player_health_bar and player_health_bar.has_method("reset"):
		player_health_bar.reset()
	if enemy_health_bar and enemy_health_bar.has_method("reset"):
		enemy_health_bar.reset()
	
	update_ui()
	round_started.emit(current_round)

func end_round(winner: String):
	if not round_active:
		return
	
	print("[FightManager] ===== ROUND %d END =====" % current_round)
	print("[FightManager] Winner: %s" % winner)
	
	round_active = false
	
	# Update win count
	if winner == "Player":
		player_wins += 1
	elif winner == "Enemy":
		enemy_wins += 1
	
	update_ui()
	round_ended.emit(winner)
	
	# Check if match is over
	if player_wins >= rounds_to_win:
		end_match("Player")
	elif enemy_wins >= rounds_to_win:
		end_match("Enemy")
	else:
		# Next round
		current_round += 1
		await get_tree().create_timer(round_restart_delay).timeout
		start_round()

func end_match(winner: String):
	print("[FightManager] ========== MATCH END ==========")
	print("[FightManager] Winner: %s" % winner)
	print("[FightManager] Final Score - Player: %d | Enemy: %d" % [player_wins, enemy_wins])
	
	match_active = false
	update_ui()
	match_ended.emit(winner, player_wins, enemy_wins)

func restart_match():
	print("[FightManager] Restarting match...")
	start_match()

func update_ui():
	# Update round label
	if round_label:
		round_label.text = "Round %d" % current_round
	
	# Update match status
	if match_status_label:
		match_status_label.text = "Player: %d | Enemy: %d" % [player_wins, enemy_wins]
	
	# Update winner label
	if winner_label:
		if not match_active:
			if player_wins >= rounds_to_win:
				winner_label.text = "PLAYER WINS!\nPress ENTER to restart"
				winner_label.modulate = Color.GREEN
			elif enemy_wins >= rounds_to_win:
				winner_label.text = "ENEMY WINS!\nPress ENTER to restart"
				winner_label.modulate = Color.RED
			winner_label.visible = true
		else:
			winner_label.visible = false

func _on_player_died():
	print("[FightManager] Player died!")
	end_round("Enemy")

func _on_enemy_died():
	print("[FightManager] Enemy died!")
	end_round("Player")

# Helper function to get match stats
func get_match_stats() -> Dictionary:
	return {
		"player_wins": player_wins,
		"enemy_wins": enemy_wins,
		"current_round": current_round,
		"match_active": match_active,
		"round_active": round_active
	}
