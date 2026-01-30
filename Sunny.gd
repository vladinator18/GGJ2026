extends Sprite2D

## Arcade Fighter Character Controller
## Floaty physics with air control, dashes, combo system, and frame-based attacks

# Movement
@export_group("Movement")
@export var ground_speed: float = 1500.0
@export var air_speed: float = 500.0
@export var jump_strength: float = -2000.0
@export var short_hop_strength: float = -350.0
@export var gravity: float = 1500.0
@export var max_fall_speed: float = 1500.0
@export var air_friction: float = 1.11

# Arcade Feel
@export_group("Arcade Mechanics")
@export var air_dash_speed: float = 450.0
@export var air_dash_duration: float = 0.2
@export var max_air_dashes: int = 2
@export var double_jump_enabled: bool = true
@export var fast_fall_multiplier: float = 2.0

# Combat
@export_group("Combat")
@export var light_damage: float = 10.0
@export var heavy_damage: float = 25.0
@export var special_damage: float = 40.0
@export var combo_reset_time: float = 0.8
@export var hitstun_duration: float = 0.3

# Health
@export_group("Health")
@export var max_health: float = 100.0
@export var health_bar: ProgressBar

# Hitboxes
@export_group("Hitboxes")
@export var light_hitbox: CollisionShape2D
@export var heavy_hitbox: CollisionShape2D

# Animations
@export_group("Animations")
@export var anim_player: AnimationPlayer
@export var idle_anim: String = "idle"
@export var walk_anim: String = "walk"
@export var jump_anim: String = "jump"
@export var fall_anim: String = "fall"
@export var dash_anim: String = "dash"
@export var crouch_anim: String = "crouch"
@export var light_attack_anim: String = "light_attack"
@export var heavy_attack_anim: String = "heavy_attack"
@export var special_anim: String = "special_attack"
@export var air_attack_anim: String = "air_attack"
@export var block_anim: String = "block"
@export var hurt_anim: String = "hurt"

# Attack Sprites
@export_group("Attack Sprites")
@export var light_attack_sprites: Array[Texture2D] = []  # 5 images for light attack
@export var heavy_attack_sprites: Array[Texture2D] = []  # 8 images for heavy attack

# Walk Cycle Animation
@export_group("Walk Cycle")
@export var walk_frame_duration: float = 0.1  # Duration to show each image
@export var walk_sprites: Array[Texture2D] = []  # 5 walk cycle images

# State
var velocity := Vector2.ZERO
var is_grounded := false
var can_move := true
var is_attacking := false
var is_blocking := false
var is_dashing := false
var facing_right := true

var air_dashes_used := 0
var jumps_used := 0
var max_jumps := 2
var combo_count := 0
var combo_timer := 0.0
var dash_timer := 0.0

# Health
var current_health: float

# Attack Animation State
var current_attack_frame := 0
var attack_frame_timer := 0.0
var light_punch_frames := 5  # Total frames for light punch
var heavy_punch_frames := 8  # Total frames for heavy punch
var current_attack_type := ""
var attack_frame_duration := 0.05  # Duration of each attack frame

# Walk cycle state
var walk_sprite_index := 0
var walk_frame_timer := 0.0

func _ready():
	if not anim_player:
		push_warning("AnimationPlayer not assigned!")
	
	# Initialize health
	current_health = max_health
	_update_health_bar()
	
	# Hide hitboxes initially
	if light_hitbox:
		light_hitbox.disabled = true
	if heavy_hitbox:
		heavy_hitbox.disabled = true
	
	# Set initial walk sprite to image 0
	if walk_sprites.size() > 0:
		texture = walk_sprites[0]

func _physics_process(delta: float):
	_update_timers(delta)
	_apply_gravity(delta)
	
	if can_move and not is_attacking:
		_handle_movement()
	
	if is_attacking:
		_update_attack_frames(delta)
	
	_apply_floaty_physics(delta)
	_move_character(delta)
	_update_animation(delta)

