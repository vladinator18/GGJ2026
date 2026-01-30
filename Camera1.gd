extends Camera2D

## Arcade Fighter Camera Controller - FINAL PRODUCTION VERSION
## Optimized for large maps with all combat features

# --- Configuration ---
@export_group("Target")
@export var target: Node2D  # Assign your player node here

@export_group("Follow Behavior")
@export var follow_smoothing: float = 5.0
@export var offset_y: float = -200.0  # Camera offset above player (adjusted for large map)
@export var look_ahead_distance: float = 150.0  # Camera shifts towards facing direction
@export var look_ahead_enabled: bool = true

@export_group("Map Boundaries")
@export var enable_limits: bool = true
@export var map_left: int = 0
@export var map_right: int = 11210  # Scaled map width
@export var map_top: int = 0
@export var map_bottom: int = 6156  # Scaled map height

@export_group("Zoom")
@export var camera_zoom: Vector2 = Vector2(1.0, 1.0)
@export var dynamic_zoom: bool = false  # Zoom based on player distance
@export var min_zoom: float = 0.6
@export var max_zoom: float = 1.0

@export_group("Camera Shake")
@export var shake_enabled: bool = true
@export var light_hit_intensity: float = 5.0
@export var heavy_hit_intensity: float = 12.0
@export var shake_decay: float = 5.0

@export_group("UI Overlay Slots")
@export var player_health_bar: Control
@export var enemy_health_bar: Control
@export var combo_counter: Label
@export var timer_label: Label
@export var round_indicator: Label
@export var pause_menu: Control

# --- Internal ---
var player_found: bool = false
var shake_strength: float = 0.0
var shake_fade: float = 0.0

func _ready():
	add_to_group("camera")
	
	# Force camera to be enabled
	enabled = true
	
	# Set zoom
	zoom = camera_zoom
	
	# Apply map limits immediately
	if enable_limits:
		limit_left = map_left
		limit_right = map_right
		limit_top = map_top
		limit_bottom = map_bottom
		limit_smoothed = true
	
	# Position smoothing
	position_smoothing_enabled = true
	position_smoothing_speed = follow_smoothing
	
	# Find player if not assigned
	if not target:
		_find_player()
	
	# Initial position
	if target:
		global_position = target.global_position + Vector2(0, offset_y)
		print("✓ Camera initialized: ", map_right, "x", map_bottom, " | Locked to player")
	else:
		# Center camera if no target
		global_position = Vector2(map_right / 2.0, map_bottom / 2.0)
		push_warning("⚠ Camera: No target assigned, centering camera")
	
	# Hide pause menu initially
	if pause_menu:
		pause_menu.visible = false
	
	print("✓ Camera limits: Left:", limit_left, " Right:", limit_right, " Top:", limit_top, " Bottom:", limit_bottom)

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		player_found = true
		print("✓ Camera found player automatically")
	else:
		push_warning("⚠ Camera: Player not found! Add player to 'player' group")

func _process(delta: float):
	if not target:
		if not player_found:
			_find_player()
		return
	
	# Calculate target position
	var target_pos = target.global_position + Vector2(0, offset_y)
	
	# Add look-ahead based on facing direction
	if look_ahead_enabled and target.get("facing_right") != null:
		var look_ahead = Vector2.ZERO
		look_ahead.x = look_ahead_distance * (1 if target.facing_right else -1)
		target_pos += look_ahead
	
	# Smooth follow
	global_position = global_position.lerp(target_pos, follow_smoothing * delta)
	
	# Apply camera shake
	if shake_enabled and shake_strength > 0:
		_apply_shake(delta)
	
	# Dynamic zoom (optional)
	if dynamic_zoom:
		_update_dynamic_zoom(delta)

# --- Camera Shake System ---

func _apply_shake(delta: float):
	shake_fade = max(0.0, shake_fade - delta)
	shake_strength = shake_fade * shake_decay
	
	if shake_strength > 0.1:
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = Vector2.ZERO
		shake_strength = 0.0

func shake(intensity: float = 5.0, duration: float = 0.3):
	"""Call this when a hit connects"""
	if not shake_enabled:
		return
	shake_strength = intensity
	shake_fade = duration

func shake_light_hit():
	"""Quick shake for light attacks"""
	shake(light_hit_intensity, 0.15)

func shake_heavy_hit():
	"""Strong shake for heavy attacks"""
	shake(heavy_hit_intensity, 0.4)

func shake_super():
	"""Massive shake for special moves"""
	shake(20.0, 0.6)

func shake_custom(intensity: float, duration: float):
	"""Custom shake with specific values"""
	shake(intensity, duration)

# --- Dynamic Zoom ---

