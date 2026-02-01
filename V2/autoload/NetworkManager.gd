extends CharacterBody2D

## NetworkPlayer - Multiplayer synchronized fighter
## Supports both Solo (AI) and PVP modes

# Inspector configurable variables
@export_group("Movement")
@export var walk_speed: float = 300.0
@export var jump_force: float = 500.0
@export var gravity: float = 980.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var light_damage: float = 10.0
@export var heavy_damage: float = 20.0
@export var ultimate_damage: float = 50.0

@export_group("Ultimate")
@export var ultimate_max: float = 100.0
@export var ultimate_cost: float = 100.0
@export var ultimate_charge_rate: float = 5.0

@export_group("Player Info")
@export var player_name: String = "Player"
@export var character_type: String = "blue"
@export var is_ai: bool = false

# Player state (synced over network)
var current_health: float = 100.0
var ultimate_charge: float = 0.0
var facing_right: bool = true
var is_dead: bool = false

# Local state
var is_attacking: bool = false
var peer_id: int = 1

# AI variables
var ai_target: CharacterBody2D = null
var ai_attack_timer: float = 0.0
var ai_decision_timer: float = 0.0

# References
@onready var sprite = $Sprite2D
@onready var name_label = $NameLabel
@onready var light_hitbox = $LightHitbox
@onready var heavy_hitbox = $HeavyHitbox
@onready var ultimate_hitbox = $UltimateHitbox
@onready var camera = $Camera2D

# Character colors
var character_colors = {
	"blue": Color(0.3, 0.6, 1, 1),
	"red": Color(1, 0.3, 0.3, 1),
	"green": Color(0.3, 1, 0.3, 1)
}

func _ready():
	current_health = max_health
	
	if sprite and character_type in character_colors:
		sprite.color = character_colors[character_type]
	
	if name_label:
		name_label.text = player_name
	
	if light_hitbox:
		light_hitbox.monitoring = false
		light_hitbox.area_entered.connect(_on_light_hitbox_hit)
	if heavy_hitbox:
		heavy_hitbox.monitoring = false
		heavy_hitbox.area_entered.connect(_on_heavy_hitbox_hit)
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = false
		ultimate_hitbox.area_entered.connect(_on_ultimate_hitbox_hit)
	
	if camera:
		camera.enabled = is_multiplayer_authority() and not is_ai

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if is_dead:
		velocity.x = 0
		return
	
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		move_and_slide()
		return
	
	if is_ai:
		_ai_behavior(delta)
	elif is_multiplayer_authority():
		_player_input(delta)
	
	move_and_slide()
	
	if ultimate_charge < ultimate_max:
		ultimate_charge += delta * ultimate_charge_rate

func _player_input(delta):
	"""Handle player input using project-defined actions"""
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = direction * walk_speed
		if direction > 0 and not facing_right:
			_flip_character.rpc(true) # Synced flip
		elif direction < 0 and facing_right:
			_flip_character.rpc(false) # Synced flip
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
	
	# Updated to use custom actions from project.godot
	if Input.is_action_just_pressed("light_attack"):
		_request_light_attack.rpc()
	elif Input.is_action_just_pressed("heavy_attack"):
		_request_heavy_attack.rpc()
	elif Input.is_action_just_pressed("ultimate_attack"):
		_request_ultimate_attack.rpc()

func _ai_behavior(delta):
	"""AI control logic"""
	if not ai_target:
		velocity.x = 0
		return
	
	ai_attack_timer -= delta
	ai_decision_timer -= delta
	
	var distance = global_position.distance_to(ai_target.global_position)
	var direction = sign(ai_target.global_position.x - global_position.x)
	
	if distance > 150:
		velocity.x = direction * walk_speed
		if direction > 0 and not facing_right:
			_flip_character.rpc(true)
		elif direction < 0 and facing_right:
			_flip_character.rpc(false)
	elif distance < 80:
		velocity.x = -direction * walk_speed * 0.5
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
	
	if ai_attack_timer <= 0 and distance <= 150 and not is_attacking:
		if ai_decision_timer <= 0:
			var attack_roll = randf()
			
			if ultimate_charge >= ultimate_cost and randf() < 0.3:
				_request_ultimate_attack.rpc()
				ai_attack_timer = randf_range(2.0, 3.0)
			elif attack_roll < 0.4:
				_request_heavy_attack.rpc()
				ai_attack_timer = randf_range(1.0, 1.5)
			elif attack_roll < 0.8:
				_request_light_attack.rpc()
				ai_attack_timer = randf_range(0.5, 1.0)
			
			ai_decision_timer = randf_range(0.2, 0.5)

