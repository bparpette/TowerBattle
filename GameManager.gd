# GameManager.gd
extends Node3D

var Block = preload("res://Block.tscn")
var Projectile = preload("res://projectile.tscn")

@onready var camera_p1 = $"../ViewportLayout/SubViewportContainer1/SubViewport1/CameraP1"
@onready var camera_p2 = $"../ViewportLayout/SubViewportContainer2/SubViewport2/CameraP2"
@onready var ui_p1 = $"../ViewportLayout/SubViewportContainer1/ControlP1"
@onready var ui_p2 = $"../ViewportLayout/SubViewportContainer2/ControlP2"
@onready var network_manager = $"../NetworkManager"
@onready var winner_label = $"../WinnerLabel"

# Game state variables
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
var target_score = 20
var winner = 0
var p1_alive = true
var p2_alive = true
var game_ended = false
var networked_block = false

# Block variables
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
var charging_power_p1 = false
var charging_power_p2 = false
var trajectory_line_p1: Node3D
var trajectory_line_p2: Node3D

# Trajectory variables
var oscillation_speed = 0.3
var min_angle = PI/30
var max_angle = PI/6 
var current_angle_p1 = 0.0
var current_angle_p2 = 0.0
var oscillation_direction_p1 = 1.0
var oscillation_direction_p2 = 1.0
const BASE_POWER = 20.0
var cleanup_height = -10.0

# GameManager.gd changes
func _ready():
	# Wait a frame to ensure all nodes are ready
	await get_tree().create_timer(0.2).timeout
	
	# Get required nodes
	camera_p1 = $"../ViewportLayout/SubViewportContainer1/SubViewport1/CameraP1"
	camera_p2 = $"../ViewportLayout/SubViewportContainer2/SubViewport2/CameraP2"
	ui_p1 = $"../ViewportLayout/SubViewportContainer1/ControlP1"
	ui_p2 = $"../ViewportLayout/SubViewportContainer2/ControlP2"
	network_manager = $"../NetworkManager"
	winner_label = $"../WinnerLabel"
	
	# Hide winner label initially
	if winner_label:
		winner_label.hide()
	
	if network_manager:
		print("Network manager found, setting up game...")
		# Connect signals
		if !network_manager.is_connected("player_matched", _on_player_matched):
			network_manager.player_matched.connect(_on_player_matched)
			network_manager.opponent_placed_block.connect(_on_opponent_placed_block)
			network_manager.opponent_shot_projectile.connect(_on_opponent_shot_projectile)
			network_manager.game_ended.connect(_on_game_ended)
			network_manager.opponent_disconnected.connect(_on_opponent_disconnected)
		
		# Setup viewports immediately based on current network role
		setup_viewports()
		
		# Don't start game until network is ready
		if !network_manager.game_started:
			print("Waiting for network game to start...")
			return
	
	# Initialize game components
	setup_projectile_timers()
	setup_trajectory_lines()
	
	# Start the game if not in network mode or if network is ready
	if !network_manager or network_manager.game_started:
		print("Starting game initialization...")
		reset_game()

func setup_viewports():
	if !network_manager:
		return
	
	print("Setting up viewports for: ", "P1" if network_manager.is_player_one else "P2")
	
	# Get viewport containers
	var container1 = $"../ViewportLayout/SubViewportContainer1"
	var container2 = $"../ViewportLayout/SubViewportContainer2"
	
	# Reset visibility
	if container1:
		container1.hide()
	if container2:
		container2.hide()
	
	if network_manager.is_player_one:
		if container1:
			container1.show()
			container1.custom_minimum_size = Vector2(1152, 648)
			if camera_p1:
				camera_p1.position = Vector3(-13, 5, -11)
				camera_p1.rotation_degrees = Vector3(-15, 45, 0)
				print("P1 camera positioned")
	else:
		if container2:
			container2.show()
			container2.custom_minimum_size = Vector2(1152, 648)
			if camera_p2:
				camera_p2.position = Vector3(28, 5, 26)
				camera_p2.rotation_degrees = Vector3(-15, -225, 0)
				print("P2 camera positioned")

