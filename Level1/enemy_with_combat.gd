extends CharacterBody2D
class_name Enemy

<<<<<<< HEAD
# Movement parameters
@export var move_speed: float = 250.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1800.0
=======
## AI Enemy: Final Tactical Controller with Combat System
## Works as Sprite2D with health, damage, and boundary checking

# --- Configuration ---
@export_group("Health")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export_group("Damage")
@export var light_attack_damage: float = 8.0
@export var heavy_attack_damage: float = 20.0

@export_group("Requirements")
@export var light_hitbox_area: Area2D  # Changed to Area2D
@export var heavy_hitbox_area: Area2D  # Changed to Area2D

@export_group("AI Spatial Zones")
@export var strike_zone: float = 250.0
@export var personal_space: float = 120.0
>>>>>>> parent of 7d25d6e (Add diagnostic script and enhance damage tracking)
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

<<<<<<< HEAD
# State variables
var current_health: float
=======
@export_group("Movement")
@export var move_speed: float = 480.0
@export var gravity: float = 2400.0

@export_group("Visuals")
@export var anim_frame_duration: float = 0.1 
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []

# --- Internal State ---
enum State { APPROACH, TACTICAL_WAIT, ATTACKING, RETREAT }
var current_state = State.APPROACH

var target: Node2D = null
var velocity := Vector2.ZERO
var is_grounded := false
>>>>>>> parent of 7d25d6e (Add diagnostic script and enhance damage tracking)
var is_attacking := false
var is_blocking := false
var is_hit_stunned := false
var is_knockdown := false
var facing_right := false

<<<<<<< HEAD
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
=======
var ai_input_dir := 0.0
var strategy_timer := 0.0
var loop_anim_index := 0
var loop_anim_timer := 0.0
var current_attack_type := ""
var current_attack_frame := 0
var attack_frame_timer := 0.0

# Hit tracking
var players_hit_this_attack: Array = []

func _ready():
	add_to_group("enemy")
	_toggle_hitboxes(false, "")
	_find_player()
	
	# Connect hitbox signals
	if light_hitbox_area:
		light_hitbox_area.body_entered.connect(_on_light_hitbox_hit)
		light_hitbox_area.area_entered.connect(_on_light_hitbox_hit_area)
	if heavy_hitbox_area:
		heavy_hitbox_area.body_entered.connect(_on_heavy_hitbox_hit)
		heavy_hitbox_area.area_entered.connect(_on_heavy_hitbox_hit_area)
	
	# Auto-detect map boundaries
	if auto_detect_boundaries:
		_detect_map_boundaries()
	
	# Set initial position
	position.y = floor_y_level
	
	# Set initial texture
	if idle_sprites.size() > 0:
		texture = idle_sprites[0]
		print("✓ Enemy spawned at: ", global_position, " | Health: ", current_health, "/", max_health)
		print("✓ Enemy boundaries: Left=", left_boundary, " Right=", right_boundary)
	else:
		push_warning("⚠ No idle sprites assigned to enemy!")

func _detect_map_boundaries():
	"""Auto-detect map boundaries from MapBorder node"""
	var border_nodes = get_tree().get_nodes_in_group("map_border")
	if border_nodes.size() > 0:
		var border = border_nodes[0]
		if border.get("map_width") != null:
			left_boundary = 50.0
			right_boundary = border.map_width - 50.0
			print("✓ AI detected map boundaries automatically")
	else:
		# Try to get from camera limits
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			var cam = cameras[0]
			if cam.get("map_right") != null:
				left_boundary = 50.0
				right_boundary = cam.map_right - 50.0
				print("✓ AI got boundaries from camera")

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		print("✓ AI found player target")
	else:
		push_warning("⚠ AI: Player not found! Ensure Player node is in 'player' group.")

func _physics_process(delta: float):
	if is_instance_valid(target):
		if not is_attacking:
			_process_tactical_logic(delta)
	else:
		_find_player()
		ai_input_dir = 0.0
	
	_apply_physics(delta)
	_move_character(delta)
	_update_visuals(delta)
	
	if is_attacking:
		_update_attack_logic(delta)

# --- Combat System ---

func _on_light_hitbox_hit(body):
	if body.is_in_group("player") and body not in players_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_light_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("player") and body not in players_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_heavy_hitbox_hit(body):
	if body.is_in_group("player") and body not in players_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _on_heavy_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("player") and body not in players_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _deal_damage_to(target_node, damage: float, attack_type: String):
	players_hit_this_attack.append(target_node)
	
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	
	# Trigger camera shake
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		if attack_type == "light":
			camera.shake_light_hit()
		else:
			camera.shake_heavy_hit()
	
	print("💥 ENEMY HIT! Attack: ", attack_type.to_upper(), " | Damage: ", damage)

