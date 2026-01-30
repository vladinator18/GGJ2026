extends Sprite2D

## AI Enemy Controller
## Tactical AI with combat system and damage tracking

# ========================================
# CONFIGURATION
# ========================================

@export_group("Health")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export_group("Damage")
@export var light_attack_damage: float = 8.0
@export var heavy_attack_damage: float = 20.0

@export_group("Requirements")
@export var light_hitbox_area: Area2D
@export var heavy_hitbox_area: Area2D

@export_group("AI Spatial Zones")
@export var strike_zone: float = 250.0
@export var personal_space: float = 120.0
@export var floor_y_level: float = 500.0

@export_group("Map Boundaries")
@export var left_boundary: float = 50.0
@export var right_boundary: float = 1870.0
@export var auto_detect_boundaries: bool = true

@export_group("AI Strategy")
@export var tactic_duration: float = 3.0
@export var aggression: float = 0.6

@export_group("Combat Speed")
@export var light_attack_duration: float = 0.09
@export var heavy_attack_duration: float = 0.14

@export_group("Movement")
@export var move_speed: float = 480.0
@export var gravity: float = 2400.0

@export_group("Animation")
@export var anim_frame_duration: float = 0.1
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []

# ========================================
# INTERNAL STATE
# ========================================

# AI state machine
enum State { APPROACH, TACTICAL_WAIT, ATTACKING, RETREAT }
var current_state = State.APPROACH

# Target and physics
var target: Node2D = null
var velocity := Vector2.ZERO
var is_grounded := false
var is_attacking := false
var facing_right := true

# AI control
var ai_input_dir := 0.0
var strategy_timer := 0.0

# Animation
var loop_anim_index := 0
var loop_anim_timer := 0.0

# Combat
var current_attack_type := ""
var current_attack_frame := 0
var attack_frame_timer := 0.0

# Hit tracking
var players_hit_this_attack: Array = []

# Game manager reference
var game_manager: Node = null

# ========================================
# INITIALIZATION
# ========================================

func _ready():
	add_to_group("enemy")
	
	# Get game manager reference
	var managers = get_tree().get_nodes_in_group("game_manager")
	if managers.size() > 0:
		game_manager = managers[0]
		print("✓ Enemy connected to Game Manager")
	else:
		push_warning("⚠ Enemy: Game Manager not found!")
	
	# Setup hitboxes
	_toggle_hitboxes(false, "")
	
	# Find player target
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
		print("✓ Enemy initialized")
		print("  - Position: ", global_position)
		print("  - Health: %d/%d" % [int(current_health), int(max_health)])
		print("  - Boundaries: %.0f to %.0f" % [left_boundary, right_boundary])
	else:
		push_warning("⚠ No idle sprites assigned to enemy!")

func _detect_map_boundaries():
	"""Auto-detect map boundaries from MapBorder node or camera"""
	var border_nodes = get_tree().get_nodes_in_group("map_border")
	if border_nodes.size() > 0:
		var border = border_nodes[0]
		if border.get("map_width") != null:
			left_boundary = 50.0
			right_boundary = border.map_width - 50.0
			print("✓ AI detected map boundaries from MapBorder")
			return
	
	# Try to get from camera limits
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		var cam = cameras[0]
		if cam.get("map_right") != null:
			left_boundary = 50.0
			right_boundary = cam.map_right - 50.0
			print("✓ AI detected boundaries from camera")

