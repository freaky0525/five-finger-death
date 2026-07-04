extends Node

var player_health: int = 5
var player_max_health: int = 5
var cigarettes: int = 0
var coins: int = 0


func reset() -> void:
	player_health = 5
	player_max_health = 5
	cigarettes = 0
	coins = 0


func save_from_player(player: CharacterBody2D) -> void:
	player_health = player.current_health
	player_max_health = player.max_health
	cigarettes = player.cigarettes


func apply_to_player(player: CharacterBody2D) -> void:
	player.max_health = player_max_health
	player.current_health = clampi(player_health, 0, player.max_health)
	player.cigarettes = cigarettes
	player.health_changed.emit(player.current_health, player.max_health)
	player.cigarettes_changed.emit(player.cigarettes)
