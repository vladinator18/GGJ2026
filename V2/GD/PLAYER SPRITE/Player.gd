extends CharacterBody2D
class_name Player

# Movement variables
@export var walk_speed: float = 200.0
@export var run_speed: float = 350.0

# Health system
@export var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

# Animation variables
var is_walking: bool = false
var is_running: bool = false
var facing_right: bool = true
var is_attacking: bool = false

# Ultimate system
@export var ultimate_charge: float = 0.0
@export var ultimate_max: float = 100.0
@export var ultimate_cost: float = 100.0
var ultimate_active: bool = false

# Player Identity
var player_id: String = "" # "player1" or "player2"
var character_key: String = "" # "blue", "red", or "green"

# References
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var heavy_hitbox = $HeavyHitbox if has_node("HeavyHitbox") else null
@onready var light_hitbox = $LightHitbox if has_node("LightHitbox") else null
@onready var ultimate_hitbox = $UltimateHitbox if has_node("UltimateHitbox") else null

# Sound Effects
@onready var walk_sound = $WalkSound if has_node("WalkSound") else null
@onready var light_attack_sound = $LightAttackSound if has_node("LightAttackSound") else null
@onready var heavy_attack_sound = $HeavyAttackSound if has_node("HeavyAttackSound") else null
@onready var ultimate_sound = $UltimateSound if has_node("UltimateSound") else null
@onready var damage_sound = $DamageSound if has_node("DamageSound") else null
@onready var death_sound = $DeathSound if has_node("DeathSound") else null

# Visual feedback
var hitbox_original_colors = {}

# Animation state
var last_animation: String = "idle"

# Character configuration data
const CHARACTER_DATA = {
	"blue": {
		"color": Color(0.3, 0.5, 1.0),
		"sprite_path": "res://assets/characters/blue/spritesheet.png",
		"max_health": 100.0,
		"walk_speed": 200.0,
		"run_speed": 350.0
	},
	"red": {
		"color": Color(1.0, 0.3, 0.3),
		"sprite_path": "res://assets/characters/red/spritesheet.png",
		"max_health": 120.0,
		"walk_speed": 180.0,
		"run_speed": 320.0
	},
	"green": {
		"color": Color(0.3, 1.0, 0.3),
		"sprite_path": "res://assets/characters/green/spritesheet.png",
		"max_health": 80.0,
		"walk_speed": 220.0,
		"run_speed": 380.0
	}
}

func _ready():
	# DO NOT call setup here - wait for parent scene to call configure_player()
	add_to_group("player")
	add_to_group("alive")
	
	# Setup hitboxes
	_setup_hitbox(heavy_hitbox, "heavy")
	_setup_hitbox(light_hitbox, "light")
	
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = false
		if not ultimate_hitbox.area_entered.is_connected(_on_ultimate_hitbox_area_entered):
			ultimate_hitbox.area_entered.connect(_on_ultimate_hitbox_area_entered)

## Called by the parent scene (GameScene) to configure this player
func configure_player(p_id: String, char_key: String):
	player_id = p_id
	character_key = char_key
	
	# Apply character-specific stats
	if CHARACTER_DATA.has(char_key):
		var data = CHARACTER_DATA[char_key]
		max_health = data.get("max_health", 100.0)
		walk_speed = data.get("walk_speed", 200.0)
		run_speed = data.get("run_speed", 350.0)
		current_health = max_health
		
		# Apply visual color tint
		var color = data.get("color", Color.WHITE)
		if sprite:
			sprite.modulate = color
		if animated_sprite:
			animated_sprite.modulate = color
	
	# Set multiplayer authority
	if GameState.game_mode == "pvp":
		_setup_multiplayer_authority()
	else:
		# Solo mode: player1 is controlled by user, player2 is AI
		if player_id == "player1":
			set_multiplayer_authority(1) # Local player
		else:
			# AI controlled - still needs authority for physics
			set_multiplayer_authority(1)
	
	print("[Player] Configured: ", player_id, " | Character: ", char_key, " | Authority: ", get_multiplayer_authority())

