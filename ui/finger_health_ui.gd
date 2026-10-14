extends Control

@export var player: Node

@onready var palm: TextureRect = $Palm
@onready var thumb: TextureRect = $Thumb
@onready var index: TextureRect = $Index
@onready var middle: TextureRect = $Middle
@onready var ring: TextureRect = $Ring
@onready var pinky: TextureRect = $Pinky

var fingers: Array[TextureRect]


func _ready():
	add_to_group("finger_health_ui")
	fingers = [
		pinky,
		ring,
		middle,
		index,
		thumb
	]
	call_deferred("_setup_player")


func _setup_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("FingerHealthUI: Player is not assigned.")
		return

	if not player.health_changed.is_connected(update_finger_ui):
		player.health_changed.connect(update_finger_ui)

	update_finger_ui(player.current_health, player.max_health)


func update_finger_ui(current_health: int, max_health: int):
	var lost_count = max_health - current_health

	for i in range(fingers.size()):
		if i < lost_count:
			fingers[i].visible = false
		else:
			fingers[i].visible = true
