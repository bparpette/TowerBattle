extends RigidBody3D

var is_moving = true
var base_speed = 5.0
var speed_multiplier = 1.0
var direction_x = 1
var direction_z = 1
var move_on_x = true
var block_size = Vector3(3, 0.5, 3)
var previous_block = null

var base_color: Color
var next_color: Color
static var last_base_color: Color

# Ajout de ces variables pour gérer les limites de mouvement
var movement_bounds = Vector2()  # x: min, y: max
 

func _ready():
	add_to_group("blocks")

	collision_layer = 4
	collision_mask = 4 | 2
	
	# Définir les limites de mouvement en fonction de la position initiale
	if previous_block:
		if previous_block.position.x < 0:  # Player 1
			movement_bounds = Vector2(-8, -2)  # Limites pour P1
		else:  # Player 2
			movement_bounds = Vector2(17, 23)  # Limites pour P2
	
	if !previous_block:
		is_moving = false
		base_color = Color(randf(), randf(), randf())
		last_base_color = base_color
		next_color = generate_next_color(base_color)
	else:
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
	# Supprimer les enfants existants
	for child in get_children():
		child.queue_free()
	
	# Créer le nouveau mesh
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = block_size  # S'assurer que la nouvelle taille est appliquée
	mesh.mesh = box
	
	# Matériau
	var material = StandardMaterial3D.new()
	var height_factor = position.y / 20.0
	material.albedo_color = base_color.lerp(next_color, height_factor)
	mesh.material_override = material
	add_child(mesh)
	
	# Mettre à jour la collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = block_size  # S'assurer que la nouvelle taille est appliquée
	collision.shape = shape
	add_child(collision)
	
	#print("Block setup avec taille: ", block_size)  # Debug

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
			# Pour le joueur 1 (gauche)
			if position.x < 0:
				position.x += current_speed * direction_x * delta
				if position.x > -2:  
					direction_x = -1
				elif position.x < -8:
					direction_x = 1
			# Pour le joueur 2 (droite)
			else:
				position.x += current_speed * direction_x * delta
				if position.x > 23:
					direction_x = -1
				elif position.x < 17:
					direction_x = 1
		else:
			# Pour le joueur 1 (gauche)
			if position.x < 0:
				position.z += current_speed * direction_z * delta
				if position.z > 3:
					direction_z = -1
				elif position.z < -3:
					direction_z = 1
			# Pour le joueur 2 (droite)
			else:
				position.z += current_speed * direction_z * delta
				if position.z > 18:
					direction_z = -1
				elif position.z < 12:
					direction_z = 1
					
		update_color()

func stop_moving():
	is_moving = false
	if previous_block:
		if move_on_x:
			position.z = previous_block.position.z
		else:
			position.x = previous_block.position.x
		var success = cut_block_on_axis('x' if move_on_x else 'z')
		
		# Notifier le GameManager de la mise à jour de hauteur
		var game_manager = get_node("/root/Main/GameManager")
		if game_manager:
			game_manager.recalculate_tower_height(position.x < 0)
		
		return success
	
	freeze = true
	return true

func cut_block_on_axis(axis: String):
	var current_pos = position[axis]
	var current_size = block_size[axis]
	var prev_pos = previous_block.position[axis]
	var prev_size = previous_block.block_size[axis]
	
	var falling_speed_reduction = 0.3 # Réduction de la vitesse pour la chute
	
	var tolerance = 0.1  # Increased from 0.05
	
	var minimum_size = 0  # Minimum block size to prevent tiny blocks
	
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
	#print(position.x)
	#print(position.y)
	freeze = true
	
	# Supprimer le bloc qui tombe après quelques secondes
	create_tween().tween_callback(falling_block.queue_free).set_delay(3.0)
	
	return true

# func handle_impact(damage: float):
# 	print("handle_impact appelé avec dommage: ", damage)
	
# 	# Réduire la taille du bloc touché de manière plus significative
# 	var height_reduction = damage * 0.5  # 50% de l'effet du dégât
# 	print("Réduction de hauteur: ", height_reduction)
	
# 	# Sauvegarder l'ancienne taille pour le debug
# 	var old_size = block_size.y
	
# 	# Réduire la taille avec une réduction minimum plus importante
# 	block_size.y = max(block_size.y - height_reduction, 0.2)
	
# 	print("Taille avant: ", old_size)
# 	print("Nouvelle taille: ", block_size.y)
	
# 	# Ajuster la position verticale pour maintenir la connexion avec les autres blocs
# 	position.y -= height_reduction / 2
	
# 	# Si le bloc est trop petit, le supprimer
# 	if block_size.y < 0.2:
# 		queue_free()
# 		return
	
# 	# Recréer la forme physique du bloc
# 	setup_block()
	
# 	# Notifier le GameManager
# 	if get_parent() and get_parent().has_method("recalculate_tower_height"):
# 		var is_p1_tower = position.x < 0
# 		get_parent().recalculate_tower_height(is_p1_tower)

# Dans Blocks.gd, modifie la fonction handle_impact:

func handle_impact(damage: float):
	print("\n=== IMPACT DETECTED ===")
	print("Block position:", position)
	
	# Identifier si c'est la tour P1 ou P2 basé sur la position X
	var is_p1_tower = position.x < 0
	print("Tower hit:", "P1" if is_p1_tower else "P2")
	
	# Récupérer tous les blocs de la même tour
	var parent = get_parent()
	if parent:
		var blocks_affected = 0
		print("Original block size:", block_size)
		
		for block in parent.get_children():
			if block is RigidBody3D and block.has_method("reduce_size"):
				# Vérifier si le bloc appartient à la même tour
				var block_is_p1 = block.position.x < 0
				if block_is_p1 == is_p1_tower:
					print("Reducing block at position:", block.position)
					block.reduce_size(0.7)  # Réduire de 30%
					blocks_affected += 1
		
		print("Total blocks affected:", blocks_affected)
		# Notifier le GameManager pour recalculer la hauteur
		parent.recalculate_tower_height(is_p1_tower)
		print("=== IMPACT PROCESSING COMPLETE ===\n")

# Modifier la fonction reduce_size dans Blocks.gd
func reduce_size(scale_factor: float):
	print("\n--- Reducing block size ---")
	print("Before reduction:")
	print("Position:", position)
	print("Current size:", block_size)
	
	# Réduire la taille en X et Z
	var old_size = block_size
	block_size.x *= scale_factor
	block_size.z *= scale_factor
	
	print("After reduction:")
	print("New size:", block_size)
	print("Reduction factor:", scale_factor)
	
	# Vérifier la taille minimum
	var min_size = 0.5
	if block_size.x < min_size || block_size.z < min_size:
		print("Block too small, destroying!")
		queue_free()
		return
	
	# Recréer le bloc avec la nouvelle taille
	setup_block()
	
	# Ajuster la position pour maintenir l'alignement
	var old_pos = position
	if position.x < 0:  # P1
		position.x = -5
		position.z = 0
	else:  # P2
		position.x = 20
		position.z = 15
	
	print("Position adjusted from", old_pos, "to", position)
	print("--- Size reduction complete ---\n")
