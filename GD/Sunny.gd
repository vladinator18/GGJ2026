extends Sprite2D

## Arcade Fighter Character Controller
## Fixed: Walk-while-punching now works without "launching" the player.

# --- Configuration ---
@export_group("Movement")
@export var ground_speed: float = 600.0
@export var air_speed: float = 400.0
@export var jump_strength: float = -800.0
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
@export var air_friction: float = 0.92  # Must be < 1.0 to prevent infinite speed

@export_group("Combat")
@export var attack_move_speed_mult: float = 0.4 # How much you can move while attacking
@export var light_attack_duration: float = 0.08 
@export var heavy_attack_duration: float = 0.13
@export var combo_reset_time: float = 0.8

@export_group("Visuals")
@export var walk_frame_duration: float = 0.1
@export var walk_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []

@export_group("Requirements")
@export var health_bar: ProgressBar
@export var light_hitbox: CollisionShape2D
@export var heavy_hitbox: CollisionShape2D

# --- Internal Variables ---
var velocity := Vector2.ZERO
var is_grounded := false
var is_attacking := false
var facing_right := true

var jumps_used := 0
var combo_count := 0
var combo_timer := 0.0

# Animation State
var current_attack_frame := 0
var attack_frame_timer := 0.0
var current_attack_type := ""
var walk_sprite_index := 0
var walk_frame_timer := 0.0

func _ready():
	_toggle_hitboxes(false)
	if walk_sprites.size() > 0:
		texture = walk_sprites[0]

func _physics_process(delta: float):
	_update_timers(delta)
	_apply_gravity(delta)
	
	# Handle movement (This now runs even while attacking!)
	_handle_movement()
	
	if is_attacking:
		_update_attack_frames(delta)
	
	_apply_physics_modifiers()
	_move_character(delta)
	_update_visuals(delta)

# --- Movement Logic ---

func _handle_movement():
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Calculate speed. If attacking, we multiply by our "mult" (0.4) 
	# to allow a slow advancing strike/sliding punch.
	var move_mult = 1.0 if not is_attacking else attack_move_speed_mult
	
	if is_grounded:
		velocity.x = input_dir * (ground_speed * move_mult)
		jumps_used = 0
		if Input.is_action_just_pressed("ui_up"): 
			_jump()
	else:
		# Air control logic
		if input_dir != 0:
			var target_vel = input_dir * (air_speed * move_mult)
			velocity.x = lerp(velocity.x, target_vel, 0.1)
		
		if Input.is_action_just_pressed("ui_up") and jumps_used < 2:
			_jump()

	# Flip sprite logic (We don't flip mid-attack to keep animation consistent)
	if input_dir != 0 and not is_attacking:
		_flip_character(input_dir > 0)

func _jump():
	velocity.y = jump_strength
	jumps_used += 1
	is_grounded = false

func _apply_gravity(delta: float):
	if not is_grounded:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

func _apply_physics_modifiers():
	if not is_grounded:
		# Friction reduces velocity.x every frame. 
		# If you don't hold a button, you'll eventually stop.
		velocity.x *= air_friction 

func _move_character(delta: float):
	position += velocity * delta
	
	# Floor detection (Assuming 500 is your ground Y level)
	if position.y >= 500:
		position.y = 500
		velocity.y = 0
		is_grounded = true

# --- Combat Logic ---

func _input(event: InputEvent):
	if event.is_action_pressed("ui_lightpunch"): _start_attack("light")
	if event.is_action_pressed("ui_heavypunch"): _start_attack("heavy")

func _start_attack(type: String):
	if is_attacking: return
	is_attacking = true
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	combo_timer = combo_reset_time
	combo_count += 1

func _update_attack_frames(delta: float):
	attack_frame_timer += delta
	var duration = light_attack_duration if current_attack_type == "light" else heavy_attack_duration
	
	if attack_frame_timer >= duration:
		attack_frame_timer = 0.0
		var sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		
		if current_attack_frame >= sprites.size():
			_end_attack()
			return
		
		texture = sprites[current_attack_frame]
		_check_hitbox_timing(current_attack_frame)
		current_attack_frame += 1

func _end_attack():
	is_attacking = false
	_toggle_hitboxes(false)
	current_attack_type = ""

func _check_hitbox_timing(frame: int):
	# Hits on frame 2 for light, frame 3 for heavy
	var active_frame = 2 if current_attack_type == "light" else 3
	if frame == active_frame:
		_toggle_hitboxes(true, current_attack_type)
	elif frame == active_frame + 1:
		_toggle_hitboxes(false)

func _toggle_hitboxes(active: bool, type: String = ""):
	if light_hitbox: light_hitbox.disabled = not (active and type == "light")
	if heavy_hitbox: heavy_hitbox.disabled = not (active and type == "heavy")

# --- Helpers ---

func _flip_character(right: bool):
	if facing_right != right:
		facing_right = right
		scale.x *= -1

func _update_timers(delta: float):
	combo_timer = max(0, combo_timer - delta)
	if combo_timer <= 0: combo_count = 0

func _update_visuals(delta: float):
	if is_attacking: return
	
	if is_grounded and abs(velocity.x) > 10:
		walk_frame_timer += delta
		if walk_frame_timer >= walk_frame_duration:
			walk_frame_timer = 0.0
			walk_sprite_index = (walk_sprite_index + 1) % walk_sprites.size()
			texture = walk_sprites[walk_sprite_index]
	else:
		if walk_sprites.size() > 0: 
			texture = walk_sprites[0]
