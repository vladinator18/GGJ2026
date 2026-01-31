extends Sprite2D

## AI Enemy: Final Tactical Controller with Border Collision
## Works as Sprite2D with proper boundary checking

# --- Configuration ---
@export_group("Requirements")
@export var light_hitbox: CollisionShape2D
@export var heavy_hitbox: CollisionShape2D

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
var is_attacking := false
var facing_right := true

var ai_input_dir := 0.0
var strategy_timer := 0.0
var loop_anim_index := 0
var loop_anim_timer := 0.0
var current_attack_type := ""
var current_attack_frame := 0
var attack_frame_timer := 0.0

func _ready():
	add_to_group("enemy")
	_toggle_hitboxes(false, "")
	_find_player()
	
	# Auto-detect map boundaries
	if auto_detect_boundaries:
		_detect_map_boundaries()
	
	# Set initial position
	position.y = floor_y_level
	
	# Set initial texture
	if idle_sprites.size() > 0:
		texture = idle_sprites[0]
		print("✓ Enemy spawned at: ", global_position)
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
	if light_hitbox: 
		light_hitbox.disabled = not (active and type == "light")
	if heavy_hitbox: 
		heavy_hitbox.disabled = not (active and type == "heavy")

# --- Physics & Movement ---

func _apply_physics(delta: float):
	# Gravity
	if not is_grounded: 
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	# Horizontal movement
	velocity.x = ai_input_dir * move_speed

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
