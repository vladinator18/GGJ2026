extends Node

## Diagnostic Script - Test Damage Tracking Setup
## Add this to your scene temporarily to verify connections

func _ready():
	print("\n=== DAMAGE TRACKING DIAGNOSTIC ===\n")
	
	# Wait a moment for everything to initialize
	await get_tree().create_timer(0.5).timeout
	
	# Check for Game Manager
	var game_managers = get_tree().get_nodes_in_group("game_manager")
	if game_managers.size() > 0:
		print("✓ Game Manager found in 'game_manager' group")
		var gm = game_managers[0]
		print("  - Node name: ", gm.name)
		print("  - Has record_damage method: ", gm.has_method("record_damage"))
		
		# Test the method
		if gm.has_method("record_damage"):
			print("\n--- Testing record_damage() ---")
			gm.record_damage("player", 10.0, true)
			gm.record_damage("enemy", 15.0, true)
			
			var player_stats = gm.get_player_damage_stats()
			var enemy_stats = gm.get_enemy_damage_stats()
			
			print("Player stats after test:")
			print("  - Damage dealt: ", player_stats.total_dealt)
			print("  - Hits landed: ", player_stats.total_hits_landed)
			
			print("Enemy stats after test:")
			print("  - Damage dealt: ", enemy_stats.total_dealt)
			print("  - Hits landed: ", enemy_stats.total_hits_landed)
	else:
		print("❌ Game Manager NOT found! Add GameManager to 'game_manager' group!")
	
	# Check for Player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("\n✓ Player found in 'player' group")
		var player = players[0]
		print("  - Node name: ", player.name)
		print("  - Has take_damage method: ", player.has_method("take_damage"))
		
		# Check if player has game_manager reference
		if player.get("game_manager") != null:
			if player.game_manager:
				print("  - ✓ Player has Game Manager reference")
			else:
				print("  - ❌ Player game_manager is null")
		else:
			print("  - ❌ Player has no game_manager variable")
	else:
		print("\n❌ Player NOT found! Add Player to 'player' group!")
	
	# Check for Enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() > 0:
		print("\n✓ Enemy found in 'enemy' group")
		var enemy = enemies[0]
		print("  - Node name: ", enemy.name)
		print("  - Has take_damage method: ", enemy.has_method("take_damage"))
		
		# Check if enemy has game_manager reference
		if enemy.get("game_manager") != null:
			if enemy.game_manager:
				print("  - ✓ Enemy has Game Manager reference")
			else:
				print("  - ❌ Enemy game_manager is null")
		else:
			print("  - ❌ Enemy has no game_manager variable")
	else:
		print("\n❌ Enemy NOT found! Add Enemy to 'enemy' group!")
	
	print("\n=== DIAGNOSTIC COMPLETE ===")
	print("\nIf you see checkmarks (✓) for all items, damage tracking should work.")
	print("If you see X marks (❌), fix those issues first.\n")
