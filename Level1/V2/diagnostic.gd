extends Node

# Diagnostic script for debugging fighting game

var player: CharacterBody2D = null
var enemy: CharacterBody2D = null
var show_debug: bool = true

func _ready():
	# Find characters
	await get_tree().create_timer(0.5).timeout
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")
	
	print("=== FIGHTING GAME DIAGNOSTICS ===")
	check_characters()
	check_input_map()
	check_collision_setup()

func _process(_delta: float):
	if Input.is_action_just_pressed("ui_cancel"):
		show_debug = not show_debug
	
	if show_debug:
		display_debug_info()

func check_characters():
	print("\n--- Character Check ---")
	if player:
		print("✓ Player found: ", player.name)
		print("  Position: ", player.position)
		print("  Script: ", player.get_script())
	else:
		print("✗ Player NOT found! Add to 'player' group")
	
	if enemy:
		print("✓ Enemy found: ", enemy.name)
		print("  Position: ", enemy.position)
		print("  Script: ", enemy.get_script())
	else:
		print("✗ Enemy NOT found! Add to 'enemy' group")

func check_input_map():
	print("\n--- Input Map Check ---")
	var required_actions = [
		"move_left", "move_right", "jump", "crouch",
		"light_attack", "heavy_attack", "block"
	]
	
	for action in required_actions:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			print("✓ ", action, " - ", events.size(), " key(s) mapped")
		else:
			print("✗ ", action, " - NOT CONFIGURED!")

func check_collision_setup():
	print("\n--- Collision Setup Check ---")
	
	if player:
		print("Player Collision:")
		print("  Layer: ", player.collision_layer)
		print("  Mask: ", player.collision_mask)
		
		var hitboxes = player.get_node_or_null("Hitboxes")
		if hitboxes:
			print("  ✓ Hitboxes node found")
			for child in hitboxes.get_children():
				if child is Area2D:
					print("    - ", child.name, " (Layer:", child.collision_layer, " Mask:", child.collision_mask, ")")
		else:
			print("  ✗ Hitboxes node NOT found!")
		
		var hurtbox = player.get_node_or_null("Hurtbox")
		if hurtbox:
			print("  ✓ Hurtbox found (Layer:", hurtbox.collision_layer, " Mask:", hurtbox.collision_mask, ")")
		else:
			print("  ✗ Hurtbox NOT found!")
	
	if enemy:
		print("\nEnemy Collision:")
		print("  Layer: ", enemy.collision_layer)
		print("  Mask: ", enemy.collision_mask)

func display_debug_info():
	var debug_text = ""
	
	if player and "current_health" in player:
		debug_text += "Player HP: " + str(int(player.current_health)) + "\n"
		debug_text += "Player State: "
		if "is_attacking" in player and player.is_attacking:
			debug_text += "ATTACKING"
		elif "is_blocking" in player and player.is_blocking:
			debug_text += "BLOCKING"
		elif "is_crouching" in player and player.is_crouching:
			debug_text += "CROUCHING"
		elif "is_hit_stunned" in player and player.is_hit_stunned:
			debug_text += "HIT STUN"
		else:
			debug_text += "NORMAL"
		debug_text += "\n"
		
		if "combo_count" in player:
			debug_text += "Combo: " + str(player.combo_count) + "\n"
	
	if enemy and "current_health" in enemy:
		debug_text += "\nEnemy HP: " + str(int(enemy.current_health)) + "\n"
		if "ai_state" in enemy:
			debug_text += "AI State: " + enemy.ai_state + "\n"
	
	# Display distance
	if player and enemy:
		var distance = abs(player.global_position.x - enemy.global_position.x)
		debug_text += "\nDistance: " + str(int(distance)) + "\n"
	
	debug_text += "\nPress ESC to toggle debug"
	
	# Draw on screen
	if has_node("/root/FightingGameLevel/UI/UIContainer/damage"):
		var label = get_node("/root/FightingGameLevel/UI/UIContainer/damage")
		label.text = debug_text

func _input(event: InputEvent):
	# Test hitbox visualization
	if event.is_action_pressed("ui_text_toggle_insert_mode"):  # Insert key
		toggle_collision_visualization()

func toggle_collision_visualization():
	get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
	print("Collision visualization: ", get_tree().debug_collisions_hint)