func reset_game():
	print("Resetting game state...")
	
	# Clear existing blocks
	for child in get_children():
		if child is RigidBody3D:
			child.queue_free()
	
	# Reset game state
	winner = 0
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
	alternate_movement_p1 = true
	alternate_movement_p2 = true
	current_block_p1 = null
	current_block_p2 = null
	last_block_p1 = null
	last_block_p2 = null
	
	# Update UI
	if ui_p1:
		ui_p1.hide_winner_message()
		ui_p1.update_score(score_p1)
	if ui_p2:
		ui_p2.hide_winner_message()
		ui_p2.update_score(score_p2)
	
	# Wait for physics to settle
	await get_tree().create_timer(0.1).timeout
	
	print("Spawning initial blocks...")
	# Spawn initial blocks
	spawn_base_block(1)
	spawn_base_block(2)
	await get_tree().create_timer(0.2).timeout
	spawn_new_block(1)
	spawn_new_block(2)

func spawn_base_block(player_num: int):
	# Check network conditions
	if network_manager:
		if (player_num == 1 and !network_manager.is_player_one) or \
		   (player_num == 2 and network_manager.is_player_one):
			return
	
	print("Spawning base block for player ", player_num)
	var base = Block.instantiate()
	add_child(base)
	
	if player_num == 1:
		base.position = Vector3(-5, 0.25, 0)
		last_block_p1 = base
		if camera_p1:
			camera_p1.update_height(0)
	else:
		base.position = Vector3(20, 0.25, 15)
		last_block_p2 = base
		if camera_p2:
			camera_p2.update_height(0)
	
	base.is_moving = false
	base.freeze = true
	print("Base block spawned for player ", player_num)

func spawn_new_block(player_num: int):
	# Check network conditions
	if network_manager:
		if (player_num == 1 and !network_manager.is_player_one) or \
		   (player_num == 2 and network_manager.is_player_one):
			return
	
	await get_tree().create_timer(0.2).timeout
	print("Attempting to spawn new block for player ", player_num)
	
	if player_num == 1 and can_spawn_p1 and game_active:
		_spawn_block_for_player_one()
	elif player_num == 2 and can_spawn_p2 and game_active:
		_spawn_block_for_player_two()

func _spawn_block_for_player_one():
	current_block_p1 = Block.instantiate()
	current_block_p1.previous_block = last_block_p1
	current_block_p1.move_on_x = alternate_movement_p1
	current_block_p1.speed_multiplier = current_speed_multiplier_p1
	
	if last_block_p1:
		current_block_p1.block_size = Vector3(
			last_block_p1.block_size.x,
			current_block_p1.block_size.y,
			last_block_p1.block_size.z
		)
	
	current_block_p1.is_moving = true
	add_child(current_block_p1)
	
	var spawn_pos = Vector3(
		-12 if alternate_movement_p1 else last_block_p1.position.x,
		last_block_p1.position.y + current_block_p1.block_size.y,
		last_block_p1.position.z + (3 if !alternate_movement_p1 else 0)
	)
	
	current_block_p1.position = spawn_pos
	alternate_movement_p1 = !alternate_movement_p1
	print("P1 block spawned at ", spawn_pos)

func _spawn_block_for_player_two():
	current_block_p2 = Block.instantiate()
	current_block_p2.previous_block = last_block_p2
	current_block_p2.move_on_x = alternate_movement_p2
	current_block_p2.speed_multiplier = current_speed_multiplier_p2
	
	if last_block_p2:
		current_block_p2.block_size = Vector3(
			last_block_p2.block_size.x,
			current_block_p2.block_size.y,
			last_block_p2.block_size.z
		)
	
	current_block_p2.is_moving = true
	add_child(current_block_p2)
	
	var spawn_pos = Vector3(
		13 if alternate_movement_p2 else last_block_p2.position.x,
		last_block_p2.position.y + current_block_p2.block_size.y,
		last_block_p2.position.z
	)
	
	current_block_p2.position = spawn_pos
	alternate_movement_p2 = !alternate_movement_p2
	print("P2 block spawned at ", spawn_pos)

