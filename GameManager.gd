extends Node3D

var Block = preload("res://Block.tscn")
var Projectile = preload("res://Projectile.tscn")
@onready var camera_p1 = $"../ViewportLayout/SubViewportContainer1/SubViewport1/CameraP1"
@onready var camera_p2 = $"../ViewportLayout/SubViewportContainer2/SubViewport2/CameraP2"
@onready var ui_p1 = $"../ViewportLayout/SubViewportContainer1/ControlP1"
@onready var ui_p2 = $"../ViewportLayout/SubViewportContainer2/ControlP2"

@onready var winner_label = $"../WinnerLabel"

# Original variables
var can_spawn_p1 = true
var can_spawn_p2 = true
var alternate_movement_p1 = true
var alternate_movement_p2 = true
var score_p1 = 0
var score_p2 = 0
var speed_increase_per_block = 0.1
var current_speed_multiplier_p1 = 1.0
var current_speed_multiplier_p2 = 1.0
var game_active = true

var target_score = 20  # Hauteur objectif en unités (ajuste selon tes besoins)
var winner = 0  # 0 = pas de gagnant, 1 = joueur 1, 2 = joueur 2

# Ajouter ces variables
var p1_alive = true
var p2_alive = true
var game_ended = false

# Variables de puissance de tir
var charging_power_p1 = false
var charging_power_p2 = false
var current_power_p1 = 0.0
var current_power_p2 = 0.0
var min_power = 10.0
var max_power = 50.0
var power_increase_rate = 30.0  # Vitesse d'augmentation de la puissance
# Dans les variables au début
var trajectory_line_p1: Node3D
var trajectory_line_p2: Node3D

# PvP-specific variables
var current_block_p1 = null
var current_block_p2 = null
var last_block_p1 = null
var last_block_p2 = null
var stack_height_p1 = 0.0
var stack_height_p2 = 0.0

# Projectile variables
var projectile_timer_p1: Timer
var projectile_timer_p2: Timer
var can_shoot_p1 = false
var can_shoot_p2 = false

# Variables pour l'oscillation de la trajectoire
var oscillation_speed = 1.0  # Vitesse d'oscillation
var min_angle = PI/6  # Angle minimum (30 degrés)
var max_angle = PI/2.5  # Environ 72 degrés
var current_angle_p1 = 0.0
var current_angle_p2 = 0.0
var oscillation_direction_p1 = 1.0  # 1.0 pour monter, -1.0 pour descendre
var oscillation_direction_p2 = 1.0
const BASE_POWER = 13.0  # Puissance de base

# Add at the top with other variables
var cleanup_height = -10.0  # Height at which blocks are deleted

func _ready():
	setup_projectile_timers()
	if winner_label:
		winner_label.hide()
	await get_tree().create_timer(0.1).timeout
	reset_game()
	setup_trajectory_lines()

func recalculate_tower_height(is_p1_tower: bool):
	if is_p1_tower:
		var max_height = 0.0
		
		# Ne calculer que la hauteur maximale
		for block in get_children():
			if block is RigidBody3D and block.position.x < 0:
				max_height = max(max_height, block.position.y)
		
		# Mettre à jour seulement la hauteur et la caméra
		stack_height_p1 = max_height
		if camera_p1:
			camera_p1.update_height(stack_height_p1)
			
	else:
		var max_height = 0.0
		
		for block in get_children():
			if block is RigidBody3D and block.position.x > 0:
				max_height = max(max_height, block.position.y)
		
		# Mettre à jour seulement la hauteur et la caméra
		stack_height_p2 = max_height
		if camera_p2:
			camera_p2.update_height(stack_height_p2)
	
	check_game_state()

func check_tower_stability():
	await get_tree().create_timer(0.2).timeout # Attendre que les blocs détruits soient enlevés
	
	# Vérifier chaque tour
	check_single_tower(true)  # P1
	check_single_tower(false) # P2

