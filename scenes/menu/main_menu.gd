extends Control

@export var tutorial_path: String = "res://scenes/tutorial/tutorial.tscn"
@export var level_1_path: String = "res://scenes/level_1/level_1.tscn"
@export var level_2_path: String = "res://scenes/level_2/level_2.tscn"
@export var japan_path: String = "res://scenes/japan/japan.tscn"
@export var boss_arena_path: String = "res://scenes/boss_arena/boss_arena.tscn"

@onready var menu: VBoxContainer = $Menu
@onready var level_picker: VBoxContainer = $LevelPicker


func _ready() -> void:
	level_picker.visible = false
	$Menu/NewGame.grab_focus()


func _on_new_game_pressed() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(tutorial_path)


func _on_choose_level_pressed() -> void:
	menu.visible = false
	level_picker.visible = true
	$LevelPicker/TutorialButton.grab_focus()


func _on_tutorial_pressed() -> void:
	_start_level(tutorial_path)


func _on_level_1_pressed() -> void:
	_start_level(level_1_path)


func _on_level_2_pressed() -> void:
	_start_level(level_2_path)


func _on_japan_pressed() -> void:
	_start_level(japan_path)


func _on_boss_arena_pressed() -> void:
	_start_level(boss_arena_path)


func _on_level_back_pressed() -> void:
	level_picker.visible = false
	menu.visible = true
	$Menu/ChooseLevel.grab_focus()


func _start_level(scene_path: String) -> void:
	GameState.reset()
	get_tree().change_scene_to_file(scene_path)


func _on_options_pressed() -> void:
	print("Options not ready yet")


func _on_quit_pressed() -> void:
	get_tree().quit()
