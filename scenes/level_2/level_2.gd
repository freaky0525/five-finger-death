extends Node2D


func _ready() -> void:
	GameState.player_health = GameState.player_max_health
	GameState.apply_to_player($Player)
	var finger_ui: Control = $CanvasLayer/FingerHealthUI
	if finger_ui.has_method("update_finger_ui"):
		finger_ui.update_finger_ui($Player.current_health, $Player.max_health)
	var cigarette_ui: Control = $CanvasLayer/CigaretteUI
	if cigarette_ui.has_method("update_ui"):
		cigarette_ui.update_ui($Player.cigarettes)
	$Wave1Zone.reset()
	$Wave2Zone.reset()
	$Wave1Zone.wave_cleared.connect(_on_wave1_cleared)
	$Wave2Zone.wave_cleared.connect(_on_wave2_cleared)


func _on_wave1_cleared() -> void:
	pass


func _on_wave2_cleared() -> void:
	$Teleporter.activate()
