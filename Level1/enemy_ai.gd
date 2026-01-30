extends Sprite2D

## AI Enemy Controller for Arcade Fighter
## Features: Multiple difficulty levels, decision-making AI, and combo system

# --- Configuration ---
@export_group("Health")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export_group("Damage")
@export var light_attack_damage: float = 8.0
@export var heavy_attack_damage: float = 20.0

@export_group("Movement")
@export var ground_speed: float = 400.0
@export var air_speed: float = 300.0
@export var jump_strength: float = -700.0
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
@export var air_friction: float = 0.92
@export var floor_y_level: float = 5656.0

@export_group("Map Boundaries")
@export var left_boundary: float = 100.0
@export var right_boundary: float = 11110.0

@export_group("Combat")
@export var attack_move_speed_mult: float = 0.3
@export var light_attack_duration: float = 0.08
@export var heavy_attack_duration: float = 0.13

@export_group("AI Behavior")
@export_enum("Easy", "Medium", "Hard", "Expert") var difficulty: int = 1
@export var aggression: float = 0.5  # 0-1, how often AI attacks vs defends
@export var reaction_time: float = 0.3  # Seconds to react to player
@export var combo_preference: float = 0.6  # Preference for combos vs single hits
@export var preferred_range: float = 200.0  # Ideal distance from player

@export_group("Visuals")
@export var anim_frame_duration: float = 0.1
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var jump_sprites: Array[Texture2D] = []
@export var crouch_down_sprites: Array[Texture2D] = []
@export var get_up_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []

@export_group("Requirements")
@export var light_hitbox_area: Area2D
@export var heavy_hitbox_area: Area2D
@export var detection_area: Area2D
@export var standing_collision: CollisionShape2D
@export var crouch_collision: CollisionShape2D

# --- Internal Variables ---
var velocity := Vector2.ZERO
var is_grounded := false
var is_attacking := false
var is_crouching := false
var is_rising := false
var facing_right := true

var player_ref: Node2D = null
var distance_to_player: float = 0.0

# AI State Machine
enum AIState { IDLE, APPROACH, RETREAT, ATTACK, DEFEND, JUMP_ATTACK }
var current_state: AIState = AIState.IDLE
var state_timer: float = 0.0
var decision_cooldown: float = 0.0
var reaction_delay: float = 0.0

# Combat tracking
var combo_timer: float = 0.0
var combo_hits: int = 0
var last_hit_time: float = 0.0
var enemies_hit_this_attack: Array = []

# Animation State
var current_attack_frame := 0
var attack_frame_timer := 0.0
var current_attack_type := ""
var loop_anim_index := 0
var loop_anim_timer := 0.0
var last_anim_set: Array[Texture2D] = []

func _ready():
	add_to_group("enemy")
	_toggle_attack_hitboxes(false)
	_update_body_collision()
	
	# Connect hitbox signals
	if light_hitbox_area:
		light_hitbox_area.body_entered.connect(_on_light_hitbox_hit)
		light_hitbox_area.area_entered.connect(_on_light_hitbox_hit_area)
	if heavy_hitbox_area:
		heavy_hitbox_area.body_entered.connect(_on_heavy_hitbox_hit)
		heavy_hitbox_area.area_entered.connect(_on_heavy_hitbox_hit_area)
	
	# Find player
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")
	
	# Set initial position
	position.y = floor_y_level
	
	if idle_sprites.size() > 0:
		texture = idle_sprites[0]
	
	# Configure difficulty
	_setup_difficulty()
	
	print("✓ Enemy AI ready - Difficulty: ", ["Easy", "Medium", "Hard", "Expert"][difficulty])
	print("✓ Enemy Health: ", current_health, "/", max_health)

func _setup_difficulty():
	match difficulty:
		0:  # Easy
			aggression = 0.3
			reaction_time = 0.6
			combo_preference = 0.2
			ground_speed = 300.0
		1:  # Medium
			aggression = 0.5
			reaction_time = 0.3
			combo_preference = 0.5
			ground_speed = 400.0
		2:  # Hard
			aggression = 0.7
			reaction_time = 0.15
			combo_preference = 0.7
			ground_speed = 500.0
		3:  # Expert
			aggression = 0.85
			reaction_time = 0.05
			combo_preference = 0.9
			ground_speed = 600.0

