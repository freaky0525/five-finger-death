extends Node2D

@export var boss_scene: PackedScene = preload("res://Enemy/Boss/boss.tscn")
@export var boss_spawn_position: Vector2 = Vector2(7000, 220)
@export var dialogue_target_y := 480.0
@export var dialogue_target_scale := 1.45
@export var dialogue_transition_duration := 0.85
@export var player_dialogue_x_nudge := -180.0
@export var merchant_dialogue_x_gap := 1100.0
@export var merchant_dialogue_scale := 1.42

const MERCHANT_LINES := [
	{
		"speaker": "merchant",
		"text": "meow\n(open shop to buy supply)",
	},
	{
		"speaker": "player",
		"text": "ur cute",
	},
	{
		"speaker": "merchant",
		"text": "",
		"show_buttons": true,
	},
]

var boss_spawned := false
var _performance_busy := false


func _ready() -> void:
	GameState.apply_to_player($Player)
	var finger_ui: Control = $CanvasLayer/FingerHealthUI
	if finger_ui.has_method("update_finger_ui"):
		finger_ui.update_finger_ui($Player.current_health, $Player.max_health)
	var cigarette_ui: Control = $CanvasLayer/CigaretteUI
	if cigarette_ui.has_method("update_ui"):
		cigarette_ui.update_ui($Player.cigarettes)
	if GameState.coins <= 0:
		GameState.coins = 50

	$BossTrigger.player_entered_zone.connect(_on_boss_trigger_entered)
	$Merchant.interact_requested.connect(_on_merchant_interact)
	call_deferred("_connect_ui")


func _connect_ui() -> void:
	var dialogue := $CanvasLayer/DialogueUI
	var shop := $CanvasLayer/ShopUI
	if dialogue.has_signal("shop_requested"):
		dialogue.shop_requested.connect(_on_shop_requested)
	if dialogue.has_signal("closed"):
		dialogue.closed.connect(_on_menu_closed)
	if shop.has_signal("closed"):
		shop.closed.connect(_on_menu_closed)


func _on_merchant_interact() -> void:
	if (
		_performance_busy
		or $CanvasLayer/DialogueUI.visible
		or $CanvasLayer/ShopUI.visible
		or $Player.dialogue_performance_active
	):
		return

	_performance_busy = true
	_set_gameplay_hud_visible(false)
	$Merchant._refresh_prompt()
	await _play_dialogue_intro()
	$CanvasLayer/DialogueUI.open($Player, $Merchant, MERCHANT_LINES)
	_performance_busy = false


func _on_shop_requested() -> void:
	$CanvasLayer/ShopUI.open()


func _on_menu_closed() -> void:
	if $CanvasLayer/DialogueUI.visible or $CanvasLayer/ShopUI.visible:
		return

	if not $Player.dialogue_performance_active:
		$Player.menu_locked = false
		_set_gameplay_hud_visible(true)
		return

	_performance_busy = true
	await _play_dialogue_outro()
	$Player.finish_exit_dialogue_performance()
	$Player/Camera2D.finish_exit_dialogue_mode()
	$Merchant.finish_exit_dialogue_performance()
	_set_gameplay_hud_visible(true)
	_performance_busy = false
	_update_merchant_prompt()


func _play_dialogue_intro() -> void:
	var duration: float = dialogue_transition_duration
	var merchant_pose := _get_merchant_dialogue_pose()
	$Player.start_dialogue_performance(
		merchant_pose.player_position,
		dialogue_target_scale,
		duration,
		merchant_pose.player_face_right
	)
	$Merchant.start_dialogue_performance(
		merchant_pose.merchant_position,
		Vector2(merchant_dialogue_scale, merchant_dialogue_scale),
		duration,
		merchant_pose.face_left
	)
	$Player/Camera2D.start_dialogue_mode(duration)
	await get_tree().create_timer(duration).timeout
	$Player.finish_dialogue_performance(merchant_pose.player_face_right)
	$Merchant.finish_dialogue_performance()


func _get_merchant_dialogue_pose() -> Dictionary:
	var player_x: float = $Player.global_position.x + player_dialogue_x_nudge
	var side: float = signf($Merchant.global_position.x - $Player.global_position.x)
	if side == 0.0:
		side = 1.0
	var player_face_right: bool = side > 0.0
	var player_pos := Vector2(player_x, dialogue_target_y)
	var merchant_pos := Vector2(player_x + side * merchant_dialogue_x_gap, dialogue_target_y)
	return {
		"player_position": player_pos,
		"merchant_position": merchant_pos,
		"face_left": player_face_right,
		"player_face_right": player_face_right,
	}


func _set_gameplay_hud_visible(show_hud: bool) -> void:
	$CanvasLayer/FingerHealthUI.visible = show_hud
	$CanvasLayer/CigaretteUI.visible = show_hud


func _play_dialogue_outro() -> void:
	var duration := dialogue_transition_duration
	$Player.start_exit_dialogue_performance(duration)
	$Merchant.start_exit_dialogue_performance(duration)
	$Player/Camera2D.start_exit_dialogue_mode(duration)
	await get_tree().create_timer(duration).timeout


func _update_merchant_prompt() -> void:
	if $Merchant.has_method("_refresh_prompt"):
		$Merchant._refresh_prompt()


func _on_boss_trigger_entered() -> void:
	if boss_spawned:
		return

	boss_spawned = true
	var boss := boss_scene.instantiate()
	add_child(boss)
	boss.global_position = boss_spawn_position
