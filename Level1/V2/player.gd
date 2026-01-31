extends CharacterBody2D
class_name Player

# Animation sprite arrays
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var jump_sprites: Array[Texture2D] = []
@export var crouch_sprites: Array[Texture2D] = []
@export var get_up_sprites: Array[Texture2D] = []
@export var taunt_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []
@export var block_sprites: Array[Texture2D] = []
@export var hit_sprites: Array[Texture2D] = []
@export var knockdown_sprites: Array[Texture2D] = []

# Node references
@export var standing_collision: CollisionShape2D
@export var crouch_collision: CollisionShape2D
@export var sprite: Sprite2D

# Movement parameters
@export var move_speed: float = 300.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1800.0
@export var floor_y_level: float = 500.0

# Combat parameters
@export var max_health: float = 100.0
@export var light_attack_damage: float = 10.0
@export var heavy_attack_damage: float = 25.0
@export var block_damage_reduction: float = 0.5

# State variables
var current_health: float = 100.0
var is_attacking: bool = false
var is_blocking: bool = false
var is_crouching: bool = false
var is_hit_stunned: bool = false
var is_knockdown: bool = false
var facing_right: bool = true
var combo_count: int = 0

# Attack tracking
var current_attack_damage: float = 0.0
var current_attack_is_heavy: bool = false

# Animation variables
var current_animation: String = "idle"
var animation_frame: int = 0
var animation_timer: float = 0.0
var frame_duration: float = 0.1

# Hitbox references
var light_hitbox: Area2D
var heavy_hitbox: Area2D
var hurtbox: Area2D

# Signals
signal health_changed(new_health: float)
signal damaged(damage: float)
signal attack_landed(damage: float, is_heavy: bool)
signal died()
signal combo_performed(count: int)

func _ready():
	print("[%s] Player _ready() called" % name)
	current_health = max_health
	
	# Get hitbox references
	light_hitbox = $Hitboxes/LightHitbox
	heavy_hitbox = $Hitboxes/HeavyHitbox
	hurtbox = $Hurtbox
	
	print("[%s] Light hitbox: %s | Heavy hitbox: %s | Hurtbox: %s" % [name, light_hitbox != null, heavy_hitbox != null, hurtbox != null])
	
	# Initialize hitbox metadata and disable monitoring (but keep monitorable true)
	if light_hitbox:
		light_hitbox.monitoring = false  # Don't detect others
		light_hitbox.set_meta("damage", 0.0)
		light_hitbox.set_meta("is_heavy", false)
	if heavy_hitbox:
		heavy_hitbox.monitoring = false  # Don't detect others
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
	
	# Initialize sprite
	if sprite and idle_sprites.size() > 0:
		sprite.texture = idle_sprites[0]

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
		handle_normal_state(delta)
	
	# Update animation
	update_animation(delta)
	
	# Move character
	move_and_slide()

func handle_normal_state(delta: float):
	# Get input
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Blocking
	if Input.is_action_pressed("block"):
		is_blocking = true
		velocity.x = 0
		play_animation("block")
		return
	else:
		is_blocking = false
	
	# Crouching
	if Input.is_action_pressed("crouch") and is_on_floor():
		if not is_crouching:
			start_crouch()
		play_animation("crouch")
		velocity.x = 0
		return
	else:
		if is_crouching:
			end_crouch()
	
	# Attacks
	if Input.is_action_just_pressed("light_attack"):
		perform_light_attack()
		return
	
	if Input.is_action_just_pressed("heavy_attack"):
		perform_heavy_attack()
		return
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		play_animation("jump")
	
	# Movement
	if input_dir != 0:
		velocity.x = input_dir * move_speed
		
		# Update facing direction
		if input_dir > 0 and not facing_right:
			flip_sprite()
		elif input_dir < 0 and facing_right:
			flip_sprite()
		
		if is_on_floor():
			play_animation("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 10)
		if is_on_floor():
			play_animation("idle")
	
	# In air
	if not is_on_floor():
		play_animation("jump")

func handle_attack_state(delta: float):
	# Lock movement during attack
	velocity.x = 0

func handle_hit_stun_state(delta: float):
	# Brief stun, no control
	velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)

func handle_knockdown_state(delta: float):
	# On ground, waiting to get up
	velocity.x = 0

