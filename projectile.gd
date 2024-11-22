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
	print("aaaa")
	if body is RigidBody3D and body.is_in_group("blocks"):
		print("IMPACTE")
		queue_free()  # On détruit le projectile après impact

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
