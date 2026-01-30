extends Control

## Character Selection Menu
## Manages character buttons and skin selection submenu

# Character Data Structure
class CharacterData:
	var character_name: String
	var normal_texture: Texture2D
	var comedy_texture: Texture2D
	var tragedy_texture: Texture2D
	var character_scene: String
	
	func _init(name: String = "", normal: Texture2D = null, comedy: Texture2D = null, 
			   tragedy: Texture2D = null, scene: String = ""):
		character_name = name
		normal_texture = normal
		comedy_texture = comedy
		tragedy_texture = tragedy
		character_scene = scene

# Main Menu References
@export_group("Main Menu - Character Buttons")
@export var character_button_1: Button
@export var character_button_2: Button
@export var character_button_3: Button
@export var character_button_4: Button

# Character 1 Data
@export_group("Character 1 Settings")
@export var char1_name: String = "Character 1"
@export var char1_normal_skin: Texture2D
@export var char1_comedy_skin: Texture2D
@export var char1_tragedy_skin: Texture2D
@export_file("*.tscn") var char1_scene_path: String

# Character 2 Data
@export_group("Character 2 Settings")
@export var char2_name: String = "Character 2"
@export var char2_normal_skin: Texture2D
@export var char2_comedy_skin: Texture2D
@export var char2_tragedy_skin: Texture2D
@export_file("*.tscn") var char2_scene_path: String

# Character 3 Data
@export_group("Character 3 Settings")
@export var char3_name: String = "Character 3"
@export var char3_normal_skin: Texture2D
@export var char3_comedy_skin: Texture2D
@export var char3_tragedy_skin: Texture2D
@export_file("*.tscn") var char3_scene_path: String

# Character 4 Data
@export_group("Character 4 Settings")
@export var char4_name: String = "Character 4"
@export var char4_normal_skin: Texture2D
@export var char4_comedy_skin: Texture2D
@export var char4_tragedy_skin: Texture2D
@export_file("*.tscn") var char4_scene_path: String


# Skin Selection Menu (Menu 2)
@export_group("Skin Selection Menu")
@export var skin_selection_menu: Control
@export var normal_skin_button: Button
@export var comedy_skin_button: Button
@export var tragedy_skin_button: Button
@export var back_button: Button

# Preview Display
@export_group("Skin Preview")
@export var skin_preview_image: TextureRect
@export var character_name_label: Label

# Animation & Audio
@export_group("Effects")
@export var menu_animation: AnimationPlayer
@export var button_press_audio: AudioStreamPlayer
@export var skin_select_audio: AudioStreamPlayer

# Internal state
var characters: Array[CharacterData] = []
var selected_character_index: int = -1
var selected_skin: String = ""

func _ready():
	_initialize_characters()
	_connect_character_buttons()
	_connect_skin_buttons()
	_setup_initial_state()

func _initialize_characters():
	# Create character data from inspector values
	characters.append(CharacterData.new(
		char1_name, char1_normal_skin, char1_comedy_skin, 
		char1_tragedy_skin, char1_scene_path
	))
	
	characters.append(CharacterData.new(
		char2_name, char2_normal_skin, char2_comedy_skin, 
		char2_tragedy_skin, char2_scene_path
	))
	
	characters.append(CharacterData.new(
		char3_name, char3_normal_skin, char3_comedy_skin, 
		char3_tragedy_skin, char3_scene_path
	))
	
	characters.append(CharacterData.new(
		char4_name, char4_normal_skin, char4_comedy_skin, 
		char4_tragedy_skin, char4_scene_path
	))

func _connect_character_buttons():
	# Connect character selection buttons
	if character_button_1:
		character_button_1.pressed.connect(_on_character_selected.bind(0))
		if char1_normal_skin:
			character_button_1.icon = char1_normal_skin
		character_button_1.text = char1_name
	
	if character_button_2:
		character_button_2.pressed.connect(_on_character_selected.bind(1))
		if char2_normal_skin:
			character_button_2.icon = char2_normal_skin
		character_button_2.text = char2_name
	
	if character_button_3:
		character_button_3.pressed.connect(_on_character_selected.bind(2))
		if char3_normal_skin:
			character_button_3.icon = char3_normal_skin
		character_button_3.text = char3_name
	
	if character_button_4:
		character_button_4.pressed.connect(_on_character_selected.bind(3))
		if char4_normal_skin:
			character_button_4.icon = char4_normal_skin
		character_button_4.text = char4_name

