extends CharacterBody2D

# 1. SETUP VARIABLES
@export var max_health = 10
@export var dash_speed = 1000.0
@export var bullet_scene: PackedScene # Drag bullet.tscn here
@export var contact_damage: int = 2
@export var contact_damage_cooldown: float = 1.0

var can_contact_damage: bool = true

@onready var player = get_tree().get_first_node_in_group("player")
@onready var muzzle = $Muzzle
@onready var sprite = $Sprite2D
@onready var timer = $ActionTimer
@onready var anim = $AnimationPlayer

# These are the "States" the boss can be in
enum State { IDLE, SHOOTING, PRE_DASH, DASHING, RESTING }
var current_state = State.IDLE

var health = max_health
var bullets_fired = 0

func _ready():
	health = max_health
	# Wait 2 seconds before starting the first attack
	start_resting(2.0)
	
# Call this inside _physics_process(delta)
func start_contact_damage_cooldown():
	can_contact_damage = false
	await get_tree().create_timer(contact_damage_cooldown).timeout
	can_contact_damage = true
func check_for_player_contact():
	if not can_contact_damage:
		return

	var areas = $TouchArea.get_overlapping_areas()
	
	for area in areas:
		if area.get_parent().has_method("take_damage") and area.get_parent().name == "Player":
			if area.get_parent().is_dead:
				return
			area.get_parent().take_damage(self, contact_damage)
			start_contact_damage_cooldown()
			return
			
		elif area.has_method("take_damage"):
			area.take_damage(self, contact_damage)
			start_contact_damage_cooldown()
			return

func _physics_process(delta):
	check_for_player_contact()
	if not is_inside_tree() or health <= 0 or not player:
		return

	match current_state:
		State.IDLE:
			# Just waiting for the timer to pick a move
			velocity = Vector2.ZERO
			
		State.SHOOTING:
			# Stay still while shooting
			velocity = Vector2.ZERO
			look_at_player()
			
		State.PRE_DASH:
			# Shaking or warning before dashing
			velocity = Vector2.ZERO
			look_at_player()
			
		State.DASHING:
			# Move fast in the current direction (friction applies)
			velocity = velocity.move_toward(Vector2.ZERO, 200 * delta)
			move_and_slide()
			
		State.RESTING:
			# Panting/Tired. Not moving.
			velocity = Vector2.ZERO
			sprite.modulate = Color.WHITE # Normal color

# --- DECISION MAKING ---
func pick_next_attack():
	if health <= 0: return
	
	# Randomly choose: 0 = Shoot, 1 = Dash
	var choice = randi() % 2 
	
	if choice == 0:
		start_shooting_sequence()
	else:
		start_dash_sequence()

# --- ATTACK 1: SHOOTING ---
func start_shooting_sequence():
	current_state = State.SHOOTING
	bullets_fired = 0
	print("Boss: Machine Gun Mode!")
	
	# PLAY ANIMATION HERE
	anim.play("shoot") 
	
	for i in range(5):
		if health <= 0: return
		fire_bullet()
		await get_tree().create_timer(0.3).timeout
	
	start_resting(2.0)

func fire_bullet():
	if not bullet_scene: return
	var b = bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = muzzle.global_position
	b.direction = muzzle.global_position.direction_to(player.global_position)
	b.rotation = b.direction.angle()

# --- ATTACK 2: DASHING ---
func start_dash_sequence():
	print("Boss: Prepare to Charge!")
	current_state = State.PRE_DASH
	
	# PLAY WARNING ANIMATION
	anim.play("pre_dash") 
	
	# Wait 1 second (warning time)
	await get_tree().create_timer(1.0).timeout
	
	if health <= 0: return
	
	# DASH TIME
	current_state = State.DASHING
	anim.play("idle") # Stop flashing red while moving
	
	var dash_dir = global_position.direction_to(player.global_position)
	velocity = dash_dir * dash_speed
	
	await get_tree().create_timer(0.5).timeout
	start_resting(1.5)
# --- UTILITY ---
func start_resting(time):
	print("Boss: Resting...")
	current_state = State.RESTING
	timer.wait_time = time
	timer.start()

# When the Rest Timer finishes, pick a new move
func _on_action_timer_timeout():
	pick_next_attack()

func look_at_player():
	if player.global_position.x < global_position.x:
		sprite.flip_h = true
		muzzle.position.x = -abs(muzzle.position.x)
	else:
		sprite.flip_h = false
		muzzle.position.x = abs(muzzle.position.x)

func take_damage(_attacker):
	health -= 1
	print("BOSS HP: ", health)
	
	# CHANGE THIS: Use self_modulate instead of modulate
	# This avoids the conflict with the AnimationPlayer
	sprite.self_modulate = Color.RED
	
	await get_tree().create_timer(0.1).timeout
	
	sprite.self_modulate = Color.WHITE
	
	if health <= 0:
		die()
		
func die():
		# Visual effect
	modulate = Color(10, 10, 10, 1) 
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2)
	queue_free()
	set_physics_process(false)
	timer.stop()
	# Play big explosion animation here
