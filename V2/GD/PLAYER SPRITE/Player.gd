extends CharacterBody2D

# Movement variables
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0

# Animation variables
var is_walking: bool = false
var is_running: bool = false
var facing_right: bool = true

# References
@onready var sprite = $Sprite2D
@onready var heavy_hitbox = $HeavyHitbox
@onready var light_hitbox = $LightHitbox

func _ready():
	# Initial setup
	pass

func _physics_process(delta):
	# Get input direction
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Handle movement
	if input_dir != 0:
		# Check if running (hold shift) - removed for now
		is_running = false  # Set to false until we add the input action
		
		var current_speed = run_speed if is_running else walk_speed
		velocity.x = input_dir * current_speed
		is_walking = true
		
		# Handle sprite flipping
		if input_dir > 0 and not facing_right:
			flip_character(true)
		elif input_dir < 0 and facing_right:
			flip_character(false)
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		is_walking = false
		is_running = false
	
	# Apply movement
	move_and_slide()
	
	# Update animation state
	update_animation()

func flip_character(right: bool):
	facing_right = right
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
	# Just keep the sprite as-is for now
	pass

# Optional: Combat functions for your hitboxes
func light_attack():
	if light_hitbox:
		light_hitbox.monitoring = true
		await get_tree().create_timer(0.2).timeout
		light_hitbox.monitoring = false

func heavy_attack():
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		await get_tree().create_timer(0.3).timeout
		heavy_hitbox.monitoring = false
