extends Node
## GameSync - Synchronizes gameplay between multiplayer clients
## Attach this to your main game scene or add as AutoLoad

# Signals
signal health_updated(player_id: int, health: float)
signal position_updated(player_id: int, position: Vector2)
signal animation_changed(player_id: int, animation: String)
signal attack_performed(player_id: int, attack_type: String)
signal round_ended(winner_id: int)

# Sync settings
const POSITION_SYNC_INTERVAL = 0.05  # 20 times per second
const HEALTH_SYNC_INTERVAL = 0.1     # 10 times per second

var position_sync_timer = 0.0
var health_sync_timer = 0.0

# Player state cache
var player_states = {
	1: {"health": 100.0, "position": Vector2.ZERO, "animation": "idle"},
	2: {"health": 100.0, "position": Vector2.ZERO, "animation": "idle"}
}

func _ready():
	set_process(GameState.game_mode == "pvp")

func _process(delta):
	if GameState.game_mode != "pvp":
		return
	
	# Throttled position sync
	position_sync_timer += delta
	if position_sync_timer >= POSITION_SYNC_INTERVAL:
		position_sync_timer = 0.0
		_sync_local_player_position()

## SYNC LOCAL PLAYER POSITION
func _sync_local_player_position():
	var player_node = get_local_player_node()
	if player_node:
		var pos = player_node.global_position
		_update_player_position.rpc(get_local_player_id(), pos)

## SYNC LOCAL PLAYER HEALTH
func sync_health(health: float):
	_update_player_health.rpc(get_local_player_id(), health)

## SYNC LOCAL PLAYER ANIMATION
func sync_animation(animation_name: String):
	_update_player_animation.rpc(get_local_player_id(), animation_name)

## SYNC ATTACK
func sync_attack(attack_type: String, attack_data: Dictionary = {}):
	_perform_attack.rpc(get_local_player_id(), attack_type, attack_data)

## SYNC ROUND END
func sync_round_end(winner_id: int):
	if NetworkManager.is_server():
		_end_round.rpc(winner_id)

## RPC: UPDATE PLAYER POSITION
@rpc("any_peer", "unreliable")
func _update_player_position(player_id: int, pos: Vector2):
	player_states[player_id]["position"] = pos
	position_updated.emit(player_id, pos)
	
	# Update remote player node
	var player_node = get_player_node(player_id)
	if player_node and player_id != get_local_player_id():
		# Interpolate for smooth movement
		player_node.global_position = player_node.global_position.lerp(pos, 0.3)

## RPC: UPDATE PLAYER HEALTH
@rpc("any_peer", "call_local", "reliable")
func _update_player_health(player_id: int, health: float):
	player_states[player_id]["health"] = health
	health_updated.emit(player_id, health)
	
	# Update UI
	var player_node = get_player_node(player_id)
	if player_node and player_node.has_method("set_health"):
		player_node.set_health(health)

## RPC: UPDATE PLAYER ANIMATION
@rpc("any_peer", "call_local", "reliable")
func _update_player_animation(player_id: int, animation: String):
	player_states[player_id]["animation"] = animation
	animation_changed.emit(player_id, animation)
	
	var player_node = get_player_node(player_id)
	if player_node and player_id != get_local_player_id():
		if player_node.has_node("AnimationPlayer"):
			player_node.get_node("AnimationPlayer").play(animation)

## RPC: PERFORM ATTACK
@rpc("any_peer", "call_local", "reliable")
func _perform_attack(attacker_id: int, attack_type: String, attack_data: Dictionary):
	attack_performed.emit(attacker_id, attack_type)
	
	var attacker = get_player_node(attacker_id)
	if attacker and attacker.has_method("execute_attack"):
		attacker.execute_attack(attack_type, attack_data)

## RPC: END ROUND
@rpc("authority", "call_local", "reliable")
func _end_round(winner_id: int):
	round_ended.emit(winner_id)
	
	# Update GameState
	var winner_key = "player1" if winner_id == 1 else "player2"
	GameState.record_round_winner(winner_key)

## HELPER FUNCTIONS
func get_local_player_id() -> int:
	return 1 if NetworkManager.get_peer_id() == NetworkManager.get_player_ids()[0] else 2

func get_local_player_node() -> Node:
	return get_player_node(get_local_player_id())

func get_player_node(player_id: int) -> Node:
	var game_scene = get_tree().current_scene
	if game_scene:
		var player_path = "Player" + str(player_id)
		if game_scene.has_node(player_path):
			return game_scene.get_node(player_path)
	return null

func get_opponent_id() -> int:
	return 2 if get_local_player_id() == 1 else 1

func get_player_health(player_id: int) -> float:
	return player_states[player_id].get("health", 100.0)
