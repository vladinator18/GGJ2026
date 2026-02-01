extends Node

## NetworkManager - AutoLoad Singleton for Multiplayer
## Add this to Project > Project Settings > Globals > AutoLoad
## Path: res://autoload/NetworkManager.gd
## Node Name: NetworkManager

# Signals
signal player_connected(peer_id: int, player_data: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_successful()
signal connection_failed()
signal server_disconnected()
signal game_started()

# Network configuration
@export var default_port: int = 7777
@export var max_players: int = 2

# Player data storage
var players: Dictionary = {}  # peer_id -> player_data
var local_player_data: Dictionary = {
	"name": "Player",
	"character": "",
	"ready": false
}

# Network state
var is_host: bool = false
var peer: ENetMultiplayerPeer = null

func _ready():
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("[NetworkManager] Ready and waiting for connections")

## Create server (host)
func create_server(port: int = -1) -> int:
	if port == -1:
		port = default_port
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	
	if error != OK:
		push_error("[NetworkManager] Failed to create server: " + str(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	# Add host to players list
	var host_id = multiplayer.get_unique_id()
	players[host_id] = local_player_data.duplicate()
	
	print("[NetworkManager] Server created on port ", port)
	print("[NetworkManager] Host ID: ", host_id)
	
	return OK

## Join server (client)
func join_server(address: String, port: int = -1) -> int:
	if port == -1:
		port = default_port
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error != OK:
		push_error("[NetworkManager] Failed to join server: " + str(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	print("[NetworkManager] Attempting to connect to ", address, ":", port)
	
	return OK

## Disconnect from network
func disconnect_from_network():
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	
	players.clear()
	is_host = false
	
	print("[NetworkManager] Disconnected from network")

## Update local player data
func set_player_name(player_name: String):
	local_player_data["name"] = player_name
	
	# If already connected, sync to network
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)

## Set character selection
func set_player_character(character_name: String):
	local_player_data["character"] = character_name
	
	# If already connected, sync to network
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)

## Set ready state
func set_ready(ready: bool):
	local_player_data["ready"] = ready
	
	# Sync to network
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)

## Check if all players are ready
func all_players_ready() -> bool:
	if players.size() < max_players:
		return false
	
	for player_data in players.values():
		if not player_data.get("ready", false):
			return false
	
	return true

## Get player data by peer ID
func get_player_data(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

## Get all player IDs
func get_player_ids() -> Array:
	return players.keys()

## Check if we're the server
func is_server() -> bool:
	return multiplayer.is_server()

## Get our peer ID
func get_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 0

## Start the game (host only)
func start_game():
	if not is_server():
		push_error("[NetworkManager] Only the host can start the game")
		return
	
	if not all_players_ready():
		push_error("[NetworkManager] Not all players are ready")
		return
	
	# Tell all clients to start
	_start_game_rpc.rpc()

## RPC: Update player data across network
@rpc("any_peer", "reliable")
func _update_player_data(peer_id: int, player_data: Dictionary):
	players[peer_id] = player_data
	player_connected.emit(peer_id, player_data)
	print("[NetworkManager] Player data updated: ", peer_id, " -> ", player_data)

## RPC: Register new player
@rpc("any_peer", "reliable")
func _register_player(peer_id: int, player_data: Dictionary):
	players[peer_id] = player_data
	player_connected.emit(peer_id, player_data)
	
	print("[NetworkManager] Player registered: ", peer_id, " -> ", player_data)
	
	# If we're the server, send all existing players to the new client
	if is_server():
		for existing_peer_id in players:
			_register_player.rpc_id(peer_id, existing_peer_id, players[existing_peer_id])

## RPC: Start the game
@rpc("any_peer", "call_local", "reliable")
func _start_game_rpc():
	game_started.emit()
	print("[NetworkManager] Game starting!")

## Signal callbacks
func _on_peer_connected(id: int):
	print("[NetworkManager] Peer connected: ", id)
	
	# Send our data to the new peer
	if is_server():
		_register_player.rpc_id(id, multiplayer.get_unique_id(), local_player_data)

func _on_peer_disconnected(id: int):
	print("[NetworkManager] Peer disconnected: ", id)
	
	if players.has(id):
		players.erase(id)
		player_disconnected.emit(id)

func _on_connected_to_server():
	print("[NetworkManager] Successfully connected to server")
	
	# Register ourselves with the server
	var my_id = multiplayer.get_unique_id()
	_register_player.rpc_id(1, my_id, local_player_data)
	
	connection_successful.emit()

func _on_connection_failed():
	print("[NetworkManager] Connection failed")
	
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	
	connection_failed.emit()

func _on_server_disconnected():
	print("[NetworkManager] Server disconnected")
	
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	
	players.clear()
	is_host = false
	
	server_disconnected.emit()
