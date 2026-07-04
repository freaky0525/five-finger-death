extends StaticBody2D

signal interact_requested

@onready var prompt: Label = $InteractPrompt

var player_in_range := false


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	prompt.text = "[G] \u5c0d\u8a71"
	UIFonts.apply(prompt)
	prompt.visible = false


func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		interact_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt.visible = false
