extends Control

@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var player_name_input = $CenterContainer/VBoxContainer/PlayerNameInput
@onready var ip_input = $CenterContainer/VBoxContainer/JoinContainer/IPInput

func _ready():
	# Link to the NetworkManager signals
	NetworkManager.connection_successful.connect(_on_connection_successful)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_button_pressed():
	NetworkManager.set_player_name(player_name_input.text)
	var err = NetworkManager.create_server()
	if err == OK:
		status_label.text = "Hosting... Waiting for opponent."
		# Change to Lobby or Character Select
		get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")

func _on_join_button_pressed():
	NetworkManager.set_player_name(player_name_input.text)
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var err = NetworkManager.join_server(ip)
	if err == OK:
		status_label.text = "Connecting..."

func _on_connection_successful():
	status_label.text = "Connected!"
	get_tree().change_scene_to_file("res://autoload/Scene/PVPLobby.tscn")

func _on_connection_failed():
	status_label.text = "Connection failed."

func _on_server_disconnected():
	status_label.text = "Server went offline."
