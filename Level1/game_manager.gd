extends Node

## Game Manager - Round System and Match Controller
## Handles rounds, UI updates, win conditions, damage tracking, and game flow

# ========================================
# CONFIGURATION
# ========================================

@export_group("Round Settings")
@export var rounds_to_win: int = 2  # Best of 3 by default
@export var round_start_delay: float = 2.0
@export var round_end_delay: float = 3.0
@export var match_end_delay: float = 5.0

@export_group("UI References")
@export var round_counter_label: Label
@export var fight_announcement_label: Label
@export var player_health_bar: ProgressBar
@export var enemy_health_bar: ProgressBar
@export var player_health_label: Label
@export var enemy_health_label: Label
@export var player_wins_label: Label
@export var enemy_wins_label: Label
@export var combo_label: Label
@export var timer_label: Label
@export var winner_label: Label
@export var damage_stats_label: Label  # NEW: Shows damage dealt stats

@export_group("Character References")
@export var player: Node2D
@export var enemy: Node2D

@export_group("Spawn Positions")
@export var player_spawn_position: Vector2 = Vector2(247, 425)
@export var enemy_spawn_position: Vector2 = Vector2(936, 425)

@export_group("Round Timer")
@export var enable_round_timer: bool = true
@export var round_time_seconds: float = 99.0

# ========================================
# INTERNAL STATE
# ========================================

# Round tracking
var current_round: int = 0
var player_round_wins: int = 0
var enemy_round_wins: int = 0
var round_timer: float = 0.0
var is_round_active: bool = false
var match_ended: bool = false

# Damage tracking - Match totals
var player_total_damage_dealt: float = 0.0
var player_total_damage_taken: float = 0.0
var enemy_total_damage_dealt: float = 0.0
var enemy_total_damage_taken: float = 0.0

# Damage tracking - Round specific
var player_round_damage_dealt: float = 0.0
var player_round_damage_taken: float = 0.0
var enemy_round_damage_dealt: float = 0.0
var enemy_round_damage_taken: float = 0.0

# Hit tracking
var player_total_hits_landed: int = 0
var player_total_hits_taken: int = 0
var enemy_total_hits_landed: int = 0
var enemy_total_hits_taken: int = 0

# Round hit tracking
var player_round_hits_landed: int = 0
var player_round_hits_taken: int = 0
var enemy_round_hits_landed: int = 0
var enemy_round_hits_taken: int = 0

# Game state
enum GameState { IDLE, ROUND_START, FIGHTING, ROUND_END, MATCH_END }
var current_game_state: GameState = GameState.IDLE

# ========================================
# INITIALIZATION
# ========================================

func _ready():
	add_to_group("game_manager")
	
	# Hide announcements initially
	if fight_announcement_label:
		fight_announcement_label.hide()
	if winner_label:
		winner_label.hide()
	if damage_stats_label:
		damage_stats_label.hide()
	
	# Initialize UI
	_update_round_wins_display()
	_update_health_bars()
	
	print("✓ Game Manager initialized")
	print("  - Rounds to win: ", rounds_to_win)
	print("  - Round timer: ", round_time_seconds, "s")
	
	# Start first round after short delay
	await get_tree().create_timer(1.0).timeout
	start_new_round()

func _process(delta: float):
	if is_round_active and enable_round_timer:
		round_timer -= delta
		if round_timer <= 0:
			round_timer = 0
			_end_round_time_up()
		_update_timer_display()

# ========================================
# ROUND MANAGEMENT
# ========================================

func start_new_round():
	"""Initialize and start a new round"""
	if match_ended:
		return
	
	current_round += 1
	current_game_state = GameState.ROUND_START
	is_round_active = false
	round_timer = round_time_seconds
	
	# Reset round-specific damage tracking (but keep match totals)
	_reset_round_stats()
	
	print("\n=== ROUND %d START ===" % current_round)
	print("Player stats - Total damage: %.0f | Total hits: %d" % [player_total_damage_dealt, player_total_hits_landed])
	print("Enemy stats  - Total damage: %.0f | Total hits: %d" % [enemy_total_damage_dealt, enemy_total_hits_landed])
	
	# Update UI
	if round_counter_label:
		round_counter_label.text = "ROUND %d" % current_round
	
	# Reset characters to spawn positions
	_reset_characters()
	
	# Show "READY" announcement
	_show_announcement("READY")
	await get_tree().create_timer(1.5).timeout
	
	# Show "FIGHT!" and activate round
	_show_announcement("FIGHT!")
	await get_tree().create_timer(1.0).timeout
	
	if fight_announcement_label:
		fight_announcement_label.hide()
	
	current_game_state = GameState.FIGHTING
	is_round_active = true
	
	# Enable character controls
	_enable_character_controls(true)

