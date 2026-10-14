extends Area2D

const FRAMES: Array[Texture2D] = [
	preload("res://asset/enemies/ninja/fireball_01.png"),
	preload("res://asset/enemies/ninja/fireball_02.png"),
	preload("res://asset/enemies/ninja/fireball_03.png"),
	preload("res://asset/enemies/ninja/fireball_04.png"),
	preload("res://asset/enemies/ninja/fireball_05.png"),
	preload("res://asset/enemies/ninja/fireball_06.png"),
]
const FRAME_SECONDS := 0.07

@export var speed := 460.0
var direction := Vector2.LEFT
var _spawn := Vector2.ZERO
var _armed := false
var _max_distance := 2400.0
var _frame_time := 0.0


func _ready() -> void:
	add_to_group("enemy_bullet")
	z_index = 5
	$Sprite2D.texture = FRAMES[0]
	$Sprite2D.scale = Vector2(0.85, 0.85)


func arm() -> void:
	_spawn = global_position
	_armed = true
	if direction.length_squared() > 0.001:
		rotation = direction.angle()


func _process(delta: float) -> void:
	if not _armed:
		return
	_frame_time += delta
	var index := int(_frame_time / FRAME_SECONDS) % FRAMES.size()
	$Sprite2D.texture = FRAMES[index]


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	position += direction * speed * delta
	if global_position.distance_to(_spawn) >= _max_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target: Node = area
	while target != null:
		if target.has_method("take_damage"):
			target.take_damage(self)
			queue_free()
			return
		target = target.get_parent()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(self)
		queue_free()
