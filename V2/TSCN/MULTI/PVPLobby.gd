extends Control

@export var default_port: int = 7777

@onready var player_name_input = $CenterContainer/VBoxContainer/PlayerNameInput
@onready var ip_input = $CenterContainer/VBoxContainer/JoinContainer/IPInput
@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/JoinContainer/JoinButton
@onready var next_button = $CenterContainer/VBoxContainer/NextButton
@onready var back_button = $CenterContainer/VBoxContainer/BackButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var player1_label = $CenterContainer/VBoxContainer/PlayersList/Player1Label
@onready var player2_label = $CenterContainer/VBoxContainer/PlayersList/Player2Label

var network_manager

func _ready():
	network_manager = get_node("/root/NetworkManager")
	
	# Connect to network signals
	network_manager.player_connected.connect(_on_player_connected)
	network_manager.player_disconnected.connect(_on_player_disconnected)
	network_manager.connection_successful.connect(_on_connection_successful)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_disconnected.connect(_on_server_disconnected)

func _on_host_button_pressed():
	var player_name = player_name_input.text
	network_manager.set_player_name(player_name)
	
	var error = network_manager.create_server(default_port)
	
	if error == OK:
		status_label.text = "Hosting on port " + str(default_port) + "... Waiting for opponent"
		status_label.modulate = Color.GREEN
		
		# Disable buttons
		host_button.disabled = true
		join_button.disabled = true
		ip_input.editable = false
		player_name_input.editable = false
		
		# Update player 1 (host)
		player1_label.text = "1. " + player_name + " (Host)"
		player1_label.modulate = Color.GREEN
		
		# Show next button for host
		next_button.visible = false  # Will show when player 2 joins
	else:
		status_label.text = "Failed to host game"
		status_label.modulate = Color.RED

func _on_join_button_pressed():
	var player_name = player_name_input.text
	var host_ip = ip_input.text
	
	network_manager.set_player_name(player_name)
	
	var error = network_manager.join_server(host_ip, default_port)
	
	if error == OK:
		status_label.text = "Connecting to " + host_ip + "..."
		status_label.modulate = Color.YELLOW
		
		# Disable buttons
		host_button.disabled = true
		join_button.disabled = true
		ip_input.editable = false
		player_name_input.editable = false
	else:
		status_label.text = "Failed to connect"
		status_label.modulate = Color.RED

func _on_next_button_pressed():
	# Only host can start
	if network_manager.is_server():
		# Check if we have 2 players
		if network_manager.players.size() >= 2:
			# Go to character select
			_goto_character_select.rpc()
		else:
			status_label.text = "Waiting for second player..."
			status_label.modulate = Color.YELLOW

@rpc("any_peer", "call_local", "reliable")
func _goto_character_select():
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_back_button_pressed():
	network_manager.disconnect_from_network()
	get_tree().change_scene_to_file("res://scenes/GameplaySelect.tscn")

func _on_player_name_input_text_changed(new_text: String):
	network_manager.set_player_name(new_text)

func _on_player_connected(peer_id: int, player_data: Dictionary):
	print("Player connected: ", player_data)
	update_players_list()
	
	status_label.text = "Player joined: " + player_data.get("name", "Unknown")
	status_label.modulate = Color.GREEN
	
	# Enable next button when we have 2 players
	if network_manager.is_server() and network_manager.players.size() >= 2:
		next_button.visible = true
		next_button.disabled = false

func _on_player_disconnected(peer_id: int):
	print("Player disconnected: ", peer_id)
	update_players_list()
	
	status_label.text = "Player disconnected"
	status_label.modulate = Color.ORANGE
	
	# Disable next button
	if network_manager.is_server():
		next_button.visible = false

func _on_connection_successful():
	status_label.text = "Connected! Waiting for host to start..."
	status_label.modulate = Color.GREEN
	update_players_list()

func _on_connection_failed():
	status_label.text = "Connection failed - check IP and port"
	status_label.modulate = Color.RED
	
	# Re-enable buttons
	host_button.disabled = false
	join_button.disabled = false
	ip_input.editable = true
	player_name_input.editable = true

func _on_server_disconnected():
	status_label.text = "Host disconnected"
	status_label.modulate = Color.RED
	
	# Re-enable buttons
	host_button.disabled = false
	join_button.disabled = false
	ip_input.editable = true
	player_name_input.editable = true
	
	# Reset player labels
	player1_label.text = "1. Waiting..."
	player1_label.modulate = Color.WHITE
	player2_label.text = "2. Waiting..."
	player2_label.modulate = Color.WHITE
	
	next_button.visible = false

func update_players_list():
	var player_ids = network_manager.get_player_ids()
	player_ids.sort()
	
	# Update player 1
	if player_ids.size() >= 1:
		var p1_data = network_manager.get_player_data(player_ids[0])
		var p1_name = p1_data.get("name", "Player 1")
		player1_label.text = "1. " + p1_name
		if network_manager.is_server() and player_ids[0] == network_manager.get_peer_id():
			player1_label.text += " (You)"
		player1_label.modulate = Color.GREEN
	else:
		player1_label.text = "1. Waiting..."
		player1_label.modulate = Color.WHITE
	
	# Update player 2
	if player_ids.size() >= 2:
		var p2_data = network_manager.get_player_data(player_ids[1])
		var p2_name = p2_data.get("name", "Player 2")
		player2_label.text = "2. " + p2_name
		if not network_manager.is_server() and player_ids[1] == network_manager.get_peer_id():
			player2_label.text += " (You)"
		player2_label.modulate = Color.GREEN
	else:
		player2_label.text = "2. Waiting..."
		player2_label.modulate = Color.WHITE
