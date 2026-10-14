extends Control

signal line_finished_typing

@export var bubble_size := Vector2(1040.0, 440.0)
@export var seconds_per_char := 0.045
@export var min_line_seconds := 0.55
@export var max_line_seconds := 5.0

@onready var bubble_texture: TextureRect = $BubbleTexture
@onready var content: MarginContainer = $Content
@onready var text_label: Label = $Content/VBox/TextLabel
@onready var shop_button: Button = $Content/VBox/ShopButton
@onready var leave_button: Button = $Content/VBox/LeaveButton

var _typing := false
var _type_elapsed := 0.0
var _type_duration := 0.0
var _full_text := ""


func _ready() -> void:
	custom_minimum_size = bubble_size
	size = bubble_size
	clip_contents = true
	shop_button.text = "Open Shop"
	leave_button.text = "Leave"
	UIFonts.apply(text_label)
	UIFonts.apply(shop_button)
	UIFonts.apply(leave_button)


func _process(delta: float) -> void:
	if not _typing:
		return

	_type_elapsed += delta
	var t := clampf(_type_elapsed / _type_duration, 0.0, 1.0)
	var visible_chars := int(ceil(_full_text.length() * t))
	text_label.text = _full_text.substr(0, visible_chars)
	if t >= 1.0:
		_typing = false
		line_finished_typing.emit()


func setup(text: String, speaker_on_right: bool, show_buttons: bool) -> void:
	_typing = false
	text_label.text = ""
	_full_text = text

	bubble_texture.flip_v = true
	bubble_texture.flip_h = speaker_on_right

	var side_margin := 72
	var top_margin := 96
	var bottom_margin := 48

	if show_buttons:
		shop_button.visible = true
		leave_button.visible = true
		text_label.visible = false
		text_label.custom_minimum_size = Vector2.ZERO
		text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_margin = 92
		bottom_margin = 56
	else:
		shop_button.visible = false
		leave_button.visible = false
		text_label.visible = true
		text_label.custom_minimum_size = Vector2(0, 80)
		text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	content.add_theme_constant_override("margin_left", side_margin)
	content.add_theme_constant_override("margin_top", top_margin)
	content.add_theme_constant_override("margin_right", side_margin)
	content.add_theme_constant_override("margin_bottom", bottom_margin)

	custom_minimum_size = bubble_size
	size = bubble_size

	if show_buttons:
		return

	if text.is_empty():
		text_label.text = ""
		return

	begin_typing(text)


func begin_typing(text: String) -> void:
	_full_text = text
	_type_duration = clampf(text.length() * seconds_per_char, min_line_seconds, max_line_seconds)
	_type_elapsed = 0.0
	_typing = true
	text_label.text = ""


func show_full_text() -> void:
	_typing = false
	text_label.text = _full_text


func get_line_duration(text: String) -> float:
	return clampf(text.length() * seconds_per_char, min_line_seconds, max_line_seconds)
