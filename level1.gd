extends Node2D

## Map Border Controller
## Creates physical boundaries and optional visual walls for the arena

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_width: float = 1920.0
@export var map_height: float = 1080.0
@export var floor_height: float = 500.0  # Y position of the floor

@export_group("Border Walls")
@export var create_physical_walls: bool = true
@export var wall_thickness: float = 50.0

@export_group("Visual Settings")
@export var show_debug_borders: bool = true
@export var border_color: Color = Color(1, 0, 0, 0.5)  # Red semi-transparent
@export var border_line_width: float = 3.0

# --- Internal ---
var left_wall: StaticBody2D
var right_wall: StaticBody2D
var ceiling: StaticBody2D
var floor_wall: StaticBody2D

func _ready():
	if create_physical_walls:
		_create_boundary_walls()
	print("✓ Map borders created: ", map_width, "x", map_height)

func _create_boundary_walls():
	# Left Wall
	left_wall = _create_wall(
		Vector2(-wall_thickness / 2, map_height / 2),
		Vector2(wall_thickness, map_height)
	)
	
	# Right Wall
	right_wall = _create_wall(
		Vector2(map_width + wall_thickness / 2, map_height / 2),
		Vector2(wall_thickness, map_height)
	)
	
	# Ceiling (optional - uncomment if needed)
	# ceiling = _create_wall(
	# 	Vector2(map_width / 2, -wall_thickness / 2),
	# 	Vector2(map_width, wall_thickness)
	# )
	
	# Floor (optional - players usually handle this in their scripts)
	# floor_wall = _create_wall(
	# 	Vector2(map_width / 2, floor_height + wall_thickness / 2),
	# 	Vector2(map_width, wall_thickness)
	# )

func _create_wall(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall = StaticBody2D.new()
	wall.position = pos
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	
	wall.add_child(collision)
	add_child(wall)
	
	return wall

func _draw():
	if not show_debug_borders:
		return
	
	# Draw border rectangle
	draw_rect(
		Rect2(0, 0, map_width, map_height),
		border_color,
		false,
		border_line_width
	)
	
	# Draw floor line
	draw_line(
		Vector2(0, floor_height),
		Vector2(map_width, floor_height),
		Color(0, 1, 0, 0.7),  # Green
		border_line_width
	)
	
	# Draw center line
	draw_line(
		Vector2(map_width / 2, 0),
		Vector2(map_width / 2, map_height),
		Color(1, 1, 0, 0.3),  # Yellow faded
		1.0
	)

# --- Helper Functions ---

func is_within_bounds(pos: Vector2) -> bool:
	"""Check if a position is within map boundaries"""
	return pos.x >= 0 and pos.x <= map_width and pos.y >= 0 and pos.y <= map_height

func clamp_to_bounds(pos: Vector2) -> Vector2:
	"""Clamp a position to stay within bounds"""
	return Vector2(
		clamp(pos.x, 0, map_width),
		clamp(pos.y, 0, map_height)
	)

func get_spawn_position(side: String = "left") -> Vector2:
	"""Get a spawn position on left or right side"""
	var x = map_width * 0.25 if side == "left" else map_width * 0.75
	return Vector2(x, floor_height)
