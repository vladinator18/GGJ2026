extends Control

## Menu UI Controller
## Manages the main menu interface with buttons and animations

# Inspector exported variables
@export_group("Menu Buttons")
@export var menu_button: Button
@export var start_button: Button
@export var online_button: Button
@export var local_button: Button
@export var settings_button: Button

@export_group("Animation")
@export var opening_animation: AnimationPlayer

# Called when the node enters the scene tree
func _ready():
	# Connect button signals if they exist
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if online_button:
		online_button.pressed.connect(_on_online_pressed)
	if local_button:
		local_button.pressed.connect(_on_local_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	# Play opening animation if available
	if opening_animation:
		opening_animation.play("open")

# Button callback functions
func _on_start_pressed():
	print("Start button pressed")
	# Add your start logic here

func _on_online_pressed():
	print("Online button pressed")
	# Add your online multiplayer logic here

func _on_local_pressed():
	print("Local button pressed")
	# Add your local game logic here

func _on_settings_pressed():
	print("Settings button pressed")
	# Add your settings menu logic here

func _on_menu_pressed():
	print("Menu button pressed")
	# Add your menu logic here
