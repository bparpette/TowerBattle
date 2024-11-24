extends Camera3D

var initial_position: Vector3
var initial_height: float
var target_height: float = 6.0
var smooth_speed: float = 5.0
var target_x: float
var is_player_one: bool  # Ajout de la déclaration de la variable


func _ready():
	is_player_one = "P1" in name
	
	# Ensure proper initial positioning based on player
	if is_player_one:
		position = Vector3(-13, 5, -11)
		rotation_degrees = Vector3(-15, 45, 0)
	else:
		position = Vector3(28, 5, 26)
		rotation_degrees = Vector3(-15, -225, 0)
	
	initial_position = position
	initial_height = position.y

func _process(delta):
	var current_height = initial_height + target_height
	position.y = lerp(position.y, current_height, smooth_speed * delta)
	
	var look_at_pos
	if is_player_one:
		look_at_pos = Vector3(-5, target_height+3, 0)  # Regarde la tour P1
	else:
		look_at_pos = Vector3(20, target_height+3, 15)  # Regarde la tour P2
	
	look_at(look_at_pos)

func update_height(new_height: float):
	target_height = new_height
