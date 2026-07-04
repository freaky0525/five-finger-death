extends Area2D

@export var amount: int = 1


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		if body.has_method("add_cigarettes"):
			body.add_cigarettes(amount)
		queue_free()
