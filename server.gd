# server.gd
extends Node

var players = {}

func _ready():
	var server = ENetMultiplayerPeer.new()
	server.create_server(12345, 10)  # Port 12345, max 10 players
	get_tree().multiplayer.peer = server
	print("Server started")

func _process(delta):
	if get_tree().multiplayer.has_peer():
		while get_tree().multiplayer.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			var packet = get_tree().multiplayer.peer.get_packet()
			if packet:
				handle_packet(packet)

func handle_packet(packet):
	var data = packet.get_var()
	if data.has("action"):
		match data["action"]:
			"connect":
				var player_id = packet.get_sender()
				players[player_id] = Vector3(0, 0, 0)  # Initial position
				print("Player connected: ", player_id)
			"move":
				var player_id = packet.get_sender()
				if player_id in players:
					players[player_id] += data["direction"]
					broadcast_state()

func broadcast_state():
	var state = {"players": players}
	for player_id in players.keys():
		rpc_id(player_id, "update_state", state)