func _reset_characters():
	"""Reset character positions and health for new round"""
	if player:
		player.global_position = player_spawn_position
		player.velocity = Vector2.ZERO
		
		if player.has_method("reset_for_new_round"):
			player.reset_for_new_round()
		else:
			player.current_health = player.max_health
	
	if enemy:
		enemy.global_position = enemy_spawn_position
		enemy.velocity = Vector2.ZERO
		
		if enemy.has_method("reset_for_new_round"):
			enemy.reset_for_new_round()
		else:
			enemy.current_health = enemy.max_health
	
	_update_health_bars()

func end_round(winner: String):
	"""Called when someone wins the round"""
	if not is_round_active:
		return
	
	is_round_active = false
	current_game_state = GameState.ROUND_END
	
	# Print round summary
	_print_round_summary(winner)
	
	# Disable character controls
	_enable_character_controls(false)
	
	# Update round wins
	if winner == "player":
		player_round_wins += 1
	elif winner == "enemy":
		enemy_round_wins += 1
	
	_show_announcement("K.O.!")
	_update_round_wins_display()
	
	await get_tree().create_timer(round_end_delay).timeout
	
	if fight_announcement_label:
		fight_announcement_label.hide()
	
	# Check for match end
	if player_round_wins >= rounds_to_win:
		_end_match("player")
	elif enemy_round_wins >= rounds_to_win:
		_end_match("enemy")
	else:
		# Start next round
		start_new_round()

func _end_round_time_up():
	"""Called when round timer reaches 0"""
	if not is_round_active:
		return
	
	print("⏰ TIME UP!")
	
	# Determine winner by health
	var winner = "draw"
	if player and enemy:
		if player.current_health > enemy.current_health:
			winner = "player"
		elif enemy.current_health > player.current_health:
			winner = "enemy"
	
	_show_announcement("TIME UP!")
	await get_tree().create_timer(1.5).timeout
	
	if winner == "draw":
		# In a draw, restart the round
		_show_announcement("DRAW!")
		await get_tree().create_timer(2.0).timeout
		start_new_round()
	else:
		end_round(winner)

func _end_match(winner: String):
	"""Called when someone wins the match"""
	match_ended = true
	current_game_state = GameState.MATCH_END
	
	# Print comprehensive match summary
	_print_match_summary(winner)
	
	# Show winner announcement
	var winner_text = "PLAYER WINS!" if winner == "player" else "ENEMY WINS!"
	_show_announcement(winner_text)
	
	if winner_label:
		winner_label.text = winner_text
		winner_label.show()
	
	# Show damage statistics
	_show_damage_stats()
	
	await get_tree().create_timer(match_end_delay).timeout
	
	print("\n✓ Match complete. Reload scene to play again.")

# ========================================
# DAMAGE TRACKING
# ========================================

func record_damage(attacker: String, damage: float, is_hit: bool = true):
	"""
	Record damage dealt/taken
	attacker: "player" or "enemy"
	damage: amount of damage
	is_hit: whether this counts as a successful hit
	"""
	print("📊 RECORDING DAMAGE: %s dealt %.0f damage" % [attacker.to_upper(), damage])
	
	if attacker == "player":
		# Player dealt damage to enemy
		player_total_damage_dealt += damage
		player_round_damage_dealt += damage
		enemy_total_damage_taken += damage
		enemy_round_damage_taken += damage
		
		if is_hit:
			player_total_hits_landed += 1
			player_round_hits_landed += 1
			enemy_total_hits_taken += 1
			enemy_round_hits_taken += 1
		
		print("  → Player total damage: %.0f | Round damage: %.0f | Hits: %d" % 
			[player_total_damage_dealt, player_round_damage_dealt, player_total_hits_landed])
	
	elif attacker == "enemy":
		# Enemy dealt damage to player
		enemy_total_damage_dealt += damage
		enemy_round_damage_dealt += damage
		player_total_damage_taken += damage
		player_round_damage_taken += damage
		
		if is_hit:
			enemy_total_hits_landed += 1
			enemy_round_hits_landed += 1
			player_total_hits_taken += 1
			player_round_hits_taken += 1
		
		print("  → Enemy total damage: %.0f | Round damage: %.0f | Hits: %d" % 
			[enemy_total_damage_dealt, enemy_round_damage_dealt, enemy_total_hits_landed])

