extends Node2D

enum Step { MOVE, PUNCH, DASH, DEFEND, DONE }

const MESSAGES := {
	Step.MOVE: "Use WASD to move",
	Step.PUNCH: "Left-click to attack the enemy on your right",
	Step.DASH: "Enemies shoot! Press Shift to dash and dodge bullets",
	Step.DEFEND: "Enemies shoot from all sides! Hold Ctrl to block bullets",
	Step.DONE: "Tutorial complete! Entering Level 1...",
}

const DASH_LANE_Y := 300.0
const DASH_LANE_HALF_HEIGHT := 90.0
const DASH_TOP_BORDER_Y := 210.0
const DASH_BOTTOM_BORDER_Y := 390.0

@export var level_1_path: String = "res://scenes/level_1/level_1.tscn"
@export var melee_enemy_scene: PackedScene = preload("res://Enemy/Melee/enemy_melee.tscn")
@export var shooter_enemy_scene: PackedScene = preload("res://Enemy/Shooter/enemy_shooter.tscn")

@onready var player: CharacterBody2D = $Player
@onready var prompt_label: Label = $CanvasLayer/TutorialPrompt/Label
@onready var prompt_panel: PanelContainer = $CanvasLayer/TutorialPrompt
@onready var melee_spawn: Marker2D = $MeleeSpawn
@onready var shooter_spawn: Marker2D = $ShooterSpawn

var current_step := Step.MOVE
var start_position: Vector2
var is_transitioning := false
var dash_lane_borders: Array[StaticBody2D] = []


func _ready() -> void:
	GameState.reset()
	_clear_dash_lane()
	player.minimum_health = 1
	player.get_node("Camera2D").lock_horizontal = true
	start_position = player.position
	UIFonts.apply(prompt_label)
	_show_step(current_step)


func _process(_delta: float) -> void:
	match current_step:
		Step.MOVE:
			if player.position.distance_to(start_position) > 60.0:
				_advance()
		Step.DASH:
			player.position.y = DASH_LANE_Y


func _spawn_melee_practice() -> void:
	var enemy := melee_enemy_scene.instantiate()
	enemy.global_position = melee_spawn.global_position
	enemy.is_stationary = true
	enemy.health = 1
	enemy.add_to_group("tutorial_enemy")
	add_child(enemy)
	enemy.defeated.connect(_advance, CONNECT_ONE_SHOT)


func _spawn_dash_shooter() -> void:
	_spawn_dash_lane()
	player.position.y = DASH_LANE_Y

	var shooter := shooter_enemy_scene.instantiate()
	shooter.global_position = shooter_spawn.global_position
	shooter.is_stationary = true
	shooter.health = 999
	shooter.add_to_group("tutorial_enemy")
	shooter.get_node("ShootTimer").wait_time = 1.4
	add_child(shooter)
	player.dodge_successful.connect(_advance, CONNECT_ONE_SHOT)


func _spawn_defend_shooters() -> void:
	_clear_dash_lane()
	player.get_node("ShieldComponent").shield_charges = 5

	var center := Vector2(960, DASH_LANE_Y)
	for i in DEFEND_SHOOTER_COUNT:
		var angle := (TAU / DEFEND_SHOOTER_COUNT) * i
		var pos := center + Vector2(cos(angle), sin(angle)) * DEFEND_CIRCLE_RADIUS

		var shooter := shooter_enemy_scene.instantiate()
		shooter.global_position = pos
		shooter.is_stationary = true
		shooter.health = 999
		shooter.add_to_group("tutorial_enemy")
		shooter.get_node("ShootTimer").wait_time = 1.8
		add_child(shooter)

	player.attack_blocked.connect(_advance, CONNECT_ONE_SHOT)


const DEFEND_SHOOTER_COUNT := 6
const DEFEND_CIRCLE_RADIUS := 380.0


func _spawn_dash_lane() -> void:
	_clear_dash_lane()
	dash_lane_borders.append(_create_lane_border(DASH_TOP_BORDER_Y))
	dash_lane_borders.append(_create_lane_border(DASH_BOTTOM_BORDER_Y))
	for border in dash_lane_borders:
		add_child(border)


func _create_lane_border(y_pos: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(960, y_pos)
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("tutorial_border")

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2200, 40)
	shape_node.shape = rect
	body.add_child(shape_node)

	var visual := Sprite2D.new()
	visual.texture = preload("res://asset/environment/wall.png")
	visual.modulate = Color(1, 0.35, 0.35, 0.55)
	visual.scale = Vector2(14, 0.35)
	body.add_child(visual)

	return body


func _clear_dash_lane() -> void:
	for border in dash_lane_borders:
		if is_instance_valid(border):
			border.queue_free()
	dash_lane_borders.clear()

	for node in get_tree().get_nodes_in_group("tutorial_border"):
		if is_instance_valid(node):
			node.queue_free()


func _clear_tutorial_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("tutorial_enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()


func _show_step(step: Step) -> void:
	prompt_label.text = MESSAGES[step]
	prompt_panel.visible = true


func _advance() -> void:
	if current_step >= Step.DONE or is_transitioning:
		return

	_clear_tutorial_enemies()
	current_step += 1
	_show_step(current_step)

	match current_step:
		Step.PUNCH:
			_spawn_melee_practice()
		Step.DASH:
			_spawn_dash_shooter()
		Step.DEFEND:
			_spawn_defend_shooters()
		Step.DONE:
			_finish_tutorial()


func _finish_tutorial() -> void:
	is_transitioning = true
	_clear_dash_lane()
	GameState.player_health = player.max_health
	GameState.save_from_player(player)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(level_1_path)
