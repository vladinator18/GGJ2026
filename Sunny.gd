extends Sprite2D

## Arcade Fighter Player Controller
## Optimized for large map with full combat system and damage tracking

# ========================================
# CONFIGURATION
# ========================================

@export_group("Health")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export_group("Damage")
@export var light_attack_damage: float = 10.0
@export var heavy_attack_damage: float = 25.0

@export_group("Movement")
@export var ground_speed: float = 600.0
@export var air_speed: float = 400.0
@export var jump_strength: float = -800.0
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
@export var air_friction: float = 0.92
@export var floor_y_level: float = 5656.0

@export_group("Map Boundaries")
@export var left_boundary: float = 100.0
@export var right_boundary: float = 11110.0
@export var clamp_to_boundaries: bool = true

@export_group("Combat")
@export var attack_move_speed_mult: float = 0.4
@export var light_attack_duration: float = 0.08
@export var heavy_attack_duration: float = 0.13
@export var combo_reset_time: float = 0.8

@export_group("Animation")
@export var anim_frame_duration: float = 0.1
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var jump_sprites: Array[Texture2D] = []
@export var taunt_sprites: Array[Texture2D] = []
@export var crouch_down_sprites: Array[Texture2D] = []
@export var get_up_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []

@export_group("Requirements")
@export var light_hitbox_area: Area2D
@export var heavy_hitbox_area: Area2D
@export var standing_collision: CollisionShape2D
@export var crouch_collision: CollisionShape2D

# ========================================
# INTERNAL STATE
# ========================================

# Physics
var velocity := Vector2.ZERO
var is_grounded := false
var facing_right := true

# Combat state
var is_attacking := false
var is_crouching := false
var is_rising := false
var is_taunting := false
var current_attack_type := ""
var current_attack_frame := 0
var attack_frame_timer := 0.0

# Combo system
var combo_hits := 0
var combo_timer := 0.0

# Animation
var loop_anim_index := 0
var loop_anim_timer := 0.0
var last_anim_set: Array[Texture2D] = []

# Hit tracking
var enemies_hit_this_attack: Array = []

# Game manager reference
var game_manager: Node = null

# ========================================
# INITIALIZATION
# ========================================

func _ready():
	add_to_group("player")
	
	# Get game manager reference
	var managers = get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		game_manager = managers[0]
		print("✓ Player connected to Game Manager")
	else:
		push_warning("⚠ Player: Game Manager not found!")
	
	# Setup hitboxes
	_toggle_attack_hitboxes(false)
	_update_body_collision()
	
	# Connect hitbox signals
	if light_hitbox_area:
		light_hitbox_area.body_entered.connect(_on_light_hitbox_hit)
		light_hitbox_area.area_entered.connect(_on_light_hitbox_hit_area)
	if heavy_hitbox_area:
		heavy_hitbox_area.body_entered.connect(_on_heavy_hitbox_hit)
		heavy_hitbox_area.area_entered.connect(_on_heavy_hitbox_hit_area)
	
	# Set initial position
	position.y = floor_y_level
	
	if idle_sprites.size() > 0:
		texture = idle_sprites[0]
	
	print("✓ Player initialized")
	print("  - Health: %d/%d" % [int(current_health), int(max_health)])
	print("  - Floor level: %.0f" % floor_y_level)
	print("  - Boundaries: %.0f to %.0f" % [left_boundary, right_boundary])

func _physics_process(delta: float):
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_movement()
	
	if is_attacking:
		_update_attack_frames(delta)
	
	_apply_physics_modifiers()
	_move_character(delta)
	_update_visuals(delta)
	_update_body_collision()

# ========================================
# COMBAT SYSTEM
# ========================================

func _on_light_hitbox_hit(body):
	print("🔍 PLAYER: Light hitbox detected BODY collision with: ", body.name, " | Groups: ", body.get_groups())
	if body.is_in_group("enemy"):
		print("  → Confirmed enemy group!")
		if body not in enemies_hit_this_attack:
			print("  → New hit, dealing damage!")
			_deal_damage_to(body, light_attack_damage, "light")
		else:
			print("  → Already hit this attack cycle")
	else:
		print("  → Not in enemy group")

func _on_light_hitbox_hit_area(area):
	print("🔍 PLAYER: Light hitbox detected AREA collision with: ", area.name)
	var body = area.get_parent()
	if body:
		print("  → Parent body: ", body.name, " | Groups: ", body.get_groups())
		if body.is_in_group("enemy") and body not in enemies_hit_this_attack:
			print("  → Valid enemy, dealing damage!")
			_deal_damage_to(body, light_attack_damage, "light")

