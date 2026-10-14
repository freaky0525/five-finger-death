extends Control

signal shop_requested
signal closed

const BUBBLE_SCENE := preload("res://ui/dialogue_bubble.tscn")
const PLAYER_TALK_SCENE := preload("res://ui/player_dialogue_talk.tscn")
const MAX_VISIBLE := 3

@export var stack_spacing := 390.0
@export var screen_center_y_ratio := 0.52
@export var stack_alphas := PackedFloat32Array([1.0, 0.5, 0.25])

@onready var bubble_layer: Control = $BubbleLayer

var _player: Node2D
var _merchant: Node2D
var _bubbles: Array[Control] = []
var _running := false
var _active_bubble: Control
var _player_talk: Node2D
var _player_sprite: CanvasItem


func _ready() -> void:
	visible = false


func open(player: Node2D, merchant: Node2D, lines: Array) -> void:
	_player = player
	_merchant = merchant
	_player_sprite = player.get_node_or_null("Sprite2D") as CanvasItem
	_ensure_player_talk()
	visible = true
	_clear_bubbles()
	_running = true
	_set_player_body_visible(true)
	_run_conversation(lines)


func close() -> void:
	if not visible and not _running:
		return
	_running = false
	_stop_player_talk()
	_set_player_body_visible(true)
	visible = false
	_clear_bubbles()
	_player = null
	_merchant = null
	_active_bubble = null
	_player_sprite = null
	closed.emit()


func _ensure_player_talk() -> void:
	if _player_talk != null and is_instance_valid(_player_talk):
		return
	if _player == null:
		return
	_player_talk = PLAYER_TALK_SCENE.instantiate()
	_player.get_parent().add_child(_player_talk)
	if _player_talk.has_method("bind_player"):
		_player_talk.bind_player(_player)


func _run_conversation(lines: Array) -> void:
	for line in lines:
		if not _running:
			return

		var action_name := str(line.get("action", ""))
		var text: String = line.get("text", "")
		var show_buttons: bool = line.get("show_buttons", false)
		if action_name != "" and text.is_empty() and not show_buttons:
			_apply_speaker_visual("merchant", false)
			if _merchant != null and _merchant.has_method("play_dialogue_action"):
				await _merchant.play_dialogue_action(action_name)
			if not _running:
				return
			continue

		var speaker_key: String = line.get("speaker", "merchant")
		var speaker := _merchant if speaker_key == "merchant" else _player

		_apply_speaker_visual(speaker_key, true)

		await _push_line(speaker, text, show_buttons)
		if not _running:
			return

		if show_buttons:
			_apply_speaker_visual(speaker_key, false)
			return

		await _wait_for_click_advance(speaker_key)

		_apply_speaker_visual(speaker_key, false)

	if _running:
		close()


func _apply_speaker_visual(speaker_key: String, line_active: bool) -> void:
	if speaker_key == "player" and line_active:
		_set_player_body_visible(false)
		if _player_talk and _player_talk.has_method("start"):
			_player_talk.start()
	elif speaker_key == "player" and not line_active:
		_stop_player_talk()
		_set_player_body_visible(true)
	else:
		_stop_player_talk()
		_set_player_body_visible(true)


func _set_player_body_visible(show_body: bool) -> void:
	if _player_sprite:
		_player_sprite.visible = show_body


func _stop_player_talk() -> void:
	if _player_talk and _player_talk.has_method("stop"):
		_player_talk.stop()


func _wait_for_click_advance(speaker_key: String) -> void:
	var bubble := _active_bubble
	if bubble == null:
		return

	if bubble.has_signal("line_finished_typing"):
		await bubble.line_finished_typing

	if speaker_key == "player":
		_stop_player_talk()
		_set_player_body_visible(true)

	while _running:
		if Input.is_action_just_pressed("punch"):
			return
		await get_tree().process_frame


func _push_line(speaker: Node2D, text: String, show_buttons: bool) -> void:
	var other := _merchant if speaker == _player else _player
	var speaker_on_right := speaker.global_position.x > other.global_position.x
	await _add_bubble(text, speaker_on_right, show_buttons)


func _add_bubble(text: String, speaker_on_right: bool, show_buttons: bool) -> void:
	if show_buttons:
		_clear_bubbles()
	else:
		_age_existing_bubbles()

	var bubble: Control = BUBBLE_SCENE.instantiate()
	bubble_layer.add_child(bubble)
	bubble.setup(text, speaker_on_right, show_buttons)
	bubble.set_meta("speaker_on_right", speaker_on_right)
	bubble.set_meta("slot", 0)
	bubble.modulate.a = 0.0
	_active_bubble = bubble

	if show_buttons:
		bubble.shop_button.pressed.connect(_on_shop_pressed)
		bubble.leave_button.pressed.connect(_on_leave_pressed)

	_bubbles.append(bubble)
	await get_tree().process_frame
	_tween_bubble_to_slot(bubble, 0)


func _age_existing_bubbles() -> void:
	for bubble in _bubbles.duplicate():
		var next_slot: int = int(bubble.get_meta("slot")) + 1
		if next_slot >= MAX_VISIBLE:
			_remove_bubble(bubble)
		else:
			bubble.set_meta("slot", next_slot)
			_tween_bubble_to_slot(bubble, next_slot)


func _tween_bubble_to_slot(bubble: Control, slot: int) -> void:
	var size := bubble.size
	if size == Vector2.ZERO:
		size = bubble.custom_minimum_size
	var target_pos := _bubble_position_for(slot, size)
	var alpha: float = stack_alphas[mini(slot, stack_alphas.size() - 1)]

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "position", target_pos, 0.35)
	tween.tween_property(bubble, "modulate:a", alpha, 0.35)


func _bubble_position_for(slot: int, size: Vector2) -> Vector2:
	var screen := get_viewport_rect().size
	var center := Vector2(screen.x * 0.5, screen.y * screen_center_y_ratio)
	var pos := center - size * 0.5
	pos.y -= slot * stack_spacing
	return pos


func _remove_bubble(bubble: Control) -> void:
	var index := _bubbles.find(bubble)
	if index >= 0:
		_bubbles.remove_at(index)
	if _active_bubble == bubble:
		_active_bubble = null
	var tween := create_tween()
	tween.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tween.tween_callback(bubble.queue_free)


func _clear_bubbles() -> void:
	for bubble in _bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	_bubbles.clear()
	_active_bubble = null


func _on_shop_pressed() -> void:
	_running = false
	_stop_player_talk()
	_set_player_body_visible(true)
	_clear_bubbles()
	visible = false
	shop_requested.emit()


func _on_leave_pressed() -> void:
	close()
