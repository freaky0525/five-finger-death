extends Control

@export var tutorial_path: String = "res://scenes/tutorial/tutorial.tscn"
@export var level_1_path: String = "res://scenes/level_1/level_1.tscn"

func _ready() -> void:
	$Menu/NewGame.grab_focus()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(tutorial_path)

func _on_options_pressed() -> void:
	print("Options not ready yet")

func _on_quit_pressed() -> void:
	get_tree().quit()
