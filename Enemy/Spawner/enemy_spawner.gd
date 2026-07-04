extends Node2D

signal enemy_spawned(enemy: Node)
signal spawning_complete

@export var enemy_scene: PackedScene # Drag Enemy.tscn here
@export var spawn_limit = 3 # How many enemies to spawn total?
@export var spawn_interval = 1.0 # How fast they come out (seconds)

@onready var timer = $Timer

var enemies_spawned_so_far = 0
var has_reported_complete := false

func _ready():
	# Set the timer's speed based on your setting
	timer.wait_time = spawn_interval

func start_spawning():
	print("Spawner Activated! Incoming Wave: ", spawn_limit)
	has_reported_complete = false
	timer.start()

func stop_spawning():
	timer.stop()

func _on_timer_timeout():
	# 1. Check if we reached the limit
	if enemies_spawned_so_far >= spawn_limit:
		stop_spawning()
		print("Wave Complete.")
		if not has_reported_complete:
			has_reported_complete = true
			spawning_complete.emit()
		return

	# 2. Spawn the enemy
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = $Marker2D.global_position

		# Optional: Add small random offset so they don't stack perfectly
		enemy.global_position.x += randf_range(-20, 20)
		enemy.global_position.y += randf_range(-20, 20)
		enemy_spawned.emit(enemy)
	
	# 3. Increase the counter
	enemies_spawned_so_far += 1


func _on_area_2d_player_entered_zone() -> void:
	pass # Replace with function body.


func _on_area_2d_2_player_entered_zone() -> void:
	pass # Replace with function body.
