extends CharacterBody2D

signal defeated

@export var health := 5
@export var speed := 90.0
@export var keep_distance := 1250.0
@export var dodge_radius := 300.0
@export var minion_scene: PackedScene
@export var minions_per_cast := 2
@export var minion_stagger := 0.5
@export var summon_cooldown := 3.0
@export var max_minions := 2
@export var minion_spawn_min_dist := 220.0
@export var minion_spawn_max_dist := 420.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var summon_timer: Timer = $SummonTimer

var _is_hit := false
var _player: CharacterBody2D
var _minions: Array[Node] = []


func _ready() -> void:
	add_to_group("level_entity")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	summon_timer.stop()
	call_deferred("_begin_summoning")


func _begin_summoning() -> void:
	if health <= 0 or not is_inside_tree():
		return
	_summon_loop()


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

	var move := Vector2.ZERO
	var to_player := global_position.direction_to(_player.global_position)
	var dist := global_position.distance_to(_player.global_position)

	if dist < keep_distance - 50.0:
		move -= to_player
	elif dist > keep_distance + 120.0:
		move += to_player * 0.35

	move += _compute_bullet_dodge()

	if move.length_squared() > 0.001:
		move = move.normalized()
	velocity = move * speed
	sprite.flip_h = _player.global_position.x < global_position.x
	move_and_slide()


func _compute_bullet_dodge() -> Vector2:
	var dodge := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemy_bullet"):
		if not is_instance_valid(node):
			continue
		var bullet := node as Area2D
		var offset := global_position - bullet.global_position
		var dist := offset.length()
		if dist > dodge_radius or dist < 1.0:
			continue

		var bullet_dir: Vector2 = bullet.get("direction")
		if bullet_dir == null:
			continue
		var bullet_speed: float = bullet.get("speed")
		if bullet_speed == null:
			bullet_speed = 400.0
		var bullet_vel := bullet_dir.normalized() * bullet_speed
		if bullet_vel.length_squared() < 1.0:
			continue

		# Bullet heading toward this enemy.
		if bullet_vel.normalized().dot(offset.normalized()) < 0.35:
			continue

		var weight := 1.0 - (dist / dodge_radius)
		dodge += offset.normalized() * weight

	return dodge


func _summon_loop() -> void:
	while is_inside_tree() and health > 0:
		await _cast_summons()
		if health <= 0 or not is_inside_tree():
			return
		await get_tree().create_timer(summon_cooldown).timeout


func _cast_summons() -> void:
	if minion_scene == null:
		return

	for i in minions_per_cast:
		if health <= 0 or not is_inside_tree():
			return
		_spawn_one_minion(i)
		if i < minions_per_cast - 1:
			await get_tree().create_timer(minion_stagger, true).timeout


func _spawn_one_minion(index: int = 0) -> void:
	if health <= 0 or minion_scene == null:
		return
	_prune_minions()
	if _minions.size() >= max_minions:
		return

	var minion := minion_scene.instantiate()
	get_tree().current_scene.add_child(minion)
	minion.global_position = _pick_minion_spawn_position(index)
	_minions.append(minion)
	if minion.has_signal("defeated"):
		minion.defeated.connect(_on_minion_defeated.bind(minion), CONNECT_ONE_SHOT)


func _pick_minion_spawn_position(index: int = 0) -> Vector2:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	var toward := Vector2.LEFT
	if _player != null:
		toward = global_position.direction_to(_player.global_position)
		if toward.length_squared() < 0.001:
			toward = Vector2.LEFT

	var spawn_dist := randf_range(minion_spawn_min_dist, minion_spawn_max_dist)
	var lateral := Vector2(-toward.y, toward.x)
	var spread := 120.0 if index % 2 == 0 else -120.0
	return global_position + toward * spawn_dist + lateral * spread


func _on_minion_defeated(minion: Node) -> void:
	_minions.erase(minion)


func _prune_minions() -> void:
	for i in range(_minions.size() - 1, -1, -1):
		if not is_instance_valid(_minions[i]):
			_minions.remove_at(i)


func take_damage(attacker) -> void:
	if _is_hit or health <= 0:
		return

	health -= 1
	if health <= 0:
		die()
		return

	_is_hit = true
	modulate = Color.RED
	await get_tree().create_timer(0.35).timeout
	if health > 0:
		_is_hit = false
		modulate = Color.WHITE


func die() -> void:
	defeated.emit()
	summon_timer.stop()
	_clear_minions()
	set_physics_process(false)
	modulate = Color(10, 10, 10, 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): queue_free())


func _clear_minions() -> void:
	_prune_minions()
	for minion in _minions:
		if is_instance_valid(minion):
			minion.queue_free()
	_minions.clear()
