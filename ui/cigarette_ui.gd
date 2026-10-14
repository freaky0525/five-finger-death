extends Control

@export var player: Node

@onready var pack: TextureRect = $Pack
@onready var count_label: Label = $CountLabel
@onready var hint_label: Label = $HintLabel


func _ready() -> void:
	hint_label.text = "R to heal"
	UIFonts.apply(hint_label)
	UIFonts.apply(count_label)
	call_deferred("_setup_player")


func _setup_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("CigaretteUI: Player is not assigned.")
		return

	if not player.cigarettes_changed.is_connected(update_ui):
		player.cigarettes_changed.connect(update_ui)

	update_ui(player.cigarettes)


func update_ui(count: int) -> void:
	count_label.text = "x%d" % count
	count_label.visible = true
	pack.visible = count > 0
	hint_label.visible = count > 0
