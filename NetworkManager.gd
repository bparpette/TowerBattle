# NetworkManager.gd
extends Node

var peer = WebSocketMultiplayerPeer.new()
var players = {}
var my_player_id = 0
var opponent_id = 0
var game_started = false
var is_player_one = false
var sync_interval = 1.0
var sync_timer = 0.0

# Game state tracking
var game_state = {
	"p1_score": 0,
	"p2_score": 0,
	"p1_tower_height": 0.0,
	"p2_tower_height": 0.0,
	"blocks": []
}

# Signals
signal player_matched(player_id: int, is_player_one: bool)
signal opponent_placed_block(player_id: int, block_data: Dictionary)
signal opponent_shot_projectile(player_id: int, start_pos: Vector3, velocity: Vector3)
signal game_ended(winner_id: int)
signal opponent_disconnected()
signal connection_failed()
signal server_disconnected()

func _ready():
	await get_tree().create_timer(0.1).timeout
	
	if multiplayer.is_server():
		is_player_one = true
		my_player_id = 1
		
	print("NetworkManager ready, is_player_one: ", is_player_one)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta):
	if multiplayer.is_server():
		sync_timer += delta
		if sync_timer >= sync_interval:
			sync_timer = 0.0
			sync_full_state()

func start_server(port: int = 9090):
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
	
	var error = peer.create_server(port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		my_player_id = 1
		is_player_one = true
		players[1] = {"is_player_one": true}
		print("Server started on port ", port, " (P1)")
	else:
		print("Failed to start server: ", error)
		connection_failed.emit()

func connect_to_server(address: String = "localhost", port: int = 9090):
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
		
	var error = peer.create_client("ws://%s:%d" % [address, port])
	if error != OK:
		print("Failed to create client: ", error)
		connection_failed.emit()
		return
		
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int):
	print("Peer connected with ID: ", id)
	print("Current scene: ", get_tree().current_scene.name)
	print("Am I server? ", multiplayer.is_server())
	print("Player count: ", players.size())
	
	if multiplayer.is_server():
		if players.size() >= 2:
			print("Game full, rejecting connection")
			return
			
		players[id] = {"is_player_one": false}
		opponent_id = id
		print("Assigning P2 role to client")
		rpc_id(id, "player_assigned", false)
		
		if players.size() == 2:
			print("Starting game with 2 players")
			player_matched.emit(1, true)
			start_game()

func _on_connected_to_server():
	print("Connected to server!")
	my_player_id = multiplayer.get_unique_id()
	opponent_id = 1
	players[my_player_id] = {"is_player_one": false}

func _on_peer_disconnected(id: int):
	if id in players:
		print("Player ", id, " disconnected")
		players.erase(id)
		opponent_disconnected.emit()
		game_started = false
		if !multiplayer.is_server():
			peer.close()

func _on_connection_failed():
	print("Failed to connect!")
	peer.close()
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected!")
	peer.close()
	game_started = false
	server_disconnected.emit()

@rpc("authority", "reliable")
func player_assigned(is_player_one_param: bool):
	print("Player assigned with role: ", "P1" if is_player_one_param else "P2")
	is_player_one = is_player_one_param
	opponent_id = 1 if !is_player_one else multiplayer.get_remote_sender_id()
	player_matched.emit(multiplayer.get_unique_id(), is_player_one)

func start_game():
	if multiplayer.is_server():
		print("Server (P1) initiating game start")
		game_state = {
			"p1_score": 0,
			"p2_score": 0,
			"p1_tower_height": 0.0,
			"p2_tower_height": 0.0,
			"blocks": []
		}
		game_started = true
		rpc("receive_game_start")

@rpc("authority", "reliable")
func receive_game_start():
	print("Received game start signal, is_player_one: ", is_player_one)
	game_started = true

func sync_full_state():
	if !multiplayer.is_server():
		return
		
	var full_state = {
		"p1_score": game_state.p1_score,
		"p2_score": game_state.p2_score,
		"p1_tower_height": game_state.p1_tower_height,
		"p2_tower_height": game_state.p2_tower_height,
		"blocks": game_state.blocks.duplicate(true)
	}
	rpc("receive_full_state", full_state)

@rpc("authority", "reliable")
func receive_full_state(state: Dictionary):
	game_state = state.duplicate(true)
	var game_manager = get_node("/root/Main/GameManager")
	if game_manager:
		game_manager.sync_from_network_state(game_state)

@rpc("any_peer", "call_local", "reliable")
func sync_block_placement(player_id: int, block_data: Dictionary):
	if multiplayer.is_server():
		if validate_block_placement(block_data):
			update_game_state_blocks(player_id, block_data)
			rpc("sync_block_placement", player_id, block_data)
	else:
		opponent_placed_block.emit(player_id, block_data)

@rpc("any_peer", "call_local", "reliable")
func sync_projectile(player_id: int, start_pos: Vector3, velocity: Vector3):
	if multiplayer.is_server():
		if validate_projectile(start_pos, velocity):
			rpc("sync_projectile", player_id, start_pos, velocity)
	opponent_shot_projectile.emit(player_id, start_pos, velocity)

func validate_block_placement(block_data: Dictionary) -> bool:
	var pos = block_data.position
	var is_p1_block = pos.x < 0
	
	if is_p1_block:
		return pos.x >= -8 and pos.x <= -2
	else:
		return pos.x >= 17 and pos.x <= 23

func validate_projectile(start_pos: Vector3, velocity: Vector3) -> bool:
	var max_velocity = 50.0
	return velocity.length() <= max_velocity

func update_game_state_blocks(player_id: int, block_data: Dictionary):
	if !multiplayer.is_server():
		return
		
	game_state.blocks.append({
		"player_id": player_id,
		"data": block_data
	})
	
	if block_data.position.x < 0:
		game_state.p1_tower_height = max(game_state.p1_tower_height, block_data.position.y)
	else:
		game_state.p2_tower_height = max(game_state.p2_tower_height, block_data.position.y)
	
	rpc("sync_game_state", game_state)

func send_block_placement(block_data: Dictionary):
	if !game_started or !multiplayer.multiplayer_peer:
		print("Cannot send block: game not ready")
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Cannot send block: not connected")
		return
	
	rpc("sync_block_placement", my_player_id, block_data)

func send_projectile(start_pos: Vector3, velocity: Vector3):
	if !game_started or !multiplayer.multiplayer_peer:
		print("Cannot send projectile: game not ready")
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Cannot send projectile: not connected")
		return
	
	rpc("sync_projectile", my_player_id, start_pos, velocity)

func send_game_end(winner_id: int):
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("sync_game_end", winner_id)

@rpc("authority", "reliable")
func sync_game_end(winner_id: int):
	game_ended.emit(winner_id)
	game_started = false
