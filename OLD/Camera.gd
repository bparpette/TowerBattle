extends Camera3D

var initial_position: Vector3
var initial_height: float
var target_height: float = 0.0
var smooth_speed: float = 5.0
var target_x: float

func _ready():
	print("\n=== Camera Initializing ===")
	print("Node name: ", name)
	initial_position = position
	initial_height = position.y
	target_x = -5.0 if position.x > 0 else 5.0
	print("Initial position: ", initial_position)
	print("Initial height: ", initial_height)
	print("Target X: ", target_x)

func _process(delta):
	var current_height = initial_height + target_height
	var previous_position = position
	position.y = lerp(position.y, current_height, smooth_speed * delta)
	
	var target_position = Vector3(target_x, target_height, 0)
	
	# Only print if position actually changed
	if previous_position != position:
		print("\n=== Camera Update (" + name + ") ===")
		print("Current height: ", current_height)
		print("Position: ", position)
		print("Looking at: ", target_position)
	
	look_at(target_position)

func update_height(new_height: float):
	print("\n=== Camera Height Update (" + name + ") ===")
	print("Previous target height: ", target_height)
	print("New target height: ", new_height)
	target_height = new_height