func _update_dynamic_zoom(delta: float):
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0 or not target:
		return
	
	var enemy = enemies[0]
	if not is_instance_valid(enemy):
		return
		
	var distance = target.global_position.distance_to(enemy.global_position)
	
	# Zoom out when far apart, zoom in when close
	var target_zoom = remap(distance, 400, 1600, max_zoom, min_zoom)
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), delta * 2.0)

# --- UI Management ---

func update_player_health(current: float, maximum: float):
	"""Update player health bar"""
	if not player_health_bar:
		return
	
	if player_health_bar is ProgressBar:
		player_health_bar.max_value = maximum
		player_health_bar.value = current
	elif player_health_bar is TextureProgressBar:
		player_health_bar.max_value = maximum
		player_health_bar.value = current
	elif player_health_bar.has_method("set_health"):
		player_health_bar.set_health(current, maximum)

func update_enemy_health(current: float, maximum: float):
	"""Update enemy health bar"""
	if not enemy_health_bar:
		return
		
	if enemy_health_bar is ProgressBar:
		enemy_health_bar.max_value = maximum
		enemy_health_bar.value = current
	elif enemy_health_bar is TextureProgressBar:
		enemy_health_bar.max_value = maximum
		enemy_health_bar.value = current
	elif enemy_health_bar.has_method("set_health"):
		enemy_health_bar.set_health(current, maximum)

func update_combo(hits: int):
	"""Update combo counter display"""
	if not combo_counter:
		return
		
	if hits > 1:
		combo_counter.text = str(hits) + " HIT COMBO!"
		combo_counter.visible = true
	else:
		combo_counter.text = ""
		combo_counter.visible = false

func update_timer(seconds: int):
	"""Update round timer"""
	if timer_label:
		var minutes = seconds / 60
		var secs = seconds % 60
		timer_label.text = "%02d:%02d" % [minutes, secs]

func update_round(current_round: int, max_rounds: int = 3):
	"""Update round indicator"""
	if round_indicator:
		round_indicator.text = "ROUND " + str(current_round) + " / " + str(max_rounds)

func show_pause_menu(show: bool):
	"""Toggle pause menu visibility"""
	if pause_menu:
		pause_menu.visible = show

func hide_all_ui():
	"""Hide all UI elements"""
	if player_health_bar: player_health_bar.visible = false
	if enemy_health_bar: enemy_health_bar.visible = false
	if combo_counter: combo_counter.visible = false
	if timer_label: timer_label.visible = false
	if round_indicator: round_indicator.visible = false

func show_all_ui():
	"""Show all UI elements"""
	if player_health_bar: player_health_bar.visible = true
	if enemy_health_bar: enemy_health_bar.visible = true
	if timer_label: timer_label.visible = true
	if round_indicator: round_indicator.visible = true

# --- Helper Functions ---

func set_map_boundaries(left: int, right: int, top: int, bottom: int):
	"""Dynamically update map boundaries"""
	limit_left = left
	limit_right = right
	limit_top = top
	limit_bottom = bottom
	map_left = left
	map_right = right
	map_top = top
	map_bottom = bottom
	print("✓ Camera boundaries updated: ", left, ",", right, ",", top, ",", bottom)

func auto_detect_boundaries():
	"""Auto-detect boundaries from MapBorder node"""
	var border_nodes = get_tree().get_nodes_in_group("map_border")
	if border_nodes.size() > 0:
		var border = border_nodes[0]
		if border.get("map_width") != null and border.get("map_height") != null:
			set_map_boundaries(0, int(border.map_width), 0, int(border.map_height))
			print("✓ Camera auto-detected boundaries from MapBorder")

func zoom_punch(intensity: float = 0.15, duration: float = 0.15):
	"""Quick zoom-in effect on heavy hits"""
	var original_zoom = zoom
	var tween = create_tween()
	tween.tween_property(self, "zoom", zoom + Vector2(intensity, intensity), duration / 2)
	tween.tween_property(self, "zoom", original_zoom, duration / 2)

func freeze_frame(duration: float = 0.1):
	"""Freeze game briefly for impact (hitpause effect)"""
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

func reset_camera():
	"""Reset camera to default state"""
	offset = Vector2.ZERO
	zoom = camera_zoom
	shake_strength = 0.0
	shake_fade = 0.0
	
	if target:
		global_position = target.global_position + Vector2(0, offset_y)
	else:
		global_position = Vector2(map_right / 2.0, map_bottom / 2.0)

func center_on_position(pos: Vector2, smooth: bool = true):
	"""Center camera on specific position"""
	if smooth:
		var tween = create_tween()
		tween.tween_property(self, "global_position", pos, 0.5)
	else:
		global_position = pos