func _on_heavy_hitbox_hit(body):
	print("🔍 PLAYER: Heavy hitbox detected BODY collision with: ", body.name, " | Groups: ", body.get_groups())
	if body.is_in_group("enemy"):
		print("  → Confirmed enemy group!")
		if body not in enemies_hit_this_attack:
			print("  → New hit, dealing damage!")
			_deal_damage_to(body, heavy_attack_damage, "heavy")
		else:
			print("  → Already hit this attack cycle")
	else:
		print("  → Not in enemy group")

func _on_heavy_hitbox_hit_area(area):
	print("🔍 PLAYER: Heavy hitbox detected AREA collision with: ", area.name)
	var body = area.get_parent()
	if body:
		print("  → Parent body: ", body.name, " | Groups: ", body.get_groups())
		if body.is_in_group("enemy") and body not in enemies_hit_this_attack:
			print("  → Valid enemy, dealing damage!")
			_deal_damage_to(body, heavy_attack_damage, "heavy")

func _deal_damage_to(target_node, damage: float, attack_type: String):
	"""Deal damage to enemy and track statistics"""
	enemies_hit_this_attack.append(target_node)
	
	# Get game manager if we don't have it yet
	if not game_manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if managers.size() > 0:
			game_manager = managers[0]
	
	# Record damage in game manager FIRST
	if game_manager and game_manager.has_method("record_damage"):
		game_manager.record_damage("player", damage, true)
		print("✓ Damage recorded to Game Manager: %.0f" % damage)
	else:
		print("⚠ Game Manager not found! Damage not tracked.")
	
	# Apply damage to target
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	
	# Update combo
	combo_hits += 1
	combo_timer = combo_reset_time
	
	# Update combo UI
	if game_manager and game_manager.has_method("update_combo"):
		game_manager.update_combo(combo_hits)
	
	# Trigger camera shake
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		if attack_type == "light":
			if camera.has_method("shake_light_hit"):
				camera.shake_light_hit()
		else:
			if camera.has_method("shake_heavy_hit"):
				camera.shake_heavy_hit()
	
	print("💥 PLAYER HIT! Type: %s | Damage: %.0f | Combo: %d" % [attack_type.to_upper(), damage, combo_hits])

func take_damage(damage: float):
	"""Receive damage from enemy"""
	current_health = max(0, current_health - damage)
	
	print("❤️ PLAYER DAMAGED! Took: %.0f | Health: %.0f/%.0f" % [damage, current_health, max_health])
	
	# Update UI through game manager
	if game_manager and game_manager.has_method("update_player_health"):
		game_manager.update_player_health(current_health, max_health)
	
	if current_health <= 0:
		_die()

func _die():
	"""Handle player defeat"""
	print("💀 PLAYER DEFEATED!")
	velocity = Vector2.ZERO
	is_attacking = false
	set_physics_process(false)

func reset_for_new_round():
	"""Reset player state for new round"""
	current_health = max_health
	velocity = Vector2.ZERO
	is_attacking = false
	is_crouching = false
	is_rising = false
	is_taunting = false
	combo_hits = 0
	combo_timer = 0.0
	enemies_hit_this_attack.clear()
	set_physics_process(true)

# ========================================
# MOVEMENT & INPUT
# ========================================

func _handle_movement():
	"""Handle player input and movement"""
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Break certain states with movement
	if (is_crouching or is_rising or is_taunting) and (abs(input_dir) > 0.1 or Input.is_action_just_pressed("ui_up")):
		is_taunting = false
		_start_get_up()
	
	# Calculate movement multiplier
	var move_mult = 1.0
	if is_attacking:
		move_mult = attack_move_speed_mult
	if is_crouching or is_rising or is_taunting:
		move_mult = 0.0
	
	# Ground movement
	if is_grounded:
		velocity.x = input_dir * (ground_speed * move_mult)
		
		if Input.is_action_just_pressed("ui_up") and not (is_crouching or is_rising or is_taunting):
			_jump()
	# Air movement
	else:
		if input_dir != 0:
			var target_vel = input_dir * (air_speed * move_mult)
			velocity.x = lerp(velocity.x, target_vel, 0.1)
	
	# Update facing direction
	if input_dir != 0 and not (is_attacking or is_crouching or is_rising or is_taunting):
		_flip_character(input_dir > 0)

func _input(event: InputEvent):
	"""Handle special input events"""
	# Taunt (T key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if is_grounded and not is_attacking:
			is_taunting = true
			is_crouching = false
			loop_anim_index = 0
	
	# Crouch toggle (Down)
	if event.is_action_pressed("ui_down") and is_grounded:
		if is_crouching:
			_start_get_up()
		elif not is_rising:
			is_crouching = true
			is_taunting = false
	
	# Attacks
	if event.is_action_pressed("ui_lightpunch"):
		_start_attack("light")
	if event.is_action_pressed("ui_heavypunch"):
		_start_attack("heavy")

