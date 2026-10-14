extends Area2D

@export var speed = 400.0
var direction = Vector2.ZERO
var max_travel_distance := 1920.0
var spawn_global_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("level_entity")
	add_to_group("enemy_bullet")
	spawn_global_position = global_position


func setup_travel_limit(limit: float) -> void:
	max_travel_distance = limit
	spawn_global_position = global_position


func _physics_process(delta):
	position += direction * speed * delta
	if global_position.distance_to(spawn_global_position) >= max_travel_distance:
		queue_free()


func _on_area_entered(area):
	var target = area
	while target != null:
		if target.has_method("take_damage"):
			target.take_damage(self)
			queue_free()
			return
		target = target.get_parent()


func _on_body_entered(body):
	handle_impact(body)


func handle_impact(target):
	set_physics_process(false)
	if target.has_method("take_damage"):
		target.take_damage(self)
	elif target.get_parent().has_method("take_damage"):
		target.get_parent().take_damage(self)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2, 2), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().finished.connect(queue_free)
