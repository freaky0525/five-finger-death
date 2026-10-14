extends Camera2D

@export var camera_smooth_speed = 0.3
@export var shake_intensity = 3.0
@export var shake_speed = 30.0
@export var lock_horizontal := false
@export var gameplay_y_offset_factor := 0.4
@export var dialogue_y_offset_factor := 0.22
@export var dialogue_zoom := Vector2(1.14, 1.14)

var last_target_x = -275.0
var noise_time = 1.0
var dialogue_mode := false


func _process(delta):
	var player = get_parent()
	var screen_size = get_viewport().get_visible_rect().size
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if lock_horizontal or dialogue_mode:
		last_target_x = -275.0
	elif direction.x > 0:
		last_target_x = -275.0
	elif direction.x < 0:
		last_target_x = -screen_size.x * 0.6

	offset.x = lerp(offset.x, last_target_x, camera_smooth_speed)

	if dialogue_mode:
		return

	var shake_vec = Vector2.ZERO
	if player.velocity.length() > 0:
		noise_time += delta * shake_speed
		shake_vec.x = sin(noise_time) * shake_intensity
		shake_vec.y = cos(noise_time * 1.5) * shake_intensity

	var base_y_offset = -screen_size.y * gameplay_y_offset_factor
	offset.x += shake_vec.x
	offset.y = base_y_offset + shake_vec.y


func start_dialogue_mode(duration: float) -> void:
	dialogue_mode = true
	var screen_size := get_viewport().get_visible_rect().size
	var target_y := -screen_size.y * dialogue_y_offset_factor
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "offset:y", target_y, duration)
	tween.tween_property(self, "zoom", dialogue_zoom, duration)


func start_exit_dialogue_mode(duration: float) -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var target_y := -screen_size.y * gameplay_y_offset_factor
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "offset:y", target_y, duration)
	tween.tween_property(self, "zoom", Vector2.ONE, duration)


func finish_exit_dialogue_mode() -> void:
	dialogue_mode = false