func check_single_tower(is_p1: bool):
	var blocks = []
	var base_y = 0.5 # Hauteur approximative du bloc de base
	
	# Collecter tous les blocs de la tour
	for block in get_children():
		if block is RigidBody3D:
			if (is_p1 and block.position.x < 0) or (not is_p1 and block.position.x > 0):
				blocks.append(block)
	
	# Trier les blocs par hauteur
	blocks.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	# Pour chaque bloc
	for i in range(blocks.size()):
		var block = blocks[i]
		if block.position.y <= base_y:
			continue # Ignorer le bloc de base
			
		# Vérifier s'il y a un support direct en dessous
		var has_support = false
		for lower_block in blocks:
			if lower_block == block:
				continue
				
			if lower_block.position.y < block.position.y and \
			   abs(lower_block.position.x - block.position.x) < 0.5 and \
			   abs(lower_block.position.z - block.position.z) < 0.5 and \
			   block.position.y - lower_block.position.y < 1.0:
				has_support = true
				break
		
		# Si pas de support, faire tomber le bloc
		if not has_support:
			block.freeze = false
			block.gravity_scale = 1.0
			
			# Supprimer le bloc après une courte chute
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(block):
					block.queue_free()
					# Recalculer la hauteur après la suppression
					recalculate_tower_height(is_p1))

func check_tower_blocks(is_p1: bool):
	var blocks = []
	# Collecter tous les blocs de la tour
	for block in get_children():
		if block is RigidBody3D:
			if (is_p1 and block.position.x < 0) or (not is_p1 and block.position.x > 0):
				blocks.append(block)
	
	# Trier les blocs par hauteur (du plus bas au plus haut)
	blocks.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	# Pour chaque bloc (sauf le bloc de base), vérifier s'il a un support
	for i in range(1, blocks.size()):
		var current_block = blocks[i]
		var has_support = false
		
		# Vérifier si un bloc en dessous supporte celui-ci
		for j in range(i):
			var lower_block = blocks[j]
			if is_block_supporting(lower_block, current_block):
				has_support = true
				break
		
		# Si pas de support, faire tomber le bloc
		if not has_support:
			make_block_fall(current_block)

func is_block_supporting(lower_block: Node3D, upper_block: Node3D) -> bool:
	# Vérifier si le bloc inférieur supporte le bloc supérieur
	var tolerance = 0.1  # Tolérance pour la superposition
	var height_diff = upper_block.position.y - lower_block.position.y
	
	# Vérifier si le bloc est juste au-dessus (avec une certaine tolérance)
	if height_diff > 0.4 and height_diff < 0.6:
		# Vérifier la superposition en X et Z
		var x_overlap = abs(upper_block.position.x - lower_block.position.x) < tolerance
		var z_overlap = abs(upper_block.position.z - lower_block.position.z) < tolerance
		return x_overlap and z_overlap
	
	return false

func make_block_fall(block: RigidBody3D):
	block.freeze = false
	block.gravity_scale = 1.0  # Activer la gravité
	# Ajouter une petite force aléatoire pour rendre la chute plus naturelle
	block.apply_central_impulse(Vector3(
		randf_range(-0.1, 0.1),
		0,
		randf_range(-0.1, 0.1)
	))
	
	# S'assurer que le bloc sera supprimé quand il tombe trop bas
	var fall_timer = Timer.new()
	add_child(fall_timer)
	fall_timer.wait_time = 3.0  # Temps avant suppression
	fall_timer.one_shot = true
	fall_timer.connect("timeout", func():
		if is_instance_valid(block):
			block.queue_free()
		fall_timer.queue_free()
	)
	fall_timer.start()

func on_blocks_destroyed():
	# Attendre une frame pour que les blocs soient bien supprimés
	await get_tree().process_frame
	
	# Recalculer les deux tours
	recalculate_tower_height(true)  # P1
	recalculate_tower_height(false) # P2

func setup_trajectory_lines():
	# Charger le script de trajectoire
	var TrajectoryLine = load("res://TrajectoryLine.gd")
	
	trajectory_line_p1 = Node3D.new()
	trajectory_line_p1.set_script(TrajectoryLine)
	add_child(trajectory_line_p1)
	
	trajectory_line_p2 = Node3D.new()
	trajectory_line_p2.set_script(TrajectoryLine)
	add_child(trajectory_line_p2)

func setup_projectile_timers():
	projectile_timer_p1 = Timer.new()
	projectile_timer_p1.wait_time = 10.0
	projectile_timer_p1.connect("timeout", _on_projectile_timer_timeout.bind(1))
	add_child(projectile_timer_p1)
	
	projectile_timer_p2 = Timer.new()
	projectile_timer_p2.wait_time = 10.0
	projectile_timer_p2.connect("timeout", _on_projectile_timer_timeout.bind(2))
	add_child(projectile_timer_p2)
	
	projectile_timer_p1.start()
	projectile_timer_p2.start()

