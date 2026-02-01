extends Node2D

# ============================================================================
# MULTIPLAYER FIGHT ARENA - Level1.gd
# Converted from Single-Player (Player vs AI) to Multiplayer (Player vs Player)
# ============================================================================

# Spawn positions
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var ai_spawn: Marker2D = $AISpawn  # Now used for Player 2

# UI Elements
@onready var round_display: Label = $UI/RoundDisplay
@onready var player_health_bar: ProgressBar = $UI/PlayerHealth
@onready var ai_health_bar: ProgressBar = $UI/AIHealth  # Now Player 2 Health
@onready var player_ultimate_bar: ProgressBar = $UI/PlayerUltimate
@onready var ai_ultimate_bar: ProgressBar = $UI/AIUltimate  # Now Player 2 Ultimate
@onready var fight_text: Label = $UI/FightText
@onready var player_label: Label = $UI/PlayerLabel
@onready var ai_label: Label = $UI/AILabel  # Now Player 2 Label

# Timers
@onready var round_timer: Timer = $RoundTimer
@onready var restart_timer: Timer = $RestartTimer

# Player scene to spawn
const PLAYER_SCENE = preload("res://TSCN/ChracterPLAYABLE/player.tscn")

# Player references (spawned dynamically)
var player1: CharacterBody2D = null
var player2: CharacterBody2D = null

# Round state
var round_active: bool = false
var match_over: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Only proceed if we're in a multiplayer session
	if not multiplayer.has_multiplayer_peer():
		push_error("Level1: No multiplayer peer found! This scene requires NetworkManager.")
		return
	
	# Update UI labels for multiplayer
	player_label.text = "PLAYER 1"
	ai_label.text = "PLAYER 2"
	
	# Update round display from GameState
	update_round_display()
	
	# Only the server handles spawning
	if multiplayer.is_server():
		spawn_players()
	
	# Start the round
	start_round()


# ============================================================================
# PLAYER SPAWNING (Server Authority)
# ============================================================================

func spawn_players() -> void:
	"""
	Server-side only: Spawns both players and assigns multiplayer authority
	"""
	if not multiplayer.is_server():
		return
	
	# Get peer IDs
	var server_id = 1
	var peers = multiplayer.get_peers()
	var client_id = peers[0] if peers.size() > 0 else -1
	
	if client_id == -1:
		push_error("Level1: No client connected!")
		return
	
	# Spawn Player 1 (Host/Server)
	spawn_player_rpc.rpc(server_id, player_spawn.global_position)
	
	# Spawn Player 2 (Client)
	spawn_player_rpc.rpc(client_id, ai_spawn.global_position)


@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, spawn_position: Vector2) -> void:
	"""
	RPC function to spawn a player on all peers
	"""
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.global_position = spawn_position
	player_instance.name = "Player_" + str(peer_id)
	
	# Set multiplayer authority so only the owning peer can control this player
	player_instance.set_multiplayer_authority(peer_id)
	
	# Add to scene
	add_child(player_instance)
	
	# Store reference based on peer ID
	if peer_id == 1:  # Server is Player 1
		player1 = player_instance
	else:  # Client is Player 2
		player2 = player_instance
	
	# Connect health signals if available
	if player_instance.has_signal("health_changed"):
		player_instance.health_changed.connect(_on_player_health_changed.bind(peer_id))
	
	if player_instance.has_signal("died"):
		player_instance.died.connect(_on_player_died.bind(peer_id))


# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

func start_round() -> void:
	"""
	Starts a new round with countdown
	"""
	round_active = false
	match_over = false
	
	# Disable player controls during countdown
	disable_all_players()
	
	# Show "FIGHT!" text
	fight_text.visible = true
	fight_text.text = "READY"
	
	# Wait 1 second, then show FIGHT
	await get_tree().create_timer(1.0).timeout
	fight_text.text = "FIGHT!"
	
	# Start round timer
	round_timer.start()


func _on_round_timer_timeout() -> void:
	"""
	Called when round countdown finishes - enables combat
	"""
	round_active = true
	fight_text.visible = false
	enable_all_players()


func disable_all_players() -> void:
	"""
	Disables input for all players
	"""
	if player1 and player1.has_method("set_input_enabled"):
		player1.set_input_enabled(false)
	elif player1:
		player1.set_physics_process(false)
	
	if player2 and player2.has_method("set_input_enabled"):
		player2.set_input_enabled(false)
	elif player2:
		player2.set_physics_process(false)


func enable_all_players() -> void:
	"""
	Enables input for all players
	"""
	if player1 and player1.has_method("set_input_enabled"):
		player1.set_input_enabled(true)
	elif player1:
		player1.set_physics_process(true)
	
	if player2 and player2.has_method("set_input_enabled"):
		player2.set_input_enabled(true)
	elif player2:
		player2.set_physics_process(true)


