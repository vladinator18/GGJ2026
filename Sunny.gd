extends Sprite2D

## Arcade Fighter Player Controller - FINAL VERSION
## Optimized for large map (11210x6156) with full combat system

# --- Configuration ---
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
@export var floor_y_level: float = 5656.0  # Floor for scaled map

@export_group("Map Boundaries")
@export var left_boundary: float = 100.0
@export var right_boundary: float = 11110.0
@export var clamp_to_boundaries: bool = true

@export_group("Combat")
@export var attack_move_speed_mult: float = 0.4
@export var light_attack_duration: float = 0.08 
@export var heavy_attack_duration: float = 0.13
@export var combo_reset_time: float = 0.8

@export_group("Visuals")
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

# --- Internal Variables ---
var velocity := Vector2.ZERO
var is_grounded := false
var is_attacking := false
var is_crouching := false 
var is_rising := false
var is_taunting := false
var facing_right := true

var jumps_used := 0
var combo_timer := 0.0
var combo_hits := 0

# Animation State
var current_attack_frame := 0
var attack_frame_timer := 0.0
var current_attack_type := ""
var loop_anim_index := 0
var loop_anim_timer := 0.0
var last_anim_set: Array[Texture2D] = []

# Hit tracking
var enemies_hit_this_attack: Array = []

func _ready():
	add_to_group("player")
	_toggle_attack_hitboxes(false)
	_update_body_collision()
	
	# Connect hitbox signals
	if light_hitbox_area:
		light_hitbox_area.body_entered.connect(_on_light_hitbox_hit)
		light_hitbox_area.area_entered.connect(_on_light_hitbox_hit_area)
	if heavy_hitbox_area:
		heavy_hitbox_area.body_entered.connect(_on_heavy_hitbox_hit)
		heavy_hitbox_area.area_entered.connect(_on_heavy_hitbox_hit_area)
	
	# Set initial position to floor level
	position.y = floor_y_level
	
	if idle_sprites.size() > 0:
		texture = idle_sprites[0]
	
	print("✓ Player ready - Health: ", current_health, "/", max_health)
	print("✓ Player floor level: ", floor_y_level)
	print("✓ Player boundaries: ", left_boundary, " to ", right_boundary)

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

# --- Combat System ---

func _on_light_hitbox_hit(body):
	if body.is_in_group("enemy") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_light_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("enemy") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, light_attack_damage, "light")

func _on_heavy_hitbox_hit(body):
	if body.is_in_group("enemy") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _on_heavy_hitbox_hit_area(area):
	var body = area.get_parent()
	if body and body.is_in_group("enemy") and body not in enemies_hit_this_attack:
		_deal_damage_to(body, heavy_attack_damage, "heavy")

func _deal_damage_to(target, damage: float, attack_type: String):
	enemies_hit_this_attack.append(target)
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Update combo
	combo_hits += 1
	combo_timer = combo_reset_time
	
	# Trigger camera shake
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		if attack_type == "light":
			camera.shake_light_hit()
		else:
			camera.shake_heavy_hit()
	
	print("💥 PLAYER HIT! Attack: ", attack_type.to_upper(), " | Damage: ", damage, " | Combo: ", combo_hits)

func take_damage(damage: float):
	current_health -= damage
	current_health = max(0, current_health)
	
	print("❤️ PLAYER DAMAGED! Took: ", damage, " | Health: ", current_health, "/", max_health)
	
	# Update UI
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("update_player_health"):
		camera.update_player_health(current_health, max_health)
	
	if current_health <= 0:
		_die()

func _die():
	print("💀 PLAYER DEFEATED!")
	# Add death logic here (stop movement, play animation, etc.)
	velocity = Vector2.ZERO
	is_attacking = false

# --- Movement & Input ---

