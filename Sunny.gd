extends CharacterBody2D
class_name Enemy

# ========================================
# Movement
# ========================================

@export var move_speed: float = 300.0
@export var gravity: float = 1800.0

# ========================================
# AI
# ========================================

@export var strike_zone: float = 80.0
@export var personal_space: float = 60.0
@export var aggression: float = 0.6
@export var reaction_time: float = 0.3
@export var tactic_duration: float = 3.0

# ========================================
# Combat
# ========================================

@export var max_health: float = 100.0
@export var light_attack_damage: float = 10.0
@export var heavy_attack_damage: float = 25.0

# ========================================
# Node References
# ========================================

@export var light_hitbox_area: Area2D
@export var heavy_hitbox_area: Area2D
@export var hurtbox_area: Area2D

# ========================================
# State
# ========================================

var current_health: float
var target: CharacterBody2D

var ai_state := "idle"
var state_timer := 0.0
var reaction_timer := 0.0

var is_attacking := false
var is_hit_stunned := false
var is_knockdown := false

var players_hit_this_attack: Array = []

# ========================================
# Signals
# ========================================

signal health_changed(new_health)
signal died()

# ========================================
# Ready
# ========================================

func _ready():

	add_to_group("enemy")
	current_health = max_health

	if light_hitbox_area:
		light_hitbox_area.monitoring = false
		light_hitbox_area.area_entered.connect(_on_light_hit)

	if heavy_hitbox_area:
		heavy_hitbox_area.monitoring = false
		heavy_hitbox_area.area_entered.connect(_on_heavy_hit)

	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_hit)

	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")

# ========================================
# Physics
# ========================================

func _physics_process(delta):

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_attacking or is_hit_stunned or is_knockdown:
		move_and_slide()
		return

	handle_ai(delta)
	move_and_slide()

# ========================================
# AI
# ========================================

func handle_ai(delta):

	if not target:
		return

	var dist = abs(target.global_position.x - global_position.x)
	var dir = sign(target.global_position.x - global_position.x)

	state_timer -= delta
	reaction_timer -= delta

	match ai_state:

		"idle":
			velocity.x = 0

			if state_timer <= 0:
				ai_state = "approach"
				state_timer = tactic_duration

		"approach":
			velocity.x = dir * move_speed

			if dist < strike_zone:
				ai_state = "attack"

		"attack":
			velocity.x = 0

			if reaction_timer <= 0:
				decide_attack()

# ========================================
# Attack Decision
# ========================================

func decide_attack():

	reaction_timer = reaction_time
	players_hit_this_attack.clear()

	if randf() < aggression:
		perform_light_attack()
	else:
		perform_heavy_attack()

# ========================================
# Attacks
# ========================================

func perform_light_attack():

	if is_attacking:
		return

	is_attacking = true

	await get_tree().create_timer(0.1).timeout
	light_hitbox_area.monitoring = true

	await get_tree().create_timer(0.15).timeout
	light_hitbox_area.monitoring = false

	is_attacking = false
	ai_state = "approach"

func perform_heavy_attack():

	if is_attacking:
		return

	is_attacking = true

	await get_tree().create_timer(0.2).timeout
	heavy_hitbox_area.monitoring = true

	await get_tree().create_timer(0.2).timeout
	heavy_hitbox_area.monitoring = false

	is_attacking = false
	ai_state = "approach"

# ========================================
# Hit Detection
# ========================================

func _on_light_hit(area):

	var body = area.get_parent()

	if body and body.is_in_group("player") and body not in players_hit_this_attack:
		players_hit_this_attack.append(body)

		if body.has_method("take_damage"):
			body.take_damage(light_attack_damage)

func _on_heavy_hit(area):

	var body = area.get_parent()

	if body and body.is_in_group("player") and body not in players_hit_this_attack:
		players_hit_this_attack.append(body)

		if body.has_method("take_damage"):
			body.take_damage(heavy_attack_damage)

func _on_hurtbox_hit(area):

	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"))

# ========================================
# Damage
# ========================================

func take_damage(dmg):

	current_health -= dmg
	health_changed.emit(current_health)

	if current_health <= 0:
		die()

func die():
	died.emit()
	queue_free()
