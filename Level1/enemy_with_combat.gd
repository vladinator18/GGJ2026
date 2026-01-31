extends CharacterBody2D
class_name Enemy

# Movement parameters
@export var move_speed: float = 250.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1800.0
@export var floor_y_level: float = 500.0

# AI parameters
@export var strike_zone: float = 80.0
@export var personal_space: float = 60.0
@export var aggression: float = 0.6
@export var reaction_time: float = 0.3
@export var tactic_duration: float = 3.0

# Combat parameters
@export var max_health: float = 100.0
@export var light_attack_damage: float = 10.0
@export var heavy_attack_damage: float = 25.0
@export var block_chance: float = 0.3

# State variables
var current_health: float
var is_attacking := false
var is_blocking := false
var is_hit_stunned := false
var is_knockdown := false
var facing_right := false

# AI
var target: CharacterBody2D
var ai_state := "idle"
var state_timer := 0.0
var reaction_timer := 0.0

# Node references
var sprite: Sprite2D
var light_hitbox: Area2D
var heavy_hitbox: Area2D
var hurtbox: Area2D

signal health_changed(new_health)
signal died()

func _ready():
	current_health = max_health

	sprite = $Sprite
	light_hitbox = $Hitboxes/LightHitbox
	heavy_hitbox = $Hitboxes/HeavyHitbox
	hurtbox = $Hurtbox

	if light_hitbox:
		light_hitbox.monitoring = false
		light_hitbox.area_entered.connect(_on_light_hitbox_area_entered)

	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		heavy_hitbox.area_entered.connect(_on_heavy_hitbox_area_entered)

	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta):

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_attacking or is_hit_stunned or is_knockdown:
		move_and_slide()
		return

	handle_ai(delta)
	move_and_slide()

func handle_ai(delta):

	if not target:
		return

	var dist = abs(target.global_position.x - global_position.x)
	var dir = sign(target.global_position.x - global_position.x)

	reaction_timer -= delta
	state_timer -= delta

	match ai_state:
		"idle":
			velocity.x = 0

			if state_timer <= 0:
				ai_state = "approach"
				state_timer = randf_range(1, tactic_duration)

		"approach":
			velocity.x = dir * move_speed

			if dist < strike_zone:
				ai_state = "attack"

		"attack":
			velocity.x = 0

			if reaction_timer <= 0:
				decide_attack()

func decide_attack():

	reaction_timer = reaction_time

	if randf() < 0.7:
		perform_light_attack()
	else:
		perform_heavy_attack()

func perform_light_attack():

	if is_attacking:
		return

	is_attacking = true

	await get_tree().create_timer(0.1).timeout
	light_hitbox.monitoring = true

	await get_tree().create_timer(0.15).timeout
	light_hitbox.monitoring = false

	is_attacking = false

func perform_heavy_attack():

	if is_attacking:
		return

	is_attacking = true

	await get_tree().create_timer(0.2).timeout
	heavy_hitbox.monitoring = true

	await get_tree().create_timer(0.2).timeout
	heavy_hitbox.monitoring = false

	is_attacking = false

func _on_light_hitbox_area_entered(area):

	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(light_attack_damage)

func _on_heavy_hitbox_area_entered(area):

	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(heavy_attack_damage)

func _on_hurtbox_area_entered(area):

	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"))

func take_damage(dmg):

	current_health -= dmg
	health_changed.emit(current_health)

	if current_health <= 0:
		die()

func die():
	died.emit()
	queue_free()
