extends Node2D

# Round system
var current_round: int = 1
var max_rounds: int = 3
var player_wins: int = 0
var ai_wins: int = 0

# Health tracking
var player_health: float = 100.0
var ai_health: float = 100.0
@export var max_health: float = 100.0

# Round state
var round_active: bool = false
var match_over: bool = false

# === ASSIGN THESE IN INSPECTOR ===
@export_group("Characters")
@export var player: CharacterBody2D
@export var ai_fighter: CharacterBody2D

@export_group("Spawn Points")
@export var player_spawn: Marker2D
@export var ai_spawn: Marker2D

@export_group("UI Elements")
@export var round_display: Label
@export var player_health_bar: ProgressBar
@export var ai_health_bar: ProgressBar
@export var player_ultimate_bar: ProgressBar
@export var ai_ultimate_bar: ProgressBar
@export var fight_text: Label

@export_group("Timers")
@export var round_timer: Timer
@export var restart_timer: Timer

# Hitbox references
var p_light: Area2D; var p_heavy: Area2D; var p_ult: Area2D
var a_light: Area2D; var a_heavy: Area2D; var a_ult: Area2D

func _ready():
	_setup_hitboxes()
	_setup_signals()
	start_round()

func _setup_hitboxes():
	# Cache references to avoid repeated get_node calls
	if player:
		p_light = player.get_node_or_null("LightHitbox")
		p_heavy = player.get_node_or_null("HeavyHitbox")
		p_ult = player.get_node_or_null("UltimateHitbox")
	if ai_fighter:
		a_light = ai_fighter.get_node_or_null("LightHitbox")
		a_heavy = ai_fighter.get_node_or_null("HeavyHitbox")
		a_ult = ai_fighter.get_node_or_null("UltimateHitbox")
		if ai_fighter.has_method("set_target"): ai_fighter.set_target(player)

func _setup_signals():
	if round_timer: round_timer.timeout.connect(_on_round_timer_timeout)
	if restart_timer: restart_timer.timeout.connect(_on_restart_timer_timeout)

func start_round():
	round_active = false
	match_over = false
	
	# Reset Positions
	player.global_position = player_spawn.global_position if player_spawn else Vector2(200, 300)
	ai_fighter.global_position = ai_spawn.global_position if ai_spawn else Vector2(600, 300)
	player.velocity = Vector2.ZERO
	ai_fighter.velocity = Vector2.ZERO
	
	# Reset Stats
	player_health = max_health
	ai_health = max_health
	if "ultimate_charge" in player: player.ultimate_charge = 0
	if "ultimate_charge" in ai_fighter: ai_fighter.ultimate_charge = 0
	
	update_ui()
	
	if round_display:
		round_display.text = "ROUND %d" % current_round
		round_display.visible = true
	if fight_text: fight_text.visible = false
	if "ai_enabled" in ai_fighter: ai_fighter.ai_enabled = false
	
	round_timer.start()

func _on_round_timer_timeout():
	round_active = true
	if fight_text:
		fight_text.text = "FIGHT!"
		fight_text.visible = true
		get_tree().create_timer(1.0).timeout.connect(func(): fight_text.visible = false)
	
	if round_display: round_display.visible = false
	if "ai_enabled" in ai_fighter: ai_fighter.ai_enabled = true

func _physics_process(_delta):
	if not round_active or match_over: return
	
	# Only check damage if a hitbox is actually active (saves CPU)
	check_player_attacks()
	check_ai_attacks()
	
	# Win/Loss Check
	if player_health <= 0: end_round(false)
	elif ai_health <= 0: end_round(true)

func check_player_attacks():
	if p_light and p_light.monitoring:
		if check_hit(p_light, ai_fighter, 120):
			deal_damage(ai_fighter, 10); charge_ult(player, 15)
			p_light.set_deferred("monitoring", false)
			
	if p_heavy and p_heavy.monitoring:
		if check_hit(p_heavy, ai_fighter, 140):
			deal_damage(ai_fighter, 25); charge_ult(player, 30)
			p_heavy.set_deferred("monitoring", false)

func check_ai_attacks():
	if a_light and a_light.monitoring:
		if check_hit(a_light, player, 120):
			deal_damage(player, 10); charge_ult(ai_fighter, 15)
			a_light.set_deferred("monitoring", false)

func check_hit(hitbox: Area2D, target: CharacterBody2D, range_limit: float) -> bool:
	# Priority 1: Distance (fastest)
	if hitbox.global_position.distance_to(target.global_position) < range_limit:
		return true
	# Priority 2: Physical overlap (most accurate)
	if hitbox.get_overlapping_bodies().has(target):
		return true
	return false

func deal_damage(target, amount):
	if target == ai_fighter:
		ai_health = max(0, ai_health - amount)
		print("★ AI Hit! HP: ", ai_health)
	else:
		player_health = max(0, player_health - amount)
		print("★ Player Hit! HP: ", player_health)
	update_ui()

func charge_ult(char, amount):
	if "ultimate_charge" in char:
		char.ultimate_charge = min(char.ultimate_charge + amount, 100)
		update_ui()

func update_ui():
	if player_health_bar: player_health_bar.value = player_health
	if ai_health_bar: ai_health_bar.value = ai_health
	if player_ultimate_bar and "ultimate_charge" in player:
		player_ultimate_bar.value = player.ultimate_charge
	if ai_ultimate_bar and "ultimate_charge" in ai_fighter:
		ai_ultimate_bar.value = ai_fighter.ultimate_charge

func end_round(player_won: bool):
	round_active = false
	if player_won: player_wins += 1
	else: ai_wins += 1
	
	if fight_text:
		fight_text.text = "PLAYER WINS ROUND!" if player_won else "AI WINS ROUND!"
		fight_text.visible = true
	
	if player_wins >= 2 or ai_wins >= 2:
		match_over = true
		get_tree().create_timer(2.0).timeout.connect(end_match)
	else:
		current_round += 1
		restart_timer.start()

func _on_restart_timer_timeout():
	start_round()

func end_match():
	if fight_text:
		fight_text.text = "MATCH OVER!"
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
