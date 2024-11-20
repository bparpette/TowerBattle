# Projectile.gd
extends RigidBody3D

var launch_force = 20.0
var damage = 10.0

func _ready():
	# Set up collision layer and mask for projectile
	collision_layer = 2  # Layer 2 for projectiles
	collision_mask = 1 | 4  # Layer 1 (environment) and 4 (blocks)

func launch(direction: Vector3):
	apply_central_impulse(direction * launch_force)

func _on_body_entered(body):
	if body.has_method("handle_impact"):
		body.handle_impact(damage)
	queue_free()  # Destroy projectile on impact
