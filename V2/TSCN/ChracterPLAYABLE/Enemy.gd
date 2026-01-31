extends CharacterBody2D
class_name AIFighter

# Movement variables
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0

# Health system
@export var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

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

# Visual feedback
var hitbox_original_colors = {}

# AI Variables
@export var ai_enabled: bool = true
var target: CharacterBody2D = null
var ai_attack_timer: float = 0.0
var ai_decision_timer: float = 0.0
@export var ai_aggression: float = 0.7  # How often AI attacks (0-1)
@export var ai_attack_distance: float = 150.0

func _ready():
	current_health = max_health
	add_to_group("ai")
	add_to_group("alive")
	
	# Store original hitbox colors and hide them
	if heavy_hitbox and heavy_hitbox.has_node("Visual"):
		var visual = heavy_hitbox.get_node("Visual")
		hitbox_original_colors["heavy"] = visual.color
		visual.visible = false
	
	if light_hitbox and light_hitbox.has_node("Visual"):
		var visual = light_hitbox.get_node("Visual")
		hitbox_original_colors["light"] = visual.color
		visual.visible = false
	
	# Disable hitbox monitoring by default
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		heavy_hitbox.area_entered.connect(_on_heavy_hitbox_area_entered)
	if light_hitbox:
		light_hitbox.monitoring = false
		light_hitbox.area_entered.connect(_on_light_hitbox_area_entered)
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = false
		ultimate_hitbox.area_entered.connect(_on_ultimate_hitbox_area_entered)
	
	# Random initial timers
	ai_attack_timer = randf_range(0.5, 1.5)
	ai_decision_timer = randf_range(0.3, 0.8)

func _physics_process(delta):
	# Check if dead
	if is_dead or current_health <= 0:
		if not is_dead:
			die()
		velocity.x = 0
		return
	
	# Don't allow movement during attacks
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 20)
		move_and_slide()
		return
	
	# AI BEHAVIOR REPLACES PLAYER INPUT
	if ai_enabled and target:
		ai_behavior(delta)
	else:
		# No AI or no target - stand still
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		is_walking = false
		is_running = false
	
	# Apply movement
	move_and_slide()
	
	# Update animation state
	update_animation()
	
	# Charge ultimate slowly over time
	if ultimate_charge < ultimate_max:
		ultimate_charge += delta * 5.0  # Passive charge

func ai_behavior(delta):
	"""AI logic that replaces player input"""
	# Update timers
	ai_attack_timer -= delta
	ai_decision_timer -= delta
	
	# Get distance to target
	var distance = global_position.distance_to(target.global_position)
	var direction = sign(target.global_position.x - global_position.x)
	
	# MOVEMENT AI - Approach if far, retreat if too close
	if distance > ai_attack_distance:
		# Too far - move towards player
		if direction > 0:
			ai_simulate_input("ui_right")
		else:
			ai_simulate_input("ui_left")
		is_walking = true
	elif distance < 80:
		# Too close - back up
		if direction > 0:
			ai_simulate_input("ui_left")
		else:
			ai_simulate_input("ui_right")
		is_walking = true
	else:
		# Good distance - stop moving
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		is_walking = false
	
	# ATTACK AI - Decide when to attack
	if ai_attack_timer <= 0 and distance <= ai_attack_distance and not is_attacking:
		if ai_decision_timer <= 0:
			var attack_choice = randf()
			
			# Choose attack based on aggression and distance
			if ultimate_charge >= ultimate_cost and randf() < 0.3:
				# Use ultimate
				ultimate_attack()
				ai_attack_timer = randf_range(2.0, 3.0)
			elif attack_choice < ai_aggression * 0.5:
				# Heavy attack
				heavy_attack()
				ai_attack_timer = randf_range(1.0, 1.5)
			elif attack_choice < ai_aggression:
				# Light attack
				light_attack()
				ai_attack_timer = randf_range(0.5, 1.0)
			
			ai_decision_timer = randf_range(0.2, 0.5)

func ai_simulate_input(action: String):
	"""Simulates input for AI movement"""
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
	
	# Flip hitboxes if needed
	if heavy_hitbox and heavy_hitbox.has_node("CollisionShape2D"):
		var hitbox_shape = heavy_hitbox.get_node("CollisionShape2D")
		hitbox_shape.position.x = abs(hitbox_shape.position.x) * (1 if right else -1)
	
	if light_hitbox and light_hitbox.has_node("CollisionShape2D"):
		var hitbox_shape = light_hitbox.get_node("CollisionShape2D")
		hitbox_shape.position.x = abs(hitbox_shape.position.x) * (1 if right else -1)

