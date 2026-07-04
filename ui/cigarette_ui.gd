extends Control

@export var player: Node

@onready var pack: TextureRect = $Pack
@onready var count_label: Label = $CountLabel
@onready var hint_label: Label = $HintLabel


func _ready() -> void:
	if player == null:
		return

	hint_label.text = "R \u62bd\u83f8\u56de\u8840"
	UIFonts.apply(hint_label)
	UIFonts.apply(count_label)
	player.cigarettes_changed.connect(update_ui)
	update_ui(player.cigarettes)


func update_ui(count: int) -> void:
	count_label.text = "x%d" % count
	pack.visible = count > 0
	count_label.visible = count > 0
	hint_label.visible = count > 0
