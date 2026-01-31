extends CharacterBody2D
class_name AIFighter

# Movement variables
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0

# Animation variables
var is_walking: bool = false
var is_running: bool = false
var facing_right: bool = true
var is_attacking: bool = false

# Ultimate system
@export var ultimate_charge: float = 0.0
@export var ultimate_max: float = 100.0
@export var ultimate_cost: float = 100.0
var ultimate_active: bool = false

# References
@onready var sprite = $Sprite2D
@onready var heavy_hitbox = $HeavyHitbox
@onready var light_hitbox = $LightHitbox
@onready var ultimate_hitbox = $UltimateHitbox if has_node("UltimateHitbox") else null

# AI Behavior variables
@export var ai_enabled: bool = true
@export var reaction_time: float = 0.3
@export var aggression: float = 0.7
@export var attack_distance: float = 150.0
@export var retreat_distance: float = 80.0
@export var difficulty: float = 0.5

# AI State
enum AIState {
	IDLE,
	APPROACH,
	ATTACK,
	RETREAT,
	BLOCK,
	COMBO,
	ULTIMATE
}

var current_state: AIState = AIState.IDLE
var target: CharacterBody2D = null
var reaction_timer: float = 0.0
var attack_cooldown: float = 0.0
var combo_count: int = 0
var decision_timer: float = 0.0
var next_action: String = ""
var action_queue: Array = []

func _ready():
	decision_timer = randf_range(0.5, 1.5)
	
	# Hide hitboxes by default
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = false
	
	if light_hitbox:
		light_hitbox.monitoring = false
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = false
	
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = false

func _physics_process(delta):
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 20)
		move_and_slide()
		return
	
	if not ai_enabled or target == null:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		move_and_slide()
		return
	
	# Update timers
	reaction_timer -= delta
	attack_cooldown -= delta
	decision_timer -= delta
	
	# Charge ultimate over time
	if ultimate_charge < ultimate_max:
		ultimate_charge += delta * 3.0
	
	# Make decisions periodically
	if decision_timer <= 0:
		make_decision()
		decision_timer = randf_range(0.3, 0.8) / difficulty
	
	# Execute AI behavior
	execute_ai_behavior(delta)
	
	# Apply movement
	move_and_slide()
	
	# Update animation state
	update_animation()

func make_decision():
	if target == null:
		current_state = AIState.IDLE
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	# Consider using ultimate if charged
	if ultimate_charge >= ultimate_cost and distance < attack_distance * 1.2:
		if randf() < (difficulty * 0.3):  # 30% chance at max difficulty
			current_state = AIState.ULTIMATE
			return
	
	# State machine decision making
	match current_state:
		AIState.IDLE:
			if distance > attack_distance:
				current_state = AIState.APPROACH
			elif distance <= attack_distance and attack_cooldown <= 0:
				current_state = AIState.ATTACK
		
		AIState.APPROACH:
			if distance <= attack_distance:
				if randf() < aggression and attack_cooldown <= 0:
					current_state = AIState.ATTACK
				else:
					current_state = AIState.IDLE
			elif distance < retreat_distance:
				current_state = AIState.RETREAT
		
		AIState.ATTACK:
			if attack_cooldown <= 0:
				decide_attack()
			else:
				if distance > attack_distance:
					current_state = AIState.APPROACH
				elif distance < retreat_distance:
					current_state = AIState.RETREAT
				else:
					current_state = AIState.IDLE
		
		AIState.RETREAT:
			if distance > retreat_distance * 1.5:
				current_state = AIState.IDLE
		
		AIState.COMBO:
			if combo_count >= 3 or attack_cooldown > 0.5:
				current_state = AIState.RETREAT
				combo_count = 0

func decide_attack():
	var distance = global_position.distance_to(target.global_position)
	var rand_val = randf()
	
	if distance < attack_distance * 0.6:
		if rand_val < (aggression * 0.6):
			next_action = "heavy_attack"
		else:
			next_action = "light_attack"
	else:
		if rand_val < 0.7:
			next_action = "light_attack"
		else:
			next_action = "heavy_attack"
	
	if randf() < (difficulty * aggression) and combo_count < 3:
		current_state = AIState.COMBO
		combo_count += 1
	else:
		combo_count = 0

