extends StaticBody2D

signal interact_requested

@onready var prompt: Label = $InteractPrompt
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $Label

var player_in_range := false
var _home_position := Vector2.ZERO
var _home_scale := Vector2.ONE
var dialogue_performance_active := false


func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _ready() -> void:
	_home_position = global_position
	_home_scale = _sprite.scale
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	prompt.text = "[G] Talk"
	UIFonts.apply(prompt)
	prompt.visible = false


func start_dialogue_performance(
	target_position: Vector2,
	target_scale: Vector2,
	duration: float,
	face_left: bool
) -> void:
	dialogue_performance_active = true
	prompt.visible = false
	_name_label.visible = false
	_sprite.flip_h = face_left
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_position, duration)
	tween.tween_property(_sprite, "scale", target_scale, duration)


func finish_dialogue_performance() -> void:
	pass


func start_exit_dialogue_performance(duration: float) -> void:
	if not dialogue_performance_active:
		return

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", _home_position, duration)
	tween.tween_property(_sprite, "scale", _home_scale, duration)


func finish_exit_dialogue_performance() -> void:
	dialogue_performance_active = false
	_sprite.flip_h = false
	_name_label.visible = true
	_refresh_prompt()


func _process(_delta: float) -> void:
	if not player_in_range:
		return

	var player := _get_player()
	if player != null and (player.menu_locked or player.dialogue_performance_active):
		return

	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false


func _refresh_prompt() -> void:
	var player := _get_player()
	var blocked: bool = (
		player != null and (player.menu_locked or player.dialogue_performance_active)
	) or dialogue_performance_active
	prompt.visible = player_in_range and not blocked