func take_damage(damage: float):
	current_health -= damage
	current_health = max(0, current_health)
	
	print("🩸 ENEMY DAMAGED! Took: ", damage, " | Health: ", current_health, "/", max_health)
	
	# Update UI
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("update_enemy_health"):
		camera.update_enemy_health(current_health, max_health)
	
	if current_health <= 0:
		_die()

func _die():
	print("💀 ENEMY DEFEATED!")
	queue_free()  # Remove enemy from scene

# --- AI Tactical System ---

func _process_tactical_logic(delta: float):
	var dist = global_position.distance_to(target.global_position)
	var dir = sign(target.global_position.x - global_position.x)
	
	# Check if we're near a boundary - if so, move away from it
	if position.x <= left_boundary + 20:
		dir = 1.0  # Force move right
	elif position.x >= right_boundary - 20:
		dir = -1.0  # Force move left
	
	strategy_timer -= delta

	match current_state:
		State.APPROACH:
			ai_input_dir = dir
			if dist < strike_zone:
				current_state = State.TACTICAL_WAIT
				strategy_timer = tactic_duration
				ai_input_dir = 0.0

		State.TACTICAL_WAIT:
			# Weave pattern: move forward/backward
			var weave_dir = dir * (1.0 if int(strategy_timer * 4) % 2 == 0 else -0.5)
			
			# Don't weave into boundaries
			if (position.x <= left_boundary + 20 and weave_dir < 0) or \
			   (position.x >= right_boundary - 20 and weave_dir > 0):
				weave_dir = 0
			
			ai_input_dir = weave_dir
			
			if strategy_timer <= 0:
				current_state = State.ATTACKING
			elif dist < personal_space: 
				# Close range response
				if randf() < aggression:
					_start_attack("light")
				else:
					current_state = State.RETREAT
					strategy_timer = 1.0

		State.RETREAT:
			var retreat_dir = -dir * 1.5
			
			# Don't retreat into boundaries
			if (position.x <= left_boundary + 20 and retreat_dir < 0) or \
			   (position.x >= right_boundary - 20 and retreat_dir > 0):
				retreat_dir = 0
			
			ai_input_dir = retreat_dir
			
			if strategy_timer <= 0 or dist > personal_space * 1.5:
				current_state = State.APPROACH

		State.ATTACKING:
			# Choose attack based on distance
			var attack_choice = "heavy" if dist < personal_space * 0.8 and randf() > 0.5 else "light"
			_start_attack(attack_choice)
			current_state = State.APPROACH
			strategy_timer = tactic_duration * randf_range(0.8, 1.2)

# --- Combat Logic ---

func _start_attack(type: String):
	if is_attacking: return
	is_attacking = true
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	ai_input_dir = 0.0
	players_hit_this_attack.clear()  # Reset hit tracking

func _update_attack_logic(delta: float):
	attack_frame_timer += delta
	var dur = light_attack_duration if current_attack_type == "light" else heavy_attack_duration
	
	if attack_frame_timer >= dur:
		attack_frame_timer = 0.0
		var sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		
		if sprites.size() > 0 and current_attack_frame < sprites.size():
			texture = sprites[current_attack_frame]
			
			# Activate hitbox on specific frame
			if current_attack_frame == 2:
				_toggle_hitboxes(true, current_attack_type)
			elif current_attack_frame == 3:
				_toggle_hitboxes(false, "")
			
			current_attack_frame += 1
		else:
			# Attack finished
			is_attacking = false
			_toggle_hitboxes(false, "")

func _toggle_hitboxes(active: bool, type: String):
	if light_hitbox_area:
		light_hitbox_area.monitoring = active and type == "light"
	if heavy_hitbox_area:
		heavy_hitbox_area.monitoring = active and type == "heavy"

# --- Physics & Movement ---

func _apply_physics(delta: float):
	# Gravity
	if not is_grounded: 
>>>>>>> parent of 7d25d6e (Add diagnostic script and enhance damage tracking)
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

<<<<<<< HEAD
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
=======
func _move_character(delta: float):
	# Move with velocity
	position += velocity * delta
	
	# Clamp to boundaries
	position.x = clamp(position.x, left_boundary, right_boundary)
	
	# Ground collision
	if position.y >= floor_y_level:
		position.y = floor_y_level
		velocity.y = 0
		is_grounded = true
	else:
		is_grounded = false
	
	# Update facing direction
	if ai_input_dir != 0 and not is_attacking: 
		facing_right = ai_input_dir > 0
		scale.x = abs(scale.x) * (1 if facing_right else -1)

# --- Visual Animation ---

func _update_visuals(delta: float):
	if is_attacking: 
		return
	
	var sprites = walk_sprites if abs(velocity.x) > 10 else idle_sprites
	
	if sprites.size() > 0:
		loop_anim_timer += delta
		if loop_anim_timer >= anim_frame_duration:
			loop_anim_timer = 0.0
			loop_anim_index = (loop_anim_index + 1) % sprites.size()
			texture = sprites[loop_anim_index]
>>>>>>> parent of 7d25d6e (Add diagnostic script and enhance damage tracking)
