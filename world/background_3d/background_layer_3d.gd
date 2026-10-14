@tool
extends Node3D
class_name BackgroundLayer3D

## One parallax layer in a 3D background scene.
## Place meshes / Sprite3D here, then tune parallax_scale in the inspector.

@export_range(0.0, 1.0, 0.01) var parallax_scale: float = 0.3
@export var scroll_axis: Vector3 = Vector3.RIGHT

var _origin: Vector3


func _ready() -> void:
	_origin = position


func apply_scroll(scroll_offset: float) -> void:
	position = _origin + scroll_axis * scroll_offset * parallax_scale


func reset_origin() -> void:
	_origin = position
