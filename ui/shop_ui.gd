extends Control

signal closed

@export var player: Node

@onready var coins_label: Label = $Panel/Margin/VBox/CoinsLabel
@onready var items_box: VBoxContainer = $Panel/Margin/VBox/ItemsBox
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

const SHOP_ITEMS := [
	{"id": "cig_1", "label": "Cigarette x1", "desc": "Restore 1 HP (press R to use)", "price": 15},
	{"id": "cig_3", "label": "Cigarette x3", "desc": "Pack of three", "price": 40},
	{"id": "shield", "label": "Shield Refill +3", "desc": "Adds block charges", "price": 30},
]


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	$Panel/Margin/VBox/Title.text = "Supply Shop"
	coins_label.text = "Coins: 0"
	close_button.text = "Close Shop"
	UIFonts.apply($Panel/Margin/VBox/Title)
	UIFonts.apply(coins_label)
	UIFonts.apply(close_button)


func open() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	coins_label.text = "Coins: %d" % GameState.coins
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
	buy_button.text = "Buy %d" % item.price
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

	coins_label.text = "Coins: %d" % GameState.coins


func _close() -> void:
	visible = false
	closed.emit()
