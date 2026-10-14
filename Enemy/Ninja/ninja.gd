extends CharacterBody2D

signal interact_requested

const IDLE_TEXTURE := preload("res://asset/enemies/ninja/idle.png")
const SEALS_A: Array[Texture2D] = [
	preload("res://asset/enemies/ninja/seal_a1.png"),
	preload("res://asset/enemies/ninja/seal_a2.png"),
	preload("res://asset/enemies/ninja/seal_a3.png"),
]
const SEALS_B: Array[Texture2D] = [
	preload("res://asset/enemies/ninja/seal_b1.png"),
	preload("res://asset/enemies/ninja/seal_b2.png"),
	preload("res://asset/enemies/ninja/seal_b3.png"),
]
const FIREBALL_SCENE := preload("res://Enemy/Ninja/fireball.tscn")
const CAST_FRAMES: Array[Texture2D] = [
	preload("res://asset/enemies/ninja/cast_1.png"),
	preload("res://asset/enemies/ninja/cast_2.png"),
	preload("res://asset/enemies/ninja/cast_3.png"),
	preload("res://asset/enemies/ninja/cast_4.png"),
]
const SEAL_FRAME_SECONDS := 0.34
const COMBAT_SEAL_SECONDS := 0.22
const CAST_FRAME_SECONDS := 0.05
const CAST_SIZE_BOOST := 1.36

@export var health := 4
@export var move_speed := 280.0
@export var preferred_range := 560.0

@onready var prompt: Label = $InteractPrompt
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $Label

var player_in_range := false
var _home_scale := Vector2.ONE
var dialogue_performance_active := false
var in_combat := false
var _casting := false
var _hurt := false


func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _ready() -> void:
	_home_scale = _sprite.scale
	_sprite.texture = IDLE_TEXTURE
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	prompt.text = "[G] Talk"
	UIFonts.apply(prompt)
	UIFonts.apply(_name_label)
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
	_sprite.flip_h = not face_left
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_position, duration)
	tween.tween_property(_sprite, "scale", target_scale, duration)


func finish_dialogue_performance() -> void:
	_face_player()


func prepare_for_combat(duration: float) -> void:
	if not dialogue_performance_active:
		return

	_show_idle()
	_face_player()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sprite, "scale", _home_scale, duration)


func start_combat() -> void:
	dialogue_performance_active = false
	in_combat = true
	prompt.visible = false
	_name_label.visible = false
	_show_idle()
	_face_player()
	_sprite.scale = _home_scale
	$InteractArea.monitoring = false
	_combat_loop()


func play_dialogue_action(action_name: String) -> void:
	match action_name:
		"seals_1":
			await _play_seals(SEALS_A)
		"seals_2":
			await _play_seals(SEALS_B)
		"fireball":
			await _play_release()
	_show_idle()


func _play_seals(frames: Array[Texture2D], frame_seconds: float = SEAL_FRAME_SECONDS) -> void:
	for tex in frames:
		if health <= 0:
			return
		_sprite.texture = tex
		_face_player()
		await get_tree().create_timer(frame_seconds).timeout


func _play_release() -> void:
	_face_player()
	var facing_right := _sprite.flip_h
	var base_scale := _sprite.scale
	_sprite.scale = base_scale * CAST_SIZE_BOOST
	for tex in CAST_FRAMES:
		if health <= 0:
			_sprite.scale = base_scale
			return
		_sprite.texture = tex
		_sprite.flip_h = facing_right
		await get_tree().create_timer(CAST_FRAME_SECONDS).timeout
	_sprite.scale = base_scale
	_sprite.flip_h = facing_right
	if health <= 0:
		return
	_launch_fireball()


func _launch_fireball() -> void:
	var fireball := FIREBALL_SCENE.instantiate()
	get_tree().current_scene.add_child(fireball)
	var palm_sign := 1.0 if _sprite.flip_h else -1.0
	var origin := global_position + Vector2(palm_sign * 120.0, -30.0)
	fireball.global_position = origin
	var player := _get_player()
	var aim := Vector2.LEFT
	if player != null:
		aim = player.global_position - origin
		if aim.length_squared() < 1.0:
			aim = Vector2.LEFT
	fireball.direction = aim.normalized()
	fireball.arm()


func _show_idle() -> void:
	_sprite.texture = IDLE_TEXTURE


func _face_player() -> void:
	var player := _get_player()
	if player == null:
		return
	# The idle art faces left, so mirror it only when the player is on the right.
	_sprite.flip_h = player.global_position.x > global_position.x


func _combat_loop() -> void:
	await get_tree().create_timer(0.35).timeout
	while in_combat and health > 0:
		await get_tree().create_timer(1.05).timeout
		if not in_combat or health <= 0:
			return
		_casting = true
		velocity = Vector2.ZERO
		_face_player()
		var all_seals: Array[Texture2D] = []
		all_seals.append_array(SEALS_A)
		all_seals.append_array(SEALS_B)
		await _play_seals(all_seals, COMBAT_SEAL_SECONDS)
		if health <= 0:
			return
		await _play_release()
		_show_idle()
		_casting = false
		await get_tree().create_timer(0.4).timeout


func _physics_process(delta: float) -> void:
	if not in_combat or health <= 0:
		return

	if _casting or _hurt:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 3.0 * delta)
		move_and_slide()
		return

	var player := _get_player()
	if player == null:
		return

	_face_player()
	var offset := global_position - player.global_position
	var distance := offset.length()
	var away := offset.normalized() if distance > 1.0 else Vector2.RIGHT
	var desired := player.global_position + away * preferred_range
	var to_desired := desired - global_position
	if to_desired.length() < 48.0:
		velocity = Vector2(-away.y, away.x) * move_speed
	else:
		velocity = to_desired.normalized() * move_speed
	move_and_slide()


func take_damage(attacker) -> void:
	if _hurt or health <= 0 or not in_combat:
		return

	health -= 1
	if health <= 0:
		_die()
		return

	_hurt = true
	var knock_dir := signf(global_position.x - attacker.global_position.x)
	if knock_dir == 0.0:
		knock_dir = 1.0
	velocity = Vector2(knock_dir * 900.0, 0.0)
	modulate = Color.RED
	await get_tree().create_timer(0.28).timeout
	if health > 0:
		_hurt = false
		modulate = Color.WHITE


func _die() -> void:
	in_combat = false
	_casting = false
	set_physics_process(false)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	modulate = Color(0.15, 0.15, 0.15, 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.finished.connect(queue_free)


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
