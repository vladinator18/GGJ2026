extends Node2D

## Multiplayer Network Manager
## Handles server and client connections for 2 players

# Network Settings
@export_group("Network Configuration")
@export var server_port: int = 131825
@export var server_address: String = "127.0.0.1"
@export var max_players: int = 2

# Network State
@export_group("Network State")
@export var is_server: bool = false
@export var auto_start_server: bool = false
@export var auto_connect_client: bool = false

# UI References
@export_group("UI Elements")
@export var status_label: Label
@export var host_button: Button
@export var join_button: Button
@export var disconnect_button: Button
@export var ip_input: LineEdit
@export var player_list_label: Label

# Game References
@export_group("Game Setup")
@export_file("*.tscn") var game_scene_path: String
@export var spawn_point_1: Node2D
@export var spawn_point_2: Node2D

# Multiplayer peer
var peer: ENetMultiplayerPeer
var connected_players: Dictionary = {}
var player_count: int = 0

# Signals
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_started()
signal client_connected()
signal connection_failed()

func _ready():
	_setup_ui()
	_connect_network_signals()
	
	if auto_start_server:
		create_server()
	elif auto_connect_client:
		join_server()

func _setup_ui():
	# Connect UI buttons
	if host_button:
		host_button.pressed.connect(create_server)
	
	if join_button:
		join_button.pressed.connect(join_server)
	
	if disconnect_button:
		disconnect_button.pressed.connect(disconnect_from_network)
		disconnect_button.disabled = true
	
	if ip_input and server_address:
		ip_input.text = server_address
	
	_update_status("Ready to connect")

func _connect_network_signals():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ========== SERVER FUNCTIONS ==========

func create_server():
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(server_port, max_players)
	
	if result != OK:
		_update_status("Failed to create server on port %d" % server_port)
		push_error("Failed to create server: " + str(result))
		return
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	
	# Add server host as player 1
	connected_players[1] = {
		"peer_id": 1,
		"player_number": 1,
		"is_ready": false
	}
	player_count = 1
	
	_update_status("Server started on port %d" % server_port)
	_update_player_list()
	_toggle_ui(false)
	
	print("Server created successfully on port %d" % server_port)
	server_started.emit()

# ========== CLIENT FUNCTIONS ==========

func join_server():
	var address = server_address
	if ip_input:
		address = ip_input.text
	
	peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(address, server_port)
	
	if result != OK:
		_update_status("Failed to connect to %s:%d" % [address, server_port])
		push_error("Failed to create client: " + str(result))
		return
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	
	_update_status("Connecting to %s:%d..." % [address, server_port])
	_toggle_ui(false)
	
	print("Attempting to connect to server at %s:%d" % [address, server_port])

# ========== NETWORK CALLBACKS ==========

func _on_peer_connected(id: int):
	print("Peer connected: " + str(id))
	
	if is_server:
		player_count += 1
		
		connected_players[id] = {
			"peer_id": id,
			"player_number": player_count,
			"is_ready": false
		}
		
		_update_status("Player %d connected" % player_count)
		_update_player_list()
		
		# Notify client of their player number
		rpc_id(id, "receive_player_number", player_count)
		
		# Start game if we have 2 players
		if player_count >= max_players:
			_start_game()
	
	player_connected.emit(id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: " + str(id))
	
	if connected_players.has(id):
		var player_num = connected_players[id]["player_number"]
		connected_players.erase(id)
		player_count -= 1
		
		_update_status("Player %d disconnected" % player_num)
		_update_player_list()
	
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Successfully connected to server")
	_update_status("Connected to server!")
	client_connected.emit()

func _on_connection_failed():
	print("Connection failed")
	_update_status("Connection failed!")
	_toggle_ui(true)
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected")
	_update_status("Server disconnected")
	disconnect_from_network()

# ========== RPC FUNCTIONS ==========

@rpc("authority", "call_remote", "reliable")
func receive_player_number(player_num: int):
	print("Assigned as Player %d" % player_num)
	_update_status("You are Player %d" % player_num)

@rpc("authority", "call_local", "reliable")
func start_multiplayer_game():
	print("Starting multiplayer game...")
	
	if game_scene_path != "":
		get_tree().change_scene_to_file(game_scene_path)
	else:
		_update_status("Game started!")

@rpc("any_peer", "call_local", "reliable")
func sync_player_position(player_id: int, pos: Vector2):
	# Override in game scene to sync player positions
	pass

@rpc("any_peer", "call_local", "reliable")
func sync_player_action(player_id: int, action: String, data: Dictionary):
	# Override in game scene to sync player actions (attacks, etc.)
	pass

# ========== GAME START ==========

func _start_game():
	if not is_server:
		return
	
	_update_status("Starting game...")
	
	# Wait a moment before starting
	await get_tree().create_timer(1.0).timeout
	
	# Tell all clients to start the game
	rpc("start_multiplayer_game")

# ========== DISCONNECT ==========

func disconnect_from_network():
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	player_count = 0
	is_server = false
	
	_update_status("Disconnected")
	_toggle_ui(true)
	
	print("Disconnected from network")

# ========== UI HELPERS ==========

func _update_status(message: String):
	if status_label:
		status_label.text = message
	print("Status: " + message)

func _update_player_list():
	if not player_list_label:
		return
	
	var text = "Players Connected: %d/%d\n" % [player_count, max_players]
	
	for player_data in connected_players.values():
		text += "Player %d (ID: %d)\n" % [player_data["player_number"], player_data["peer_id"]]
	
	player_list_label.text = text

func _toggle_ui(enabled: bool):
	if host_button:
		host_button.disabled = not enabled
	if join_button:
		join_button.disabled = not enabled
	if disconnect_button:
		disconnect_button.disabled = enabled
	if ip_input:
		ip_input.editable = enabled

# ========== PUBLIC API ==========

func get_player_number() -> int:
	var my_id = multiplayer.get_unique_id()
	
	if connected_players.has(my_id):
		return connected_players[my_id]["player_number"]
	
	return 0

func is_player_host() -> bool:
	return multiplayer.is_server()

func get_connected_player_count() -> int:
	return player_count

# ========== HELPER FUNCTIONS ==========

func spawn_player(player_id: int, player_scene: PackedScene):
	if not is_server:
		return
	
	var player_instance = player_scene.instantiate()
	
	# Get player number
	var player_num = connected_players[player_id]["player_number"]
	
	# Set spawn position
	if player_num == 1 and spawn_point_1:
		player_instance.position = spawn_point_1.position
	elif player_num == 2 and spawn_point_2:
		player_instance.position = spawn_point_2.position
	
	player_instance.name = "Player" + str(player_num)
	player_instance.set_multiplayer_authority(player_id)
	
	add_child(player_instance)
	
	return player_instance
