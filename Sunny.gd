extends CharacterBody2D

# ========================================
# CONFIGURATION
# ========================================

@export_group("Movement")
@export var ground_speed := 600.0
@export var air_speed := 400.0
@export var jump_strength := -800.0
@export var gravity := 2000.0
@export var max_fall_speed := 1200.0
@export var air_friction := 0.92

@export_group("Combat")
@export var attack_move_speed_mult := 0.4
@export var light_attack_duration := 0.08
@export var heavy_attack_duration := 0.13

@export_group("Animation")
@export var anim_frame_duration := 0.1
@export var idle_sprites: Array[Texture2D]
@export var walk_sprites: Array[Texture2D]
@export var jump_sprites: Array[Texture2D]
@export var crouch_sprites: Array[Texture2D]
@export var get_up_sprites: Array[Texture2D]
@export var taunt_sprites: Array[Texture2D]
@export var light_attack_sprites: Array[Texture2D]
@export var heavy_attack_sprites: Array[Texture2D]

@export_group("References")
@export var sprite: Sprite2D
@export var light_hitbox: Area2D
@export var heavy_hitbox: Area2D
@export var standing_collision: CollisionShape2D
@export var crouch_collision: CollisionShape2D

# ========================================
# STATE
# ========================================

var facing_right := true
var is_attacking := false
var is_crouching := false
var is_rising := false
var is_taunting := false

var current_attack_type := ""
var attack_frame := 0
var attack_timer := 0.0

# Animation
var anim_index := 0
var anim_timer := 0.0
var last_anim_set: Array[Texture2D] = []

# ========================================
# READY
# ========================================

func _ready():
	_toggle_attack_hitboxes(false)
	_update_body_collision()

	light_hitbox.body_entered.connect(_on_light_hit)
	heavy_hitbox.body_entered.connect(_on_heavy_hit)

	if idle_sprites.size() > 0:
		sprite.texture = idle_sprites[0]

# ========================================
# PHYSICS
# ========================================

func _physics_process(delta):
	_apply_gravity(delta)
	_handle_movement()

	if is_attacking:
		_update_attack(delta)

	move_and_slide()
	_update_animation(delta)
	_update_body_collision()

# ========================================
# MOVEMENT
# ========================================

func _handle_movement():
	var dir := Input.get_axis("ui_left", "ui_right")

	var speed_mult := 1.0
	if is_attacking:
		speed_mult = attack_move_speed_mult
	if is_crouching or is_rising or is_taunting:
		speed_mult = 0.0

	if is_on_floor():
		velocity.x = dir * ground_speed * speed_mult
		if Input.is_action_just_pressed("ui_up"):
			velocity.y = jump_strength
	else:
		velocity.x = lerp(velocity.x, dir * air_speed * speed_mult, 0.1)
		velocity.x *= air_friction

	if dir != 0 and not is_attacking:
		_flip(dir > 0)

# ========================================
# INPUT
# ========================================

func _input(event):
	if event.is_action_pressed("ui_lightpunch"):
		_start_attack("light")
	if event.is_action_pressed("ui_heavypunch"):
		_start_attack("heavy")

	if event.is_action_pressed("ui_down") and is_on_floor():
		is_crouching = true
	if event.is_action_released("ui_down"):
		is_crouching = false

# ========================================
# GRAVITY
# ========================================

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

# ========================================
# ATTACKS
# ========================================

func _start_attack(type: String):
	if is_attacking or not is_on_floor():
		return

	is_attacking = true
	current_attack_type = type
	attack_frame = 0
	attack_timer = 0.0

func _update_attack(delta):
	attack_timer += delta
	var duration := light_attack_duration if current_attack_type == "light" else heavy_attack_duration

	if attack_timer >= duration:
		attack_timer = 0.0

		var sprites := light_attack_sprites if current_attack_type == "light" else heavy_attack_sprites
		if attack_frame >= sprites.size():
			is_attacking = false
			_toggle_attack_hitboxes(false)
			return

		sprite.texture = sprites[attack_frame]
		_handle_hitbox_frames(attack_frame)
		attack_frame += 1

func _handle_hitbox_frames(frame: int):
	var active := 2 if current_attack_type == "light" else 3
	if frame == active:
		_toggle_attack_hitboxes(true)
	elif frame == active + 1:
		_toggle_attack_hitboxes(false)

func _toggle_attack_hitboxes(active: bool):
	light_hitbox.monitoring = active and current_attack_type == "light"
	heavy_hitbox.monitoring = active and current_attack_type == "heavy"

# ========================================
# HIT DETECTION
# ========================================

func _on_light_hit(body):
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(10)

func _on_heavy_hit(body):
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(25)

# ========================================
# OLD-SYSTEM ANIMATION
# ========================================

func _update_animation(delta):
	if is_attacking:
		return

	var anim_set := idle_sprites
	var mode := "loop"

	if not is_on_floor():
		anim_set = jump_sprites
		mode = "air"
	elif is_taunting:
		anim_set = taunt_sprites
		mode = "once"
	elif is_rising:
		anim_set = get_up_sprites
		mode = "once"
	elif is_crouching:
		anim_set = crouch_sprites
		mode = "hold"
	elif abs(velocity.x) > 10:
		anim_set = walk_sprites

	if anim_set != last_anim_set:
		anim_index = 0
		anim_timer = 0.0
		last_anim_set = anim_set

	if anim_set.is_empty():
		return

	anim_timer += delta
	if anim_timer >= anim_frame_duration:
		anim_timer = 0.0

		match mode:
			"loop":
				anim_index = (anim_index + 1) % anim_set.size()
			"hold":
				anim_index = min(anim_index + 1, anim_set.size() - 1)
			"once":
				if anim_index < anim_set.size() - 1:
					anim_index += 1
				else:
					is_rising = false
					is_taunting = false
			"air":
				anim_index = 0 if velocity.y < 0 else 1
				anim_index = clamp(anim_index, 0, anim_set.size() - 1)

	sprite.texture = anim_set[anim_index]

# ========================================
# UTIL
# ========================================

func _update_body_collision():
	standing_collision.disabled = is_crouching
	crouch_collision.disabled = not is_crouching

func _flip(right: bool):
	if facing_right != right:
		facing_right = right
		scale.x *= -1
