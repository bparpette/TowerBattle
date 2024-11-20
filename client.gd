# client.gd
extends Node

var player_position = Vector3()

func _ready():
	var client = ENetMultiplayerPeer.new()
	client.create_client("127.0.0.1", 12345)  # Connect to server at localhost
	get_tree().multiplayer.peer = client
	print("Client connected")
	rpc("connect")

func _process(delta):
	if Input.is_action_pressed("ui_right"):
		rpc("move", {"direction": Vector3(1, 0, 0)})
	elif Input.is_action_pressed("ui_left"):
		rpc("move", {"direction": Vector3(-1, 0, 0)})

@remote
func update_state(state):
	if state.has("players"):
		player_position = state["players"][get_tree().get_multiplayer().get_unique_id()]
		print("Player position: ", player_position)
 
