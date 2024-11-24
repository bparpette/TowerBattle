# lobby.gd
extends Control

@onready var main_scene = preload("res://main.tscn")
@onready var network_manager = $NetworkManager
@onready var address_input = $VBoxContainer/AddressInput
@onready var port_input = $VBoxContainer/PortInput
@onready var status_label = $VBoxContainer/StatusLabel
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)

func _on_host_button_pressed():
	var port = int(port_input.text)
	setup_network_manager()
	if network_manager:  # Add this check
		print("Starting server on port: ", port)
		network_manager.start_server(port)
		status_label.text = "Waiting for opponent..."

func _on_join_button_pressed():
	var address = address_input.text
	var port = int(port_input.text)
	setup_network_manager()
	if network_manager:  # Add this check
		network_manager.connect_to_server(address, port)
		status_label.text = "Connecting..."

func setup_network_manager():
	# First try to get existing NetworkManager
	network_manager = $NetworkManager
	
	# If it doesn't exist, create it
	if !network_manager:
		print("Creating new NetworkManager")
		var NetworkManager = load("res://NetworkManager.gd")
		network_manager = Node.new()
		network_manager.set_script(NetworkManager)
		network_manager.name = "NetworkManager"
		add_child(network_manager)
	
	# Remove any existing connections to avoid duplicates
	if network_manager.is_connected("player_matched", _on_player_matched):
		network_manager.player_matched.disconnect(_on_player_matched)
	if network_manager.is_connected("connection_failed", _on_connection_failed):
		network_manager.connection_failed.disconnect(_on_connection_failed)
	if network_manager.is_connected("server_disconnected", _on_server_disconnected):
		network_manager.server_disconnected.disconnect(_on_server_disconnected)
	
	# Add connections
	network_manager.player_matched.connect(_on_player_matched)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_disconnected.connect(_on_server_disconnected)

func _on_player_matched(_player_id: int, is_player_one: bool):
	print("Player matched signal received in lobby")
	print("Is player one: ", is_player_one)
	
	var game_instance = main_scene.instantiate()
	
	if network_manager and network_manager.get_parent() == self:
		remove_child(network_manager)
		network_manager.name = "NetworkManager"
		game_instance.add_child(network_manager)
		
		# Ensure game state is preserved during transition
		var root = get_tree().root
		var current_scene = root.get_child(root.get_child_count() - 1)
		root.add_child(game_instance)
		current_scene.queue_free()
		
		print("Scene transition complete")
	else:
		print("NetworkManager not found or already moved!")

func _on_connection_failed():
	status_label.text = "Connection failed!"

func _on_server_disconnected():
	status_label.text = "Server disconnected!"