func execute_ai_behavior(delta):
	if target == null:
		return
	
	var direction = sign(target.global_position.x - global_position.x)
	var distance = global_position.distance_to(target.global_position)
	
	match current_state:
		AIState.IDLE:
			velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
			is_walking = false
		
		AIState.APPROACH:
			if distance > attack_distance * 0.8:
				simulate_input("ui_right" if direction > 0 else "ui_left", delta)
				is_walking = true
		
		AIState.ATTACK:
			velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
			is_walking = false
			
			if next_action == "light_attack" and reaction_timer <= 0:
				perform_light_attack()
				attack_cooldown = randf_range(0.5, 1.0) / difficulty
				reaction_timer = reaction_time
				next_action = ""
			elif next_action == "heavy_attack" and reaction_timer <= 0:
				perform_heavy_attack()
				attack_cooldown = randf_range(0.8, 1.5) / difficulty
				reaction_timer = reaction_time
				next_action = ""
		
		AIState.RETREAT:
			simulate_input("ui_left" if direction > 0 else "ui_right", delta)
			is_walking = true
		
		AIState.COMBO:
			velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
			if attack_cooldown <= 0:
				if randf() < 0.6:
					perform_light_attack()
					attack_cooldown = 0.3
				else:
					perform_heavy_attack()
					attack_cooldown = 0.5
		
		AIState.ULTIMATE:
			velocity.x = 0
			perform_ultimate_attack()
			current_state = AIState.RETREAT

func simulate_input(action: String, duration: float):
	if action == "ui_left":
		velocity.x = -walk_speed
		if facing_right:
			flip_character(false)
	elif action == "ui_right":
		velocity.x = walk_speed
		if not facing_right:
			flip_character(true)

func flip_character(right: bool):
	facing_right = right
	if sprite:
		sprite.flip_h = not right
	
	if heavy_hitbox and heavy_hitbox.has_node("CollisionShape2D"):
		var hitbox_shape = heavy_hitbox.get_node("CollisionShape2D")
		hitbox_shape.position.x = abs(hitbox_shape.position.x) * (1 if right else -1)
	
	if light_hitbox and light_hitbox.has_node("CollisionShape2D"):
		var hitbox_shape = light_hitbox.get_node("CollisionShape2D")
		hitbox_shape.position.x = abs(hitbox_shape.position.x) * (1 if right else -1)

func update_animation():
	pass

func perform_light_attack():
	if is_attacking:
		return
	is_attacking = true
	light_attack()
	is_attacking = false

func perform_heavy_attack():
	if is_attacking:
		return
	is_attacking = true
	heavy_attack()
	is_attacking = false

func perform_ultimate_attack():
	if is_attacking or ultimate_charge < ultimate_cost:
		return
	is_attacking = true
	ultimate_attack()
	is_attacking = false

func light_attack():
	print("AI light attack!")
	if light_hitbox:
		light_hitbox.monitoring = true
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = true
		
		await get_tree().create_timer(0.15).timeout
		
		light_hitbox.monitoring = false
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = false

func heavy_attack():
	print("AI heavy attack!")
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = true
		
		await get_tree().create_timer(0.25).timeout
		
		heavy_hitbox.monitoring = false
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = false

func ultimate_attack():
	ultimate_active = true
	ultimate_charge = 0.0
	print("AI ULTIMATE ATTACK!")
	
	create_ultimate_effect()
	
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = true
		await get_tree().create_timer(0.5).timeout
		ultimate_hitbox.monitoring = false
	
	ultimate_active = false

func create_ultimate_effect():
	var ultimate_visual = ColorRect.new()
	ultimate_visual.color = Color(0.8, 0, 1, 0.6)  # Purple for AI
	ultimate_visual.size = Vector2(400, 400)
	ultimate_visual.position = Vector2(-200, -200)
	add_child(ultimate_visual)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ultimate_visual, "modulate:a", 0.0, 0.5)
	tween.tween_property(ultimate_visual, "scale", Vector2(1.5, 1.5), 0.5)
	
	await tween.finished
	ultimate_visual.queue_free()

func on_hit_landed(damage: float):
	ultimate_charge = min(ultimate_charge + damage * 2, ultimate_max)

func set_target(new_target: CharacterBody2D):
	target = new_target

func set_difficulty_preset(preset: String):
	match preset:
		"easy":
			difficulty = 0.3
			aggression = 0.4
			reaction_time = 0.6
		"medium":
			difficulty = 0.5
			aggression = 0.6
			reaction_time = 0.4
		"hard":
			difficulty = 0.8
			aggression = 0.8
			reaction_time = 0.2
		"expert":
			difficulty = 1.0
			aggression = 0.9
			reaction_time = 0.1

func _draw():
	if ai_enabled and target:
		draw_circle(Vector2.ZERO, attack_distance, Color(1, 0, 0, 0.1))
		draw_circle(Vector2.ZERO, retreat_distance, Color(0, 0, 1, 0.1))