func _setup_multiplayer_authority():
	# In PvP mode, assign authority based on network peer IDs
	var player_ids = NetworkManager.get_player_ids()
	if player_ids.size() >= 2:
		player_ids.sort()
		
		if player_id == "player1":
			set_multiplayer_authority(player_ids[0])
		elif player_id == "player2":
			set_multiplayer_authority(player_ids[1])

func _setup_hitbox(hitbox: Area2D, key: String):
	if hitbox:
		hitbox.monitoring = false
		if hitbox.has_node("Visual"):
			var visual = hitbox.get_node("Visual")
			hitbox_original_colors[key] = visual.color
			visual.visible = false
		
		# Connect signals safely
		var callable = _on_heavy_hitbox_area_entered if key == "heavy" else _on_light_hitbox_area_entered
		if not hitbox.area_entered.is_connected(callable):
			hitbox.area_entered.connect(callable)

func _physics_process(delta):
	# Only process input if this is our player
	if not is_multiplayer_authority():
		return
	
	if is_dead or current_health <= 0:
		if not is_dead:
			die()
		velocity.x = 0
		return
	
	# AI control for player2 in solo mode
	if GameState.game_mode == "solo" and player_id == "player2":
		_ai_behavior(delta)
		return
	
	# Normal player input
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 20)
		move_and_slide()
		return
	
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	if input_dir != 0:
		var current_speed = run_speed if is_running else walk_speed
		velocity.x = input_dir * current_speed
		is_walking = true
		
		if input_dir > 0 and not facing_right:
			flip_character(true)
		elif input_dir < 0 and facing_right:
			flip_character(false)
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		is_walking = false
	
	move_and_slide()
	update_animation()
	
	if Input.is_action_just_pressed("light_attack") and not is_attacking:
		light_attack()
	if Input.is_action_just_pressed("heavy_attack") and not is_attacking:
		heavy_attack()
	if Input.is_action_just_pressed("ultimate_attack") and not is_attacking:
		if ultimate_charge >= ultimate_cost:
			ultimate_attack()
	
	if ultimate_charge < ultimate_max:
		ultimate_charge += delta * 5.0

# Simple AI behavior for solo mode
func _ai_behavior(_delta: float):
	# TODO: Implement AI logic
	# For now, just stand idle
	velocity.x = 0
	is_walking = false
	move_and_slide()
	update_animation()

func flip_character(right: bool):
	facing_right = right
	if sprite: sprite.flip_h = not right
	if animated_sprite: animated_sprite.flip_h = not right
	
	# Helper to flip collision shapes safely
	_flip_hitbox_shape(heavy_hitbox, right)
	_flip_hitbox_shape(light_hitbox, right)

func _flip_hitbox_shape(hitbox: Area2D, right: bool):
	if hitbox and hitbox.has_node("CollisionShape2D"):
		var shape = hitbox.get_node("CollisionShape2D")
		shape.position.x = abs(shape.position.x) * (1 if right else -1)

func update_animation():
	# CRITICAL FIX: Ensure sprite_frames exists before checking animations
	if not animated_sprite or not animated_sprite.sprite_frames:
		return 
	
	var new_animation: String = "idle"
	
	if is_dead:
		new_animation = "death"
	elif is_attacking:
		return # Attacks manage their own play_animation calls
	elif ultimate_active:
		new_animation = "ultimate"
	elif is_walking:
		new_animation = "run" if is_running else "walk"
	
	if new_animation != last_animation:
		play_animation(new_animation)
	
	if is_walking and walk_sound:
		if not walk_sound.playing: walk_sound.play()
	elif walk_sound and walk_sound.playing:
		walk_sound.stop()

func play_animation(anim_name: String):
	# CRITICAL FIX: Double check for null instances and missing animation names
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
			last_animation = anim_name
		else:
			print("Warning: Animation '", anim_name, "' not found in SpriteFrames!")

