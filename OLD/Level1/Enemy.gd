extends CharacterBody2D


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
	if heavy_hitbox:
		heavy_hitbox.monitoring = false  # Don't detect others
		heavy_hitbox.visible = false  # Hide by default
		heavy_hitbox.set_meta("damage", 0.0)
		heavy_hitbox.set_meta("is_heavy", false)
	
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
		light_hitbox.visible = true  # Make visible during attack
		print("[%s] Light hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.15).timeout
	if light_hitbox:
		light_hitbox.monitoring = false
		light_hitbox.visible = false  # Hide when inactive
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
		heavy_hitbox.visible = true  # Make visible during attack
		print("[%s] Heavy hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		heavy_hitbox.visible = false  # Hide when inactive
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
