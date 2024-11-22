extends RigidBody3D

var launch_force = 20.0
var damage = 10.0
var trajectory_points = []  # Pour stocker les points de la trajectoire
var initial_velocity = Vector3.ZERO

func _ready():
	collision_layer = 2
	collision_mask = 1 | 4

func launch(initial_velocity: Vector3):
	self.initial_velocity = initial_velocity
	linear_velocity = initial_velocity
	

# Fonction pour calculer la trajectoire
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
