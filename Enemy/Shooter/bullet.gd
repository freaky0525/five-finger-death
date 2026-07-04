extends Area2D

@export var speed = 400.0
var direction = Vector2.ZERO


func _ready() -> void:
	add_to_group("level_entity")


func _physics_process(delta):
	position += direction * speed * delta
	

# THIS IS FOR THE PLAYER (Area2D)
func _on_area_entered(area):
	var target = area
	while target != null:
		if target.has_method("take_damage"):
			# If the bullet hits, it should disappear immediately
			# so it can't trigger take_damage multiple times
			target.take_damage(self)
			queue_free() 
			return
		target = target.get_parent()


func _on_body_entered(body):
	handle_impact(body)

func handle_impact(target):
	# 1. Stop the bullet from moving
	set_physics_process(false)
	
	# 2. Check for damage
	if target.has_method("take_damage"):
		target.take_damage(self)
	elif target.get_parent().has_method("take_damage"):
		target.get_parent().take_damage(self)
	
	# 3. IMPACT TWEEN
	# We make the bullet grow and fade out quickly
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2, 2), 0.1) # Grow
	tween.tween_property(self, "modulate:a", 0.0, 0.1)     # Fade
	
	# Delete after the 0.1s animation
	tween.chain().finished.connect(queue_free)
