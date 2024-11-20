extends Node3D

var Block = preload("res://Block.tscn")
var Projectile = preload("res://Projectile.tscn")
@onready var camera_p1 = $"../CameraP1"
@onready var camera_p2 = $"../CameraP2"
@onready var ui_p1 = $"../ControlP1"
@onready var ui_p2 = $"../ControlP2"

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

# Add at the top with other variables
var cleanup_height = -10.0  # Height at which blocks are deleted

func _ready():
	setup_projectile_timers()
	await get_tree().create_timer(0.1).timeout
	reset_game()

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

func spawn_projectile(player_num: int, spawn_position: Vector3, direction: Vector3):
	var projectile = Projectile.instantiate()
	add_child(projectile)
	projectile.position = spawn_position
	projectile.launch(direction)
	
	if player_num == 1:
		can_shoot_p1 = false
	else:
		can_shoot_p2 = false

func reset_game():
	for child in get_children():
		if child is RigidBody3D:
			child.queue_free()
	
	score_p1 = 0
	score_p2 = 0
	current_speed_multiplier_p1 = 1.0
	current_speed_multiplier_p2 = 1.0
	game_active = true
	stack_height_p1 = 0.0
	stack_height_p2 = 0.0
	
	can_shoot_p1 = false
	can_shoot_p2 = false
	
	if ui_p1:
		ui_p1.update_score(score_p1)
	if ui_p2:
		ui_p2.update_score(score_p2)
	
	spawn_base_block(1)
	spawn_base_block(2)
	spawn_new_block(1)
	spawn_new_block(2)

func spawn_base_block(player_num: int):
	var base = Block.instantiate()
	add_child(base)
	base.position = Vector3(-5 if player_num == 1 else 5, 0.25, 0)
	base.is_moving = false
	base.freeze = true
	if player_num == 1:
		last_block_p1 = base
		if camera_p1:
			camera_p1.update_height(0)
	else:
		last_block_p2 = base
		if camera_p2:
			camera_p2.update_height(0)

func spawn_new_block(player_num: int):
	# Add delay before spawning new block
	await get_tree().create_timer(0.2).timeout
	
	if player_num == 1 and can_spawn_p1 and game_active:
		current_block_p1 = Block.instantiate()
		current_block_p1.previous_block = last_block_p1
		current_block_p1.move_on_x = alternate_movement_p1
		current_block_p1.speed_multiplier = current_speed_multiplier_p1
		current_block_p1.is_moving = true
		add_child(current_block_p1)

		var spawn_pos = Vector3(
			-7 if alternate_movement_p1 else last_block_p1.position.x,
			last_block_p1.position.y + current_block_p1.block_size.y + 0.1,
			last_block_p1.position.z
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
			7 if alternate_movement_p2 else last_block_p2.position.x,
			last_block_p2.position.y + current_block_p2.block_size.y + 0.1,
			last_block_p2.position.z
		)

		current_block_p2.position = spawn_pos
		alternate_movement_p2 = !alternate_movement_p2

func game_over():
	game_active = false
	print("GAME OVER")
	# You could modify this to show game-over screen for each player, if applicable
	
	await get_tree().create_timer(1.0).timeout
	
	if Input.is_action_just_pressed("ui_select"):
		reset_game()

func update_score(player_num: int, new_score: int):
	if player_num == 1:
		ui_p1.update_score(new_score)
	else:
		ui_p2.update_score(new_score)

func _input(event):
	# Player 1 block placement control
	if event.is_action_pressed("ui_select_p1"):
		if current_block_p1 and current_block_p1.is_moving:
			if current_block_p1.stop_moving():
				can_spawn_p1 = false
				last_block_p1 = current_block_p1
				stack_height_p1 = current_block_p1.position.y
				camera_p1.update_height(stack_height_p1)
				if last_block_p1.freeze == true:
					score_p1 += 1
					print("Player 1 Score: ", score_p1)
					update_score(1, score_p1)
				
				current_speed_multiplier_p1 += speed_increase_per_block
				await get_tree().create_timer(0.5).timeout
				can_spawn_p1 = true
				spawn_new_block(1)
			else:
				game_over()
	
	# Player 2 block placement control
	if event.is_action_pressed("ui_select_p2"):
		if current_block_p2 and current_block_p2.is_moving:
			if current_block_p2.stop_moving():
				can_spawn_p2 = false
				last_block_p2 = current_block_p2
				stack_height_p2 = current_block_p2.position.y
				camera_p2.update_height(stack_height_p2)
				if last_block_p2.freeze == true:
					score_p2 += 1
					print("Player 2 Score: ", score_p2)
					update_score(2, score_p2)
				
				current_speed_multiplier_p2 += speed_increase_per_block
				await get_tree().create_timer(0.5).timeout
				can_spawn_p2 = true
				spawn_new_block(2)
			else:
				game_over()
	
	# Shooting controls for Player 1
	if event.is_action_pressed("p1_shoot") and can_shoot_p1:
		var spawn_pos = Vector3(-7, last_block_p1.position.y + 1, 0)
		var direction = Vector3(1, 0.5, 0)  # Adjust as needed
		spawn_projectile(1, spawn_pos, direction)
	
	# Shooting controls for Player 2
	if event.is_action_pressed("p2_shoot") and can_shoot_p2:
		var spawn_pos = Vector3(7, last_block_p2.position.y + 1, 0)
		var direction = Vector3(-1, 0.5, 0)  # Adjust as needed
		spawn_projectile(2, spawn_pos, direction)

func _physics_process(_delta):
	# Clean up fallen blocks
	for child in get_children():
		if child is RigidBody3D and child.position.y < cleanup_height:
			child.queue_free()