# ============================================================================
# HEALTH & UI SYNCHRONIZATION
# ============================================================================

func _process(_delta: float) -> void:
	"""
	Updates UI elements every frame
	"""
	update_health_bars()
	update_ultimate_bars()


func update_health_bars() -> void:
	"""
	Syncs health bars with player current_health
	"""
	if player1 and "current_health" in player1 and "max_health" in player1:
		var health_percent = (float(player1.current_health) / float(player1.max_health)) * 100.0
		player_health_bar.value = health_percent
	
	if player2 and "current_health" in player2 and "max_health" in player2:
		var health_percent = (float(player2.current_health) / float(player2.max_health)) * 100.0
		ai_health_bar.value = health_percent


func update_ultimate_bars() -> void:
	"""
	Syncs ultimate bars with player ultimate charge
	"""
	if player1 and "ultimate_charge" in player1 and "ultimate_max" in player1:
		var ultimate_percent = (float(player1.ultimate_charge) / float(player1.ultimate_max)) * 100.0
		player_ultimate_bar.value = ultimate_percent
	
	if player2 and "ultimate_charge" in player2 and "ultimate_max" in player2:
		var ultimate_percent = (float(player2.ultimate_charge) / float(player2.ultimate_max)) * 100.0
		ai_ultimate_bar.value = ultimate_percent


func update_round_display() -> void:
	"""
	Updates round display from GameState
	"""
	if GameState:
		round_display.text = "ROUND " + str(GameState.current_round)


func _on_player_health_changed(new_health: int, peer_id: int) -> void:
	"""
	Optional: Called when player health changes via signal
	"""
	# Health bars are already updated in _process, but you can add
	# additional effects here (screen shake, damage numbers, etc.)
	pass


# ============================================================================
# WIN CONDITION & DEFEAT HANDLING
# ============================================================================

func _on_player_died(peer_id: int) -> void:
	"""
	Called when a player dies - handles round/match end
	"""
	if not round_active or match_over:
		return
	
	# Only server processes win conditions
	if not multiplayer.is_server():
		return
	
	round_active = false
	
	# Determine winner (opposite of who died)
	var winner_id = 2 if peer_id == 1 else 1
	
	# Record round winner in GameState
	GameState.record_round_winner(winner_id)
	
	# Check if match is over
	if GameState.is_match_over():
		end_match(winner_id)
	else:
		# Start next round
		restart_round()


func check_for_defeat() -> void:
	"""
	Manually checks if any player has reached 0 health
	Useful if players don't emit "died" signal
	"""
	if not round_active or match_over:
		return
	
	if not multiplayer.is_server():
		return
	
	var player1_dead = false
	var player2_dead = false
	
	if player1 and "current_health" in player1:
		player1_dead = player1.current_health <= 0
	
	if player2 and "current_health" in player2:
		player2_dead = player2.current_health <= 0
	
	if player1_dead:
		_on_player_died(1)
	elif player2_dead:
		_on_player_died(2)


func restart_round() -> void:
	"""
	Restarts the arena for the next round
	"""
	# Show round over message
	show_round_result()
	
	# Wait before restarting
	restart_timer.start()


func _on_restart_timer_timeout() -> void:
	"""
	Reloads the scene for the next round
	"""
	get_tree().reload_current_scene()


func end_match(winner_id: int) -> void:
	"""
	Ends the entire match and returns to main menu
	"""
	match_over = true
	
	# Show match winner
	show_match_result(winner_id)
	
	# Wait 3 seconds before returning to menu
	await get_tree().create_timer(3.0).timeout
	
	# Return to main menu
	get_tree().change_scene_to_file("res://TSCN/MainMenu.tscn")


func show_round_result() -> void:
	"""
	Displays which player won the round
	"""
	fight_text.visible = true
	
	var p1_wins = GameState.player1_rounds if GameState else 0
	var p2_wins = GameState.player2_rounds if GameState else 0
	
	if p1_wins > p2_wins:
		fight_text.text = "PLAYER 1 WINS ROUND!"
	else:
		fight_text.text = "PLAYER 2 WINS ROUND!"


func show_match_result(winner_id: int) -> void:
	"""
	Displays the final match winner
	"""
	fight_text.visible = true
	fight_text.text = "PLAYER " + str(winner_id) + " WINS!"
	
	# Optionally show final score
	var p1_wins = GameState.player1_rounds if GameState else 0
	var p2_wins = GameState.player2_rounds if GameState else 0
	round_display.text = "FINAL SCORE: %d - %d" % [p1_wins, p2_wins]


# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""
	Clean up when leaving the scene
	"""
	if player1:
		player1.queue_free()
	if player2:
		player2.queue_free()