func sync_from_network_state(state: Dictionary):
	score_p1 = state.p1_score
	score_p2 = state.p2_score
	
	if ui_p1:
		ui_p1.update_score(score_p1)
	if ui_p2:
		ui_p2.update_score(score_p2)
	
	stack_height_p1 = state.p1_tower_height
	stack_height_p2 = state.p2_tower_height
	
	if camera_p1:
		camera_p1.update_height(stack_height_p1)
	if camera_p2:
		camera_p2.update_height(stack_height_p2)

func _on_player_matched(_player_id: int, is_player_one: bool):
	print("Player matched in GameManager, is_player_one: ", is_player_one)
	setup_viewports()
	await get_tree().create_timer(0.5).timeout
	reset_game()

func _on_opponent_placed_block(player_id: int, block_data: Dictionary):
	var block = Block.instantiate()
	add_child(block)
	block.networked_block = true
	block.deserialize(block_data)
	block.is_moving = false
	block.freeze = true
	
	if player_id == network_manager.opponent_id:
		if network_manager.is_player_one:
			recalculate_tower_height(false)
		else:
			recalculate_tower_height(true)

func _on_opponent_shot_projectile(player_id: int, start_pos: Vector3, velocity: Vector3):
	var projectile = Projectile.instantiate()
	add_child(projectile)
	projectile.position = start_pos
	projectile.launch(velocity)

func _on_game_ended(winner_id: int):
	game_ended = true
	winner = 1 if winner_id == network_manager.my_player_id else 2
	declare_winner()

func _on_opponent_disconnected():
	if winner_label:
		winner_label.text = "Opponent disconnected!\nPress R to restart"
		winner_label.show()
		
# GameManager.gd (continued)

func setup_projectile_timers():
	if projectile_timer_p1:
		projectile_timer_p1.queue_free()
	if projectile_timer_p2:
		projectile_timer_p2.queue_free()
	
	projectile_timer_p1 = Timer.new()
	projectile_timer_p1.wait_time = 10.0
	projectile_timer_p1.one_shot = false
	projectile_timer_p1.autostart = true
	projectile_timer_p1.connect("timeout", _on_projectile_timer_timeout.bind(1))
	add_child(projectile_timer_p1)
	
	projectile_timer_p2 = Timer.new()
	projectile_timer_p2.wait_time = 10.0
	projectile_timer_p2.one_shot = false
	projectile_timer_p2.autostart = true
	projectile_timer_p2.connect("timeout", _on_projectile_timer_timeout.bind(2))
	add_child(projectile_timer_p2)

func setup_trajectory_lines():
	var TrajectoryLine = load("res://TrajectoryLine.gd")
	
	trajectory_line_p1 = Node3D.new()
	trajectory_line_p1.set_script(TrajectoryLine)
	add_child(trajectory_line_p1)
	
	trajectory_line_p2 = Node3D.new()
	trajectory_line_p2.set_script(TrajectoryLine)
	add_child(trajectory_line_p2)



func recalculate_tower_height(is_p1_tower: bool):
	if is_p1_tower:
		var max_height = 0.0
		for block in get_children():
			if block is RigidBody3D and block.position.x < 0:
				max_height = max(max_height, block.position.y)
		
		stack_height_p1 = max_height
		if camera_p1:
			camera_p1.update_height(stack_height_p1)
	else:
		var max_height = 0.0
		for block in get_children():
			if block is RigidBody3D and block.position.x > 0:
				max_height = max(max_height, block.position.y)
		
		stack_height_p2 = max_height
		if camera_p2:
			camera_p2.update_height(stack_height_p2)
	
	check_game_state()