func _connect_skin_buttons():
	# Connect skin selection buttons
	if normal_skin_button:
		normal_skin_button.pressed.connect(_on_skin_selected.bind("normal"))
	
	if comedy_skin_button:
		comedy_skin_button.pressed.connect(_on_skin_selected.bind("comedy"))
	
	if tragedy_skin_button:
		tragedy_skin_button.pressed.connect(_on_skin_selected.bind("tragedy"))
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _setup_initial_state():
	# Hide skin selection menu initially
	if skin_selection_menu:
		skin_selection_menu.visible = false

func _on_character_selected(index: int):
	if index < 0 or index >= characters.size():
		return
	
	selected_character_index = index
	
	# Play audio
	if button_press_audio:
		button_press_audio.play()
	
	# Show skin selection menu
	_show_skin_menu()

func _show_skin_menu():
	if not skin_selection_menu:
		return
	
	var character = characters[selected_character_index]
	
	# Update character name label
	if character_name_label:
		character_name_label.text = character.character_name
	
	# Update skin button icons
	if normal_skin_button and character.normal_texture:
		normal_skin_button.icon = character.normal_texture
		normal_skin_button.text = "Normal"
	
	if comedy_skin_button and character.comedy_texture:
		comedy_skin_button.icon = character.comedy_texture
		comedy_skin_button.text = "Comedy"
	
	if tragedy_skin_button and character.tragedy_texture:
		tragedy_skin_button.icon = character.tragedy_texture
		tragedy_skin_button.text = "Tragedy"
	
	# Show default preview (normal skin)
	_update_preview("normal")
	
	# Animate menu transition
	if menu_animation:
		menu_animation.play("show_skin_menu")
	else:
		skin_selection_menu.visible = true

func _on_skin_selected(skin_type: String):
	selected_skin = skin_type
	
	# Play audio
	if skin_select_audio:
		skin_select_audio.play()
	
	# Update preview
	_update_preview(skin_type)
	
	# Load game with selected character and skin
	await get_tree().create_timer(0.3).timeout
	_load_game()

func _update_preview(skin_type: String):
	if not skin_preview_image:
		return
	
	var character = characters[selected_character_index]
	var texture: Texture2D = null
	
	match skin_type:
		"normal":
			texture = character.normal_texture
		"comedy":
			texture = character.comedy_texture
		"tragedy":
			texture = character.tragedy_texture
	
	if texture:
		skin_preview_image.texture = texture

func _on_back_pressed():
	if button_press_audio:
		button_press_audio.play()
	
	# Hide skin menu
	if menu_animation:
		menu_animation.play_backwards("show_skin_menu")
		await menu_animation.animation_finished
		skin_selection_menu.visible = false
	else:
		if skin_selection_menu:
			skin_selection_menu.visible = false
	
	selected_character_index = -1
	selected_skin = ""

func _load_game():
	var character = characters[selected_character_index]
	var skin_texture = _get_skin_texture(character, selected_skin)
	
	print("Loading: %s with %s skin" % [character.character_name, selected_skin])
	
	# You can pass data through scene metadata or save it temporarily
	# For now, just load the scene
	if character.character_scene != "":
		var result = get_tree().change_scene_to_file(character.character_scene)
		if result != OK:
			push_error("Failed to load scene: " + character.character_scene)
	
	print("Loading: %s with %s skin" % [character.character_name, selected_skin])
	
	# Load character scene
	if character.character_scene != "":
		var result = get_tree().change_scene_to_file(character.character_scene)
		if result != OK:
			push_error("Failed to load scene: " + character.character_scene)

# Public function to get current selection
func get_selected_character_data() -> Dictionary:
	if selected_character_index == -1:
		return {}
	
	var character = characters[selected_character_index]
	return {
		"name": character.character_name,
		"skin": selected_skin,
		"texture": _get_skin_texture(character, selected_skin),
		"scene": character.character_scene
	}

func _get_skin_texture(character: CharacterData, skin_type: String) -> Texture2D:
	match skin_type:
		"normal":
			return character.normal_texture
		"comedy":
			return character.comedy_texture
		"tragedy":
			return character.tragedy_texture
		_:
			return character.normal_texture
