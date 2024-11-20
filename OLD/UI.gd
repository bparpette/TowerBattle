extends Control

@onready var score_label = $Label  # On suppose que tu as nommé le Label comme "Label"

# Fonction pour mettre à jour l'affichage du score
func update_score(score: int):
	score_label.text = "Score: %d" % score
