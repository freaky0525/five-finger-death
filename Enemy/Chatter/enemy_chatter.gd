extends CharacterBody2D

signal defeated

const FRAME_DIR := "res://asset/enemies/chatter/"

@export var health := 1
@export var speed := 480.0
@export var chatter_fps := 14.0
@export var contact_damage_cooldown := 0.55

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_hit := false
var _can_contact_damage := true
var _player: CharacterBody2D


func _ready() -> void:
	add_to_group("level_entity")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_build_sprite_frames()
	animated_sprite.play("chatter")


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("chatter")
	frames.set_animation_speed("chatter", chatter_fps)
	frames.set_animation_loop("chatter", true)

	var closed_tex := load("%smouth_closed.png" % FRAME_DIR) as Texture2D
	var open_tex := load("%smouth_open.png" % FRAME_DIR) as Texture2D
	if closed_tex:
		frames.add_frame("chatter", closed_tex)
	if open_tex:
		frames.add_frame("chatter", open_tex)

	animated_sprite.sprite_frames = frames


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or health <= 0:
		return

	if _is_hit:
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
		move_and_slide()
		return

	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return

	var aim := _player.global_position + Vector2(0, 90)
	var direction := global_position.direction_to(aim)
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT

	velocity = direction * speed
	animated_sprite.flip_h = _player.global_position.x < global_position.x
	check_for_player_contact()
	move_and_slide()


func take_damage(attacker) -> void:
	if _is_hit or health <= 0:
		return

	health -= 1
	if health <= 0:
		die()
		return

	_is_hit = true
	modulate = Color.RED
	await get_tree().create_timer(0.25).timeout
	if health > 0:
		_is_hit = false
		modulate = Color.WHITE


func check_for_player_contact() -> void:
	if not is_inside_tree() or not _can_contact_damage:
		return

	for area in $TouchArea.get_overlapping_areas():
		var target: Node = area
		if not target.has_method("take_damage") and target.get_parent().has_method("take_damage"):
			target = target.get_parent()
		if not target.has_method("take_damage"):
			continue
		if target.name != "Player" and not target.is_in_group("player"):
			continue

		target.take_damage(self)
		_start_contact_damage_cooldown()
		return


func _start_contact_damage_cooldown() -> void:
	_can_contact_damage = false
	await get_tree().create_timer(contact_damage_cooldown).timeout
	_can_contact_damage = true


func die() -> void:
	defeated.emit()
	set_physics_process(false)
	$TouchArea/CollisionShape2D.set_deferred("disabled", true)
	modulate = Color(10, 10, 10, 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func(): queue_free())
