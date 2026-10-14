extends CharacterBody2D

signal health_changed(current_health, max_health)
signal cigarettes_changed(count: int)
signal dodge_successful
signal attack_blocked

@export var speed = 500.0
@export var max_health: int = 5
@export var knockback_force: float = 650.0
@export var invincibility_duration: float = 0.5
@export var minimum_health: int = 0
@export var walk_lane_y := 300.0

var current_health: int = 5
var cigarettes: int = 0
var is_dead = false
var is_invincible := false
var is_hurt := false
var menu_locked := false
var dialogue_performance_active := false
var _dialogue_home_position := Vector2.ZERO

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D


func _ready():
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _physics_process(_delta):
	if is_dead:
		velocity = Vector2.ZERO
		return

	if menu_locked:
		velocity = Vector2.ZERO
		return

	if is_hurt:
		velocity = velocity.move_toward(Vector2.ZERO, knockback_force * 2.0 * _delta)
		move_and_slide()
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

	if $ShieldComponent.is_defending:
		velocity = Vector2.ZERO
	elif $DashComponent.is_dashing:
		velocity = direction.normalized() * $DashComponent.dash_speed
	else:
		velocity = direction * speed

	if $CombatComponent.is_attacking:
		velocity = velocity * 0.2

	move_and_slide()


func start_dialogue_performance(target_pos: Vector2, target_scale: float, duration: float, face_right: bool = true) -> void:
	menu_locked = true
	_dialogue_home_position = global_position
	sprite.flip_h = not face_right
	anim.play("walk")
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, duration)
	tween.tween_property(sprite, "scale", Vector2.ONE * target_scale, duration)


func finish_dialogue_performance(face_right: bool = true) -> void:
	dialogue_performance_active = true
	sprite.flip_h = not face_right
	anim.play("idle")


func start_exit_dialogue_performance(duration: float) -> void:
	if not dialogue_performance_active:
		return

	anim.play("walk")
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", _dialogue_home_position, duration)
	tween.tween_property(sprite, "scale", Vector2.ONE, duration)


func finish_exit_dialogue_performance() -> void:
	dialogue_performance_active = false
	menu_locked = false
	global_position = _dialogue_home_position
	sprite.scale = Vector2.ONE
	anim.play("idle")


func _process(_delta):
	if is_dead:
		return

	if menu_locked:
		return

	if is_hurt:
		return

	if Input.is_action_just_pressed("use_cigarette"):
		use_cigarette()

	if $ShieldComponent.is_defending:
		return

	if $DashComponent.is_dashing:
		return

	if $CombatComponent.is_attacking:
		anim.play("punch")
		return

	if velocity.length() > 0:
		anim.play("walk")
	else:
		anim.play("idle")


func take_damage(attacker, damage_amount: int = 1):
	if is_dead or is_invincible:
		return

	if $DashComponent.is_dashing:
		dodge_successful.emit()
		return

	if $ShieldComponent.is_defending:
		attack_blocked.emit()
		print("Blocked by the Safe Zone!")
		return

	current_health -= damage_amount

	if minimum_health > 0:
		current_health = max(current_health, minimum_health)
	else:
		current_health = clamp(current_health, 0, max_health)

	print("Player health:", current_health)

	health_changed.emit(current_health, max_health)

	if current_health <= 0 and minimum_health <= 0:
		die()
		return

	_apply_hit_reaction(attacker)


func _apply_hit_reaction(attacker: Node2D) -> void:
	is_invincible = true
	var passthrough: bool = false
	if attacker != null and is_instance_valid(attacker):
		passthrough = attacker.get("passthrough_on_hit") == true

	if not passthrough:
		is_hurt = true
		var knock_dir: Vector2 = Vector2.RIGHT
		if attacker != null and is_instance_valid(attacker):
			knock_dir = global_position - attacker.global_position
		if knock_dir.length_squared() < 1.0:
			knock_dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
		else:
			knock_dir = knock_dir.normalized()
		velocity = knock_dir * knockback_force

	_flash_hurt()
	await get_tree().create_timer(invincibility_duration).timeout

	if not is_instance_valid(self) or is_dead:
		return

	is_invincible = false
	is_hurt = false
	sprite.modulate = Color.WHITE


func _flash_hurt() -> void:
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.35, 0.45), 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)


func add_cigarettes(amount: int = 1) -> void:
	cigarettes += amount
	cigarettes_changed.emit(cigarettes)
	GameState.cigarettes = cigarettes


func use_cigarette() -> void:
	if cigarettes <= 0 or current_health >= max_health:
		return

	cigarettes -= 1
	current_health = mini(current_health + 1, max_health)
	cigarettes_changed.emit(cigarettes)
	GameState.cigarettes = cigarettes
	GameState.player_health = current_health
	health_changed.emit(current_health, max_health)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	GameState.player_health = max_health
	GameState.player_max_health = max_health
	GameState.cigarettes = cigarettes
	_reset_wave_borders()
	set_physics_process(false)
	set_process(false)
	get_tree().call_deferred("reload_current_scene")


func _reset_wave_borders() -> void:
	for zone in get_tree().get_nodes_in_group("wave_zone"):
		if zone.has_method("reset"):
			zone.reset()