func _on_projectile_timer_timeout(player_num: int):
	if player_num == 1:
		can_shoot_p1 = true
	else:
		can_shoot_p2 = true

func spawn_projectile(player_num: int):
	var start_pos: Vector3
	var trajectory_line: Node3D
	var angle: float
	var target_pos: Vector3
	
	if player_num == 1:
		start_pos = Vector3(
			last_block_p1.position.x,
			last_block_p1.position.y + 1,
			last_block_p1.position.z
		)
		target_pos = Vector3(
			last_block_p2.position.x,
			last_block_p2.position.y,
			last_block_p2.position.z
		)
		trajectory_line = trajectory_line_p1
		angle = current_angle_p1
	else:
		start_pos = Vector3(
			last_block_p2.position.x,
			last_block_p2.position.y + 1,
			last_block_p2.position.z
		)
		target_pos = Vector3(
			last_block_p1.position.x,
			last_block_p1.position.y,
			last_block_p1.position.z
		)
		trajectory_line = trajectory_line_p2
		angle = current_angle_p2
	
	# Calculer la direction horizontale vers la cible
	var direction_to_target = (target_pos - start_pos).normalized()
	direction_to_target.y = 0
	
	# Calculer le vecteur de direction final avec l'angle actuel
	var launch_direction = Vector3(
		direction_to_target.x,
		tan(angle),
		direction_to_target.z
	).normalized()
	
	# Ajuster la puissance en fonction de la distance
	var distance = start_pos.distance_to(target_pos)
	var adjusted_power = BASE_POWER * (distance / 20.0)
	
	var projectile = Projectile.instantiate()
	add_child(projectile)
	projectile.position = start_pos
	projectile.launch(launch_direction * adjusted_power)
	
	# Réinitialiser les variables
	if player_num == 1:
		charging_power_p1 = false
		current_angle_p1 = min_angle
		oscillation_direction_p1 = 1.0
		trajectory_line.clear()
	else:
		charging_power_p2 = false
		current_angle_p2 = min_angle
		oscillation_direction_p2 = 1.0
		trajectory_line.clear()

func reset_game():
	if winner_label:
		winner_label.hide()

	for child in get_children():
		if child is RigidBody3D:
			child.queue_free()
	
	# Reset complet des variables des deux joueurs
	winner = 0  # Réinitialiser le gagnant
	score_p1 = 0
	score_p2 = 0
	current_speed_multiplier_p1 = 1.0
	current_speed_multiplier_p2 = 1.0
	game_active = true
	stack_height_p1 = 0.0
	stack_height_p2 = 0.0
	p1_alive = true
	p2_alive = true
	game_ended = false
	can_spawn_p1 = true
	can_spawn_p2 = true
	alternate_movement_p1 = true  # Réinitialiser l'alternance des mouvements
	alternate_movement_p2 = true
	current_block_p1 = null      # Réinitialiser les blocs courants
	current_block_p2 = null
	last_block_p1 = null         # Réinitialiser les derniers blocs
	last_block_p2 = null
	
	if ui_p1:
		ui_p1.hide_winner_message()
		ui_p1.update_score(score_p1)
	if ui_p2:
		ui_p2.hide_winner_message()
		ui_p2.update_score(score_p2)
	
	# Attendre un court instant pour s'assurer que tout est nettoyé
	await get_tree().create_timer(0.1).timeout
	
	# Spawner les blocs de base et les premiers blocs mobiles
	spawn_base_block(1)
	spawn_base_block(2)
	await get_tree().create_timer(0.2).timeout  # Petit délai entre les spawns
	spawn_new_block(1)
	spawn_new_block(2)

func spawn_base_block(player_num: int):
	var base = Block.instantiate()
	add_child(base)
	if player_num == 1:
		base.position = Vector3(-5, 0.25, 0)  # Tour du P1
		last_block_p1 = base
		if camera_p1:
			camera_p1.update_height(0)
	else:
		base.position = Vector3(20, 0.25, 15)  # Tour du P2
		last_block_p2 = base
		if camera_p2:
			camera_p2.update_height(0)
	base.is_moving = false
	base.freeze = true

