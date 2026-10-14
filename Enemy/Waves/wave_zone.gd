extends Node2D

signal wave_cleared

@export var border_left_x: float = 0.0
@export var border_right_x: float = 1000.0
@export var trigger_paths: Array[NodePath] = []
@export var spawner_paths: Array[NodePath] = []

@onready var left_border: StaticBody2D = $LeftBorder
@onready var right_border: StaticBody2D = $RightBorder
@onready var left_visual: Sprite2D = $LeftBorder/Visual
@onready var right_visual: Sprite2D = $RightBorder/Visual

const WORLD_LAYER := 1

var is_active := false
var active_enemies := 0
var completed_spawners := 0


func _ready() -> void:
	add_to_group("wave_zone")
	_position_borders()
	_set_borders_enabled(false)

	for trigger_path in trigger_paths:
		get_parent().get_node(trigger_path).player_entered_zone.connect(_on_wave_triggered)

	for spawner_path in spawner_paths:
		var spawner = get_parent().get_node(spawner_path)
		spawner.enemy_spawned.connect(_on_enemy_spawned)
		spawner.spawning_complete.connect(_on_spawner_complete)


func _position_borders() -> void:
	var center_y := 250.0
	left_border.position = Vector2(border_left_x, center_y)
	right_border.position = Vector2(border_right_x, center_y)


func _on_wave_triggered() -> void:
	if is_active:
		return

	is_active = true
	completed_spawners = 0
	active_enemies = 0
	_set_borders_enabled(true)

	for spawner_path in spawner_paths:
		var spawner := get_parent().get_node(spawner_path)
		if spawner.has_method("start_spawning"):
			spawner.start_spawning()


func _on_enemy_spawned(enemy: Node) -> void:
	if not is_active:
		return

	if enemy.get_meta("wave_tracked", false):
		return

	enemy.set_meta("wave_tracked", true)
	active_enemies += 1

	var on_removed := func() -> void:
		_unregister_enemy(enemy)

	if enemy.has_signal("defeated"):
		enemy.defeated.connect(on_removed, CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(on_removed, CONNECT_ONE_SHOT)


func _unregister_enemy(enemy: Node) -> void:
	if not is_active:
		return

	if enemy.get_meta("wave_counted_out", false):
		return

	enemy.set_meta("wave_counted_out", true)
	active_enemies = max(active_enemies - 1, 0)
	_check_wave_cleared()


func _on_spawner_complete() -> void:
	completed_spawners += 1
	_check_wave_cleared()


func _check_wave_cleared() -> void:
	if not is_active:
		return

	if completed_spawners < spawner_paths.size():
		return

	if active_enemies > 0:
		return

	is_active = false
	_set_borders_enabled(false)
	wave_cleared.emit()


func reset() -> void:
	is_active = false
	active_enemies = 0
	completed_spawners = 0
	_set_borders_enabled(false)


func _set_borders_enabled(enabled: bool) -> void:
	var layer := WORLD_LAYER if enabled else 0
	left_border.collision_layer = layer
	right_border.collision_layer = layer
	left_visual.visible = enabled
	right_visual.visible = enabled
