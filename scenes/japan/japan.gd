extends Node2D

@export var dialogue_target_y := 43.0
@export var dialogue_target_scale := 1.45
@export var dialogue_transition_duration := 0.85
@export var player_dialogue_x_nudge := -180.0
@export var ninja_dialogue_x_gap := 900.0
@export var ninja_dialogue_scale := 1.42

const NINJA_LINES := [
	{
		"speaker": "player",
		"text": "hey",
	},
	{
		"speaker": "merchant",
		"action": "seals_1",
	},
	{
		"speaker": "player",
		"text": "sorry i dont speak sign language",
	},
	{
		"speaker": "merchant",
		"action": "seals_2",
	},
	{
		"speaker": "merchant",
		"text": "豪火球の術!!!",
	},
	{
		"speaker": "merchant",
		"action": "fireball",
	},
]

var _performance_busy := false


func _ready() -> void:
	GameState.player_health = GameState.player_max_health
	GameState.apply_to_player($Player)
	var finger_ui: Control = $CanvasLayer/FingerHealthUI
	if finger_ui.has_method("update_finger_ui"):
		finger_ui.update_finger_ui($Player.current_health, $Player.max_health)
	var cigarette_ui: Control = $CanvasLayer/CigaretteUI
	if cigarette_ui.has_method("update_ui"):
		cigarette_ui.update_ui($Player.cigarettes)
	$Ninja.interact_requested.connect(_on_ninja_interact)
	$CanvasLayer/DialogueUI.closed.connect(_on_dialogue_closed)


func _on_ninja_interact() -> void:
	if (
		_performance_busy
		or $CanvasLayer/DialogueUI.visible
		or $Player.dialogue_performance_active
	):
		return

	_performance_busy = true
	_set_gameplay_hud_visible(false)
	$Ninja._refresh_prompt()
	await _play_dialogue_intro()
	$CanvasLayer/DialogueUI.open($Player, $Ninja, NINJA_LINES)
	_performance_busy = false


func _on_dialogue_closed() -> void:
	if not $Player.dialogue_performance_active:
		$Player.menu_locked = false
		_set_gameplay_hud_visible(true)
		return

	_performance_busy = true
	await _play_dialogue_outro()
	$Player.finish_exit_dialogue_performance()
	$Player/Camera2D.finish_exit_dialogue_mode()
	$Ninja.start_combat()
	_set_gameplay_hud_visible(true)
	_performance_busy = false


func _play_dialogue_intro() -> void:
	var duration: float = dialogue_transition_duration
	var pose := _get_dialogue_pose()
	$Player.start_dialogue_performance(
		pose.player_position,
		dialogue_target_scale,
		duration,
		pose.player_face_right
	)
	$Ninja.start_dialogue_performance(
		pose.ninja_position,
		Vector2(ninja_dialogue_scale, ninja_dialogue_scale),
		duration,
		pose.face_left
	)
	$Player/Camera2D.start_dialogue_mode(duration)
	await get_tree().create_timer(duration).timeout
	$Player.finish_dialogue_performance(pose.player_face_right)
	$Ninja.finish_dialogue_performance()


func _get_dialogue_pose() -> Dictionary:
	var player_x: float = $Player.global_position.x + player_dialogue_x_nudge
	var side: float = signf($Ninja.global_position.x - $Player.global_position.x)
	if side == 0.0:
		side = 1.0
	var player_face_right: bool = side > 0.0
	var player_pos := Vector2(player_x, dialogue_target_y)
	var ninja_pos := Vector2(player_x + side * ninja_dialogue_x_gap, dialogue_target_y)
	return {
		"player_position": player_pos,
		"ninja_position": ninja_pos,
		"face_left": player_face_right,
		"player_face_right": player_face_right,
	}


func _set_gameplay_hud_visible(show_hud: bool) -> void:
	$CanvasLayer/FingerHealthUI.visible = show_hud
	$CanvasLayer/CigaretteUI.visible = show_hud


func _play_dialogue_outro() -> void:
	var duration := dialogue_transition_duration
	$Player.start_exit_dialogue_performance(duration)
	$Ninja.prepare_for_combat(duration)
	$Player/Camera2D.start_exit_dialogue_mode(duration)
	await get_tree().create_timer(duration).timeout
