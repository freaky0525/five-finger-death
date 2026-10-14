@tool
extends Node3D
class_name BackgroundScene3D

## Root node for a level background authored in 3D.
## The orthographic camera stays fixed; layers move at different parallax speeds.

@export var pixels_to_world: float = 0.01
@export var scroll_origin_pixels: float = 0.0
@export var camera_y: float = 3.0
@export var camera_z: float = 18.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	if _camera:
		_camera.position = Vector3(0.0, camera_y, camera_z)
		_sync_camera_size()


func _sync_camera_size() -> void:
	if _camera == null or not _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return

	var viewport_height := get_viewport().get_visible_rect().size.y
	_camera.size = viewport_height * pixels_to_world * 0.5


func update_from_player(player_x_pixels: float) -> void:
	var scroll_offset := (player_x_pixels - scroll_origin_pixels) * pixels_to_world
	for child in get_children():
		if child is BackgroundLayer3D:
			child.apply_scroll(scroll_offset)