func _jump():
	"""Execute jump"""
	velocity.y = jump_strength
	is_grounded = false

func _start_get_up():
	"""Start get-up animation from crouch"""
	is_crouching = false
	is_rising = true
	loop_anim_index = 0

# ========================================
# ATTACK LOGIC
# ========================================

func _start_attack(type: String):
	"""Initiate attack"""
	if is_attacking or not is_grounded:
		return
	
	is_attacking = true
	is_taunting = false
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	enemies_hit_this_attack.clear()

func _update_attack_frames(delta: float):
	"""Update attack animation and hitboxes"""
	attack_frame_timer += delta
	var duration = light_attack_duration if current_attack_type == "light" else heavy_attack_duration
	
	if attack_frame_timer >= duration:
		attack_frame_timer = 0.0
		var sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		
		# Check if attack is complete
		if current_attack_frame >= sprites.size():
			is_attacking = false
			_toggle_attack_hitboxes(false)
			return
		
		# Update texture
		texture = sprites[current_attack_frame]
		
		# Handle hitbox timing
		_check_hitbox_timing(current_attack_frame)
		
		current_attack_frame += 1

func _check_hitbox_timing(frame: int):
	"""Activate/deactivate hitboxes based on attack frame"""
	var active_frame = 2 if current_attack_type == "light" else 3
	
	if frame == active_frame:
		_toggle_attack_hitboxes(true, current_attack_type)
	elif frame == active_frame + 1:
		_toggle_attack_hitboxes(false)

func _toggle_attack_hitboxes(active: bool, type: String = ""):
	"""Enable/disable attack hitboxes"""
	if active:
		print("⚡ PLAYER: Activating %s attack hitbox!" % type.to_upper())
	else:
		print("⚫ PLAYER: Deactivating attack hitboxes")
	
	if light_hitbox_area:
		light_hitbox_area.monitoring = active and type == "light"
		if active and type == "light":
			print("  → Light hitbox monitoring: ", light_hitbox_area.monitoring)
	if heavy_hitbox_area:
		heavy_hitbox_area.monitoring = active and type == "heavy"
		if active and type == "heavy":
			print("  → Heavy hitbox monitoring: ", heavy_hitbox_area.monitoring)

# ========================================
# PHYSICS & MOVEMENT
# ========================================

func _apply_gravity(delta: float):
	"""Apply gravity when airborne"""
	if not is_grounded:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

func _apply_physics_modifiers():
	"""Apply air friction and other modifiers"""
	if not is_grounded:
		velocity.x *= air_friction

func _move_character(delta: float):
	"""Move character and handle collisions"""
	position += velocity * delta
	
	# Clamp to map boundaries
	if clamp_to_boundaries:
		position.x = clamp(position.x, left_boundary, right_boundary)
	
	# Floor collision
	if position.y >= floor_y_level:
		position.y = floor_y_level
		velocity.y = 0
		is_grounded = true
	else:
		is_grounded = false

# ========================================
# ANIMATION
# ========================================

func _update_visuals(delta: float):
	"""Update character sprite animation"""
	if is_attacking:
		return
	
	# Determine current animation set
	var current_anim_set: Array[Texture2D] = idle_sprites
	var mode = "loop"
	
	if not is_grounded:
		current_anim_set = jump_sprites
		mode = "air_frame"
	elif is_taunting:
		current_anim_set = taunt_sprites
		mode = "transient_taunt"
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
	
	# Reset animation if changed
	if current_anim_set != last_anim_set:
		loop_anim_index = 0
		loop_anim_timer = 0.0
		last_anim_set = current_anim_set
	
	# Update animation frame
	if current_anim_set.size() > 0:
		if mode == "air_frame":
			# Show rising or falling frame
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
				elif mode == "transient" or mode == "transient_taunt":
					if loop_anim_index < current_anim_set.size() - 1:
						loop_anim_index += 1
					else:
						is_rising = false
						is_taunting = false
		
		texture = current_anim_set[loop_anim_index]

# ========================================
# UTILITY
# ========================================

func _update_body_collision():
	"""Update collision shape based on crouch state"""
	if standing_collision and crouch_collision:
		standing_collision.disabled = is_crouching
		crouch_collision.disabled = not is_crouching

func _flip_character(right: bool):
	"""Flip character sprite horizontally"""
	if facing_right != right:
		facing_right = right
		scale.x *= -1

func _update_timers(delta: float):
	"""Update combo and other timers"""
	if combo_hits > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			print("🔥 COMBO ENDED! Total hits: %d" % combo_hits)
			combo_hits = 0
			
			# Update combo UI
			if game_manager and game_manager.has_method("update_combo"):
				game_manager.update_combo(combo_hits)
