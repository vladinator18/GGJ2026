extends Camera2D

@export var follow_speed: float = 5.0
@export var min_zoom: float = 0.8
@export var max_zoom: float = 1.5
@export var zoom_margin: float = 200.0

var player: Node2D = null
var enemy: Node2D = null

func _ready():
	# Find player and enemy
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")

func _process(delta: float):
	if not player or not enemy:
		return
	
	# Calculate midpoint between fighters
	var midpoint = (player.global_position + enemy.global_position) / 2.0
	
	# Smoothly move camera to midpoint
	global_position = global_position.lerp(midpoint, follow_speed * delta)
	
	# Calculate distance between fighters
	var distance = player.global_position.distance_to(enemy.global_position)
	
	# Adjust zoom based on distance
	var target_zoom = clamp(1.0 - (distance - zoom_margin) / 1000.0, min_zoom, max_zoom)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), follow_speed * delta)
