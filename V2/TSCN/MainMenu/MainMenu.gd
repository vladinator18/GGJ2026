extends Control

@onready var level1_button = $VBoxContainer/Level1Button
@onready var level2_button = $VBoxContainer/Level2Button
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	# Connect button signals if not already connected in scene
	if not level1_button.pressed.is_connected(_on_level_1_button_pressed):
		level1_button.pressed.connect(_on_level_1_button_pressed)
	if not level2_button.pressed.is_connected(_on_level_2_button_pressed):
		level2_button.pressed.connect(_on_level_2_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_level_1_button_pressed():
	# Load single-player arcade mode
	get_tree().change_scene_to_file("res://Level1.tscn")

func _on_level_2_button_pressed():
	# Load multiplayer menu
	get_tree().change_scene_to_file("res://MultiplayerMenu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
