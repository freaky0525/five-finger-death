extends CharacterBody2D

signal defeated

enum State { ORBIT, RUNNING, CHARGING }

const FRAME_DIR := "res://asset/enemies/rocket/"

# Melee-style movement (same defaults as enemy_melee.gd)
@export var health := 3
@export var speed := 300.0
@export var orbit_radius := 1000.0
@export var orbit_speed := 1.0
@export var target_height_offset := 115.0
@export var charge_hit_radius := 160.0

@export var charge_speed := 3200.0
@export var charge_overshoot := 220.0
@export var charge_cooldown := 1.0
@export var run_anim_speed := 20.0
@export var charge_anim_speed := 24.0
@export var stuck_move_threshold := 2.5
@export var stuck_frame_limit := 5
@export var backoff_distance := 56.0
var passthrough_on_hit := true

const _COLLISION_MASK_WORLD := 1
const _COLLISION_MASK_WORLD_AND_PLAYER := 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var touch_area: Area2D = $TouchArea
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var touch_shape: CollisionShape2D = $TouchArea/CollisionShape2D

var _state := State.ORBIT
var _is_hit := false
var _charge_cooldown_left := 0.0
var _charge_direction := Vector2.RIGHT
var _charge_traveled := 0.0
var _charge_stuck_frames := 0
var _orbit_angle := 0.0
var _charge_hit_done := false
var _player: CharacterBody2D


func _ready() -> void:
	add_to_group("level_entity")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_orbit_angle = randf() * TAU
	_build_sprite_frames()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_show_idle()
	_set_state(State.ORBIT)
	# First charge after a short beat so spawn matches melee (not instant dash).
	_charge_cooldown_left = charge_cooldown * 0.5


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	var idle_texture := load("%s0001.png" % FRAME_DIR) as Texture2D
	if idle_texture:
		frames.add_frame("idle", idle_texture)

	frames.add_animation("run")
	frames.set_animation_speed("run", run_anim_speed)
	frames.set_animation_loop("run", false)
	for frame_id in range(27, 44):
		var texture := load("%s%04d.png" % [FRAME_DIR, frame_id]) as Texture2D
		if texture:
			frames.add_frame("run", texture)

	frames.add_animation("charge")
	frames.set_animation_speed("charge", charge_anim_speed)
	frames.set_animation_loop("charge", true)
	for frame_id in range(51, 56):
		var texture := load("%s%04d.png" % [FRAME_DIR, frame_id]) as Texture2D
		if texture:
			frames.add_frame("charge", texture)

	animated_sprite.sprite_frames = frames


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or health <= 0:
		return

	if _is_hit:
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
		move_and_slide()
		return

	match _state:
		State.ORBIT:
			_process_orbit(delta)
		State.RUNNING:
			velocity = Vector2.ZERO
		State.CHARGING:
			_process_charge(delta)


func _process_orbit(delta: float) -> void:
	_charge_cooldown_left = max(_charge_cooldown_left - delta, 0.0)

	if _charge_cooldown_left <= 0.0:
		_start_run()
		return

	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return

	var center_point := _player.global_position + Vector2(0, target_height_offset)
	_orbit_angle += orbit_speed * delta
	var target_pos := center_point + Vector2(
		cos(_orbit_angle) * orbit_radius,
		sin(_orbit_angle) * orbit_radius
	)
	var dist_to_player := global_position.distance_to(center_point)
	var move_dir := Vector2.ZERO
	if dist_to_player < orbit_radius - 50.0:
		move_dir = global_position.direction_to(center_point) * -1.2
	else:
		move_dir = global_position.direction_to(target_pos)
	velocity = move_dir * speed
	_update_facing_from_player()
	_show_idle()
	move_and_slide()


func _process_charge(_delta: float) -> void:
	var before := global_position
	velocity = _charge_direction.normalized() * charge_speed
	_update_facing()
	move_and_slide()
	_try_charge_hit(before, global_position)

	var moved := global_position.distance_to(before)
	_charge_traveled += moved
	if moved < stuck_move_threshold:
		_charge_stuck_frames += 1
	else:
		_charge_stuck_frames = 0

	if _charge_stuck_frames >= stuck_frame_limit:
		_backoff_from_block()
		_end_charge()
	elif _has_passed_player():
		_end_charge()