func perform_light_attack():
	if is_attacking or not is_on_floor():
		return
	
	print("[%s] Performing LIGHT attack (damage: %s)" % [name, light_attack_damage])
	is_attacking = true
	play_animation("light_attack")
	
	# Store damage in the hitbox node
	if light_hitbox:
		light_hitbox.set_meta("damage", light_attack_damage)
		light_hitbox.set_meta("is_heavy", false)
	
	# Enable hitbox during active frames
	await get_tree().create_timer(0.1).timeout
	if light_hitbox:
		light_hitbox.monitoring = true
		print("[%s] Light hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.15).timeout
	if light_hitbox:
		light_hitbox.monitoring = false
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
	play_animation("heavy_attack")
	
	# Store damage in the hitbox node
	if heavy_hitbox:
		heavy_hitbox.set_meta("damage", heavy_attack_damage)
		heavy_hitbox.set_meta("is_heavy", true)
	
	# Enable hitbox during active frames
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		print("[%s] Heavy hitbox ENABLED" % name)
	
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
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
	
	# Hit detection (enemy hurtbox)
	var target = get_target_from_area(area)
	if target and target.has_method("take_damage"):
		print("[%s] Dealing %s damage to %s" % [name, light_attack_damage, target.name])
		target.take_damage(light_attack_damage, false)
		combo_count += 1
		attack_landed.emit(light_attack_damage, false)
		combo_performed.emit(combo_count)

func _on_heavy_hitbox_area_entered(area: Area2D):
	print("[%s] Heavy hitbox HIT: %s" % [name, area.name])
	
	# Ignore our own hurtbox
	if is_own_area(area):
		print("[%s] Ignoring own hurtbox" % name)
		return
	
	# Hit detection (enemy hurtbox)
	var target = get_target_from_area(area)
	if target and target.has_method("take_damage"):
		print("[%s] Dealing %s damage to %s" % [name, heavy_attack_damage, target.name])
		target.take_damage(heavy_attack_damage, true)
		combo_count += 1
		attack_landed.emit(heavy_attack_damage, true)
		combo_performed.emit(combo_count)

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
		damage *= block_damage_reduction
		print("[%s] Blocked! Reduced to: %s" % [name, damage])
	
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
	play_animation("hit")
	combo_count = 0
	
	if is_heavy:
		# Knockdown on heavy hit
		is_knockdown = true
		is_hit_stunned = false
		play_animation("knockdown")
		await get_tree().create_timer(1.5).timeout
		if is_knockdown:
			get_up()
	else:
		await get_tree().create_timer(0.3).timeout
		is_hit_stunned = false

func die():
	is_knockdown = true
	play_animation("knockdown")
	died.emit()
	set_physics_process(false)

func get_up():
	is_knockdown = false
	play_animation("get_up")
	await get_tree().create_timer(0.5).timeout

func start_crouch():
	is_crouching = true
	if standing_collision:
		standing_collision.disabled = true
	if crouch_collision:
		crouch_collision.disabled = false

func end_crouch():
	is_crouching = false
	if standing_collision:
		standing_collision.disabled = false
	if crouch_collision:
		crouch_collision.disabled = true

func flip_sprite():
	facing_right = not facing_right
	sprite.flip_h = not sprite.flip_h
	
	# Flip hitbox positions
	if light_hitbox:
		light_hitbox.position.x *= -1
		light_hitbox.scale.x *= -1
	if heavy_hitbox:
		heavy_hitbox.position.x *= -1
		heavy_hitbox.scale.x *= -1

func play_animation(anim_name: String):
	if current_animation != anim_name:
		current_animation = anim_name
		animation_frame = 0
		animation_timer = 0.0

func update_animation(delta: float):
	animation_timer += delta
	
	if animation_timer >= frame_duration:
		animation_timer = 0.0
		
		var sprites = get_animation_sprites(current_animation)
		if sprites.size() > 0:
			animation_frame = (animation_frame + 1) % sprites.size()
			if sprite:
				sprite.texture = sprites[animation_frame]

func get_animation_sprites(anim_name: String) -> Array[Texture2D]:
	match anim_name:
		"idle": return idle_sprites
		"walk": return walk_sprites
		"jump": return jump_sprites
		"crouch": return crouch_sprites
		"get_up": return get_up_sprites
		"taunt": return taunt_sprites
		"light_attack": return light_attack_sprites
		"heavy_attack": return heavy_attack_sprites
		"block": return block_sprites
		"hit": return hit_sprites
		"knockdown": return knockdown_sprites
		_: return idle_sprites

func reset():
	print("[%s] RESET" % name)
	current_health = max_health
	is_attacking = false
	is_blocking = false
	is_crouching = false
	is_hit_stunned = false
	is_knockdown = false
	combo_count = 0
	current_attack_damage = 0.0
	current_attack_is_heavy = false
	velocity = Vector2.ZERO
	position.y = floor_y_level - 46
	set_physics_process(true)
	play_animation("idle")
	health_changed.emit(current_health)
