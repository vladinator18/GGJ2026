extends Node

## Game Manager - Round System and Match Controller
## Handles rounds, UI updates, win conditions, and game flow

# --- Configuration ---
@export_group("Round Settings")
@export var rounds_to_win: int = 2  # Best of 3 by default
@export var round_start_delay: float = 2.0
@export var round_end_delay: float = 3.0
@export var match_end_delay: float = 5.0

@export_group("UI References")
@export var round_counter_label: Label  # Shows "ROUND 1", "ROUND 2", etc.
@export var fight_announcement_label: Label  # Shows "FIGHT!", "K.O.!", etc.
@export var player_health_bar: ProgressBar
@export var enemy_health_bar: ProgressBar
@export var player_health_label: Label  # Optional: Shows "100/100"
@export var enemy_health_label: Label   # Optional: Shows "100/100"
@export var player_wins_label: Label    # Shows player's round wins
@export var enemy_wins_label: Label     # Shows enemy's round wins
@export var combo_label: Label          # Shows combo counter
@export var timer_label: Label          # Shows round timer
@export var winner_label: Label         # Shows final winner

@export_group("Character References")
@export var player: Node2D
@export var enemy: Node2D

@export_group("Spawn Positions")
@export var player_spawn_position: Vector2 = Vector2(247, 425)
@export var enemy_spawn_position: Vector2 = Vector2(936, 425)

@export_group("Round Timer")
@export var enable_round_timer: bool = true
@export var round_time_seconds: float = 99.0

# --- Internal State ---
var current_round: int = 0
var player_round_wins: int = 0
var enemy_round_wins: int = 0
var round_timer: float = 0.0
var is_round_active: bool = false
var match_ended: bool = false

enum GameState { IDLE, ROUND_START, FIGHTING, ROUND_END, MATCH_END }
var current_game_state: GameState = GameState.IDLE

func _ready():
	add_to_group("game_manager")
	
	# Hide fight announcements initially
	if fight_announcement_label:
		fight_announcement_label.hide()
	
	if winner_label:
		winner_label.hide()
	
	# Initialize UI
	_update_round_wins_display()
	_update_health_bars()
	
	print("✓ Game Manager ready")
	print("✓ Rounds to win: ", rounds_to_win)
	
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

# --- Round Management ---

func start_new_round():
	if match_ended:
		return
	
	current_round += 1
	current_game_state = GameState.ROUND_START
	is_round_active = false
	round_timer = round_time_seconds
	
	print("\n=== ROUND ", current_round, " START ===")
	
	# Update UI
	if round_counter_label:
		round_counter_label.text = "ROUND " + str(current_round)
	
	# Reset characters
	_reset_characters()
	
	# Show "READY" announcement
	_show_announcement("READY")
	await get_tree().create_timer(1.5).timeout
	
	# Show "FIGHT!" and start round
	_show_announcement("FIGHT!")
	await get_tree().create_timer(1.0).timeout
	
	if fight_announcement_label:
		fight_announcement_label.hide()
	
	current_game_state = GameState.FIGHTING
	is_round_active = true
	
	# Enable character controls
	if player:
		player.set_physics_process(true)
	if enemy:
		enemy.set_physics_process(true)

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
	
	print("=== ROUND ", current_round, " END - Winner: ", winner, " ===")
	
	# Disable character controls
	if player:
		player.set_physics_process(false)
	if enemy:
		enemy.set_physics_process(false)
	
	# Update round wins
	if winner == "player":
		player_round_wins += 1
		_show_announcement("K.O.!")
	else:
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
	
	print("\n🏆 === MATCH END - ", winner.to_upper(), " WINS! === 🏆")
	
	# Show winner announcement
	var winner_text = "PLAYER WINS!" if winner == "player" else "ENEMY WINS!"
	_show_announcement(winner_text)
	
	if winner_label:
		winner_label.text = winner_text
		winner_label.show()
	
	await get_tree().create_timer(match_end_delay).timeout
	
	# Option to restart or return to menu
	print("Match complete. Reload scene to play again.")

# --- Character Events ---

func on_player_defeated():
	"""Called when player health reaches 0"""
	if is_round_active:
		end_round("enemy")

func on_enemy_defeated():
	"""Called when enemy health reaches 0"""
	if is_round_active:
		end_round("player")

# --- UI Updates ---

func update_player_health(current: float, maximum: float):
	if player_health_bar:
		player_health_bar.max_value = maximum
		player_health_bar.value = current
	
	if player_health_label:
		player_health_label.text = "%d/%d" % [int(current), int(maximum)]
	
	# Check for defeat
	if current <= 0 and is_round_active:
		on_player_defeated()

func update_enemy_health(current: float, maximum: float):
	if enemy_health_bar:
		enemy_health_bar.max_value = maximum
		enemy_health_bar.value = current
	
	if enemy_health_label:
		enemy_health_label.text = "%d/%d" % [int(current), int(maximum)]
	
	# Check for defeat
	if current <= 0 and is_round_active:
		on_enemy_defeated()

func update_combo(combo_count: int):
	if combo_label:
		if combo_count > 1:
			combo_label.text = str(combo_count) + " HIT COMBO!"
			combo_label.show()
		else:
			combo_label.hide()

func _update_health_bars():
	"""Update both health bars to full"""
	if player:
		update_player_health(player.current_health, player.max_health)
	if enemy:
		update_enemy_health(enemy.current_health, enemy.max_health)

func _update_round_wins_display():
	if player_wins_label:
		player_wins_label.text = "P: " + str(player_round_wins)
	
	if enemy_wins_label:
		enemy_wins_label.text = "E: " + str(enemy_round_wins)

func _update_timer_display():
	if timer_label:
		var minutes = int(round_timer) / 60
		var seconds = int(round_timer) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _show_announcement(text: String):
	if fight_announcement_label:
		fight_announcement_label.text = text
		fight_announcement_label.show()

# --- Public Utility Functions ---

func restart_match():
	"""Restart the entire match"""
	current_round = 0
	player_round_wins = 0
	enemy_round_wins = 0
	match_ended = false
	_update_round_wins_display()
	
	if winner_label:
		winner_label.hide()
	
	start_new_round()

func pause_game():
	get_tree().paused = true

func resume_game():
	get_tree().paused = false