func spawn_new_block(player_num: int):
	await get_tree().create_timer(0.2).timeout
	if player_num == 1 and can_spawn_p1 and game_active:
			current_block_p1 = Block.instantiate()
			current_block_p1.previous_block = last_block_p1
			current_block_p1.move_on_x = alternate_movement_p1
			current_block_p1.speed_multiplier = current_speed_multiplier_p1
			current_block_p1.is_moving = true
			add_child(current_block_p1)

			var spawn_pos = Vector3(
				-12 if alternate_movement_p1 else last_block_p1.position.x,
				last_block_p1.position.y + current_block_p1.block_size.y,
				# Offset en Z quand le mouvement est sur cet axe
				last_block_p1.position.z + (3 if !alternate_movement_p1 else 0)
			)

			current_block_p1.position = spawn_pos
			alternate_movement_p1 = !alternate_movement_p1
		
	elif player_num == 2 and can_spawn_p2 and game_active:
		current_block_p2 = Block.instantiate()
		current_block_p2.previous_block = last_block_p2
		current_block_p2.move_on_x = alternate_movement_p2
		current_block_p2.speed_multiplier = current_speed_multiplier_p2
		current_block_p2.is_moving = true
		add_child(current_block_p2)

		var spawn_pos = Vector3(
			13 if alternate_movement_p2 else last_block_p2.position.x,  # Ajusté pour la position 20
			last_block_p2.position.y + current_block_p2.block_size.y,
			last_block_p2.position.z  # Position Z - Devrait être fixe pour chaque joueur

		)
		
		

		current_block_p2.position = spawn_pos
		alternate_movement_p2 = !alternate_movement_p2

func game_over(player_num: int):
	if player_num == 1:
		p1_alive = false
		print("Player 1 lost at height: ", stack_height_p1)
	else:
		p2_alive = false
		print("Player 2 lost at height: ", stack_height_p2)
		
	# Vérifier si les deux joueurs ont perdu ou si un joueur a dépassé l'autre
	check_game_state()

func update_score(player_num: int, new_score: int):
	if player_num == 1:
		ui_p1.update_score(new_score, 1)  # Ajoute le numéro du joueur (1)
	else:
		ui_p2.update_score(new_score, 2)  # Ajoute le numéro du joueur (2)

func check_game_state():
	# Victoire par score cible
	if score_p1 >= target_score:
		game_ended = true
		winner = 1
		declare_winner()
		return
	
	if score_p2 >= target_score:
		game_ended = true
		winner = 2
		declare_winner()
		return
	
	# Les deux joueurs morts
	if !p1_alive && !p2_alive:
		game_ended = true
		if score_p1 > score_p2:
			winner = 1
		elif score_p2 > score_p1:
			winner = 2
		else:
			winner = 0
		declare_winner()
		return
	
	# Un joueur mort, l'autre doit le dépasser d'au moins 1 point
	if !p1_alive && p2_alive && score_p2 > score_p1:
		game_ended = true
		winner = 2
		declare_winner()
		return
			
	if !p2_alive && p1_alive && score_p1 > score_p2:
		game_ended = true
		winner = 1
		declare_winner()
		return

func declare_winner():
	var message = ""
	
	if winner == 0:
		message = "IT'S A TIE!"
	elif winner == 1 || winner == 2:
		if score_p1 >= target_score || score_p2 >= target_score:
			message = "THE WINNER IS P%d BY REACHING TARGET SCORE!" % winner
		elif !p1_alive && !p2_alive:
			message = "THE WINNER IS P%d WITH HIGHER SCORE!" % winner
		else:
			message = "THE WINNER IS P%d BY SURPASSING OPPONENT!" % winner
	
	if winner_label:
		winner_label.text = message + "\nPress R to restart"
		winner_label.show()
	if ui_p1:
		ui_p1.show_winner_message(winner)
	if ui_p2:
		ui_p2.show_winner_message(winner)

