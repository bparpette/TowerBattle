extends RigidBody3D

var launch_force = 20.0
var damage = 10.0
var trajectory_points = []  # Pour stocker les points de la trajectoire
var initial_velocity = Vector3.ZERO

func _ready():
	collision_layer = 2
	collision_mask = 4  # On simplifie pour ne détecter que les blocks
	print;;("INIT")

func launch(initial_velocity: Vector3):
	self.initial_velocity = initial_velocity
	linear_velocity = initial_velocity

func _physics_process(_delta):
	for body in get_colliding_bodies():
		print("Collision with: ", body.name)
		if body.is_in_group("blocks"):
			print("C'est un block!")
			_on_body_entered(body)


func _on_body_entered(body):
	print("Projectile collision detected")
	if body is RigidBody3D and body.is_in_group("blocks"):
		print("Hit a block!")
		
		# Trouver le game manager pour accéder au bloc en mouvement
		var game_manager = get_node("/root/Main/GameManager")
		var reduction_factor = 0.05  # 5% de réduction
		
		# Déterminer si on touche la tour P1 ou P2
		var is_p1_tower = body.position.x < 0
		var current_moving_block = game_manager.current_block_p1 if is_p1_tower else game_manager.current_block_p2
		var base_block = game_manager.last_block_p1 if is_p1_tower else game_manager.last_block_p2
		
		print("Reducing entire tower size, including moving block")
		
		# Réduire la taille du bloc en mouvement
		if current_moving_block:
			print("Reducing moving block size")
			current_moving_block.reduce_size(reduction_factor)
			
		# Réduire la taille de tous les blocs de la tour
		var current_block = base_block
		while current_block != null:
			print("Reducing block at height: ", current_block.position.y)
			current_block.reduce_size(reduction_factor)
			current_block = current_block.previous_block
		
		print("Finished reducing block sizes")
		queue_free()  # Détruire le projectile après impact

func calculate_trajectory(steps: int = 50, time_step: float = 0.1) -> Array:
	var points = []
	var pos = position
	var vel = initial_velocity
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * Vector3.DOWN
	
	for i in range(steps):
		points.append(pos)
		vel += gravity * time_step
		pos += vel * time_step
		
	return points