@rpc("any_peer", "call_local")
func _flip_character(right: bool):
	facing_right = right
	if sprite:
		sprite.scale.x = -1 if not right else 1
	
	if light_hitbox and light_hitbox.has_node("CollisionShape2D"):
		var shape = light_hitbox.get_node("CollisionShape2D")
		shape.position.x = abs(shape.position.x) * (1 if right else -1)
	
	if heavy_hitbox and heavy_hitbox.has_node("CollisionShape2D"):
		var shape = heavy_hitbox.get_node("CollisionShape2D")
		shape.position.x = abs(shape.position.x) * (1 if right else -1)

@rpc("any_peer", "call_local")
func _request_light_attack():
	if not is_attacking and not is_dead:
		_perform_light_attack.rpc()

@rpc("any_peer", "call_local")
func _request_heavy_attack():
	if not is_attacking and not is_dead:
		_perform_heavy_attack.rpc()

@rpc("any_peer", "call_local")
func _request_ultimate_attack():
	if not is_attacking and not is_dead and ultimate_charge >= ultimate_cost:
		_perform_ultimate_attack.rpc()

@rpc("any_peer", "call_local")
func _perform_light_attack():
	if is_attacking or is_dead: return
	is_attacking = true
	if light_hitbox:
		light_hitbox.monitoring = true
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = true
		await get_tree().create_timer(0.15).timeout
		light_hitbox.monitoring = false
		if light_hitbox.has_node("Visual"):
			light_hitbox.get_node("Visual").visible = false
	is_attacking = false

@rpc("any_peer", "call_local")
func _perform_heavy_attack():
	if is_attacking or is_dead: return
	is_attacking = true
	if heavy_hitbox:
		heavy_hitbox.monitoring = true
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = true
		await get_tree().create_timer(0.25).timeout
		heavy_hitbox.monitoring = false
		if heavy_hitbox.has_node("Visual"):
			heavy_hitbox.get_node("Visual").visible = false
	is_attacking = false

@rpc("any_peer", "call_local")
func _perform_ultimate_attack():
	if is_attacking or is_dead or ultimate_charge < ultimate_cost: return
	is_attacking = true
	ultimate_charge = 0.0
	_create_ultimate_effect()
	if ultimate_hitbox:
		ultimate_hitbox.monitoring = true
		await get_tree().create_timer(0.5).timeout
		ultimate_hitbox.monitoring = false
	is_attacking = false

func _create_ultimate_effect():
	var effect = ColorRect.new()
	effect.color = character_colors.get(character_type, Color.WHITE)
	effect.color.a = 0.6
	effect.size = Vector2(400, 400)
	effect.position = Vector2(-200, -200)
	add_child(effect)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "modulate:a", 0.0, 0.5)
	tween.tween_property(effect, "scale", Vector2(1.5, 1.5), 0.5)
	await tween.finished
	effect.queue_free()

func _on_light_hitbox_hit(area: Area2D):
	if is_multiplayer_authority() or is_ai:
		var target = area.get_parent()
		if target and target != self and target.has_method("take_damage"):
			target.take_damage.rpc(light_damage, get_path())

func _on_heavy_hitbox_hit(area: Area2D):
	if is_multiplayer_authority() or is_ai:
		var target = area.get_parent()
		if target and target != self and target.has_method("take_damage"):
			target.take_damage.rpc(heavy_damage, get_path())

func _on_ultimate_hitbox_hit(area: Area2D):
	if is_multiplayer_authority() or is_ai:
		var target = area.get_parent()
		if target and target != self and target.has_method("take_damage"):
			target.take_damage.rpc(ultimate_damage, get_path())

@rpc("any_peer", "call_local")
func take_damage(damage: float, attacker_path: NodePath):
	if is_dead: return
	current_health -= damage
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if sprite and not is_dead:
			sprite.modulate = Color.WHITE
	ultimate_charge = min(ultimate_charge + damage, ultimate_max)
	if current_health <= 0:
		_die()

func _die():
	is_dead = true
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)

func setup(id: int, p_name: String, char: String, ai: bool = false):
	peer_id = id
	player_name = p_name
	character_type = char
	is_ai = ai
	if not ai:
		set_multiplayer_authority(id)
	name = "Player" + str(id)
	if sprite and character_type in character_colors:
		sprite.color = character_colors[character_type]
	if name_label:
		name_label.text = player_name

func set_ai_target(target: CharacterBody2D):
	ai_target = target
