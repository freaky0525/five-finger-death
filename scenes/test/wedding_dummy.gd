extends Node2D

var health := 3
var down := false
var _cracks: Array[Texture2D] = []


func _ready() -> void:
	_ensure_texture()
	_cracks = [
		_load_png("res://asset/wedding/25_dummy_hit_01.png"),
		_load_png("res://asset/wedding/26_dummy_hit_02.png"),
	]
	var body := get_node_or_null("Body") as Sprite2D
	var area := Area2D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex_size := Vector2(682, 1024)
	if body != null and body.texture != null:
		tex_size = body.texture.get_size()
	rect.size = tex_size * 0.82
	shape_node.shape = rect
	area.add_child(shape_node)
	if body != null:
		body.add_child(area)
	else:
		shape_node.position = Vector2(0, -210)
		add_child(area)


func _ensure_texture() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null or body.texture != null:
		return
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path("res://asset/wedding/20_dummy_wood_hand.png"))
	if err != OK:
		return
	body.texture = ImageTexture.create_from_image(image)


func _load_png(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func take_damage(_attacker) -> void:
	if down:
		return
	health -= 1
	var body := get_node_or_null("Body") as Sprite2D
	if health <= 0:
		down = true
		_vanish()
		return
	var crack_i := 2 - health
	if body != null and crack_i >= 0 and crack_i < _cracks.size() and _cracks[crack_i] != null:
		body.texture = _cracks[crack_i]
	modulate = Color(1, 0.86, 0.78)
	var kick := create_tween()
	kick.tween_property(self, "modulate", Color.WHITE, 0.16)
	kick.parallel().tween_property(self, "rotation_degrees", -12.0, 0.07)
	kick.tween_property(self, "rotation_degrees", 0.0, 0.14)


func _vanish() -> void:
	_drop_sign()
	modulate = Color.WHITE
	var body := get_node_or_null("Body") as CanvasItem
	if body == null:
		visible = false
		return
	var fade := create_tween()
	fade.tween_property(body, "modulate:a", 0.0, 0.16)
	fade.tween_callback(func() -> void: body.visible = false)


func _drop_sign() -> void:
	var sign := get_node_or_null("Sign") as Sprite2D
	if sign == null:
		return
	var rest := sign.global_position
	var root := get_parent()
	remove_child(sign)
	root.add_child(sign)
	sign.global_position = rest
	sign.z_index = 6
	var drop := create_tween()
	drop.set_parallel(true)
	drop.tween_property(sign, "global_position", rest + Vector2(36, 220), 0.4)
	drop.tween_property(sign, "rotation_degrees", 16.0, 0.4)
