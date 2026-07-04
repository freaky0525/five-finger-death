extends Control

signal closed

@export var player: Node

@onready var coins_label: Label = $Panel/Margin/VBox/CoinsLabel
@onready var items_box: VBoxContainer = $Panel/Margin/VBox/ItemsBox
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

const SHOP_ITEMS := [
	{"id": "cig_1", "label": "\u9999\u83f8 x1", "desc": "\u56de 1 HP\uff08\u6309 R \u4f7f\u7528\uff09", "price": 15},
	{"id": "cig_3", "label": "\u9999\u83f8 x3", "desc": "\u4e00\u5305\u4e09\u6839", "price": 40},
	{"id": "shield", "label": "\u76fe\u5145\u80fd +3", "desc": "\u589e\u52a0\u683c\u64cb\u6b21\u6578", "price": 30},
]


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	$Panel/Margin/VBox/Title.text = "\u88dc\u7d66\u5546\u5e97"
	coins_label.text = "\u91d1\u5e63\uff1a0"
	close_button.text = "\u95dc\u9589\u5546\u5e97"
	UIFonts.apply($Panel/Margin/VBox/Title)
	UIFonts.apply(coins_label)
	UIFonts.apply(close_button)


func open() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	coins_label.text = "\u91d1\u5e63\uff1a%d" % GameState.coins
	for child in items_box.get_children():
		child.queue_free()

	for item in SHOP_ITEMS:
		items_box.add_child(_make_item_row(item))


func _make_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_make_label(item.label, 24))
	info.add_child(_make_label(item.desc, 16, Color(0.8, 0.8, 0.8)))
	row.add_child(info)

	var buy_button := Button.new()
	buy_button.text = "\u8cfc\u8cb7 %d" % item.price
	buy_button.custom_minimum_size = Vector2(140, 48)
	UIFonts.apply(buy_button)
	buy_button.pressed.connect(_buy.bind(item))
	row.add_child(buy_button)

	return row


func _make_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	UIFonts.apply(label)
	return label


func _resolve_player() -> CharacterBody2D:
	if is_instance_valid(player):
		return player as CharacterBody2D
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _buy(item: Dictionary) -> void:
	var p := _resolve_player()
	if p == null:
		push_warning("ShopUI: missing player reference.")
		return

	if GameState.coins < item.price:
		return

	GameState.coins -= item.price

	match item.id:
		"cig_1":
			p.add_cigarettes(1)
		"cig_3":
			p.add_cigarettes(3)
		"shield":
			var shield := p.get_node_or_null("ShieldComponent")
			if shield:
				shield.shield_charges += 3

	coins_label.text = "\u91d1\u5e63\uff1a%d" % GameState.coins


func _close() -> void:
	visible = false
	closed.emit()