func _handle_movement():
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Any horizontal or vertical movement breaks states
	if (is_crouching or is_rising or is_taunting) and (abs(input_dir) > 0.1 or Input.is_action_just_pressed("ui_up")):
		is_taunting = false
		_start_get_up()
	
	var move_mult = 1.0
	if is_attacking: move_mult = attack_move_speed_mult
	if is_crouching or is_rising or is_taunting: move_mult = 0.0 

	if is_grounded:
		velocity.x = input_dir * (ground_speed * move_mult)
		jumps_used = 0
		if Input.is_action_just_pressed("ui_up") and not (is_crouching or is_rising or is_taunting): 
			_jump()
	else:
		if input_dir != 0:
			var target_vel = input_dir * (air_speed * move_mult)
			velocity.x = lerp(velocity.x, target_vel, 0.1)

	if input_dir != 0 and not (is_attacking or is_crouching or is_rising or is_taunting):
		_flip_character(input_dir > 0)

func _input(event: InputEvent):
	# Taunt (T)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if is_grounded and not is_attacking:
			is_taunting = true
			is_crouching = false
			loop_anim_index = 0
	
	# Crouch Toggle (Down)
	if event.is_action_pressed("ui_down") and is_grounded:
		if is_crouching: _start_get_up()
		elif not is_rising:
			is_crouching = true
			is_taunting = false
	
	# Attacks
	if event.is_action_pressed("ui_lightpunch"): _start_attack("light")
	if event.is_action_pressed("ui_heavypunch"): _start_attack("heavy")

# --- Animation & Visuals ---

func _update_visuals(delta: float):
	if is_attacking: return
	
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

	if current_anim_set != last_anim_set:
		loop_anim_index = 0
		loop_anim_timer = 0.0
		last_anim_set = current_anim_set

	if current_anim_set.size() > 0:
		if mode == "air_frame":
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

# --- Logic Helpers ---

func _start_attack(type: String):
	if is_attacking or not is_grounded: return
	is_attacking = true
	is_taunting = false
	current_attack_type = type
	current_attack_frame = 0
	attack_frame_timer = 0.0
	enemies_hit_this_attack.clear()

func _update_attack_frames(delta: float):
	attack_frame_timer += delta
	var duration = light_attack_duration if current_attack_type == "light" else heavy_attack_duration
	if attack_frame_timer >= duration:
		attack_frame_timer = 0.0
		var sprites = light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		if current_attack_frame >= sprites.size():
			is_attacking = false
			_toggle_attack_hitboxes(false)
			return
		texture = sprites[current_attack_frame]
		_check_hitbox_timing(current_attack_frame)
		current_attack_frame += 1

func _check_hitbox_timing(frame: int):
	var active_frame = 2 if current_attack_type == "light" else 3
	if frame == active_frame: _toggle_attack_hitboxes(true, current_attack_type)
	elif frame == active_frame + 1: _toggle_attack_hitboxes(false)

func _toggle_attack_hitboxes(active: bool, type: String = ""):
	if light_hitbox_area:
		light_hitbox_area.monitoring = active and type == "light"
	if heavy_hitbox_area:
		heavy_hitbox_area.monitoring = active and type == "heavy"

func _jump():
	velocity.y = jump_strength
	is_grounded = false

func _start_get_up():
	is_crouching = false
	is_rising = true
	loop_anim_index = 0

func _apply_gravity(delta: float):
	if not is_grounded:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

func _apply_physics_modifiers():
	if not is_grounded: velocity.x *= air_friction 

func _move_character(delta: float):
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

func _update_body_collision():
	if standing_collision and crouch_collision:
		standing_collision.disabled = is_crouching
		crouch_collision.disabled = not is_crouching

func _flip_character(right: bool):
	if facing_right != right:
		facing_right = right
		scale.x *= -1

func _update_timers(delta: float):
	if combo_hits > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			print("🔥 COMBO ENDED! Total hits: ", combo_hits)
			combo_hits = 0
	
	# Update UI combo counter
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("update_combo"):
		camera.update_combo(combo_hits)