# --- Combat Functions ---

func light_attack():
	if is_attacking or is_dead: return
	is_attacking = true
	play_animation("light_attack")
	if light_attack_sound: light_attack_sound.play()
	
	if light_hitbox:
		light_hitbox.monitoring = true
		if light_hitbox.has_node("Visual"): light_hitbox.get_node("Visual").visible = true
		await get_tree().create_timer(0.15).timeout
		light_hitbox.monitoring = false
		if light_hitbox.has_node("Visual"): light_hitbox.get_node("Visual").visible = false
	
	is_attacking = false

func heavy_attack():
	if is_attacking or is_dead: return
	is_attacking = true
	play_animation("heavy_attack")
	if heavy_attack_sound: heavy_attack_sound.play()
	
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		if heavy_hitbox.has_node("Visual"): heavy_hitbox.get_node("Visual").visible = true
		await get_tree().create_timer(0.25).timeout
		heavy_hitbox.monitoring = false
		if heavy_hitbox.has_node("Visual"): heavy_hitbox.get_node("Visual").visible = false
	
	is_attacking = false

func ultimate_attack():
	if is_attacking or ultimate_charge < ultimate_cost or is_dead: return
	is_attacking = true
	ultimate_active = true
	ultimate_charge = 0.0
	
	play_animation("ultimate")
	if ultimate_sound: ultimate_sound.play()
	create_ultimate_effect()
	
	# Record ultimate usage in GameState
	GameState.record_ultimate(player_id)
	
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = true
		await get_tree().create_timer(0.5).timeout
		ultimate_hitbox.monitoring = false
	
	is_attacking = false
	ultimate_active = false

func create_ultimate_effect():
	var ultimate_visual = ColorRect.new()
	ultimate_visual.color = Color(1, 0.8, 0, 0.6)
	ultimate_visual.size = Vector2(400, 400)
	ultimate_visual.position = Vector2(-200, -200)
	add_child(ultimate_visual)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ultimate_visual, "modulate:a", 0.0, 0.5)
	tween.tween_property(ultimate_visual, "scale", Vector2(1.5, 1.5), 0.5)
	await tween.finished
	ultimate_visual.queue_free()

func _on_light_hitbox_area_entered(area: Area2D):
	_handle_impact(area, 10.0)

func _on_heavy_hitbox_area_entered(area: Area2D):
	_handle_impact(area, 20.0)

func _on_ultimate_hitbox_area_entered(area: Area2D):
	_handle_impact(area, 50.0)

func _handle_impact(area: Area2D, damage: float):
	var target = area.get_parent()
	if target and target != self and target.has_method("take_damage"):
		target.take_damage(damage)
		on_hit_landed(damage)

func take_damage(damage: float):
	if is_dead: return
	current_health -= damage
	if damage_sound: damage_sound.play()
	
	var obj = sprite if sprite else animated_sprite
	if obj:
		obj.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		# Restore original character color
		if CHARACTER_DATA.has(character_key):
			obj.modulate = CHARACTER_DATA[character_key].get("color", Color.WHITE)
		else:
			obj.modulate = Color(1, 1, 1)
	
	ultimate_charge = min(ultimate_charge + damage * 1.0, ultimate_max)
	if current_health <= 0: die()

func die():
	is_dead = true
	if is_in_group("alive"): remove_from_group("alive")
	if death_sound: death_sound.play()
	play_animation("death")
	
	var obj = sprite if sprite else animated_sprite
	if obj:
		var tween = create_tween()
		tween.tween_property(obj, "modulate:a", 0.0, 1.0)

func on_hit_landed(damage: float):
	ultimate_charge = min(ultimate_charge + damage * 2, ultimate_max)
	# Record attack stats in GameState
	GameState.record_attack(player_id, damage)

# Getters for UI and game logic
func get_health_percentage() -> float:
	return (current_health / max_health) * 100.0

func get_ultimate_percentage() -> float:
	return (ultimate_charge / ultimate_max) * 100.0
