extends Node

@onready var player = get_parent()
@onready var hitbox_area = $"../PunchHitbox"
@onready var hitbox_shape = $"../PunchHitbox/CollisionShape2D"
@onready var sprite = $"../Sprite2D"

var is_attacking = false

func _process(_delta):
	if player.menu_locked:
		return

	if Input.is_action_just_pressed("punch") and not is_attacking:
		punch()

func punch():
	is_attacking = true
	
	# Flip the hitbox based on where the player is looking
	if sprite.flip_h:
		hitbox_area.position.x = -abs(hitbox_area.position.x)
	else:
		hitbox_area.position.x = abs(hitbox_area.position.x)

	# Enable the hitbox
	hitbox_shape.disabled = false
	
	# Wait for a short duration (the length of the punch)
	await get_tree().create_timer(0.2).timeout
	
	# Disable the hitbox
	hitbox_shape.disabled = true
	is_attacking = false

# THIS IS THE KEY: 
# Go to your PunchHitbox in the Editor -> Node Tab -> Signals 
# Connect 'area_entered' to this function below:
func _on_punch_hitbox_area_entered(area):
	
	var current_node = area
	while current_node != null:
		if current_node.has_method("take_damage"):
			current_node.take_damage(player)
			return # Stop searching once we hit the enemy
		current_node = current_node.get_parent()
