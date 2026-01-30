extends Camera2D

## Camera Controller for Fighting Game
## Features: Dynamic following, screen shake, and smooth transitions

@export_group("Camera Settings")
@export var follow_player: bool = true
@export var follow_enemy: bool = true
@export var camera_smoothing: float = 5.0
@export var min_zoom: float = 0.8
@export var max_zoom: float = 1.2
@export var zoom_smoothing: float = 3.0

@export_group("Camera Bounds")
@export var left_limit: float = 0.0
@export var right_limit: float = 11210.0
@export var top_limit: float = 0.0
@export var bottom_limit: float = 6156.0

@export_group("Shake Settings")
@export var light_hit_shake_strength: float = 3.0
@export var heavy_hit_shake_strength: float = 8.0
@export var shake_decay: float = 5.0

@export_group("Character References")
@export var player: Node2D
@export var enemy: Node2D

# Internal state
var shake_strength: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var target_zoom: float = 1.0

func _ready():
	add_to_group("camera")
	
	# Set camera limits
	limit_left = int(left_limit)
	limit_right = int(right_limit)
	limit_top = int(top_limit)
	limit_bottom = int(bottom_limit)
	
	# Find characters if not set
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not enemy:
		enemy = get_tree().get_first_node_in_group("enemy")
	
	print("✓ Camera ready")

func _process(delta: float):
	_update_camera_position(delta)
	_update_camera_zoom(delta)
	_apply_screen_shake(delta)

func _update_camera_position(delta: float):
	var focus_point = Vector2.ZERO
	var valid_targets = 0
	
	# Calculate midpoint between characters
	if follow_player and player:
		focus_point += player.global_position
		valid_targets += 1
	
	if follow_enemy and enemy:
		focus_point += enemy.global_position
		valid_targets += 1
	
	if valid_targets > 0:
		focus_point /= valid_targets
		target_position = focus_point
	
	# Smooth camera movement
	global_position = global_position.lerp(target_position, camera_smoothing * delta)

func _update_camera_zoom(delta: float):
	if not player or not enemy:
		return
	
	# Calculate distance between characters
	var distance = abs(player.global_position.x - enemy.global_position.x)
	
	# Adjust zoom based on distance
	var desired_zoom = 1.0
	if distance > 800:
		desired_zoom = 0.9
	elif distance > 1200:
		desired_zoom = 0.8
	elif distance < 400:
		desired_zoom = 1.1
	
	desired_zoom = clamp(desired_zoom, min_zoom, max_zoom)
	target_zoom = desired_zoom
	
	# Smooth zoom
	var current_zoom = zoom.x
	current_zoom = lerp(current_zoom, target_zoom, zoom_smoothing * delta)
	zoom = Vector2(current_zoom, current_zoom)

func _apply_screen_shake(delta: float):
	if shake_strength > 0:
		shake_strength = max(shake_strength - shake_decay * delta, 0)
		shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		offset = shake_offset
	else:
		offset = Vector2.ZERO

# --- Public Methods ---

func shake_light_hit():
	shake_strength = light_hit_shake_strength

func shake_heavy_hit():
	shake_strength = heavy_hit_shake_strength

func shake_custom(strength: float):
	shake_strength = strength

func update_player_health(current: float, maximum: float):
	# Forward to game manager if available
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("update_player_health"):
		game_manager.update_player_health(current, maximum)

func update_combo(combo_count: int):
	# Forward to game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("update_combo"):
		game_manager.update_combo(combo_count)