func _physics_process(delta: float):
	_update_timers(delta)
	_apply_gravity(delta)
	
	if player_ref:
		distance_to_player = abs(player_ref.global_position.x - global_position.x)
		_ai_decision_making(delta)
	
	if is_attacking:
		_update_attack_frames(delta)
	
	_apply_physics_modifiers()
	_move_character(delta)
	_update_visuals(delta)
	_update_body_collision()

# --- AI Decision Making ---

func _ai_decision_making(delta: float):
	if is_attacking or is_rising:
		return
	
	state_timer += delta
	decision_cooldown -= delta
	
	# Make new decision periodically
	if decision_cooldown <= 0:
		_make_decision()
		decision_cooldown = randf_range(0.3, 1.0) / (difficulty + 1)
	
	# Execute current state
	_execute_state()

func _make_decision():
	if not player_ref or not is_grounded:
		return
	
	var player_health_ratio = 1.0
	if player_ref.has_method("get") and player_ref.get("current_health"):
		player_health_ratio = player_ref.current_health / player_ref.max_health
	
	var health_ratio = current_health / max_health
	var is_winning = health_ratio > player_health_ratio
	
	# Adjust aggression based on health
	var current_aggression = aggression
	if health_ratio < 0.3:
		current_aggression *= 0.6  # More defensive when low health
	elif is_winning:
		current_aggression *= 1.2  # More aggressive when winning
	
	# Decision weights
	var should_attack = randf() < current_aggression
	var in_attack_range = distance_to_player < 150.0
	var in_preferred_range = abs(distance_to_player - preferred_range) < 100.0
	
	if should_attack and in_attack_range:
		# Choose attack type
		if randf() < combo_preference and combo_hits > 0:
			current_state = AIState.ATTACK
			_start_attack("heavy")
		else:
			current_state = AIState.ATTACK
			_start_attack("light")
	elif distance_to_player > preferred_range + 100:
		current_state = AIState.APPROACH
	elif distance_to_player < preferred_range - 100:
		current_state = AIState.RETREAT
	elif randf() < 0.2 and difficulty >= 2:  # Jump attacks for hard+ difficulty
		current_state = AIState.JUMP_ATTACK
	else:
		current_state = AIState.IDLE

func _execute_state():
	match current_state:
		AIState.IDLE:
			velocity.x = 0
		
		AIState.APPROACH:
			var direction = sign(player_ref.global_position.x - global_position.x)
			velocity.x = direction * ground_speed
			_flip_character(direction > 0)
		
		AIState.RETREAT:
			var direction = -sign(player_ref.global_position.x - global_position.x)
			velocity.x = direction * ground_speed * 0.7
			_flip_character(player_ref.global_position.x > global_position.x)
		
		AIState.JUMP_ATTACK:
			if is_grounded:
				_jump()
				var direction = sign(player_ref.global_position.x - global_position.x)
				velocity.x = direction * air_speed
				current_state = AIState.APPROACH
		
		AIState.DEFEND:
			if not is_crouching and is_grounded:
				is_crouching = true
			velocity.x = 0

# --- Combat System ---

func _on_light_hitbox_hit(body):
	if body.is_in_group("player") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_light_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("player") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_heavy_hitbox_hit(body):
	if body.is_in_group("player") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _on_heavy_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("player") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _deal_damage_to(target, damage: float, attack_type: String):
	enemies_hit_this_attack.append(target)
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Update combo
	combo_hits += 1
	combo_timer = 0.8
	last_hit_time = Time.get_ticks_msec() / 1000.0
	
	# Camera shake
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		if attack_type == "light":
			camera.shake_light_hit()
		else:
			camera.shake_heavy_hit()
	
	print("💥 ENEMY HIT! Attack: ", attack_type.to_upper(), " | Damage: ", damage, " | Combo: ", combo_hits)

func take_damage(damage: float):
	current_health -= damage
	current_health = max(0, current_health)
	
	print("❤️ ENEMY DAMAGED! Took: ", damage, " | Health: ", current_health, "/", max_health)
	
	# Update UI
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("update_enemy_health"):
		game_manager.update_enemy_health(current_health, max_health)
	
	# React to damage
	if randf() < 0.3 and is_grounded:  # 30% chance to retreat when hit
		current_state = AIState.RETREAT
		decision_cooldown = 0.5
	
	if current_health <= 0:
		_die()

