extends Node2D


func _ready() -> void:
	GameState.player_health = GameState.player_max_health
	GameState.apply_to_player($Player)
	var finger_ui: Control = $CanvasLayer/FingerHealthUI
	if finger_ui.has_method("update_finger_ui"):
		finger_ui.update_finger_ui($Player.current_health, $Player.max_health)
	$Wave1Zone.reset()
	$Wave2Zone.reset()
	$Wave2Zone.wave_cleared.connect(_on_wave2_cleared)


func _on_wave2_cleared() -> void:
	$Teleporter.activate()
