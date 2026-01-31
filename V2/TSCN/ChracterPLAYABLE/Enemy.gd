extends CharacterBody2D
class_name Playerighter

# AI Behavior variables
@export var ai_enabled: bool = true
@export var reaction_time: float = 0.3  # Seconds before AI reacts
@export var aggression: float = 0.7  # 0.0 = defensive, 1.0 = aggressive
@export var attack_distance: float = 150.0  # Distance to start attacking
@export var retreat_distance: float = 80.0  # Too close, back up
@export var difficulty: float = 0.5  # 0.0 = easy, 1.0 = hard

# AI State
enum AIState {
	IDLE,
	APPROACH,
	ATTACK,
	RETREAT,
	BLOCK,
	COMBO
}

var current_state: AIState = AIState.IDLE
var target: CharacterBody2D = null
var reaction_timer: float = 0.0
var attack_cooldown: float = 0.0
var combo_count: int = 0
var decision_timer: float = 0.0

# AI decision making
var next_action: String = ""
var action_queue: Array = []

func _ready():
	super._ready()  # Call parent ready
	decision_timer = randf_range(0.5, 1.5)

func _physics_process(delta):
	if not ai_enabled or target == null:
		super._physics_process(delta)
		return
	
	# Update timers
	reaction_timer -= delta
	attack_cooldown -= delta
	decision_timer -= delta
	
	# Make decisions periodically
	if decision_timer <= 0:
		make_decision()
		decision_timer = randf_range(0.3, 0.8) / difficulty
	
	# Execute AI behavior
	execute_ai_behavior(delta)
	
	# Call parent physics process for movement
	super._physics_process(delta)

func make_decision():
	if target == null:
		current_state = AIState.IDLE
		return
	
	var distance = global_position.distance_to(target.global_position)
	var health_ratio = 1.0  # TODO: Add health system
	
	# State machine decision making
	match current_state:
		AIState.IDLE:
			if distance > attack_distance:
				current_state = AIState.APPROACH
			elif distance <= attack_distance and attack_cooldown <= 0:
				current_state = AIState.ATTACK
		
		AIState.APPROACH:
			if distance <= attack_distance:
				if randf() < aggression and attack_cooldown <= 0:
					current_state = AIState.ATTACK
				else:
					current_state = AIState.IDLE
			elif distance < retreat_distance:
				current_state = AIState.RETREAT
		
		AIState.ATTACK:
			if attack_cooldown <= 0:
				decide_attack()
			else:
				if distance > attack_distance:
					current_state = AIState.APPROACH
				elif distance < retreat_distance:
					current_state = AIState.RETREAT
				else:
					current_state = AIState.IDLE
		
		AIState.RETREAT:
			if distance > retreat_distance * 1.5:
				current_state = AIState.IDLE
		
		AIState.COMBO:
			if combo_count >= 3 or attack_cooldown > 0.5:
				current_state = AIState.RETREAT
				combo_count = 0

func decide_attack():
	var distance = global_position.distance_to(target.global_position)
	var rand_val = randf()
	
	# Choose attack based on distance and aggression
	if distance < attack_distance * 0.6:
		# Close range - more likely to use heavy attack
		if rand_val < (aggression * 0.6):
			next_action = "heavy_attack"
		else:
			next_action = "light_attack"
	else:
		# Medium range - prefer light attacks
		if rand_val < 0.7:
			next_action = "light_attack"
		else:
			next_action = "heavy_attack"
	
	# Chance for combo
	if randf() < (difficulty * aggression) and combo_count < 3:
		current_state = AIState.COMBO
		combo_count += 1
	else:
		combo_count = 0

func execute_ai_behavior(delta):
	if target == null:
		return
	
	# Calculate direction to target
	var direction = sign(target.global_position.x - global_position.x)
	var distance = global_position.distance_to(target.global_position)
	
	# Execute current state
	match current_state:
		AIState.IDLE:
			# Stand still, occasionally adjust position
			if randf() < 0.1:
				simulate_input("ui_left" if randf() < 0.5 else "ui_right", 0.1)
		
		AIState.APPROACH:
			# Move toward target
			if distance > attack_distance * 0.8:
				simulate_input("ui_right" if direction > 0 else "ui_left", delta)
		
		AIState.ATTACK:
			# Face target and attack
			if next_action == "light_attack" and reaction_timer <= 0:
				perform_light_attack()
				attack_cooldown = randf_range(0.5, 1.0) / difficulty
				reaction_timer = reaction_time
				next_action = ""
			elif next_action == "heavy_attack" and reaction_timer <= 0:
				perform_heavy_attack()
				attack_cooldown = randf_range(0.8, 1.5) / difficulty
				reaction_timer = reaction_time
				next_action = ""
		
		AIState.RETREAT:
			# Move away from target
			simulate_input("ui_left" if direction > 0 else "ui_right", delta)
		
		AIState.COMBO:
			# Execute combo chain
			if attack_cooldown <= 0:
				if randf() < 0.6:
					perform_light_attack()
					attack_cooldown = 0.3
				else:
					perform_heavy_attack()
					attack_cooldown = 0.5

func simulate_input(action: String, duration: float):
	# Override the input for AI control
	if action == "ui_left":
		velocity.x = -walk_speed
		if facing_right:
			flip_character(false)
	elif action == "ui_right":
		velocity.x = walk_speed
		if not facing_right:
			flip_character(true)

func perform_light_attack():
	light_attack()
	print("AI performs light attack")

func perform_heavy_attack():
	heavy_attack()
	print("AI performs heavy attack")

func set_target(new_target: CharacterBody2D):
	target = new_target

func set_difficulty_preset(preset: String):
	match preset:
		"easy":
			difficulty = 0.3
			aggression = 0.4
			reaction_time = 0.6
		"medium":
			difficulty = 0.5
			aggression = 0.6
			reaction_time = 0.4
		"hard":
			difficulty = 0.8
			aggression = 0.8
			reaction_time = 0.2
		"expert":
			difficulty = 1.0
			aggression = 0.9
			reaction_time = 0.1

# Debug visualization
func _draw():
	if ai_enabled and target:
		# Draw detection range
		draw_circle(Vector2.ZERO, attack_distance, Color(1, 0, 0, 0.1))
		draw_circle(Vector2.ZERO, retreat_distance, Color(0, 0, 1, 0.1))
