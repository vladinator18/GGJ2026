
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
@export var auto_detect_boundaries: bool = true
@export var tactic_duration: float = 3.0

# Combat parameters
@export var max_health: float = 100.0
@export var light_attack_damage: float = 10.0
@export var heavy_attack_damage: float = 25.0
@export var block_chance: float = 0.3

# State variables
var current_health: float = 100.0
var is_attacking: bool = false
var is_blocking: bool = false
var is_hit_stunned: bool = false
var is_knockdown: bool = false
var facing_right: bool = false

# Attack tracking
var current_attack_damage: float = 0.0
var current_attack_is_heavy: bool = false

# AI state
var target: CharacterBody2D = null
var ai_state: String = "idle"
var state_timer: float = 0.0
var reaction_timer: float = 0.0

# Animation
var sprite: Sprite2D
var animation_frame: int = 0
var animation_timer: float = 0.0
var frame_duration: float = 0.1

# Collision references
var standing_collision: CollisionShape2D
var crouch_collision: CollisionShape2D
var light_hitbox: Area2D
var heavy_hitbox: Area2D
var hurtbox: Area2D

# Signals
signal health_changed(new_health: float)
signal damaged(damage: float)
signal attack_landed(damage: float, is_heavy: bool)
signal died()

func _ready():
	print("[%s] Enemy _ready() called" % name)
	current_health = max_health
	
	# Get node references
	sprite = $Sprite
	standing_collision = $CollisionShapes/StandingCollision
	crouch_collision = $CollisionShapes/CrouchCollision
	light_hitbox = $Hitboxes/LightHitbox
	heavy_hitbox = $Hitboxes/HeavyHitbox
	hurtbox = $Hurtbox
	
	print("[%s] Light hitbox: %s | Heavy hitbox: %s | Hurtbox: %s" % [name, light_hitbox != null, heavy_hitbox != null, hurtbox != null])
	
	# Initialize hitbox metadata and disable monitoring (but keep monitorable true)
	if light_hitbox:
		light_hitbox.monitoring = false  # Don't detect others
		light_hitbox.visible = false  # Hide by default
		light_hitbox.set_meta("damage", 0.0)
		light_hitbox.set_meta("is_heavy", false)
		# Disable collision detection when inactive
		for child in light_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
	if heavy_hitbox:
		heavy_hitbox.monitoring = false  # Don't detect others
		heavy_hitbox.visible = false  # Hide by default
		heavy_hitbox.set_meta("damage", 0.0)
		heavy_hitbox.set_meta("is_heavy", false)
		# Disable collision detection when inactive
		for child in heavy_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
	
	# Connect hitbox signals
	if light_hitbox:
		light_hitbox.area_entered.connect(_on_light_hitbox_area_entered)
	if heavy_hitbox:
		heavy_hitbox.area_entered.connect(_on_heavy_hitbox_area_entered)
	
	# Connect hurtbox signal (for receiving damage)
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Set initial position
	position.y = floor_y_level - 46
	
	# Find player
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	if target:
		print("[%s] Target found: %s" % [name, target.name])
	else:
		print("[%s] WARNING: No target found!" % name)

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Snap to floor
	if position.y > floor_y_level - 46:
		position.y = floor_y_level - 46
		velocity.y = 0
	
	# Handle state-based behavior
	if is_knockdown:
		handle_knockdown_state(delta)
	elif is_hit_stunned:
		handle_hit_stun_state(delta)
	elif is_attacking:
		handle_attack_state(delta)
	else:
		handle_ai_behavior(delta)
	
	# Move character
	move_and_slide()

func handle_ai_behavior(delta: float):
	if not target:
		velocity.x = 0
		return
	
	reaction_timer -= delta
	state_timer -= delta
	
	# Update facing direction
	var direction_to_target = sign(target.global_position.x - global_position.x)
	if direction_to_target > 0 and not facing_right:
		flip_sprite()
	elif direction_to_target < 0 and facing_right:
		flip_sprite()
	
	var distance_to_target = abs(target.global_position.x - global_position.x)
	
	# State machine
	if state_timer <= 0:
		choose_new_state(distance_to_target)
	
	match ai_state:
		"idle":
			velocity.x = 0
		
		"approach":
			if distance_to_target > strike_zone:
				velocity.x = direction_to_target * move_speed
			else:
				ai_state = "attack"
		
		"retreat":
			velocity.x = -direction_to_target * move_speed * 0.7
		
		"attack":
			velocity.x = 0
			if reaction_timer <= 0 and distance_to_target < strike_zone:
				decide_attack()
		
		"block":
			velocity.x = 0
			is_blocking = true
			if state_timer <= 0:
				is_blocking = false