func get_player_damage_stats() -> Dictionary:
	"""Get player's damage statistics"""
	return {
		"total_dealt": player_total_damage_dealt,
		"total_taken": player_total_damage_taken,
		"round_dealt": player_round_damage_dealt,
		"round_taken": player_round_damage_taken,
		"total_hits_landed": player_total_hits_landed,
		"total_hits_taken": player_total_hits_taken,
		"round_hits_landed": player_round_hits_landed,
		"round_hits_taken": player_round_hits_taken,
		"accuracy": _calculate_accuracy(player_total_hits_landed, player_total_hits_landed + player_total_hits_taken)
	}

func get_enemy_damage_stats() -> Dictionary:
	"""Get enemy's damage statistics"""
	return {
		"total_dealt": enemy_total_damage_dealt,
		"total_taken": enemy_total_damage_taken,
		"round_dealt": enemy_round_damage_dealt,
		"round_taken": enemy_round_damage_taken,
		"total_hits_landed": enemy_total_hits_landed,
		"total_hits_taken": enemy_total_hits_taken,
		"round_hits_landed": enemy_round_hits_landed,
		"round_hits_taken": enemy_round_hits_taken,
		"accuracy": _calculate_accuracy(enemy_total_hits_landed, enemy_total_hits_landed + enemy_total_hits_taken)
	}

func _calculate_accuracy(hits_landed: int, total_hits: int) -> float:
	"""Calculate hit accuracy percentage"""
	if total_hits == 0:
		return 0.0
	return (float(hits_landed) / float(total_hits)) * 100.0

func _reset_round_stats():
	"""Reset round-specific damage tracking"""
	player_round_damage_dealt = 0.0
	player_round_damage_taken = 0.0
	enemy_round_damage_dealt = 0.0
	enemy_round_damage_taken = 0.0
	player_round_hits_landed = 0
	player_round_hits_taken = 0
	enemy_round_hits_landed = 0
	enemy_round_hits_taken = 0

# ========================================
# CHARACTER EVENTS
# ========================================

func on_player_defeated():
	"""Called when player health reaches 0"""
	if is_round_active:
		end_round("enemy")

func on_enemy_defeated():
	"""Called when enemy health reaches 0"""
	if is_round_active:
		end_round("player")

# ========================================
# UI UPDATES
# ========================================

func update_player_health(current: float, maximum: float):
	"""Update player health UI"""
	if player_health_bar:
		player_health_bar.max_value = maximum
		player_health_bar.value = current
	
	if player_health_label:
		player_health_label.text = "%d/%d" % [int(current), int(maximum)]
	
	# Check for defeat
	if current <= 0 and is_round_active:
		on_player_defeated()

func update_enemy_health(current: float, maximum: float):
	"""Update enemy health UI"""
	if enemy_health_bar:
		enemy_health_bar.max_value = maximum
		enemy_health_bar.value = current
	
	if enemy_health_label:
		enemy_health_label.text = "%d/%d" % [int(current), int(maximum)]
	
	# Check for defeat
	if current <= 0 and is_round_active:
		on_enemy_defeated()

func update_combo(combo_count: int):
	"""Update combo counter UI"""
	if combo_label:
		if combo_count > 1:
			combo_label.text = "%d HIT COMBO!" % combo_count
			combo_label.show()
		else:
			combo_label.hide()

func _update_health_bars():
	"""Refresh both health bars"""
	if player:
		update_player_health(player.current_health, player.max_health)
	if enemy:
		update_enemy_health(enemy.current_health, enemy.max_health)

func _update_round_wins_display():
	"""Update round wins counters"""
	if player_wins_label:
		player_wins_label.text = "P: %d" % player_round_wins
	
	if enemy_wins_label:
		enemy_wins_label.text = "E: %d" % enemy_round_wins

func _update_timer_display():
	"""Update round timer display"""
	if timer_label:
		var minutes = int(round_timer) / 60
		var seconds = int(round_timer) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _show_announcement(text: String):
	"""Display fight announcement (READY, FIGHT!, K.O., etc.)"""
	if fight_announcement_label:
		fight_announcement_label.text = text
		fight_announcement_label.show()

