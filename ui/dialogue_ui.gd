extends Control

signal shop_requested
signal closed

@onready var text_label: Label = $Panel/Margin/VBox/TextLabel
@onready var shop_button: Button = $Panel/Margin/VBox/ShopButton
@onready var leave_button: Button = $Panel/Margin/VBox/LeaveButton


func _ready() -> void:
	visible = false
	shop_button.pressed.connect(_on_shop_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	shop_button.text = "\u958b\u555f\u5546\u5e97"
	leave_button.text = "\u96e2\u958b"
	UIFonts.apply(text_label)
	UIFonts.apply(shop_button)
	UIFonts.apply(leave_button)
	var title: Label = $Panel/Margin/VBox/Title
	UIFonts.apply(title)


func open(text: String) -> void:
	text_label.text = text
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_shop_pressed() -> void:
	visible = false
	shop_requested.emit()


func _on_leave_pressed() -> void:
	close()
