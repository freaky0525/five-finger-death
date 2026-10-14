extends CanvasLayer

## Renders a 3D background scene behind 2D gameplay.
## Gameplay stays 2D; only the backdrop is composed in 3D.

@export var background_scene: PackedScene
@export var canvas_layer: int = -100

@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport

var _background_root: BackgroundScene3D


func _ready() -> void:
	layer = canvas_layer
	_viewport.transparent_bg = true
	_viewport.size = get_viewport().get_visible_rect().size

	if background_scene:
		_background_root = background_scene.instantiate() as BackgroundScene3D
		_viewport.add_child(_background_root)

	get_tree().root.size_changed.connect(_on_viewport_resized)


func _process(_delta: float) -> void:
	if _background_root == null:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_background_root.update_from_player(player.global_position.x)


func _on_viewport_resized() -> void:
	if _viewport:
		_viewport.size = get_viewport().get_visible_rect().size
	if _background_root:
		_background_root._sync_camera_size()
