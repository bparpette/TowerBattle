extends Control

func _ready():
	# Styliser les boutons
	var buttons = [
		$MainContainer/VBoxContainer/StartButton,
		$MainContainer/VBoxContainer/HowToPlayButton,
		$MainContainer/VBoxContainer/QuitButton,
		$HowToPlayPanel/BackButton
	]
	
	for button in buttons:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 1.0)  # Couleur de base
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_bottom_left = 10
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.3, 0.7, 1.0)  # Couleur au survol
		hover_style.corner_radius_top_left = 10
		hover_style.corner_radius_top_right = 10
		hover_style.corner_radius_bottom_right = 10
		hover_style.corner_radius_bottom_left = 10
		
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover_style)

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_how_to_play_button_pressed():
	$HowToPlayPanel.show()

func _on_quit_button_pressed():
	get_tree().quit()

func _on_back_button_pressed():
	$HowToPlayPanel.hide()
