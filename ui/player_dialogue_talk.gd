extends Node2D

const TALK_DIR := "res://asset/ui/dialogue_talk/"
const SHADER := preload("res://ui/dialogue_talk_key.gdshader")

@export var talk_fps := 22.0
@export var base_scale := 0.38

@onready var sprite: Sprite2D = $Sprite2D

var _textures: Array[Texture2D] = []
var _frame := 0
var _tick := 0.0
var _active := false
var _player: Node2D


func _ready() -> void:
	_load_textures()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	sprite.material = mat
	sprite.texture = _textures[0] if _textures.size() > 0 else null
	visible = false
	z_index = 50


func bind_player(player: Node2D) -> void:
	_player = player


func _load_textures() -> void:
	_textures.clear()
	for i in range(1, 4):
		var tex := load("%stalk_%d.jpg" % [TALK_DIR, i]) as Texture2D
		if tex:
			_textures.append(tex)


func _process(delta: float) -> void:
	if not _active or _textures.is_empty():
		return

	_sync_to_player()

	_tick += delta
	var frame_time := 1.0 / talk_fps
	if _tick >= frame_time:
		_tick -= frame_time
		_frame = (_frame + 1) % _textures.size()
		sprite.texture = _textures[_frame]


func _sync_to_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	global_position = _player.global_position
	var player_sprite: Sprite2D = _player.get_node_or_null("Sprite2D") as Sprite2D
	if player_sprite:
		var s := player_sprite.scale.x * base_scale
		scale = Vector2(s, s)
		sprite.flip_h = player_sprite.flip_h


func start() -> void:
	if _textures.is_empty():
		return
	_active = true
	visible = true
	_frame = 0
	_tick = 0.0
	sprite.texture = _textures[0]
	_sync_to_player()


func stop() -> void:
	_active = false
	visible = false


func is_active() -> bool:
	return _active
