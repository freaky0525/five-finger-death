extends Area2D

@export var target_scene: String = "res://scenes/boss_arena/boss_arena.tscn"

@onready var visual: Sprite2D = $Visual
@onready var prompt: Label = $Prompt

var is_active := false


func _ready() -> void:
	_set_active_visual(false)
	prompt.text = "Enter Boss Area"
	UIFonts.apply(prompt)


func activate() -> void:
	is_active = true
	_set_active_visual(true)


func _set_active_visual(active: bool) -> void:
	visual.modulate = Color(0.4, 0.85, 1.0, 1.0) if active else Color(0.35, 0.35, 0.35, 0.6)
	prompt.visible = active


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return

	if body.name == "Player" or body.is_in_group("player"):
		GameState.save_from_player(body)
		_free_orphan_level_entities()
		get_tree().call_deferred("change_scene_to_file", target_scene)


func _free_orphan_level_entities() -> void:
	var root := get_tree().root
	for node in get_tree().get_nodes_in_group("level_entity"):
		if node.get_parent() == root:
			node.queue_free()
