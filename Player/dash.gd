extends Node

@export var dash_speed = 2000.0
var is_dashing = false

@onready var player = get_parent()
@onready var anim = $"../AnimationPlayer"


func _process(_delta):
	if player.menu_locked:
		if is_dashing:
			is_dashing = false
			$DashTimer.stop()
		return

	if Input.is_action_just_pressed("dash") and $DashCooldown.is_stopped():
		is_dashing = true
		$DashTimer.start(0.3)
		$DashCooldown.start(1.0)
		anim.play("dash")
	
	if is_dashing and $DashTimer.is_stopped():
		is_dashing = false
		anim.play("idle")