# func declare_winner():
# 	if winner == 1:
# 		if winner_label:
# 			winner_label.text = "THE WINNER IS P1\nPress R to restart"
# 			winner_label.show()
# 		print("PLAYER 1 WINS BY REACHING TARGET SCORE!")
# 		print("Final scores - P1: ", score_p1, " P2: ", score_p2)
# 		ui_p1.show_winner_message(1)
# 		ui_p2.show_winner_message(1)
# 	elif winner == 2:
# 		if winner_label:
# 			winner_label.text = "THE WINNER IS P2\nPress R to restart"
# 			winner_label.show()
# 		print("PLAYER 2 WINS BY REACHING TARGET SCORE!")
# 		print("Final scores - P1: ", score_p1, " P2: ", score_p2)
# 		ui_p1.show_winner_message(2)
# 		ui_p2.show_winner_message(2)
# 	elif score_p1 > score_p2:
# 		print("THE WINNER IS P1")
# 		print("Final scores - P1: ", score_p1, " P2: ", score_p2)
# 	elif score_p2 > score_p1:
# 		print("THE WINNER IS P2")
# 		print("Final scores - P1: ", score_p1, " P2: ", score_p2)
# 	else:
# 		print("IT'S A TIE!")
# 		print("Final scores - P1: ", score_p1, " P2: ", score_p2)

func _input(event):

	# Ajouter cette condition au début de la fonction _input
	if event.is_action_pressed("ui_reset"):  # "ui_reset" doit être configuré sur la touche R
		if game_ended:
			reset_game()
			return

	# Player 1 block placement control
	if event.is_action_pressed("ui_select_p1"):
		if current_block_p1 and current_block_p1.is_moving and p1_alive and !game_ended:
			if current_block_p1.stop_moving():
				can_spawn_p1 = false
				last_block_p1 = current_block_p1
				stack_height_p1 = current_block_p1.position.y
				camera_p1.update_height(stack_height_p1)
				if last_block_p1.freeze == true:
					score_p1 += 1
					update_score(1, score_p1)
					
					# Vérifier immédiatement si le score cible est atteint
					if score_p1 >= target_score:
						game_ended = true
						winner = 1
						declare_winner()
						return
						
					if !p2_alive:
						check_game_state()
					
					if !game_ended:  # Ne spawner que si le jeu n'est pas fini
						current_speed_multiplier_p1 += speed_increase_per_block
						await get_tree().create_timer(0.5).timeout
						can_spawn_p1 = true
						spawn_new_block(1)
			else:
				game_over(1)
	
	# Player 2 block placement control
	if event.is_action_pressed("ui_select_p2"):
		if current_block_p2 and current_block_p2.is_moving and p2_alive and !game_ended:
			if current_block_p2.stop_moving():
				can_spawn_p2 = false
				last_block_p2 = current_block_p2
				stack_height_p2 = current_block_p2.position.y
				camera_p2.update_height(stack_height_p2)
				if last_block_p2.freeze == true:
					score_p2 += 1
					update_score(2, score_p2)
					
					# Vérifier immédiatement si le score cible est atteint
					if score_p2 >= target_score:
						game_ended = true
						winner = 2
						declare_winner()
						return
						
					if !p1_alive:
						check_game_state()
					
					if !game_ended:  # Ne spawner que si le jeu n'est pas fini
						current_speed_multiplier_p2 += speed_increase_per_block
						await get_tree().create_timer(0.5).timeout
						can_spawn_p2 = true
						spawn_new_block(2)
			else:
				game_over(2)
	
	# # Shooting controls for Player 1
	# if event.is_action_pressed("p1_shoot") and can_shoot_p1:
	# 	var spawn_pos = Vector3(-7, last_block_p1.position.y + 1, 0)
	# 	var direction = Vector3(1, 0.5, 0)  # Adjust as needed
	# 	spawn_projectile(1, spawn_pos, direction)
	
	# # Shooting controls for Player 2
	# if event.is_action_pressed("p2_shoot") and can_shoot_p2:
	# 	var spawn_pos = Vector3(7, last_block_p2.position.y + 1, 0)
	# 	var direction = Vector3(-1, 0.5, 0)  # Adjust as needed
	# 	spawn_projectile(2, spawn_pos, direction)

	 # Contrôles de tir pour P1
	if event.is_action_pressed("p1_shoot") and can_shoot_p1:
		charging_power_p1 = true
	elif event.is_action_released("p1_shoot") and charging_power_p1:
		spawn_projectile(1)
		can_shoot_p1 = false
		projectile_timer_p1.start()
	
	# Contrôles de tir pour P2
	if event.is_action_pressed("p2_shoot") and can_shoot_p2:
		charging_power_p2 = true
	elif event.is_action_released("p2_shoot") and charging_power_p2:
		spawn_projectile(2)
		can_shoot_p2 = false
		projectile_timer_p2.start()