func _input(event: InputEvent):
	if not can_move:
		return
	
	if not is_attacking:
		_handle_attacks(event)
	
	if event.is_action_pressed("ui_block"):
		is_blocking = true
	elif event.is_action_released("ui_block"):
		is_blocking = false

func _update_timers(delta: float):
	if combo_timer > 0:
		combo_timer -= delta
	else:
		combo_count = 0
	
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

func _apply_gravity(delta: float):
	if not is_grounded:
		var grav = gravity
		
		# Fast fall
		if Input.is_action_pressed("ui_down") and velocity.y > 0:
			grav *= fast_fall_multiplier
		
		velocity.y += grav * delta
		velocity.y = min(velocity.y, max_fall_speed)

func _handle_movement():
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Ground movement
	if is_grounded:
		velocity.x = input_dir * ground_speed
		air_dashes_used = 0
		jumps_used = 0
		
		# Jump
		if Input.is_action_just_pressed("ui_up"):
			_jump()
	
	# Air movement
	else:
		if not is_dashing:
			var speed = air_speed if input_dir != 0 else ground_speed
			velocity.x = lerp(velocity.x, input_dir * speed, 0.15)
		
		# Double jump
		if Input.is_action_just_pressed("ui_up"):
			if double_jump_enabled and jumps_used < max_jumps:
				_jump()
		
		# Air dash
		if Input.is_action_just_pressed("ui_dash"):
			if air_dashes_used < max_air_dashes:
				_air_dash(input_dir)
	
	# Update facing
	if input_dir > 0:
		facing_right = true
		scale.x = abs(scale.x)
	elif input_dir < 0:
		facing_right = false
		scale.x = -abs(scale.x)

func _jump():
	var strength = jump_strength
	
	# Short hop if tap
	if not Input.is_action_pressed("ui_up"):
		strength = short_hop_strength
	
	velocity.y = strength
	jumps_used += 1
	is_grounded = false

func _air_dash(direction: float):
	is_dashing = true
	dash_timer = air_dash_duration
	air_dashes_used += 1
	
	var dash_dir = direction if direction != 0 else (1 if facing_right else -1)
	velocity.x = dash_dir * air_dash_speed
	velocity.y *= 0.5  # Reduce vertical momentum
	
	if anim_player:
		anim_player.play(dash_anim)

func _apply_floaty_physics(delta: float):
	# Air friction for arcade feel
	if not is_grounded and not is_dashing:
		velocity.x *= air_friction

func _move_character(delta: float):
	position += velocity * delta
	
	# Ground detection (replace with proper collision)
	if position.y >= 500:
		position.y = 500
		velocity.y = 0
		is_grounded = true
		jumps_used = 0
	else:
		is_grounded = false

func _handle_attacks(event: InputEvent):
	# Light punch
	if event.is_action_pressed("ui_lightpunch"):
		_start_attack("light", light_damage)
	
	# Heavy punch
	elif event.is_action_pressed("ui_heavypunch"):
		_start_attack("heavy", heavy_damage)
	
	# Special attack
	elif event.is_action_pressed("ui_special_attack"):
		_attack("special", special_anim, special_damage)

func _start_attack(type: String, damage: float):
	is_attacking = true
	can_move = false
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	combo_timer = combo_reset_time
	combo_count += 1
	
	print("%s attack started! Damage: %.0f | Combo: %d" % [type.capitalize(), damage, combo_count])

func _update_attack_frames(delta: float):
	attack_frame_timer += delta
	
	if attack_frame_timer >= attack_frame_duration:
		attack_frame_timer = 0.0
		
		var total_frames = light_punch_frames if current_attack_type == "light" else heavy_punch_frames
		var peak_frame = 4 if current_attack_type == "light" else 5
		var attack_sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		
		# Update sprite texture
		if attack_sprites.size() > 0 and current_attack_frame < attack_sprites.size():
			texture = attack_sprites[current_attack_frame]
		
		current_attack_frame += 1
		
		# Enable hitbox at peak frame
		if current_attack_frame == peak_frame:
			_enable_hitbox(current_attack_type)
		
		# Disable hitbox after peak frame
		elif current_attack_frame == peak_frame + 1:
			_disable_hitbox(current_attack_type)
		
		# End attack animation
		if current_attack_frame >= total_frames:
			_end_attack()

