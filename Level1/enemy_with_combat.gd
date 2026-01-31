extends CharacterBody2D

# Enemy AI Constants
const SPEED = 200.0
const DETECTION_RANGE = 400.0
const ATTACK_RANGE = 80.0
const JUMP_VELOCITY = -350.0

# Node References
@onready var sprite: Sprite2D = $Sprite2D
@onready var standing_collision: CollisionShape2D = $StandingCollision
@onready var crouch_collision: CollisionShape2D = $CrouchCollision
@onready var light_hitbox: Area2D = $LightHitbox
@onready var heavy_hitbox: Area2D = $HeavyHitbox

# State
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var player: CharacterBody2D = null
var facing_right: bool = false
var is_attacking: bool = false

# Patrol
var patrol_direction: int = 1
var patrol_timer: float = 0.0
var patrol_change_time: float = 3.0

# Get gravity
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# Add to enemy group
	add_to_group("enemy")
	
	# Connect hitbox signals
	if light_hitbox:
		light_hitbox.body_entered.connect(_on_light_hitbox_body_entered)
	if heavy_hitbox:
		heavy_hitbox.body_entered.connect(_on_heavy_hitbox_body_entered)
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# State machine
	match current_state:
		State.IDLE:
			state_idle(delta)
		State.PATROL:
			state_patrol(delta)
		State.CHASE:
			state_chase(delta)
		State.ATTACK:
			state_attack(delta)
		State.HURT:
			state_hurt(delta)
		State.DEAD:
			state_dead(delta)
	
	# Move
	move_and_slide()
	
	# Check for player
	if player and current_state != State.DEAD:
		check_player_distance()

func state_idle(delta):
	velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# Transition to patrol after a moment
	patrol_timer += delta
	if patrol_timer > 2.0:
		current_state = State.PATROL
		patrol_timer = 0.0

func state_patrol(delta):
	# Move in patrol direction
	velocity.x = patrol_direction * SPEED * 0.5
	
	# Flip sprite
	if patrol_direction > 0 and not facing_right:
		flip_character(true)
	elif patrol_direction < 0 and facing_right:
		flip_character(false)
	
	# Change direction periodically
	patrol_timer += delta
	if patrol_timer > patrol_change_time:
		patrol_direction *= -1
		patrol_timer = 0.0

func state_chase(delta):
	if not player:
		current_state = State.IDLE
		return
	
	# Move towards player
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * SPEED
	
	# Flip sprite
	if direction > 0 and not facing_right:
		flip_character(true)
	elif direction < 0 and facing_right:
		flip_character(false)

func state_attack(delta):
	velocity.x = move_toward(velocity.x, 0, SPEED)
	# Attack logic handled in perform_attack()

func state_hurt(delta):
	velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	# Hurt state handled by take_damage()

func state_dead(delta):
	velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	# Dead - do nothing

func check_player_distance():
	if not player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance < ATTACK_RANGE and not is_attacking:
		# Attack!
		current_state = State.ATTACK
		perform_attack()
	elif distance < DETECTION_RANGE:
		# Chase player
		if current_state != State.ATTACK:
			current_state = State.CHASE
	else:
		# Return to patrol
		if current_state == State.CHASE:
			current_state = State.PATROL

func perform_attack():
	if is_attacking:
		return
	
	is_attacking = true
	
	# Randomly choose light or heavy attack
	var use_heavy = randf() > 0.7
	
	if use_heavy:
		await perform_heavy_attack()
	else:
		await perform_light_attack()
	
	is_attacking = false
	current_state = State.CHASE if player else State.IDLE

func perform_light_attack():
	# Startup frames
	await get_tree().create_timer(0.15).timeout
	if light_hitbox:
		light_hitbox.monitoring = true
	
	# Active frames
	await get_tree().create_timer(0.2).timeout
	if light_hitbox:
		light_hitbox.monitoring = false
	
	# Recovery frames
	await get_tree().create_timer(0.25).timeout

func perform_heavy_attack():
	# Startup frames
	await get_tree().create_timer(0.2).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
	
	# Active frames
	await get_tree().create_timer(0.25).timeout
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
	
	# Recovery frames
	await get_tree().create_timer(0.35).timeout

func flip_character(right: bool):
	facing_right = right
	if sprite:
		sprite.flip_h = not right
	
	# Flip hitboxes
	if light_hitbox:
		light_hitbox.position.x = abs(light_hitbox.position.x) * (-1 if right else 1)
		light_hitbox.scale.x = -1 if right else 1
	if heavy_hitbox:
		heavy_hitbox.position.x = abs(heavy_hitbox.position.x) * (-1 if right else 1)
		heavy_hitbox.scale.x = -1 if right else 1

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO):
	if current_state == State.DEAD:
		return
	
	# Apply knockback
	velocity = knockback_direction * 300
	
	# Enter hurt state
	current_state = State.HURT
	
	# Flash sprite (visual feedback)
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE
	
	# Return to previous state
	await get_tree().create_timer(0.3).timeout
	if current_state == State.HURT:
		current_state = State.CHASE if player else State.IDLE

func die():
	current_state = State.DEAD
	
	# Disable collisions
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Visual feedback
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# Remove after delay
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _on_light_hitbox_body_entered(body):
	if body.has_method("take_damage"):
		var knockback = Vector2(100 if facing_right else -100, -50)
		body.take_damage(10, knockback)
		print("Enemy light attack hit: ", body.name)

func _on_heavy_hitbox_body_entered(body):
	if body.has_method("take_damage"):
		var knockback = Vector2(200 if facing_right else -200, -100)
		body.take_damage(20, knockback)
		print("Enemy heavy attack hit: ", body.name)
