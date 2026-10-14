extends CharacterBody2D

signal defeated

@export var health = 3
@export var speed = 300.0
@export var is_stationary: bool = false
@export var orbit_radius = 250.0
@export var orbit_speed = 10
@export var target_height_offset = 115.0

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
@onready var sprite = $Sprite2D

var is_hit = false
var orbit_angle = 0.0


func _ready():
	add_to_group("level_entity")
	orbit_angle = randf() * TAU


func _physics_process(delta):
	if not is_inside_tree() or not player or health <= 0:
		return

	if is_hit:
		if is_stationary:
			return
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
		if is_inside_tree():
			move_and_slide()
		return

	if is_stationary:
		sprite.flip_h = player.global_position.x < global_position.x
		check_for_player_contact()
		return

	var center_point = player.global_position + Vector2(0, target_height_offset)
	orbit_angle += orbit_speed * delta
	var target_pos = center_point + Vector2(
		cos(orbit_angle) * orbit_radius,
		sin(orbit_angle) * orbit_radius
	)
	var direction = global_position.direction_to(target_pos)
	var distance = global_position.distance_to(target_pos)
	var current_speed = speed if distance > 20 else speed * 0.8
	velocity = direction * current_speed
	sprite.flip_h = player.global_position.x < global_position.x
	check_for_player_contact()
	if is_inside_tree() and not is_queued_for_deletion():
		move_and_slide()


func take_damage(attacker):
	if is_hit or health <= 0:
		return

	health -= 1
	if health <= 0:
		die()
		return

	is_hit = true
	if is_stationary:
		modulate = Color.RED
		await get_tree().create_timer(0.4).timeout
		if health > 0:
			is_hit = false
			modulate = Color.WHITE
		return

	var knock_dir = sign(global_position.x - attacker.global_position.x)
	if knock_dir == 0:
		knock_dir = 1

	velocity = Vector2(knock_dir * 1200, -300)
	modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	if health > 0:
		is_hit = false
		modulate = Color.WHITE


func check_for_player_contact():
	if not is_inside_tree():
		return
	var areas = $TouchArea.get_overlapping_areas()
	for area in areas:
		if area.has_method("take_damage"):
			area.take_damage(self)
		elif area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(self)


func die():
	defeated.emit()
	set_physics_process(false)
	set_process(false)
	$TouchArea/CollisionShape2D.set_deferred("disabled", true)
	modulate = Color(10, 10, 10, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): queue_free())
