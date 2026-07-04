extends Area2D

# This signal tells the game "The player crossed the line!"
signal player_entered_zone

var has_triggered = false

func _on_body_entered(body):
	if has_triggered:
		return
		
	# Check if it's the player
	if body.name == "Player" or body.is_in_group("player"):
		print("Player crossed the line! Battle starts!")
		has_triggered = true
		player_entered_zone.emit() # Send the signal
		
		# Optional: Delete the trigger so it doesn't fire again
		# queue_free()
