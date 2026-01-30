extends Button

## Character Select Button
## Transitions to character selection scene with fade animation and audio

# Inspector exported variables
@export_group("Scene Transition")
@export_file("*.tscn") var character_select_scene: String = "res://scenes/character_select.tscn"

@export_group("Animation & Audio")
@export var fade_animation: AnimationPlayer
@export var press_audio: AudioStreamPlayer

@export_group("Transition Settings")
@export var fade_duration: float = 0.5
@export var audio_delay: float = 0.1

# Called when the node enters the scene tree
func _ready():
	pressed.connect(_on_button_pressed)

# Handle button press
func _on_button_pressed():
	# Play audio cue
	if press_audio:
		press_audio.play()
	
	# Disable button to prevent double-clicks
	disabled = true
	
	# Play fade animation if available
	if fade_animation:
		fade_animation.play("fade_out")
		# Wait for animation to complete before changing scene
		await fade_animation.animation_finished
		_change_scene()
	else:
		# If no animation, wait for audio then change scene
		await get_tree().create_timer(fade_duration).timeout
		_change_scene()

# Change to character select scene
func _change_scene():
	if character_select_scene and character_select_scene != "":
		var result = get_tree().change_scene_to_file(character_select_scene)
		if result != OK:
			push_error("Failed to load scene: " + character_select_scene)
			disabled = false
	else:
		push_warning("No character select scene specified!")
		disabled = false