func _enable_hitbox(type: String):
	if type == "light" and light_hitbox:
		light_hitbox.disabled = false
		print("Light hitbox enabled (Frame %d)" % current_attack_frame)
	elif type == "heavy" and heavy_hitbox:
		heavy_hitbox.disabled = false
		print("Heavy hitbox enabled (Frame %d)" % current_attack_frame)

func _disable_hitbox(type: String):
	if type == "light" and light_hitbox:
		light_hitbox.disabled = true
		print("Light hitbox disabled (Frame %d)" % current_attack_frame)
	elif type == "heavy" and heavy_hitbox:
		heavy_hitbox.disabled = true
		print("Heavy hitbox disabled (Frame %d)" % current_attack_frame)

func _end_attack():
	is_attacking = false
	can_move = true
	current_attack_type = ""
	current_attack_frame = 0
	
	# Reset to idle sprite (first walk sprite)
	if walk_sprites.size() > 0:
		texture = walk_sprites[0]
		walk_sprite_index = 0
	
	print("Attack ended")

func _attack(type: String, anim: String, damage: float):
	is_attacking = true
	can_move = false
	combo_timer = combo_reset_time
	combo_count += 1
	
	var attack_anim = anim if is_grounded else air_attack_anim
	
	if anim_player:
		anim_player.play(attack_anim)
		await anim_player.animation_finished
	
	is_attacking = false
	can_move = true
	
	print("%s attack! Damage: %.0f | Combo: %d" % [type.capitalize(), damage, combo_count])

func _update_animation(delta: float):
	# Don't override attack or dash animations
	if is_attacking or is_dashing:
		return
	
	if not anim_player:
		# Manual walk cycle if no AnimationPlayer
		if is_grounded and abs(velocity.x) > 10 and walk_sprites.size() > 0:
			_update_walk_cycle(delta)
		elif walk_sprites.size() > 0:
			# Reset to first image when not walking
			texture = walk_sprites[0]
			walk_sprite_index = 0
			walk_frame_timer = 0.0
		return
	
	if is_blocking:
		anim_player.play(block_anim)
	elif not is_grounded:
		anim_player.play(jump_anim if velocity.y < 0 else fall_anim)
	elif abs(velocity.x) > 10:
		anim_player.play(walk_anim)
	else:
		anim_player.play(idle_anim)

func _update_walk_cycle(delta: float):
	"""Simple 5-image walk cycle that loops"""
	walk_frame_timer += delta
	
	if walk_frame_timer >= walk_frame_duration:
		walk_frame_timer = 0.0
		walk_sprite_index = (walk_sprite_index + 1) % walk_sprites.size()
		
		if walk_sprites.size() > 0:
			texture = walk_sprites[walk_sprite_index]

# Health System
func _update_health_bar():
	if health_bar:
		health_bar.value = (current_health / max_health) * 100.0

func take_damage(damage: float):
	if is_blocking:
		damage *= 0.2
	
	current_health -= damage
	current_health = max(0.0, current_health)
	_update_health_bar()
	
	print("Took %.0f damage! Health: %.0f/%.0f" % [damage, current_health, max_health])
	
	if current_health <= 0:
		_on_death()
		return
	
	if anim_player and not is_attacking:
		can_move = false
		anim_player.play(hurt_anim)
		await get_tree().create_timer(hitstun_duration).timeout
		can_move = true

func heal(amount: float):
	current_health += amount
	current_health = min(current_health, max_health)
	_update_health_bar()
	print("Healed %.0f! Health: %.0f/%.0f" % [amount, current_health, max_health])

func _on_death():
	print("Character defeated!")
	can_move = false
	is_attacking = false
	# Add death animation/logic here

func reset_combo():
	combo_count = 0
	combo_timer = 0.0

# Public API
func get_health_percentage() -> float:
	return (current_health / max_health) * 100.0

func is_alive() -> bool:
	return current_health > 0
