extends RigidBody3D

var is_moving = true
var base_speed = 5.0
var speed_multiplier = 1.0
var direction_x = 1
var direction_z = 1
var move_on_x = true
var block_size = Vector3(3, 0.5, 3)
var previous_block = null

# Au début du fichier, ajoutez ces variables
var base_color: Color  # Couleur de base du bloc
var next_color: Color  # Couleur cible pour le dégradé
static var last_base_color: Color  # Pour garder en mémoire la dernière couleur de base utilisée


func _ready():
	collision_layer = 4  # Layer for blocks
	collision_mask = 4 | 2  # Collide with other blocks and projectiles
	
	if !previous_block:  # Si c'est le bloc de base
		is_moving = false
		# Générer une première couleur aléatoire pour la base
		base_color = Color(randf(), randf(), randf())
		last_base_color = base_color
		next_color = generate_next_color(base_color)
	else:
		# Utiliser la couleur du bloc précédent comme référence
		base_color = previous_block.next_color
		next_color = generate_next_color(base_color)
	
	gravity_scale = 0.0
	freeze = true
	
	if previous_block:
		block_size = Vector3(
			previous_block.block_size.x,
			block_size.y,
			previous_block.block_size.z
		)
	
	setup_block()

func generate_next_color(current_color: Color) -> Color:
	var hue_shift = randf_range(-0.1, 0.1)  # Petit changement aléatoire de teinte
	var new_h = fposmod(current_color.h + hue_shift, 1.0)
	var new_s = clamp(current_color.s + randf_range(-0.1, 0.1), 0.5, 1.0)
	var new_v = clamp(current_color.v + randf_range(-0.1, 0.1), 0.5, 1.0)
	return Color.from_hsv(new_h, new_s, new_v)


func setup_block():
	for child in get_children():
		child.queue_free()
	
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = block_size
	mesh.mesh = box
	
	var material = StandardMaterial3D.new()
	
	# Calculer la couleur en fonction de la position verticale
	var height_factor = position.y / 20.0  # Ajustez 20.0 selon la hauteur maximale souhaitée
	material.albedo_color = base_color.lerp(next_color, height_factor)
	
	mesh.material_override = material
	add_child(mesh)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = block_size
	collision.shape = shape
	add_child(collision)

# Dans la fonction cut_block_on_axis, ajouter ceci pour le bloc qui tombe
# (dans la partie où vous créez le falling_block)
	
	

func update_color():
	if has_node("MeshInstance3D"):
		var mesh = get_node("MeshInstance3D")
		if mesh.material_override:
			var height_factor = position.y / 20.0
			mesh.material_override.albedo_color = base_color.lerp(next_color, height_factor)


func _physics_process(delta):
	if is_moving:
		var current_speed = base_speed * speed_multiplier
		if move_on_x:
			position.x += current_speed * direction_x * delta
			if position.x > 7 or position.x < -7:
				direction_x *= -1
		else:
			position.z += current_speed * direction_z * delta
			if position.z > 7 or position.z < -7:
				direction_z *= -1
		
		update_color()

func stop_moving():
	is_moving = false
	if previous_block:
		if move_on_x:
			position.z = previous_block.position.z
		else:
			position.x = previous_block.position.x
		return cut_block_on_axis('x' if move_on_x else 'z')
	freeze = true
	return true

func cut_block_on_axis(axis: String):
	var current_pos = position[axis]
	var current_size = block_size[axis]
	var prev_pos = previous_block.position[axis]
	var prev_size = previous_block.block_size[axis]
	
	var falling_speed_reduction = 0.3 # Réduction de la vitesse pour la chute
	
	var tolerance = 0.1  # Increased from 0.05
	
	var minimum_size = 0.5  # Minimum block size to prevent tiny blocks
	
	var current_start = current_pos - (current_size / 2)
	var current_end = current_pos + (current_size / 2)
	var prev_start = prev_pos - (prev_size / 2)
	var prev_end = prev_pos + (prev_size / 2)
	
	if abs(current_pos - prev_pos) < tolerance:
		if axis == 'x':
			position.x = prev_pos
		else:
			position.z = prev_pos
		return true
	
	if current_start > prev_end or current_end < prev_start:
		freeze = false
		gravity_scale = 1.0
		return false
	
	# Calculer la nouvelle taille pour le bloc principal
	var new_start = max(current_start, prev_start)
	var new_end = min(current_end, prev_end)
	var new_size = new_end - new_start
	
	if new_size < minimum_size:
		freeze = false
		gravity_scale = 1.0
		return false
	
	var new_pos = new_start + (new_size / 2)
	
	# Créer le bloc qui va tomber
	var falling_block = duplicate()
	get_parent().add_child(falling_block)
	
	# Configurer le bloc qui tombe
	falling_block.previous_block = null
	falling_block.is_moving = false
	falling_block.freeze = false
	falling_block.gravity_scale = 1.0
	falling_block.base_color = base_color
	falling_block.next_color = next_color
	
	# Calculer la taille et position exactes du bloc qui tombe
	if axis == 'x':
		if current_pos > prev_pos:
			# Le bloc dépasse à droite
			falling_block.block_size = Vector3(
				current_end - prev_end,
				block_size.y,
				block_size.z
			)
			falling_block.position = Vector3(
				prev_end + falling_block.block_size.x/2,
				position.y,
				position.z
			)
			falling_block.linear_velocity.x = base_speed * speed_multiplier * direction_x * falling_speed_reduction
		else:
			# Le bloc dépasse à gauche
			falling_block.block_size = Vector3(
				prev_start - current_start,
				block_size.y,
				block_size.z
			)
			falling_block.position = Vector3(
				prev_start - falling_block.block_size.x/2,
				position.y,
				position.z
			)
			falling_block.linear_velocity.x = base_speed * speed_multiplier * direction_x * falling_speed_reduction
	else:
		if current_pos > prev_pos:
			# Le bloc dépasse devant
			falling_block.block_size = Vector3(
				block_size.x,
				block_size.y,
				current_end - prev_end
			)
			falling_block.position = Vector3(
				position.x,
				position.y,
				prev_end + falling_block.block_size.z/2
			)
			falling_block.linear_velocity.z = base_speed * speed_multiplier * direction_z * falling_speed_reduction
		else:
			# Le bloc dépasse derrière
			falling_block.block_size = Vector3(
				block_size.x,
				block_size.y,
				prev_start - current_start
			)
			falling_block.position = Vector3(
				position.x,
				position.y,
				prev_start - falling_block.block_size.z/2
			)
			# Inverser la direction pour les blocs qui tombent derrière
			falling_block.linear_velocity.z = -base_speed * speed_multiplier * direction_z * falling_speed_reduction
	
	falling_block.setup_block()
	
	# Mettre à jour le bloc principal
	if axis == 'x':
		block_size.x = new_size
		position.x = new_pos
	else:
		block_size.z = new_size
		position.z = new_pos
	
	setup_block()
	print(position.x)
	print(position.y)
	freeze = true
	
	# Supprimer le bloc qui tombe après quelques secondes
	create_tween().tween_callback(falling_block.queue_free).set_delay(3.0)
	
	return true

func handle_impact(damage: float):
	# Reduce block size based on damage
	var size_reduction = damage * 0.01  # Adjust this multiplier as needed
	block_size *= (1.0 - size_reduction)
	
	# Minimum size check
	if block_size.x < 0.5 or block_size.z < 0.5:
		queue_free()
		return
	
	# Update the block's physical representation
	setup_block()
