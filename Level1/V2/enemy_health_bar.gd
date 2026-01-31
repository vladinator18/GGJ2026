extends ProgressBar
class_name HealthBar

# References to UI elements
@export var health_bar: ProgressBar
@export var health_label: Label
@export var character_name_label: Label

# Reference to the character this health bar tracks
@export var tracked_character: CharacterBody2D

# Character name to display
@export var display_name: String = "Player"

# Colors for health bar
@export var health_high_color: Color = Color(0.0, 1.0, 0.0)  # Green
@export var health_mid_color: Color = Color(1.0, 1.0, 0.0)   # Yellow
@export var health_low_color: Color = Color(1.0, 0.0, 0.0)   # Red

var max_health: float = 100.0

func _ready():
	# Set character name
	if character_name_label:
		character_name_label.text = display_name
	
	# Connect to character signals
	if tracked_character:
		connect_to_character(tracked_character)
	else:
		print("[HealthBar] WARNING: No tracked_character assigned to %s" % name)

func connect_to_character(character: CharacterBody2D):
	tracked_character = character
	
	# Get max health - fixed version
	if "max_health" in tracked_character:
		max_health = tracked_character.max_health
	else:
		print("[HealthBar] WARNING: tracked_character doesn't have max_health property, using default: %f" % max_health)
	
	# Set initial health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = max_health
	
	# Connect to health_changed signal
	if tracked_character.has_signal("health_changed"):
		tracked_character.health_changed.connect(_on_health_changed)
		print("[HealthBar] Connected to %s's health_changed signal" % tracked_character.name)
	else:
		print("[HealthBar] WARNING: %s doesn't have health_changed signal!" % tracked_character.name)
	
	# Get current health and update display
	var current_health = max_health
	if "current_health" in tracked_character:
		current_health = tracked_character.current_health
	
	update_health_display(current_health)

func _on_health_changed(new_health: float):
	update_health_display(new_health)

func update_health_display(health: float):
	# Validate input
	if health == null:
		print("[HealthBar] ERROR: Received null health value!")
		return
	
	# Update progress bar
	if health_bar:
		health_bar.value = health
		
		# Update color based on health percentage
		var health_percent = health / max_health if max_health > 0 else 0
		if health_percent > 0.6:
			health_bar.modulate = health_high_color
		elif health_percent > 0.3:
			health_bar.modulate = health_mid_color
		else:
			health_bar.modulate = health_low_color
	
	# Update label
	if health_label:
		health_label.text = "%d / %d" % [int(health), int(max_health)]

func reset():
	if tracked_character and "current_health" in tracked_character:
		var current_health = tracked_character.current_health
		update_health_display(current_health)
