extends Camera2D

@export var camera_smooth_speed = 0.3
@export var shake_intensity = 3.0
@export var shake_speed = 30.0
@export var lock_horizontal := false

var last_target_x = -275.0
var noise_time = 1.0

func _process(delta):
	var player = get_parent()
	var screen_size = get_viewport_rect().size
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if lock_horizontal:
		last_target_x = -275.0
	elif direction.x > 0:
		last_target_x = -275.0
	elif direction.x < 0:
		last_target_x = -screen_size.x * 0.6

	# Calculate Shake
	var shake_vec = Vector2.ZERO
	if player.velocity.length() > 0:
		noise_time += delta * shake_speed
		shake_vec.x = sin(noise_time) * shake_intensity
		shake_vec.y = cos(noise_time * 1.5) * shake_intensity

	var base_y_offset = -screen_size.y * 0.4
	offset.x = lerp(offset.x, last_target_x, camera_smooth_speed) + shake_vec.x
	offset.y = base_y_offset + shake_vec.y
