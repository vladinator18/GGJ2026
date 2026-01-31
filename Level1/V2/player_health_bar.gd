extends ProgressBar


# References to UI elements (optional - can be null if you just want a simple bar)
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
	
	# Get max health
	if tracked_character.has_method("get"):
		max_health = tracked_character.get("max_health")
	
	# Set initial health bar (this ProgressBar itself)
	max_value = max_health
	value = max_health
	
	# Connect to health_changed signal
	if tracked_character.has_signal("health_changed"):
		tracked_character.health_changed.connect(_on_health_changed)
		print("[HealthBar] Connected to %s's health_changed signal" % tracked_character.name)
	else:
		print("[HealthBar] WARNING: %s doesn't have health_changed signal!" % tracked_character.name)
	
	# Update display
	update_health_display(max_health)

func _on_health_changed(new_health: float):
	update_health_display(new_health)

func update_health_display(health: float):
	# Update progress bar (this ProgressBar itself)
	value = health
	
	# Update color based on health percentage
	var health_percent = health / max_health
	if health_percent > 0.6:
		modulate = health_high_color
	elif health_percent > 0.3:
		modulate = health_mid_color
	else:
		modulate = health_low_color
	
	# Update label
	if health_label:
		health_label.text = "%d / %d" % [int(health), int(max_health)]

func reset():
	if tracked_character and tracked_character.has_method("get"):
		var current_health = tracked_character.get("current_health")
		update_health_display(current_health)
