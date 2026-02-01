extends Node

## NetworkManager.gd - The Engine for your Multiplayer

# Signals required by your UI
signal player_connected(peer_id: int, player_data: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_successful
signal connection_failed
signal server_disconnected

# Data storage
var players = {} # Dictionary to store: peer_id -> { "name": "Name" }
var local_player_name = "Player"

func _ready():
	# Connect Godot's built-in multiplayer signals to our internal logic
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_fail)
	multiplayer.server_disconnected.connect(_on_server_offline)

## --- SETTERS & GETTERS ---
func set_player_name(new_name: String):
	local_player_name = new_name if new_name != "" else "Player"

func is_server():
	return multiplayer.is_server()

func get_peer_id():
	return multiplayer.get_unique_id()

func get_player_ids():
	return players.keys()

func get_player_data(id: int):
	return players.get(id, {"name": "Unknown"})

## --- COMMANDS ---
func create_server(port: int) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# Register host immediately
		_register_player.rpc(get_peer_id(), {"name": local_player_name})
	return error

func join_server(ip: String, port: int) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error

func disconnect_from_network():
	multiplayer.multiplayer_peer = null
	players.clear()

## --- MULTIPLAYER LOGIC (RPCs) ---
@rpc("any_peer", "call_local", "reliable")
func _register_player(id: int, data: Dictionary):
	players[id] = data
	player_connected.emit(id, data)

## --- SIGNAL CALLBACKS ---
func _on_peer_connected(id: int):
	# If we are the client who just joined, send our name to everyone
	_register_player.rpc_id(id, get_peer_id(), {"name": local_player_name})

func _on_peer_disconnected(id: int):
	if players.has(id):
		players.erase(id)
		player_disconnected.emit(id)

func _on_connection_success():
	connection_successful.emit()

func _on_connection_fail():
	connection_failed.emit()

func _on_server_offline():
	players.clear()
	server_disconnected.emit()
