extends CanvasLayer

const OPEN_TIME := 1.05
const WIPE := preload("res://ui/iris_wipe.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.color = Color.BLACK
	_mat = ShaderMaterial.new()
	_mat.shader = WIPE
	_rect.material = _mat
	add_child(_rect)
	_fit()
	get_viewport().size_changed.connect(_fit)


func change_scene(path: String) -> void:
	if _busy or path.is_empty():
		return
	_busy = true
	_cover()
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		_hide()
		_busy = false
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await _open_on_player()
	_busy = false


func reload_current() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	change_scene(scene.scene_file_path)


func _cover() -> void:
	_fit()
	_mat.set_shader_parameter("center", Vector2(0.5, 0.5))
	_mat.set_shader_parameter("radius", 0.0)
	visible = true


func _open_on_player() -> void:
	var t := 0.0
	while t < OPEN_TIME:
		var uv := _player_uv()
		_mat.set_shader_parameter("center", uv)
		var u := clampf(t / OPEN_TIME, 0.0, 1.0)
		u = 1.0 - pow(1.0 - u, 3.0)
		_mat.set_shader_parameter("radius", lerpf(0.07, _cover_radius(uv), u))
		await get_tree().process_frame
		t += get_process_delta_time()
	_hide()


func _player_uv() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2(0.5, 0.5)
	var xform := get_viewport().get_canvas_transform()
	var screen := xform * player.global_position
	var size := get_viewport().get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return Vector2(0.5, 0.5)
	return screen / size


func _cover_radius(center: Vector2) -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var farthest := 0.0
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
	for corner in corners:
		var point := Vector2(corner) - center
		point.x *= aspect
		farthest = maxf(farthest, point.length())
	return farthest + 0.12


func _fit() -> void:
	if _rect == null:
		return
	var size := get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = size
	if _mat != null and size.y > 1.0:
		_mat.set_shader_parameter("aspect", size.x / size.y)


func _hide() -> void:
	visible = false
	_mat.set_shader_parameter("radius", 0.0)