func _input(event):
	if event.is_action_pressed("ui_reset"):
		if game_ended:
			reset_game()
			return

	if event.is_action_pressed("ui_select_p1") and network_manager.is_player_one:
		handle_block_placement(1)
	
	if event.is_action_pressed("ui_select_p2") and !network_manager.is_player_one:
		handle_block_placement(2)
	
	if event.is_action_pressed("p1_shoot") and can_shoot_p1:
		charging_power_p1 = true
	elif event.is_action_released("p1_shoot") and charging_power_p1:
		spawn_projectile(1)
		can_shoot_p1 = false
		projectile_timer_p1.start()
	
	if event.is_action_pressed("p2_shoot") and can_shoot_p2:
		charging_power_p2 = true
	elif event.is_action_released("p2_shoot") and charging_power_p2:
		spawn_projectile(2)
		can_shoot_p2 = false
		projectile_timer_p2.start()

func handle_block_placement(player_num: int):
	var current_block = current_block_p1 if player_num == 1 else current_block_p2
	if current_block and current_block.is_moving and \
	   (player_num == 1 and p1_alive or player_num == 2 and p2_alive) and \
	   !game_ended:
		if current_block.stop_moving():
			var block_data = current_block.serialize()
			network_manager.send_block_placement(block_data)
			process_successful_placement(player_num)
		else:
			game_over(player_num)

func process_successful_placement(player_num: int):
	if player_num == 1:
		can_spawn_p1 = false
		last_block_p1 = current_block_p1
		stack_height_p1 = current_block_p1.position.y
		camera_p1.update_height(stack_height_p1)
		if last_block_p1.freeze:
			update_score_and_spawn(1)
	else:
		can_spawn_p2 = false
		last_block_p2 = current_block_p2
		stack_height_p2 = current_block_p2.position.y
		camera_p2.update_height(stack_height_p2)
		if last_block_p2.freeze:
			update_score_and_spawn(2)

func update_score_and_spawn(player_num: int):
	if player_num == 1:
		score_p1 += 1
		update_score(1, score_p1)
		if score_p1 >= target_score:
			game_ended = true
			winner = 1
			declare_winner()
			return
		if !p2_alive:
			check_game_state()
		if !game_ended:
			current_speed_multiplier_p1 += speed_increase_per_block
			await get_tree().create_timer(0.5).timeout
			can_spawn_p1 = true
			spawn_new_block(1)
	else:
		score_p2 += 1
		update_score(2, score_p2)
		if score_p2 >= target_score:
			game_ended = true
			winner = 2
			declare_winner()
			return
		if !p1_alive:
			check_game_state()
		if !game_ended:
			current_speed_multiplier_p2 += speed_increase_per_block
			await get_tree().create_timer(0.5).timeout
			can_spawn_p2 = true
			spawn_new_block(2)

# GameManager.gd (continued)

func _physics_process(_delta):
	for child in get_children():
		if child is RigidBody3D and child.position.y < cleanup_height:
			child.queue_free()

func _process(delta):
	if charging_power_p1:
		process_charging(delta, 1)
	if charging_power_p2:
		process_charging(delta, 2)

	if ui_p1:
		update_cooldown_ui(1)
	if ui_p2:
		update_cooldown_ui(2)

func process_charging(delta: float, player_num: int):
	var current_angle = current_angle_p1 if player_num == 1 else current_angle_p2
	var oscillation_direction = oscillation_direction_p1 if player_num == 1 else oscillation_direction_p2
	
	current_angle += oscillation_speed * delta * oscillation_direction
	
	if current_angle >= max_angle:
		current_angle = max_angle
		oscillation_direction = -1.0
	elif current_angle <= min_angle:
		current_angle = min_angle
		oscillation_direction = 1.0
	
	if player_num == 1:
		current_angle_p1 = current_angle
		oscillation_direction_p1 = oscillation_direction
	else:
		current_angle_p2 = current_angle
		oscillation_direction_p2 = oscillation_direction
	
	update_trajectory_preview(player_num)

func update_cooldown_ui(player_num: int):
	var timer = projectile_timer_p1 if player_num == 1 else projectile_timer_p2
	var ui = ui_p1 if player_num == 1 else ui_p2
	
	if timer and ui:
		if timer.is_stopped():
			ui.update_cooldown(100)
		else:
			var percent = (1.0 - (timer.time_left / timer.wait_time)) * 100.0
			ui.update_cooldown(percent)