func choose_new_state(distance: float):
	state_timer = randf_range(1.0, tactic_duration)
	
	# Aggressive behavior
	if randf() < aggression:
		if distance > strike_zone + 50:
			ai_state = "approach"
		elif distance < personal_space:
			ai_state = "retreat"
		else:
			ai_state = "attack"
	else:
		# Defensive behavior
		if distance < personal_space:
			if randf() < block_chance:
				ai_state = "block"
			else:
				ai_state = "retreat"
		elif distance > strike_zone + 100:
			ai_state = "approach"
		else:
			ai_state = "idle"

func decide_attack():
	reaction_timer = reaction_time
	
	var distance_to_target = abs(target.global_position.x - global_position.x)
	
	if distance_to_target < strike_zone:
		if randf() < 0.7:
			perform_light_attack()
		else:
			perform_heavy_attack()

func handle_attack_state(delta: float):
	velocity.x = 0

func handle_hit_stun_state(delta: float):
	velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)

func handle_knockdown_state(delta: float):
	velocity.x = 0

func perform_light_attack():
	if is_attacking or not is_on_floor():
		return
	
	print("[%s] Performing LIGHT attack (damage: %s)" % [name, light_attack_damage])
	is_attacking = true
	
	# Store damage in the hitbox node
	if light_hitbox:
		light_hitbox.set_meta("damage", light_attack_damage)
		light_hitbox.set_meta("is_heavy", false)
	
	# Enable hitbox during active frames
	await get_tree().create_timer(0.1).timeout
	if light_hitbox:
		light_hitbox.monitoring = true
		light_hitbox.visible = true
		# Enable collision shape
		for child in light_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false
		print("[%s] Light hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.15).timeout
	if light_hitbox:
		light_hitbox.monitoring = false
		light_hitbox.visible = false
		# Disable collision shape
		for child in light_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		print("[%s] Light hitbox DISABLED" % name)
		# Clear damage after attack
		light_hitbox.set_meta("damage", 0.0)
	
	await get_tree().create_timer(0.15).timeout
	is_attacking = false

func perform_heavy_attack():
	if is_attacking or not is_on_floor():
		return
	
	print("[%s] Performing HEAVY attack (damage: %s)" % [name, heavy_attack_damage])
	is_attacking = true
	
	# Store damage in the hitbox node
	if heavy_hitbox:
		heavy_hitbox.set_meta("damage", heavy_attack_damage)
		heavy_hitbox.set_meta("is_heavy", true)
	
	# Enable hitbox during active frames
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		heavy_hitbox.visible = true
		# Enable collision shape
		for child in heavy_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false
		print("[%s] Heavy hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		heavy_hitbox.visible = false
		# Disable collision shape
		for child in heavy_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		print("[%s] Heavy hitbox DISABLED" % name)
		# Clear damage after attack
		heavy_hitbox.set_meta("damage", 0.0)
	
	await get_tree().create_timer(0.2).timeout
	is_attacking = false

func _on_light_hitbox_area_entered(area: Area2D):
	print("[%s] Light hitbox HIT: %s" % [name, area.name])
	
	# Ignore our own hurtbox
	if is_own_area(area):
		print("[%s] Ignoring own hurtbox" % name)
		return
	
	# Hit detection
	var target_node = get_target_from_area(area)
	if target_node and target_node.has_method("take_damage"):
		print("[%s] Dealing %s damage to %s" % [name, light_attack_damage, target_node.name])
		target_node.take_damage(light_attack_damage, false)
		attack_landed.emit(light_attack_damage, false)

func _on_heavy_hitbox_area_entered(area: Area2D):
	print("[%s] Heavy hitbox HIT: %s" % [name, area.name])
	
	# Ignore our own hurtbox
	if is_own_area(area):
		print("[%s] Ignoring own hurtbox" % name)
		return
	
	# Hit detection
	var target_node = get_target_from_area(area)
	if target_node and target_node.has_method("take_damage"):
		print("[%s] Dealing %s damage to %s" % [name, heavy_attack_damage, target_node.name])
		target_node.take_damage(heavy_attack_damage, true)
		attack_landed.emit(heavy_attack_damage, true)

func _on_hurtbox_area_entered(area: Area2D):
	print("[%s] HURTBOX detected: %s" % [name, area.name])
	
	# Ignore our own hitboxes
	if is_own_area(area):
		print("[%s] Ignoring own hitbox" % name)
		return
	
	# Get damage info from the hitbox metadata
	if area.has_meta("damage") and area.has_meta("is_heavy"):
		var damage = area.get_meta("damage")
		var is_heavy = area.get_meta("is_heavy")
		
		# Ignore if damage is 0 (not an active attack)
		if damage <= 0:
			print("[%s] Ignoring inactive hitbox (damage = 0)" % name)
			return
		
		print("[%s] Receiving attack from hitbox metadata: damage=%s, heavy=%s" % [name, damage, is_heavy])
		take_damage(damage, is_heavy)
	else:
		print("[%s] ERROR: Hitbox doesn't have damage metadata!" % name)

func is_own_area(area: Area2D) -> bool:
	# Check if the area belongs to this character
	var area_owner = area
	while area_owner:
		if area_owner == self:
			return true
		area_owner = area_owner.get_parent()
	return false

func get_target_from_area(area: Area2D) -> Node:
	# Navigate up the tree to find the CharacterBody2D
	var current = area.get_parent()
	while current:
		if current is CharacterBody2D and current != self:
			return current
		current = current.get_parent()
	return null

func get_current_attack_damage() -> Dictionary:
	return {
		"damage": current_attack_damage,
		"is_heavy": current_attack_is_heavy
	}

func take_damage(damage: float, is_heavy: bool = false):
	print("[%s] ===== TAKING DAMAGE =====" % name)
	print("[%s] Damage: %s | Heavy: %s | Blocking: %s" % [name, damage, is_heavy, is_blocking])
	print("[%s] Health before: %s" % [name, current_health])
	
	if is_blocking:
		damage *= 0.5
		print("[%s] Blocked! Reduced to: %s" % name, damage)
	
	current_health -= damage
	current_health = max(0, current_health)
	
	print("[%s] Health after: %s" % [name, current_health])
	
	health_changed.emit(current_health)
	damaged.emit(damage)
	
	if current_health <= 0:
		print("[%s] DIED!" % name)
		die()
		return
	
	# Hit stun
	is_hit_stunned = true
	
	if is_heavy:
		# Knockdown on heavy hit
		is_knockdown = true
		is_hit_stunned = false
		await get_tree().create_timer(1.5).timeout
		if is_knockdown:
			get_up()
	else:
		await get_tree().create_timer(0.3).timeout
		is_hit_stunned = false

func die():
	is_knockdown = true
	died.emit()
	set_physics_process(false)

func get_up():
	is_knockdown = false
	await get_tree().create_timer(0.5).timeout

func flip_sprite():
	facing_right = not facing_right
	
	# Flip sprite if it exists
	if sprite:
		sprite.flip_h = not sprite.flip_h
	
	# Flip hitbox positions
	if light_hitbox:
		light_hitbox.position.x *= -1
		light_hitbox.scale.x *= -1
	if heavy_hitbox:
		heavy_hitbox.position.x *= -1
		heavy_hitbox.scale.x *= -1

func reset():
	print("[%s] RESET" % name)
	current_health = max_health
	is_attacking = false
	is_blocking = false
	is_hit_stunned = false
	is_knockdown = false
	current_attack_damage = 0.0
	current_attack_is_heavy = false
	velocity = Vector2.ZERO
	position.y = floor_y_level - 46
	ai_state = "idle"
	state_timer = 0.0
	set_physics_process(true)
	health_changed.emit(current_health)

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
>>>>>>> parent of 35caa8e (Add V2 fighting game level with player and enemy logic)