func _find_player():
	"""Locate player target"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		print("✓ AI found player target")
	else:
		push_warning("⚠ AI: Player not found! Ensure Player is in 'player' group.")

func _physics_process(delta: float):
	# Ensure we have a target
	if is_instance_valid(target):
		if not is_attacking:
			_process_tactical_logic(delta)
	else:
		_find_player()
		ai_input_dir = 0.0
	
	# Update physics and visuals
	_apply_physics(delta)
	_move_character(delta)
	_update_visuals(delta)
	
	if is_attacking:
		_update_attack_logic(delta)

# ========================================
# COMBAT SYSTEM
# ========================================

func _on_light_hitbox_hit(body):
	print("🔍 ENEMY: Light hitbox detected BODY collision with: ", body.name, " | Groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("  → Confirmed player group!")
		if body not in players_hit_this_attack:
			print("  → New hit, dealing damage!")
			_deal_damage_to(body, light_attack_damage, "light")
		else:
			print("  → Already hit this attack cycle")
	else:
		print("  → Not in player group")

func _on_light_hitbox_hit_area(area):
	print("🔍 ENEMY: Light hitbox detected AREA collision with: ", area.name)
	var body = area.get_parent()
	if body:
		print("  → Parent body: ", body.name, " | Groups: ", body.get_groups())
		if body.is_in_group("player") and body not in players_hit_this_attack:
			print("  → Valid player, dealing damage!")
			_deal_damage_to(body, light_attack_damage, "light")

func _on_heavy_hitbox_hit(body):
	print("🔍 ENEMY: Heavy hitbox detected BODY collision with: ", body.name, " | Groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("  → Confirmed player group!")
		if body not in players_hit_this_attack:
			print("  → New hit, dealing damage!")
			_deal_damage_to(body, heavy_attack_damage, "heavy")
		else:
			print("  → Already hit this attack cycle")
	else:
		print("  → Not in player group")

func _on_heavy_hitbox_hit_area(area):
	print("🔍 ENEMY: Heavy hitbox detected AREA collision with: ", area.name)
	var body = area.get_parent()
	if body:
		print("  → Parent body: ", body.name, " | Groups: ", body.get_groups())
		if body.is_in_group("player") and body not in players_hit_this_attack:
			print("  → Valid player, dealing damage!")
			_deal_damage_to(body, heavy_attack_damage, "heavy")

func _deal_damage_to(target_node, damage: float, attack_type: String):
	"""Deal damage to player and track statistics"""
	players_hit_this_attack.append(target_node)
	
	# Get game manager if we don't have it yet
	if not game_manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if managers.size() > 0:
			game_manager = managers[0]
	
	# Record damage in game manager FIRST
	if game_manager and game_manager.has_method("record_damage"):
		game_manager.record_damage("enemy", damage, true)
		print("✓ Damage recorded to Game Manager: %.0f" % damage)
	else:
		print("⚠ Game Manager not found! Damage not tracked.")
	
	# Apply damage to target
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	
	# Trigger camera shake
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		if attack_type == "light":
			if camera.has_method("shake_light_hit"):
				camera.shake_light_hit()
		else:
			if camera.has_method("shake_heavy_hit"):
				camera.shake_heavy_hit()
	
	print("💥 ENEMY HIT! Type: %s | Damage: %.0f" % [attack_type.to_upper(), damage])

func take_damage(damage: float):
	"""Receive damage from player"""
	current_health = max(0, current_health - damage)
	
	print("🩸 ENEMY DAMAGED! Took: %.0f | Health: %.0f/%.0f" % [damage, current_health, max_health])
	
	# Update UI through game manager
	if game_manager and game_manager.has_method("update_enemy_health"):
		game_manager.update_enemy_health(current_health, max_health)
	
	if current_health <= 0:
		_die()

func _die():
	"""Handle enemy defeat"""
	print("💀 ENEMY DEFEATED!")
	set_physics_process(false)
	queue_free()

func reset_for_new_round():
	"""Reset enemy state for new round"""
	current_health = max_health
	velocity = Vector2.ZERO
	is_attacking = false
	current_state = State.APPROACH
	strategy_timer = 0.0
	players_hit_this_attack.clear()
	set_physics_process(true)

# ========================================
# AI TACTICAL SYSTEM
# ========================================

func _process_tactical_logic(delta: float):
	"""Main AI decision-making system"""
	if not is_instance_valid(target):
		return
	
	var dist = global_position.distance_to(target.global_position)
	var dir = sign(target.global_position.x - global_position.x)
	
	# Boundary avoidance - override direction if near edge
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

# ========================================
# ATTACK LOGIC
# ========================================

func _start_attack(type: String):
	"""Initiate attack"""
	if is_attacking:
		return
	
	is_attacking = true
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	ai_input_dir = 0.0
	players_hit_this_attack.clear()

func _update_attack_logic(delta: float):
	"""Update attack animation and hitboxes"""
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
	"""Enable/disable attack hitboxes"""
	if active:
		print("⚡ ENEMY: Activating %s attack hitbox!" % type.to_upper())
	else:
		print("⚫ ENEMY: Deactivating attack hitboxes")
	
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

func _apply_physics(delta: float):
	"""Apply gravity and movement physics"""
	# Gravity
	if not is_grounded:
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	# Horizontal movement
	velocity.x = ai_input_dir * move_speed

func _move_character(delta: float):
	"""Move character and handle collisions"""
	# Apply velocity
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

# ========================================
# ANIMATION
# ========================================

func _update_visuals(delta: float):
	"""Update character sprite animation"""
	if is_attacking:
		return
	
	# Choose animation set
	var sprites = walk_sprites if abs(velocity.x) > 10 else idle_sprites
	
	if sprites.size() > 0:
		loop_anim_timer += delta
		if loop_anim_timer >= anim_frame_duration:
			loop_anim_timer = 0.0
			loop_anim_index = (loop_anim_index + 1) % sprites.size()
			texture = sprites[loop_anim_index]