func spawn_projectile(player_num: int):
	var start_pos: Vector3
	var trajectory_line: Node3D
	var angle: float
	var target_pos: Vector3
	
	if player_num == 1:
		start_pos = Vector3(-3, 1, 0)
		target_pos = Vector3(20, last_block_p2.position.y, 15)
		trajectory_line = trajectory_line_p1
		angle = current_angle_p1
	else:
		start_pos = Vector3(23, 1, 12)
		target_pos = Vector3(-5, last_block_p1.position.y, 0)
		trajectory_line = trajectory_line_p2
		angle = current_angle_p2
	
	var direction_to_target = (target_pos - start_pos).normalized()
	direction_to_target.y = 0
	
	var launch_direction = Vector3(
		direction_to_target.x,
		tan(angle),
		direction_to_target.z
	).normalized()
	
	var distance = start_pos.distance_to(target_pos)
	var adjusted_power = BASE_POWER * (distance / 20.0)
	
	var projectile = Projectile.instantiate()
	add_child(projectile)
	projectile.position = start_pos
	projectile.launch(launch_direction * adjusted_power)
	
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
	
	if player_num == (1 if network_manager.my_player_id == 1 else 2):
		network_manager.send_projectile(start_pos, launch_direction * adjusted_power)

func update_trajectory_preview(player: int):
	var start_pos: Vector3
	var trajectory_line: Node3D
	var angle: float
	var target_pos: Vector3
	
	if player == 1:
		start_pos = Vector3(-3, 1, 0)
		target_pos = Vector3(20, last_block_p2.position.y, 15)
		trajectory_line = trajectory_line_p1
		angle = current_angle_p1
	else:
		start_pos = Vector3(23, 1, 12)
		target_pos = Vector3(-5, last_block_p1.position.y, 0)
		trajectory_line = trajectory_line_p2
		angle = current_angle_p2
	
	var direction_to_target = (target_pos - start_pos).normalized()
	direction_to_target.y = 0
	
	var launch_direction = Vector3(
		direction_to_target.x,
		tan(angle),
		direction_to_target.z
	).normalized()
	
	var distance = start_pos.distance_to(target_pos)
	var adjusted_power = BASE_POWER * (distance / 20.0)
	
	var initial_velocity = launch_direction * adjusted_power
	var points = calculate_trajectory_points(start_pos, initial_velocity)
	trajectory_line.draw_trajectory(points)

# GameManager.gd (final part)

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

func game_over(player_num: int):
	if player_num == 1:
		p1_alive = false
		print("Player 1 lost at height: ", stack_height_p1)
	else:
		p2_alive = false
		print("Player 2 lost at height: ", stack_height_p2)
	
	check_game_state()

func update_score(player_num: int, new_score: int):
	if player_num == 1:
		ui_p1.update_score(new_score, 1)
	else:
		ui_p2.update_score(new_score, 2)

func check_game_state():
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

func _on_projectile_timer_timeout(player_num: int):
	if player_num == 1:
		can_shoot_p1 = true
	else:
		can_shoot_p2 = true

func declare_winner():
	var message = ""
	
	if winner == 0:
		message = "IT'S A TIE!"
	elif winner == 1 || winner == 2:
		if score_p1 >= target_score || score_p2 >= target_score:
			message = "THE WINNER IS P%d \nBY REACHING TARGET SCORE!" % winner
		elif !p1_alive && !p2_alive:
			message = "THE WINNER IS P%d \nWITH HIGHER SCORE!" % winner
		else:
			message = "THE WINNER IS P%d \nBY SURPASSING OPPONENT!" % winner
	
	if winner_label:
		winner_label.text = message + "\n\nPress R to restart"
		winner_label.show()
	if ui_p1:
		ui_p1.show_winner_message(winner)
	if ui_p2:
		ui_p2.show_winner_message(winner)
	
	if network_manager:
		network_manager.send_game_end(winner)
