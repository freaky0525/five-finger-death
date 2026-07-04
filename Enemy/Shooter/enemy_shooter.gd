extends CharacterBody2D

signal defeated

@export var health = 2
@export var speed = 150.0
@export var is_stationary: bool = false
@export var orbit_radius = 1000.0 # Stay far away
@export var orbit_speed = 1.0
@export var bullet_scene: PackedScene # Drag bullet.tscn here in Inspector

@onready var player = get_tree().get_first_node_in_group("player")
@onready var muzzle = $Muzzle

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
		_update_facing()
		return

	# 1. Update the angle for rotation
	orbit_angle += orbit_speed * delta
	
	# 2. Define the center (Player's chest)
	var center_point = player.global_position + Vector2(0, -40)
	
	# 3. Calculate the ideal point on the circle
	var target_pos = center_point + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	
	# 4. DISTANCE CHECK: Are we too close?
	var dist_to_player = global_position.distance_to(center_point)
	
	var move_dir = Vector2.ZERO
	
	if dist_to_player < orbit_radius - 50:
		# TOO CLOSE: Move directly away from player
		move_dir = global_position.direction_to(center_point) * -1.2 # Move away faster
	else:
		# OUTSIDE OR ON THE CIRCLE: Move toward the orbit point
		move_dir = global_position.direction_to(target_pos)

	velocity = move_dir * speed
	
	$Sprite2D.flip_h = (player.global_position.x < global_position.x)
	
	if is_inside_tree() and not is_queued_for_deletion():
		move_and_slide()
		
	# HANDLE FILPPING AND MUZZLE POSITION
	if player.global_position.x < global_position.x:
		$Sprite2D.flip_h = true
		# Move muzzle to the left side
		$Muzzle.position.x = -abs($Muzzle.position.x)
	else:
		$Sprite2D.flip_h = false
		# Move muzzle to the right side
		$Muzzle.position.x = abs($Muzzle.position.x)
	
	if is_inside_tree() and not is_queued_for_deletion():
		move_and_slide()


func _update_facing() -> void:
	if not player:
		return

	if player.global_position.x < global_position.x:
		$Sprite2D.flip_h = true
		$Muzzle.position.x = -abs($Muzzle.position.x)
	else:
		$Sprite2D.flip_h = false
		$Muzzle.position.x = abs($Muzzle.position.x)


# 2. SHOOTING LOGIC
# Connect the ShootTimer's "timeout" signal to this function
func _on_shoot_timer_timeout():
	if is_hit or health <= 0 or not player: return
	
	print("Shooter: FIRING!")
	var b = bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	
	b.global_position = muzzle.global_position
	# Aim the bullet toward the player
	b.direction = muzzle.global_position.direction_to(player.global_position + Vector2(0, -40))
	# dMake the bullet look where it is flying
	b.rotation = b.direction.angle()

func take_damage(attacker):
	if is_hit or health <= 0: return
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

	var knock_dir = 1 if global_position.x > attacker.global_position.x else -1
	velocity = Vector2(knock_dir * 800, -200)
	modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	if health > 0:
		is_hit = false
		modulate = Color.WHITE

func die():
	defeated.emit()
	set_physics_process(false)
	$ShootTimer.stop()
	modulate = Color(10, 10, 10, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): queue_free())