func _physics_process(_delta):
	# Clean up fallen blocks
	for child in get_children():
		if child is RigidBody3D and child.position.y < cleanup_height:
			child.queue_free()

func _process(delta):
	# Gestion de l'oscillation pour P1
	if charging_power_p1:
		current_angle_p1 += oscillation_speed * delta * oscillation_direction_p1
		if current_angle_p1 >= max_angle:
			current_angle_p1 = max_angle
			oscillation_direction_p1 = -1.0
		elif current_angle_p1 <= min_angle:
			current_angle_p1 = min_angle
			oscillation_direction_p1 = 1.0
		update_trajectory_preview(1)
	
	# Gestion de l'oscillation pour P2
	if charging_power_p2:
		current_angle_p2 += oscillation_speed * delta * oscillation_direction_p2
		if current_angle_p2 >= max_angle:
			current_angle_p2 = max_angle
			oscillation_direction_p2 = -1.0
		elif current_angle_p2 <= min_angle:
			current_angle_p2 = min_angle
			oscillation_direction_p2 = 1.0
		update_trajectory_preview(2)

		# Mettre à jour le cooldown pour P1
	if !can_shoot_p1:
		var time_left = projectile_timer_p1.time_left
		var percent = (1 - (time_left / projectile_timer_p1.wait_time)) * 100
		ui_p1.update_cooldown(percent)
	else:
		ui_p1.update_cooldown(100)
	
	# Mettre à jour le cooldown pour P2
	if !can_shoot_p2:
		var time_left = projectile_timer_p2.time_left
		var percent = (1 - (time_left / projectile_timer_p2.wait_time)) * 100
		ui_p2.update_cooldown(percent)
	else:
		ui_p2.update_cooldown(100)

func update_trajectory_preview(player: int):
	var start_pos: Vector3
	var trajectory_line: Node3D
	var angle: float
	var target_pos: Vector3
	
	if player == 1:
		# Position de départ depuis la tour P1
		start_pos = Vector3(
			last_block_p1.position.x,  # Position X de la tour P1
			last_block_p1.position.y + 1,  # Légèrement au-dessus du dernier bloc
			last_block_p1.position.z  # Même Z que la tour
		)
		# Position cible sur la tour P2
		target_pos = Vector3(
			last_block_p2.position.x,  # Position X de la tour P2
			last_block_p2.position.y,  # Hauteur de la tour P2
			last_block_p2.position.z   # Position Z de la tour P2
		)
		trajectory_line = trajectory_line_p1
		angle = current_angle_p1
	else:
		# Position de départ depuis la tour P2
		start_pos = Vector3(
			last_block_p2.position.x,
			last_block_p2.position.y + 1,
			last_block_p2.position.z
		)
		# Position cible sur la tour P1
		target_pos = Vector3(
			last_block_p1.position.x,
			last_block_p1.position.y,
			last_block_p1.position.z
		)
		trajectory_line = trajectory_line_p2
		angle = current_angle_p2
	
	# Calculer la direction horizontale vers la cible
	var direction_to_target = (target_pos - start_pos).normalized()
	direction_to_target.y = 0  # On garde seulement la direction horizontale
	
	# Calculer le vecteur de direction final avec l'angle actuel
	var launch_direction = Vector3(
		direction_to_target.x,
		tan(angle),
		direction_to_target.z
	).normalized()
	
	# Ajuster la puissance en fonction de la distance
	var distance = start_pos.distance_to(target_pos)
	var adjusted_power = BASE_POWER * (distance / 20.0)  # Ajuste la puissance selon la distance
	
	# Calculer la vélocité initiale
	var initial_velocity = launch_direction * adjusted_power
	
	# Calculer les points de la trajectoire
	var points = calculate_trajectory_points(start_pos, initial_velocity)
	
	# Dessiner la trajectoire
	trajectory_line.draw_trajectory(points)

func calculate_trajectory_points(start_pos: Vector3, initial_velocity: Vector3, steps: int = 50, time_step: float = 0.1) -> Array:
	var points = []
	var pos = start_pos
	var vel = initial_velocity
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * Vector3.DOWN
	
	for i in range(steps):
		points.append(pos)
		vel += gravity * time_step
		pos += vel * time_step
	
	return points