func _show_damage_stats():
	"""Display damage statistics at end of match"""
	if not damage_stats_label:
		return
	
	var stats_text = "=== MATCH STATISTICS ===\n\n"
	stats_text += "PLAYER:\n"
	stats_text += "  Damage Dealt: %.0f\n" % player_total_damage_dealt
	stats_text += "  Damage Taken: %.0f\n" % player_total_damage_taken
	stats_text += "  Hits Landed: %d\n" % player_total_hits_landed
	stats_text += "  Accuracy: %.1f%%\n\n" % _calculate_accuracy(player_total_hits_landed, player_total_hits_landed + enemy_total_hits_landed)
	
	stats_text += "ENEMY:\n"
	stats_text += "  Damage Dealt: %.0f\n" % enemy_total_damage_dealt
	stats_text += "  Damage Taken: %.0f\n" % enemy_total_damage_taken
	stats_text += "  Hits Landed: %d\n" % enemy_total_hits_landed
	stats_text += "  Accuracy: %.1f%%" % _calculate_accuracy(enemy_total_hits_landed, enemy_total_hits_landed + player_total_hits_landed)
	
	damage_stats_label.text = stats_text
	damage_stats_label.show()

# ========================================
# UTILITY FUNCTIONS
# ========================================

func _enable_character_controls(enabled: bool):
	"""Enable/disable character physics processing"""
	if player:
		player.set_physics_process(enabled)
	if enemy:
		enemy.set_physics_process(enabled)

func _print_round_summary(winner: String):
	"""Print round statistics to console"""
	print("\n=== ROUND %d END - Winner: %s ===" % [current_round, winner.to_upper()])
	print("Player - Damage Dealt: %.0f | Damage Taken: %.0f | Hits: %d" % 
		[player_round_damage_dealt, player_round_damage_taken, player_round_hits_landed])
	print("Enemy  - Damage Dealt: %.0f | Damage Taken: %.0f | Hits: %d" % 
		[enemy_round_damage_dealt, enemy_round_damage_taken, enemy_round_hits_landed])

func _print_match_summary(winner: String):
	"""Print comprehensive match statistics"""
	print("\n🏆 === MATCH END - %s WINS! === 🏆" % winner.to_upper())
	print("\n--- MATCH STATISTICS ---")
	print("\nPLAYER:")
	print("  Total Damage Dealt: %.0f" % player_total_damage_dealt)
	print("  Total Damage Taken: %.0f" % player_total_damage_taken)
	print("  Total Hits Landed: %d" % player_total_hits_landed)
	print("  Total Hits Taken: %d" % player_total_hits_taken)
	print("  Hit Accuracy: %.1f%%" % _calculate_accuracy(player_total_hits_landed, player_total_hits_landed + enemy_total_hits_landed))
	print("  Rounds Won: %d" % player_round_wins)
	
	print("\nENEMY:")
	print("  Total Damage Dealt: %.0f" % enemy_total_damage_dealt)
	print("  Total Damage Taken: %.0f" % enemy_total_damage_taken)
	print("  Total Hits Landed: %d" % enemy_total_hits_landed)
	print("  Total Hits Taken: %d" % enemy_total_hits_taken)
	print("  Hit Accuracy: %.1f%%" % _calculate_accuracy(enemy_total_hits_landed, enemy_total_hits_landed + player_total_hits_landed))
	print("  Rounds Won: %d" % enemy_round_wins)

# ========================================
# PUBLIC UTILITY FUNCTIONS
# ========================================

func restart_match():
	"""Restart the entire match with fresh stats"""
	current_round = 0
	player_round_wins = 0
	enemy_round_wins = 0
	match_ended = false
	
	# Reset all damage tracking
	player_total_damage_dealt = 0.0
	player_total_damage_taken = 0.0
	enemy_total_damage_dealt = 0.0
	enemy_total_damage_taken = 0.0
	player_total_hits_landed = 0
	player_total_hits_taken = 0
	enemy_total_hits_landed = 0
	enemy_total_hits_taken = 0
	
	_update_round_wins_display()
	
	if winner_label:
		winner_label.hide()
	if damage_stats_label:
		damage_stats_label.hide()
	
	start_new_round()

func pause_game():
	"""Pause the game"""
	get_tree().paused = true

func resume_game():
	"""Resume the game"""
	get_tree().paused = false
