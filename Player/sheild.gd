extends Node

@export var shield_charges = 5
var is_defending = false

@onready var anim = $"../AnimationPlayer"
@onready var player = get_parent()

func _process(_delta):
	if player.menu_locked:
		if is_defending:
			is_defending = false
			anim.play("idle")
		return

	# Start defending: Only if we have charges and just pressed the key
	if Input.is_action_just_pressed("defend") and shield_charges > 0:
		shield_charges -= 1
		is_defending = true
		anim.play("shield") # Switch to your shield picture
	
	# Stop defending: When the key is released
	if Input.is_action_just_released("defend"):
		is_defending = false
		anim.play("idle") # Go back to normal
