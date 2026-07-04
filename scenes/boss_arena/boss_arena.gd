extends Node2D

@export var boss_scene: PackedScene = preload("res://Enemy/Boss/boss.tscn")
@export var boss_spawn_position: Vector2 = Vector2(7000, 220)

var boss_spawned := false


func _ready() -> void:
	GameState.apply_to_player($Player)
	var finger_ui: Control = $CanvasLayer/FingerHealthUI
	if finger_ui.has_method("update_finger_ui"):
		finger_ui.update_finger_ui($Player.current_health, $Player.max_health)
	if GameState.coins <= 0:
		GameState.coins = 50

	$BossTrigger.player_entered_zone.connect(_on_boss_trigger_entered)
	$Merchant.interact_requested.connect(_on_merchant_interact)
	call_deferred("_connect_ui")


func _connect_ui() -> void:
	var dialogue := $CanvasLayer/DialogueUI
	var shop := $CanvasLayer/ShopUI
	if dialogue.has_signal("shop_requested"):
		dialogue.shop_requested.connect(_on_shop_requested)
	if dialogue.has_signal("closed"):
		dialogue.closed.connect(_on_menu_closed)
	if shop.has_signal("closed"):
		shop.closed.connect(_on_menu_closed)


func _on_merchant_interact() -> void:
	if $CanvasLayer/DialogueUI.visible or $CanvasLayer/ShopUI.visible:
		return

	$Player.menu_locked = true
	$CanvasLayer/DialogueUI.open(
		"\u563f\uff0c\u964c\u751f\u4eba\u2026\u2026\n\n\u524d\u9762\u5c31\u662f Boss \u7684\u9818\u57df\u4e86\u3002\n\u60f3\u6d3b\u547d\uff1f\u5728\u6211\u9019\u88dc\u7d66\u5427\u3002\n\n\uff08\u6309\u300c\u958b\u555f\u5546\u5e97\u300d\u8cfc\u8cb7\u9999\u83f8\u548c\u76fe\u5145\u80fd\uff09"
	)


func _on_shop_requested() -> void:
	$CanvasLayer/ShopUI.open()


func _on_menu_closed() -> void:
	if $CanvasLayer/DialogueUI.visible or $CanvasLayer/ShopUI.visible:
		return
	$Player.menu_locked = false


func _on_boss_trigger_entered() -> void:
	if boss_spawned:
		return

	boss_spawned = true
	var boss := boss_scene.instantiate()
	add_child(boss)
	boss.global_position = boss_spawn_position