func update_animation():
	# Simplified - no frame animation until you add AnimatedSprite2D
	pass

# Combat functions with visual feedback
func light_attack():
	if is_attacking or is_dead:
		return
	
	is_attacking = true
	print("AI light attack!")
	
	# Show hitbox visual
	if light_hitbox:
		light_hitbox.monitoring = true
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = true
		
		# Flash effect
		await flash_hitbox(light_hitbox, 0.15)
		
		# Hide and disable
		light_hitbox.monitoring = false
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = false
	
	is_attacking = false

func heavy_attack():
	if is_attacking or is_dead:
		return
	
	is_attacking = true
	print("AI heavy attack!")
	
	# Show hitbox visual
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = true
		
		# Flash effect (longer for heavy)
		await flash_hitbox(heavy_hitbox, 0.25)
		
		# Hide and disable
		heavy_hitbox.monitoring = false
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = false
	
	is_attacking = false

func ultimate_attack():
	if is_attacking or ultimate_charge < ultimate_cost or is_dead:
		return
	
	is_attacking = true
	ultimate_active = true
	ultimate_charge = 0.0  # Consume all charge
	
	print("AI ULTIMATE ATTACK!")
	
	# Create ultimate visual effect
	create_ultimate_effect()
	
	# Large AOE damage
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = true
		await get_tree().create_timer(0.5).timeout
		ultimate_hitbox.monitoring = false
	
	is_attacking = false
	ultimate_active = false

func flash_hitbox(hitbox: Area2D, duration: float):
	"""Flash the hitbox for visual feedback"""
	await get_tree().create_timer(duration).timeout

func create_ultimate_effect():
	"""Create a large circular ultimate effect"""
	# Create a temporary visual node
	var ultimate_visual = ColorRect.new()
	ultimate_visual.color = Color(0.8, 0, 1, 0.6)  # Purple for AI
	ultimate_visual.size = Vector2(400, 400)
	ultimate_visual.position = Vector2(-200, -200)
	add_child(ultimate_visual)
	
	# Animate it
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ultimate_visual, "modulate:a", 0.0, 0.5)
	tween.tween_property(ultimate_visual, "scale", Vector2(1.5, 1.5), 0.5)
	
	# Remove after animation
	await tween.finished
	ultimate_visual.queue_free()

# Hitbox collision handlers
func _on_light_hitbox_area_entered(area: Area2D):
	"""Called when light attack hitbox hits something"""
	var target_hit = area.get_parent()
	if target_hit and target_hit != self and target_hit.has_method("take_damage"):
		var damage = 10.0
		target_hit.take_damage(damage)
		on_hit_landed(damage)

func _on_heavy_hitbox_area_entered(area: Area2D):
	"""Called when heavy attack hitbox hits something"""
	var target_hit = area.get_parent()
	if target_hit and target_hit != self and target_hit.has_method("take_damage"):
		var damage = 20.0
		target_hit.take_damage(damage)
		on_hit_landed(damage)

func _on_ultimate_hitbox_area_entered(area: Area2D):
	"""Called when ultimate hitbox hits something"""
	var target_hit = area.get_parent()
	if target_hit and target_hit != self and target_hit.has_method("take_damage"):
		var damage = 50.0
		target_hit.take_damage(damage)
		on_hit_landed(damage)

# Damage handling
func take_damage(damage: float):
	"""Called when this AI takes damage"""
	if is_dead:
		return
	
	current_health -= damage
	print("AI took ", damage, " damage! Health: ", current_health)
	
	# Flash red when hit
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if sprite:
			sprite.modulate = Color(1, 1, 1)
	
	# Charge ultimate when taking damage
	ultimate_charge = min(ultimate_charge + damage * 1.0, ultimate_max)
	
	if current_health <= 0:
		die()

func die():
	"""Handle AI death"""
	is_dead = true
	remove_from_group("alive")
	print("AI defeated!")
	
	# Disable AI
	ai_enabled = false
	
	# Disable hitboxes
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
	if light_hitbox:
		light_hitbox.monitoring = false
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = false
	
	# Optional: Add death animation
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		await tween.finished

# Called when this character hits something
func on_hit_landed(damage: float):
	"""Called when an attack lands"""
	# Charge ultimate on hit
	ultimate_charge = min(ultimate_charge + damage * 2, ultimate_max)
	print("AI Ultimate charge: ", ultimate_charge, "/", ultimate_max)

# AI Setup function
func set_target(new_target: CharacterBody2D):
	"""Set the player as the AI's target"""
	target = new_target
	print("AI target set to: ", new_target.name if new_target else "none")
