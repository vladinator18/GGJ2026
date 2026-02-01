extends Node

signal player_connected(peer_id: int, player_data: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_successful
signal connection_failed
signal server_disconnected

var players = {} 
var local_player_name = "Player"

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_fail)
	multiplayer.server_disconnected.connect(_on_server_offline)

func set_player_name(new_name: String):
	local_player_name = new_name if new_name != "" else "Player"

func create_server(port: int = 7777) -> int:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		players[multiplayer.get_unique_id()] = {"name": local_player_name}
		player_connected.emit(multiplayer.get_unique_id(), players[multiplayer.get_unique_id()])
	return error

func join_server(ip: String, port: int = 7777) -> int:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error

func disconnect_from_network():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()

@rpc("any_peer", "reliable")
func _register_player(data: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	players[id] = data
	player_connected.emit(id, data)

func _on_peer_connected(id: int):
	_register_player.rpc({"name": local_player_name})

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
