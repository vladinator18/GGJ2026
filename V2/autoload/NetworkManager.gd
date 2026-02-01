extends Node

## NetworkManager - AutoLoad Singleton for Multiplayer
## Path: res://autoload/NetworkManager.gd

# Signals
signal player_connected(peer_id: int, player_data: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_successful()
signal connection_failed()
signal server_disconnected()
signal game_started()
signal lobby_updated()
signal error_occurred(message: String)

# Network configuration
@export var default_port: int = 7777
@export var max_players: int = 2
@export var max_connection_attempts: int = 3
@export var connection_timeout: float = 10.0

# Player data storage
var players: Dictionary = {}  # peer_id -> player_data
var local_player_data: Dictionary = {
	"name": "Player",
	"character": "",
	"ready": false,
	"connected_at": 0
}

# Network state
var is_host: bool = false
var peer: ENetMultiplayerPeer = null
var connection_attempt: int = 0

# Connection tracking
var server_address: String = ""
var server_port: int = 7777

func _ready():
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("[NetworkManager] Ready and waiting for connections")

## --- Connection Methods ---

func create_server(port: int = -1) -> int:
	"""Create a server/host"""
	if port == -1: 
		port = default_port
	
	if peer:
		push_warning("[NetworkManager] Already connected to a network")
		return ERR_ALREADY_EXISTS
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	
	if error != OK:
		push_error("[NetworkManager] Failed to create server: " + str(error))
		peer = null
		error_occurred.emit("Failed to create server: " + str(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	server_port = port
	
	# Add host to players list immediately
	var host_id = multiplayer.get_unique_id()
	local_player_data["connected_at"] = Time.get_ticks_msec()
	players[host_id] = local_player_data.duplicate()
	
	print("[NetworkManager] Server created on port ", port, " | Host ID: ", host_id)
	lobby_updated.emit()
	return OK

func join_server(address: String, port: int = -1) -> int:
	"""Join a server as a client"""
	if port == -1: 
		port = default_port
	
	if peer:
		push_warning("[NetworkManager] Already connected to a network")
		return ERR_ALREADY_EXISTS
	
	# Validate address
	if address.is_empty() or address == "":
		error_occurred.emit("Invalid server address")
		return ERR_INVALID_PARAMETER
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error != OK:
		push_error("[NetworkManager] Failed to join server: " + str(error))
		peer = null
		error_occurred.emit("Failed to connect to server")
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	server_address = address
	server_port = port
	connection_attempt += 1
	
	print("[NetworkManager] Attempting to connect to ", address, ":", port, " (Attempt ", connection_attempt, ")")
	
	# Start connection timeout
	get_tree().create_timer(connection_timeout).timeout.connect(_on_connection_timeout)
	
	return OK

func disconnect_from_network():
	"""Disconnect from current network"""
	if peer:
		# Notify others if we're leaving gracefully
		if multiplayer.has_multiplayer_peer():
			_notify_disconnect.rpc()
		
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	
	players.clear()
	is_host = false
	connection_attempt = 0
	server_address = ""
	
	print("[NetworkManager] Disconnected from network")

func _on_connection_timeout():
	"""Handle connection timeout"""
	if not multiplayer.has_multiplayer_peer() or players.is_empty():
		if connection_attempt < max_connection_attempts:
			print("[NetworkManager] Connection timeout, retrying...")
			disconnect_from_network()
			join_server(server_address, server_port)
		else:
			print("[NetworkManager] Connection timeout, max attempts reached")
			disconnect_from_network()
			connection_failed.emit()
			error_occurred.emit("Connection timeout")

## --- Player Data & State Management ---

func set_player_name(player_name: String):
	"""Set local player name and sync to network"""
	local_player_data["name"] = player_name
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)
		lobby_updated.emit()

func set_player_character(character_name: String):
	"""Set local player character and sync to network"""
	local_player_data["character"] = character_name
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)
		lobby_updated.emit()

func set_ready(ready: bool):
	"""Set local player ready state and sync to network"""
	local_player_data["ready"] = ready
	if multiplayer.has_multiplayer_peer():
		_update_player_data.rpc(multiplayer.get_unique_id(), local_player_data)
		lobby_updated.emit()

func all_players_ready() -> bool:
	"""Check if all players are ready to start"""
	if players.size() < max_players: 
		return false
	
	for player_data in players.values():
		if not player_data.get("ready", false): 
			return false
	
	return true

func get_lobby_info() -> Dictionary:
	"""Get formatted lobby information"""
	var info = {
		"player_count": players.size(),
		"max_players": max_players,
		"is_full": players.size() >= max_players,
		"all_ready": all_players_ready(),
		"players": []
	}
	
	for peer_id in players.keys():
		var pdata = players[peer_id]
		info["players"].append({
			"peer_id": peer_id,
			"name": pdata.get("name", "Unknown"),
			"character": pdata.get("character", ""),
			"ready": pdata.get("ready", false),
			"is_host": peer_id == 1
		})
	
	return info

func start_game():
	"""Start the game (host only)"""
	if not is_host:
		push_warning("[NetworkManager] Only host can start the game")
		return
	
	if not all_players_ready():
		push_warning("[NetworkManager] Cannot start - not all players ready")
		error_occurred.emit("Not all players are ready")
		return
	
	print("[NetworkManager] Host starting game...")
	_start_game_rpc.rpc()

## --- RPCs ---

@rpc("any_peer", "reliable")
func _register_player(peer_id: int, player_data: Dictionary):
	"""Register a new player in the lobby"""
	players[peer_id] = player_data
	player_connected.emit(peer_id, player_data)
	lobby_updated.emit()
	print("[NetworkManager] Registered: ", peer_id, " -> ", player_data)
	
	# Two-way Handshake: Server sends its data back to newly connected client
	if multiplayer.is_server() and peer_id != 1:
		_register_player.rpc_id(peer_id, 1, local_player_data)
		
		# Send existing players to the new client
		for existing_id in players.keys():
			if existing_id != peer_id and existing_id != 1:
				_register_player.rpc_id(peer_id, existing_id, players[existing_id])

@rpc("any_peer", "reliable")
func _update_player_data(peer_id: int, player_data: Dictionary):
	"""Update existing player data"""
	if players.has(peer_id):
		players[peer_id].merge(player_data)
	else:
		players[peer_id] = player_data
	
	player_connected.emit(peer_id, player_data)
	lobby_updated.emit()
	print("[NetworkManager] Data updated: ", peer_id, " -> ", player_data)

@rpc("any_peer", "call_local", "reliable")
func _start_game_rpc():
	"""RPC to start the game on all clients"""
	game_started.emit()
	print("[NetworkManager] Game starting!")

@rpc("any_peer", "reliable")
func _notify_disconnect():
	"""Notify others that this peer is disconnecting"""
	print("[NetworkManager] Peer notified disconnect: ", multiplayer.get_remote_sender_id())

## --- Signal Callbacks ---

func _on_peer_connected(id: int):
	"""Called when a peer connects to the server"""
	print("[NetworkManager] Peer connected: ", id)
	
	# Send our data to the newly connected peer
	_register_player.rpc_id(id, multiplayer.get_unique_id(), local_player_data)

func _on_peer_disconnected(id: int):
	"""Called when a peer disconnects"""
	print("[NetworkManager] Peer disconnected: ", id)
	
	if players.has(id):
		players.erase(id)
		player_disconnected.emit(id)
		lobby_updated.emit()
	
	# If we're the host and a player left, we might want to handle this
	if is_host and players.size() < max_players:
		print("[NetworkManager] Player slot available")

func _on_connected_to_server():
	"""Called when successfully connected to server as client"""
	print("[NetworkManager] Successfully connected to server!")
	connection_attempt = 0
	local_player_data["connected_at"] = Time.get_ticks_msec()
	connection_successful.emit()

func _on_connection_failed():
	"""Called when connection to server fails"""
	print("[NetworkManager] Connection failed!")
	
	if connection_attempt < max_connection_attempts:
		print("[NetworkManager] Retrying connection... (", connection_attempt, "/", max_connection_attempts, ")")
		get_tree().create_timer(2.0).timeout.connect(func(): join_server(server_address, server_port))
	else:
		disconnect_from_network()
		connection_failed.emit()
		error_occurred.emit("Failed to connect after " + str(max_connection_attempts) + " attempts")

func _on_server_disconnected():
	"""Called when disconnected from server"""
	print("[NetworkManager] Server disconnected!")
	disconnect_from_network()
	server_disconnected.emit()
	error_occurred.emit("Disconnected from server")

## --- Getters ---

func get_player_data(peer_id: int) -> Dictionary:
	"""Get player data for a specific peer"""
	return players.get(peer_id, {})

func get_player_ids() -> Array:
	"""Get all connected player IDs"""
	return players.keys()

func is_server() -> bool:
	"""Check if this instance is the server"""
	return multiplayer.is_server()

func get_peer_id() -> int:
	"""Get this instance's peer ID"""
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0

func is_network_connected() -> bool:
	"""Check if connected to a network"""
	return multiplayer.has_multiplayer_peer()

func get_player_count() -> int:
	"""Get number of connected players"""
	return players.size()

## --- Debug Methods ---

func print_network_state():
	"""Debug: Print current network state"""
	print("=== NetworkManager Debug ===")
	print("Is Host: ", is_host)
	print("Peer ID: ", get_peer_id())
	print("Connected: ", is_network_connected())
	print("Players: ", players.size(), "/", max_players)
	for peer_id in players.keys():
		var pdata = players[peer_id]
		print("  - ", peer_id, ": ", pdata.get("name"), " | Character: ", pdata.get("character"), " | Ready: ", pdata.get("ready"))
	print("============================")