func _has_passed_player() -> bool:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null or not is_instance_valid(_player):
		return _charge_traveled >= 4000.0

	var aim := _player.global_position + Vector2(0, -40)
	var to_aim := aim - global_position
	return to_aim.dot(_charge_direction.normalized()) < -charge_overshoot


func _start_run() -> void:
	if _state != State.ORBIT or _is_hit:
		return

	_update_charge_direction()
	_set_state(State.RUNNING)
	animated_sprite.play("run")
	_update_facing()


func _start_charge() -> void:
	if _state != State.RUNNING:
		return

	_update_charge_direction()
	_charge_hit_done = false
	_set_state(State.CHARGING)
	_charge_traveled = 0.0
	_charge_stuck_frames = 0
	animated_sprite.play("charge")
	velocity = _charge_direction.normalized() * charge_speed
	_update_facing()


func _end_charge() -> void:
	_set_state(State.ORBIT)
	_charge_cooldown_left = charge_cooldown
	velocity = Vector2.ZERO
	_charge_traveled = 0.0
	_charge_stuck_frames = 0
	_show_idle()


func _show_idle() -> void:
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")


func _backoff_from_block() -> void:
	var back := -_charge_direction.normalized()
	if back.length_squared() < 0.001:
		back = Vector2.LEFT
	global_position += back * backoff_distance


func _on_animation_finished() -> void:
	if _state == State.RUNNING and animated_sprite.animation == "run":
		_start_charge()


func _update_charge_direction() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player:
		_charge_direction = global_position.direction_to(_player.global_position + Vector2(0, -40))
		if _charge_direction.length_squared() < 0.001:
			_charge_direction = Vector2.RIGHT
	else:
		_charge_direction = Vector2.RIGHT


func _update_facing_from_player() -> void:
	if _player and _player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	elif _player and _player.global_position.x > global_position.x:
		animated_sprite.flip_h = false


func _set_state(state: State) -> void:
	_state = state
	var combat_active := state == State.CHARGING
	body_shape.disabled = false
	collision_mask = _COLLISION_MASK_WORLD if combat_active else _COLLISION_MASK_WORLD_AND_PLAYER
	touch_shape.disabled = not combat_active
	touch_area.monitoring = combat_active


func _update_facing() -> void:
	if _charge_direction.x < 0.0:
		animated_sprite.flip_h = true
	elif _charge_direction.x > 0.0:
		animated_sprite.flip_h = false


func take_damage(attacker) -> void:
	if _is_hit or health <= 0:
		return

	health -= 1
	if health <= 0:
		die()
		return

	_is_hit = true
	_set_state(State.ORBIT)
	_charge_cooldown_left = charge_cooldown
	velocity = Vector2.ZERO
	_show_idle()

	modulate = Color.RED
	await get_tree().create_timer(0.4).timeout

	if health > 0:
		_is_hit = false
		modulate = Color.WHITE


func _try_charge_hit(from_pos: Vector2, to_pos: Vector2) -> void:
	if _charge_hit_done:
		return

	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null or not is_instance_valid(_player):
		return

	var aim := _player.global_position + Vector2(0, -40)
	var seg := to_pos - from_pos
	var closest := to_pos
	var len_sq := seg.length_squared()
	if len_sq >= 0.001:
		var t := clampf((aim - from_pos).dot(seg) / len_sq, 0.0, 1.0)
		closest = from_pos + seg * t
	if closest.distance_to(aim) > charge_hit_radius:
		return

	_player.take_damage(self)
	_charge_hit_done = true


func die() -> void:
	defeated.emit()
	set_physics_process(false)
	touch_area.set_deferred("monitoring", false)
	touch_shape.set_deferred("disabled", true)
	body_shape.set_deferred("disabled", true)
	modulate = Color(10, 10, 10, 1)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): queue_free())