func _die():
	print("💀 ENEMY DEFEATED!")
	velocity = Vector2.ZERO
	is_attacking = false
	
	# Notify game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("on_enemy_defeated"):
		game_manager.on_enemy_defeated()
	
	# Disable AI
	set_physics_process(false)

# --- Attack System ---

func _start_attack(type: String):
	if is_attacking or not is_grounded:
		return
	
	is_attacking = true
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	enemies_hit_this_attack.clear()
	
	# Face player when attacking
	if player_ref:
		_flip_character(player_ref.global_position.x > global_position.x)

func _update_attack_frames(delta: float):
	attack_frame_timer += delta
	var duration = light_attack_duration if current_attack_type == "light" else heavy_attack_duration
	
	if attack_frame_timer >= duration:
		attack_frame_timer = 0.0
		var sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		
		if current_attack_frame >= sprites.size():
			is_attacking = false
			_toggle_attack_hitboxes(false)
			return
		
		texture = sprites[current_attack_frame]
		_check_hitbox_timing(current_attack_frame)
		current_attack_frame += 1

func _check_hitbox_timing(frame: int):
	var active_frame = 2 if current_attack_type == "light" else 3
	if frame == active_frame:
		_toggle_attack_hitboxes(true, current_attack_type)
	elif frame == active_frame + 1:
		_toggle_attack_hitboxes(false)

func _toggle_attack_hitboxes(active: bool, type: String = ""):
	if light_hitbox_area:
		light_hitbox_area.monitoring = active and type == "light"
	if heavy_hitbox_area:
		heavy_hitbox_area.monitoring = active and type == "heavy"

# --- Movement & Physics ---

func _jump():
	velocity.y = jump_strength
	is_grounded = false

func _apply_gravity(delta: float):
	if not is_grounded:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

func _apply_physics_modifiers():
	if not is_grounded:
		velocity.x *= air_friction
	
	if is_attacking:
		velocity.x *= attack_move_speed_mult

func _move_character(delta: float):
	position += velocity * delta
	
	# Clamp to boundaries
	position.x = clamp(position.x, left_boundary, right_boundary)
	
	# Floor collision
	if position.y >= floor_y_level:
		position.y = floor_y_level
		velocity.y = 0
		is_grounded = true
	else:
		is_grounded = false

# --- Animation & Visuals ---

func _update_visuals(delta: float):
	if is_attacking:
		return
	
	var current_anim_set: Array[Texture2D] = idle_sprites
	var mode = "loop"
	
	if not is_grounded:
		current_anim_set = jump_sprites
		mode = "air_frame"
	elif is_rising:
		current_anim_set = get_up_sprites
		mode = "transient"
	elif is_crouching:
		current_anim_set = crouch_down_sprites
		mode = "hold_last"
	elif abs(velocity.x) > 10:
		current_anim_set = walk_sprites
	else:
		current_anim_set = idle_sprites
	
	if current_anim_set != last_anim_set:
		loop_anim_index = 0
		loop_anim_timer = 0.0
		last_anim_set = current_anim_set
	
	if current_anim_set.size() > 0:
		if mode == "air_frame":
			loop_anim_index = 0 if velocity.y < 0 else 1
			loop_anim_index = clamp(loop_anim_index, 0, current_anim_set.size() - 1)
		else:
			loop_anim_timer += delta
			if loop_anim_timer >= anim_frame_duration:
				loop_anim_timer = 0.0
				if mode == "loop":
					loop_anim_index = (loop_anim_index + 1) % current_anim_set.size()
				elif mode == "hold_last":
					loop_anim_index = min(loop_anim_index + 1, current_anim_set.size() - 1)
				elif mode == "transient":
					if loop_anim_index < current_anim_set.size() - 1:
						loop_anim_index += 1
					else:
						is_rising = false
						is_crouching = false
		
		texture = current_anim_set[loop_anim_index]

func _update_body_collision():
	if standing_collision and crouch_collision:
		standing_collision.disabled = is_crouching
		crouch_collision.disabled = not is_crouching

func _flip_character(right: bool):
	if facing_right != right:
		facing_right = right
		scale.x *= -1

func _update_timers(delta: float):
	if combo_hits > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_hits = 0

# --- Public Methods ---

func reset_for_new_round():
	"""Called by game manager at start of new round"""
	current_health = max_health
	velocity = Vector2.ZERO
	is_attacking = false
	is_crouching = false
	combo_hits = 0
	current_state = AIState.IDLE
	set_physics_process(true)
	print("✓ Enemy reset for new round")
