extends Node

# Simple test script - attach to Game root node temporarily
# Press these keys to test:
# T - Deal 10 damage to enemy
# Y - Deal 10 damage to player
# R - Reset both characters

@export var player: CharacterBody2D
@export var enemy: CharacterBody2D

func _ready():
	print("=== DAMAGE TEST SCRIPT ACTIVE ===")
	print("Press T - Damage Enemy")
	print("Press Y - Damage Player")
	print("Press R - Reset both")

func _process(_delta):
	if Input.is_action_just_pressed("ui_focus_next"):  # Tab key / T
		if enemy and enemy.has_method("take_damage"):
			print("[TEST] Dealing 10 damage to enemy")
			enemy.take_damage(10.0, false)
	
	if Input.is_action_just_pressed("ui_focus_prev"):  # Shift+Tab / Y
		if player and player.has_method("take_damage"):
			print("[TEST] Dealing 10 damage to player")
			player.take_damage(10.0, false)
	
	if Input.is_key_pressed(KEY_R):
		if player and player.has_method("reset"):
			print("[TEST] Resetting player")
			player.reset()
		if enemy and enemy.has_method("reset"):
			print("[TEST] Resetting enemy")
			enemy.reset()
