extends Node2D

# Round system
var current_round: int = 1
var max_rounds: int = 3
var player_wins: int = 0
var ai_wins: int = 0

# Health tracking
var player_health: float = 100.0
var ai_health: float = 100.0
var max_health: float = 100.0

# Round state
var round_active: bool = false
var match_over: bool = false

# References
@onready var player = $Player
@onready var ai = $AI
@onready var ui = $UI
@onready var round_display = $UI/RoundDisplay
@onready var player_health_bar = $UI/PlayerHealth
@onready var ai_health_bar = $UI/AIHealth
@onready var fight_text = $UI/FightText
@onready var round_timer = $RoundTimer
@onready var restart_timer = $RestartTimer
@onready var player_spawn = $PlayerSpawn
@onready var ai_spawn = $AISpawn

func _ready():
	# Set up AI with harder difficulty for level 2
	if ai.has_method("set_target"):
		ai.set_target(player)
		ai.set_difficulty_preset("hard")  # Harder for level 2!
		ai.ai_enabled = false
	
	# Connect hitbox signals
	setup_combat_detection()
	
	# Start first round
	start_round()

func setup_combat_detection():
	# Connect player attacks to AI damage
	if player.has_node("HeavyHitbox"):
		var heavy = player.get_node("HeavyHitbox")
		if not heavy.area_entered.is_connected(_on_player_heavy_hit):
			heavy.area_entered.connect(_on_player_heavy_hit)
	
	if player.has_node("LightHitbox"):
		var light = player.get_node("LightHitbox")
		if not light.area_entered.is_connected(_on_player_light_hit):
			light.area_entered.connect(_on_player_light_hit)
	
	# Connect AI attacks to player damage
	if ai.has_node("HeavyHitbox"):
		var heavy = ai.get_node("HeavyHitbox")
		if not heavy.area_entered.is_connected(_on_ai_heavy_hit):
			heavy.area_entered.connect(_on_ai_heavy_hit)
	
	if ai.has_node("LightHitbox"):
		var light = ai.get_node("LightHitbox")
		if not light.area_entered.is_connected(_on_ai_light_hit):
			light.area_entered.connect(_on_ai_light_hit)

func start_round():
	round_active = false
	
	# Reset positions
	player.global_position = player_spawn.global_position
	ai.global_position = ai_spawn.global_position
	player.velocity = Vector2.ZERO
	ai.velocity = Vector2.ZERO
	
	# Reset health
	player_health = max_health
	ai_health = max_health
	update_health_bars()
	
	# Update UI
	round_display.text = "ROUND %d" % current_round
	round_display.visible = true
	fight_text.visible = false
	
	# Disable AI and player control temporarily
	if ai.has_method("set"):
		ai.ai_enabled = false
	
	# Start countdown
	round_timer.start()

func _on_round_timer_timeout():
	# Show FIGHT! and enable combat
	fight_text.visible = true
	fight_text.text = "FIGHT!"
	round_display.visible = false
	round_active = true
	
	# Enable AI
	if ai.has_method("set"):
		ai.ai_enabled = true
	
	# Hide FIGHT text after 1 second
	await get_tree().create_timer(1.0).timeout
	fight_text.visible = false

func _physics_process(delta):
	if not round_active or match_over:
		return
	
	# Check for round end
	if player_health <= 0:
		end_round(false)
	elif ai_health <= 0:
		end_round(true)

func end_round(player_won: bool):
	round_active = false
	
	if player_won:
		player_wins += 1
		fight_text.text = "PLAYER WINS!"
	else:
		ai_wins += 1
		fight_text.text = "AI WINS!"
	
	fight_text.visible = true
	
	# Disable AI
	if ai.has_method("set"):
		ai.ai_enabled = false
	
	# Check if match is over
	if player_wins >= 2 or ai_wins >= 2:
		# Match over
		await get_tree().create_timer(2.0).timeout
		end_match()
	else:
		# Next round
		current_round += 1
		restart_timer.start()

func _on_restart_timer_timeout():
	start_round()

func end_match():
	match_over = true
	
	if player_wins > ai_wins:
		fight_text.text = "PLAYER WINS THE MATCH!\n%d - %d" % [player_wins, ai_wins]
	else:
		fight_text.text = "AI WINS THE MATCH!\n%d - %d" % [ai_wins, player_wins]
	
	fight_text.visible = true
	
	# Option to restart
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

# Combat damage functions
func _on_player_heavy_hit(area):
	if area.get_parent() == ai and round_active:
		deal_damage_to_ai(20.0)

func _on_player_light_hit(area):
	if area.get_parent() == ai and round_active:
		deal_damage_to_ai(10.0)

func _on_ai_heavy_hit(area):
	if area.get_parent() == player and round_active:
		deal_damage_to_player(20.0)

func _on_ai_light_hit(area):
	if area.get_parent() == player and round_active:
		deal_damage_to_player(10.0)

func deal_damage_to_player(amount: float):
	player_health -= amount
	player_health = max(0, player_health)
	update_health_bars()
	print("Player took %d damage! Health: %d" % [amount, player_health])

func deal_damage_to_ai(amount: float):
	ai_health -= amount
	ai_health = max(0, ai_health)
	update_health_bars()
	print("AI took %d damage! Health: %d" % [amount, ai_health])

func update_health_bars():
	player_health_bar.value = player_health
	ai_health_bar.value = ai_health
