extends Control

@onready var score_label = get_node("Label")
@onready var winner_label = $"../WinnerLabel" 
var progress_bar: ProgressBar
var cooldown_indicator: Label

func _ready():
	if winner_label:
		winner_label.hide()
	
	# Score progress bar
	progress_bar = ProgressBar.new()
	progress_bar.set_position(Vector2(10, 40))
	progress_bar.set_size(Vector2(300, 20))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2 
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	progress_bar.add_theme_stylebox_override("background", style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.3, 0.3)
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_right = 8
	fill_style.corner_radius_bottom_left = 8
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	progress_bar.custom_minimum_size = Vector2(300, 20)
	progress_bar.show_percentage = false
	progress_bar.max_value = get_node("/root/Main/GameManager").target_score
	
	add_child(progress_bar)
	
	# Cooldown indicator
	cooldown_indicator = Label.new()
	cooldown_indicator.set_position(Vector2(10, 70))
	cooldown_indicator.add_theme_color_override("font_color", Color.GREEN)
	cooldown_indicator.text = "Projectile Ready!"
	
	add_child(cooldown_indicator)

func update_score(score: int, player_number: int = 1):
	if player_number == -1:
		player_number = 2 if "P2" in name else 1
	else:
		player_number = 2 if "P2" in name else 1  # Force le bon numéro de joueur basé sur le nom du Control

	# print("updating score for: ", name, " player: ", player_number)


	var game_manager = get_node("/root/Main/GameManager")
	var target_score = game_manager.target_score
	score_label.text = "Player %d Score: %d / %d" % [player_number, score, target_score]
	if progress_bar:
		progress_bar.value = score

func update_cooldown(percent: float):
	if cooldown_indicator:
		if percent >= 100:
			cooldown_indicator.text = "Projectile Ready!"
			cooldown_indicator.add_theme_color_override("font_color", Color.GREEN)
		else:
			cooldown_indicator.text = "Cooldown: %d%%" % percent
			cooldown_indicator.add_theme_color_override("font_color", Color.RED)

func show_winner_message(player_number: int):
	if winner_label:
		winner_label.text = "THE WINNER IS P%d\nPress R to restart" % player_number
		winner_label.show()

func hide_winner_message():
	if winner_label:
		winner_label.hide()
