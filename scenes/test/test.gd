extends Node2D

## Wedding opening. Editor positions of GroomRig / BrideRig are the moment the ring lands.
## At runtime he starts further back, and the player pushes him forward.

enum Beat { INTRO, RING, PINKY, KISS, SNATCH }

const SNATCH_AT := 0.78
const INTRO_LINE1 := 0.65
const INTRO_LINE2 := 3.15
const INTRO_TITLE := 4.85
const INTRO_TITLE_HOLD := 1.45
const INTRO_TITLE_FADE := 1.85
const INTRO_LINE3 := 8.4
const INTRO_END := 10.9
const KISS_SCALE := Vector2(0.46, 0.46)
const RING_WORN := 0.036
const WORLD_W := 3840.0
const CAM_Y := 540.0
const VIEW_HALF := 960.0

@onready var panorama: Sprite2D = $Panorama
@onready var arch: Sprite2D = $Arch
@onready var groom_rig: Node2D = $GroomRig
@onready var suit: Sprite2D = $GroomRig/Suit
@onready var kiss: Sprite2D = $GroomRig/Kiss
@onready var bride_rig: Node2D = $BrideRig
@onready var bride_body: Sprite2D = $BrideRig/Body
@onready var bride_kiss: Sprite2D = $BrideRig/Kiss
@onready var hench_a: Sprite2D = $HenchA
@onready var hench_b: Sprite2D = $HenchB
@onready var petals: CPUParticles2D = $Petals
@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var dummy: Node2D = $Dummy
@onready var music: AudioStreamPlayer = $Music
@onready var story: Label = $CanvasLayer/Story
@onready var bride_line: Label = $CanvasLayer/BrideLine
@onready var rage: Label = $CanvasLayer/Rage
@onready var pop: Label = $CanvasLayer/Pop
@onready var prompt: PanelContainer = $CanvasLayer/Prompt
@onready var track: ColorRect = $CanvasLayer/Prompt/VBox/Track
@onready var fill: ColorRect = $CanvasLayer/Prompt/VBox/Track/Fill
@onready var flash: ColorRect = $CanvasLayer/Flash

var beat := Beat.INTRO
var beat_t := 0.0
var _time := 0.0
var _progress := 0.0
var _mouse_dx := 0.0
var _nervous := 1.0
var _frozen := false
var _rage_shiver := 0.0
var _wiggle := Vector2.ZERO
var _groom_rot := 0.0
var _bride_rot := 0.0
var _groom_base := Vector2.ZERO
var _bride_base := Vector2.ZERO
var _groom_ring := Vector2.ZERO
var _groom_start := Vector2.ZERO
var _groom_close := Vector2.ZERO
var _bride_rest := Vector2.ZERO
var _bride_hook := Vector2.ZERO
var _bride_close := Vector2.ZERO
var _kiss_travel := Vector2.ZERO
var _peck_point := Vector2.ZERO
var _peck_from := Vector2.ZERO
var _tip_gap := Vector2(70, 0)
var _ring_worn := false
var _ring_punch := 0.0
var _pop_life := 0.0
var _popped := false
var _veins_on := false
var _left := false
var _shake_mag := 0.0
var _zoom_target := Vector2.ONE
var _playing := false
var _story_line := ""
var _title_t := -1.0
var _play_t := 0.0
var _pano_x := 1920.0
var _clap_speed := 7.2
var _arch_rot := 0.0
var _kiss_rot := -16.0

var _suit_tip: Marker2D
var _bride_tip: Marker2D
var _kiss_tip: Marker2D
var _bride_kiss_tip: Marker2D
var _ring: Sprite2D
var _bride_ring_tex: Texture2D
var _arrow: Node2D
var _shadow_g: Sprite2D
var _shadow_b: Sprite2D
var _clink: AudioStreamPlayer
var _whoosh: AudioStreamPlayer
var _pop_sfx: AudioStreamPlayer
var _throb: AudioStreamPlayer
var _veins: Array[Line2D] = []
var _claps: Array[Dictionary] = []
var _bits: Array[Dictionary] = []


func _ready() -> void:
	GameState.reset()
	camera.make_current()
	_pano_x = panorama.position.x
	player.visible = false
	player.menu_locked = true
	var player_cam := player.get_node("Camera2D") as Camera2D
	player_cam.enabled = false
	player_cam.set_process(false)
	_build_bounds()
	_arch_rot = arch.rotation
	_kiss_rot = kiss.rotation_degrees
	kiss.visible = false
	bride_kiss.visible = false
	hench_a.visible = false
	hench_b.visible = false
	_dress(story, 40)
	_dress(bride_line, 32)
	_dress(rage, 76)
	_dress(pop, 100)
	_dress(prompt.get_node("VBox/Hint") as Label, 28)
	bride_line.size = Vector2(400, 76)
	pop.size = Vector2(260, 150)
	story.text = ""
	bride_line.text = ""
	rage.text = ""
	pop.text = "啵"
	pop.visible = false
	rage.visible = false
	bride_line.visible = false
	prompt.visible = false
	flash.color = Color(1, 1, 1, 0)
	_cache_clappers()
	_suit_tip = _add_tip(suit, Vector2(1392, 570))
	_bride_tip = _add_tip(bride_body, Vector2(64, 200))
	_kiss_tip = _add_tip(kiss, Vector2(948, 380))
	_bride_kiss_tip = _add_tip(bride_kiss, Vector2(186, 204))
	_build_ring()
	_bride_ring_tex = _load_tex("res://asset/wedding/27_bride_hand_ring.png")
	_build_veins()
	_build_arrow()
	_build_shadows()
	_build_audio()
	_setup_petals()
	# Measure while both hands are still on the editor "ring landed" pose.
	_groom_ring = groom_rig.position
	_bride_rest = bride_rig.position
	_tip_gap = _bride_tip.global_position - _suit_tip.global_position
	if _tip_gap.length() < 20.0:
		_tip_gap = Vector2(70, 0)
	_groom_start = _groom_ring + Vector2(-175, 14)
	_groom_close = _groom_ring + Vector2(28, 2)
	_bride_hook = _bride_rest + Vector2(-26, 8)
	_bride_close = _bride_rest + Vector2(-34, 12)
	_kiss_travel = _groom_close + _tip_gap * 0.45
	_peck_point = _groom_close + _tip_gap * 1.25
	_groom_base = _groom_start
	_bride_base = _bride_rest
	_apply_bodies()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_mouse_dx += motion.relative.x


func _process(delta: float) -> void:
	_time += delta
	beat_t += delta
	_tick_world(delta)
	if _playing:
		_play_control(delta)
		return
	match beat:
		Beat.INTRO:
			_play_intro()
		Beat.RING:
			_play_ring(delta)
		Beat.PINKY:
			_play_pinky()
		Beat.KISS:
			_play_kiss(delta)
		Beat.SNATCH:
			_play_snatch()
	_apply_bodies()
	_stick_props()
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 1.8)
	if _pop_life > 0.0:
		_pop_life -= delta
		pop.modulate.a = clampf(_pop_life / 0.35, 0.0, 1.0)
		if _pop_life <= 0.0:
			pop.visible = false


func _play_intro() -> void:
	_nervous = 1.0
	if beat_t >= INTRO_END:
		_enter_ring()
		return
	if beat_t >= INTRO_TITLE and beat_t < INTRO_LINE3:
		if _title_t < 0.0:
			_slam_title()
		_tick_title(get_process_delta_time())
		return
	if beat_t < INTRO_LINE1:
		_set_story("", Color.WHITE)
	elif beat_t < INTRO_LINE2:
		_set_story("你曾在世界大殺四方，獨孤求敗，沒有對手。", Color(1, 0.97, 0.9))
	elif beat_t < INTRO_TITLE:
		_set_story("世人稱你為.....", Color(1, 0.97, 0.9))
	else:
		_set_story("但今天便是你收手的日子。", Color(1, 0.97, 0.9))


func _enter_ring() -> void:
	beat = Beat.RING
	beat_t = 0.0
	_progress = 0.0
	_ring.visible = true
	_ring.scale = Vector2.ONE * RING_WORN * 0.45
	prompt.visible = true
	_set_story("請為新娘戴上戒指。", Color(1, 0.95, 0.82))
	_set_bar(0.0)


func _play_ring(delta: float) -> void:
	_nervous = 1.0
	_groom_base = _groom_start.lerp(_groom_ring, _ease(_progress))
	_bride_base = _bride_rest
	var pushed := _push_amount(delta)
	if pushed > 0.0:
		_progress = minf(1.0, _progress + pushed)
	else:
		_progress = maxf(0.0, _progress - delta * 0.22)
	_set_bar(_progress)
	var worn := Vector2.ONE * RING_WORN
	if _ring.scale.x < worn.x:
		_ring.scale = _ring.scale.lerp(worn, clampf(delta * 8.0, 0.0, 1.0))
	if _progress >= 1.0:
		_wear_ring()


func _wear_ring() -> void:
	beat = Beat.PINKY
	beat_t = 0.0
	_progress = 1.0
	_ring_worn = true
	_ring_punch = 0.28
	prompt.visible = false
	_set_story("", Color.WHITE)
	_clap_speed = 11.5
	_shake_mag = maxf(_shake_mag, 5.0)
	_clink.play()
	_ring.visible = false
	if _bride_ring_tex != null:
		bride_body.texture = _bride_ring_tex
		bride_body.scale = Vector2(0.22, 0.22)


func _play_pinky() -> void:
	var t := beat_t
	_groom_base = _groom_ring
	_bride_base = _bride_rest
	_wiggle = Vector2.ZERO
	if t < 0.35:
		_nervous = 1.0
		_bride_rot = 0.0
	elif t < 1.0:
		var u := _ease((t - 0.35) / 0.65)
		_bride_base = _bride_rest.lerp(_bride_hook, u)
		_bride_rot = lerpf(0.0, -8.0, u)
		_nervous = 1.0
		if t > 0.5:
			_set_bride("別緊張。")
	elif t < 1.65:
		var u := (t - 1.0) / 0.65
		var wave := sin(u * TAU * 2.0)
		_wiggle = Vector2(wave * 16.0, 0.0)
		_bride_base = _bride_hook
		_bride_rot = -8.0 + wave * 4.0
		_groom_rot = wave * 2.0
		_nervous = 0.85
		_set_bride("別緊張。")
	elif t < 2.35:
		var u := _ease((t - 1.65) / 0.7)
		_groom_base = _groom_ring.lerp(_groom_close, u)
		_bride_base = _bride_hook.lerp(_bride_close, u)
		_bride_rot = lerpf(-8.0, -3.0, u)
		_groom_rot = lerpf(_groom_rot, 0.0, u)
		_nervous = lerpf(0.85, 0.0, u)
		_set_bride("過來啦。")
	elif t < 3.15:
		_groom_base = _groom_close
		_bride_base = _bride_close
		_bride_rot = -3.0
		_groom_rot = 0.0
		_nervous = 0.0
		if t > 2.7:
			_set_bride("")
			_set_story("現在，你可以親吻新娘了。", Color(1, 0.95, 0.82))
	else:
		_begin_kiss()


func _begin_kiss() -> void:
	beat = Beat.KISS
	beat_t = 0.0
	_progress = 0.0
	_nervous = 0.45
	_groom_rot = 0.0
	suit.visible = false
	kiss.visible = true
	kiss.scale = KISS_SCALE
	bride_body.visible = false
	bride_kiss.visible = true
	bride_kiss.scale = KISS_SCALE
	_groom_base = _groom_close
	_bride_base = _bride_close
	groom_rig.position = _groom_base
	bride_rig.position = _bride_base
	var gap := _bride_kiss_tip.global_position - _kiss_tip.global_position
	if gap.length() < 20.0:
		gap = Vector2(140, 0)
	_kiss_travel = _groom_close + gap * 0.45
	_peck_point = _groom_close + gap * 1.25
	if is_instance_valid(_ring):
		_ring.visible = false
	_bride_rot = -3.0
	_wiggle = Vector2.ZERO
	prompt.visible = true
	_set_bar(0.0)
	_set_story("現在，你可以親吻新娘了。", Color(1, 0.95, 0.82))


func _play_kiss(delta: float) -> void:
	_groom_base = _groom_close.lerp(_kiss_travel, _ease(_progress))
	_bride_base = _bride_close
	_bride_rot = -3.0
	var pushed := _push_amount(delta)
	if pushed > 0.0:
		_progress = minf(1.0, _progress + pushed)
	else:
		_progress = maxf(0.0, _progress - delta * 0.2)
	_set_bar(_progress / SNATCH_AT)
	kiss.scale = KISS_SCALE
	kiss.rotation_degrees = _kiss_rot
	if _progress >= SNATCH_AT:
		_begin_snatch()


func _begin_snatch() -> void:
	beat = Beat.SNATCH
	beat_t = 0.0
	_peck_from = _groom_base
	_frozen = true
	_nervous = 0.0
	_wiggle = Vector2.ZERO
	prompt.visible = false
	_set_story("", Color.WHITE)
	_set_bride("")
	_arrow.visible = false
	_clap_speed = 0.0
	flash.color = Color(1, 1, 1, 0.55)
	hench_a.visible = true
	hench_b.visible = true
	hench_a.rotation_degrees = 78.0
	hench_b.rotation_degrees = -64.0
	_whoosh.play()
	_burst(bride_rig.global_position + Vector2(-20, -10))
	_shake_mag = maxf(_shake_mag, 8.0)


func _play_snatch() -> void:
	var t := beat_t
	var grab := _bride_close
	if t < 0.22:
		var u := (t / 0.22) ** 2
		hench_a.global_position = Vector2(2360, grab.y - 80).lerp(grab + Vector2(90, -60), u)
		hench_b.global_position = Vector2(2580, grab.y + 120).lerp(grab + Vector2(130, 70), u)
		_groom_base = _peck_from
		_bride_base = grab
	elif t < 0.68:
		var u := ((t - 0.22) / 0.46) ** 2
		var off := Vector2(1600.0 * u, -40.0 * u)
		_bride_base = grab + off
		_bride_rot = lerpf(-3.0, 26.0, u)
		hench_a.global_position = _bride_base + Vector2(90, -60)
		hench_b.global_position = _bride_base + Vector2(150, 80)
	else:
		bride_rig.visible = false
		hench_a.visible = false
		hench_b.visible = false

	if t < 0.46:
		_groom_base = _peck_from.lerp(_kiss_travel, _ease(t / 0.46))
		_frozen = true
	elif t < 0.58:
		var u := (t - 0.46) / 0.12
		_groom_base = _kiss_travel.lerp(_peck_point, u * u)
		if not _popped and u > 0.55:
			_popped = true
			_show_pop()
	elif t < 1.28:
		_groom_base = _peck_point
		_frozen = true
		_rage_shiver = 0.0
	elif t < 1.85:
		var u := clampf((t - 1.28) / 0.4, 0.0, 1.0)
		_groom_base = _peck_point
		_frozen = false
		_rage_shiver = u
		_set_veins(u)
		kiss.modulate = Color(1, 1, 1).lerp(Color(1, 0.68, 0.64), u)
		kiss.rotation_degrees = lerpf(_kiss_rot, _kiss_rot - 18.0, u)
		kiss.scale = KISS_SCALE
		if u > 0.15 and not _veins_on:
			_veins_on = true
			_throb.play()
			_shake_mag = maxf(_shake_mag, 16.0)
			_zoom_target = Vector2(1.1, 1.1)
		if u > 0.65:
			_set_rage("……")
	elif t < 2.55:
		_groom_base = _peck_point
		_rage_shiver = 1.0
		_set_veins(1.0)
		if t > 1.95:
			_set_rage("我的老婆。")
			if t < 2.05:
				_shake_mag = maxf(_shake_mag, 12.0)
	elif t < 4.15:
		_groom_base = _peck_point
		_rage_shiver = 0.65
		_set_veins(1.0)
		_set_story("收手的日子，到此為止。", Color(1, 0.96, 0.9))
	elif not _left:
		_begin_play()


func _apply_bodies() -> void:
	var shiver := Vector2.ZERO
	if _frozen:
		shiver = Vector2.ZERO
	elif _rage_shiver > 0.0:
		shiver = Vector2(sin(_time * 52.0) * 3.2, cos(_time * 47.0) * 2.0) * _rage_shiver
	elif _nervous > 0.01:
		shiver = Vector2(
			sin(_time * 22.0) * 4.4 + sin(_time * 13.0) * 2.1,
			cos(_time * 18.0) * 2.2
		) * _nervous
	groom_rig.position = _groom_base + _wiggle + shiver
	groom_rig.rotation_degrees = _groom_rot
	var bob := 0.0
	if beat == Beat.INTRO or beat == Beat.RING or beat == Beat.KISS:
		bob = sin(_time * 1.5) * 2.0
	bride_rig.position = _bride_base + _wiggle * 0.8 + Vector2(0.0, bob)
	bride_rig.rotation_degrees = _bride_rot


func _stick_props() -> void:
	if is_instance_valid(_ring) and not _ring_worn:
		_ring.global_position = _suit_tip.global_position
	if _ring_punch > 0.0:
		_ring_punch = maxf(0.0, _ring_punch - get_process_delta_time())
		var u := 1.0 - clampf(_ring_punch / 0.28, 0.0, 1.0)
		_ring.scale = Vector2.ONE * RING_WORN * (1.0 + sin(u * PI) * 0.28)
	if _shadow_g != null:
		var anchor := _kiss_tip.global_position if kiss.visible else _suit_tip.global_position
		_shadow_g.global_position = anchor + Vector2(10, 36)
		_shadow_g.modulate.a = 0.0 if not groom_rig.visible else 0.8
	if _shadow_b != null:
		_shadow_b.global_position = bride_rig.global_position + Vector2(-30, 78)
		_shadow_b.visible = bride_rig.visible
	var show_arrow := (beat == Beat.RING or beat == Beat.KISS) and _progress < 0.92
	_arrow.visible = show_arrow
	if show_arrow:
		var tip := _kiss_tip.global_position if beat == Beat.KISS else _suit_tip.global_position
		_arrow.global_position = tip + Vector2(28 + sin(_time * 5.0) * 8.0, -18)
		_arrow.modulate.a = 0.45 + sin(_time * 4.0) * 0.25
	if _pop_life > 0.0 and _kiss_tip != null:
		_place_world_label(pop, _kiss_tip.global_position + Vector2(10, -80))
	if bride_line.visible:
		_place_world_label(bride_line, bride_rig.global_position + Vector2(30, -150))


func _begin_play() -> void:
	_playing = true
	_left = true
	_play_t = 0.0
	_frozen = true
	_rage_shiver = 0.0
	_nervous = 0.0
	_zoom_target = Vector2.ONE
	camera.zoom = Vector2.ONE
	_shake_mag = 0.0
	camera.offset = Vector2.ZERO
	groom_rig.visible = false
	rage.visible = false
	pop.visible = false
	bride_line.visible = false
	prompt.visible = false
	player.global_position = Vector2(1120, 620)
	player.visible = true
	player.menu_locked = false
	var player_cam := player.get_node("Camera2D") as Camera2D
	player_cam.enabled = false
	player_cam.set_process(false)
	camera.make_current()
	if not music.playing:
		music.play()
	_set_story("用 WASD 移動", Color(1, 0.97, 0.9))


func _play_control(delta: float) -> void:
	_play_t += delta
	player.global_position.x = clampf(player.global_position.x, 180.0, WORLD_W - 140.0)
	player.global_position.y = clampf(player.global_position.y, 500.0, 700.0)
	var target_x := clampf(player.global_position.x, VIEW_HALF, WORLD_W - VIEW_HALF)
	var blend := 1.0 - exp(-7.0 * delta)
	camera.position.x = lerpf(camera.position.x, target_x, blend)
	camera.position.y = CAM_Y
	panorama.position.x = _pano_x + (camera.position.x - VIEW_HALF) * -0.05
	var dummy_body := dummy.get_node_or_null("Body") as Node2D
	var dummy_point := dummy_body.global_position if dummy_body != null else dummy.global_position
	var near_dummy := player.global_position.distance_to(dummy_point) < 460.0
	var dummy_up := not bool(dummy.get("down"))
	if near_dummy and dummy_up:
		_set_story("按下左鍵攻擊木手，找回昔日的憤怒。", Color(1, 0.97, 0.9))
	elif _play_t < 2.4:
		_set_story("用 WASD 移動", Color(1, 0.97, 0.9))
	else:
		_set_story("", Color.WHITE)


func _build_bounds() -> void:
	_add_wall(Vector2(WORLD_W * 0.5, 470), Vector2(WORLD_W + 200.0, 70))
	_add_wall(Vector2(WORLD_W * 0.5, 860), Vector2(WORLD_W + 200.0, 70))
	_add_wall(Vector2(60, 660), Vector2(80, 460))
	_add_wall(Vector2(WORLD_W - 60.0, 660), Vector2(80, 460))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = center
	body.add_child(shape_node)
	add_child(body)


func _tick_world(delta: float) -> void:
	arch.rotation = _arch_rot + sin(_time * 0.75) * deg_to_rad(0.45)
	if _playing:
		return
	camera.zoom = camera.zoom.lerp(_zoom_target, clampf(delta * 2.4, 0.0, 1.0))
	if _shake_mag > 0.0:
		_shake_mag = maxf(0.0, _shake_mag - delta * 18.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_mag
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	var dropping := _clap_speed <= 0.0
	for clap in _claps:
		var spr := clap["node"] as Sprite2D
		var base_p: Vector2 = clap["pos"]
		var base_s: Vector2 = clap["scl"]
		var base_r: float = clap["rot"]
		if dropping:
			spr.position = spr.position.lerp(base_p + Vector2(0, 22), clampf(delta * 4.0, 0.0, 1.0))
			spr.rotation = lerp_angle(spr.rotation, base_r + 0.2, clampf(delta * 4.0, 0.0, 1.0))
			spr.scale = base_s
		else:
			var wave := sin(_time * _clap_speed + float(clap["phase"]))
			spr.position = base_p + Vector2(0, wave * 11.0)
			spr.rotation = base_r + wave * 0.045
			spr.scale = Vector2(base_s.x, base_s.y * (1.0 + wave * 0.04))
	_tick_bits(delta)


func _push_amount(delta: float) -> float:
	var amount := 0.0
	if Input.is_action_pressed("move_right"):
		amount += 0.58 * delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		amount += maxf(_mouse_dx, 0.0) / 300.0
	_mouse_dx = 0.0
	return amount


func _set_story(text: String, color: Color) -> void:
	if text == _story_line and _title_t < 0.0:
		return
	_title_t = -1.0
	_story_line = text
	story.text = text
	story.visible = text != ""
	story.modulate = Color(1, 1, 1, 1)
	story.scale = Vector2.ONE
	story.offset_bottom = 140.0
	story.pivot_offset = Vector2(640, 56)
	story.add_theme_font_size_override("font_size", 40)
	story.add_theme_constant_override("outline_size", 12)
	story.add_theme_color_override("font_color", color)


func _slam_title() -> void:
	_title_t = 0.0
	_story_line = "天下無敵手"
	story.text = "天下無敵手"
	story.visible = true
	story.modulate = Color(1, 1, 1, 1)
	story.offset_bottom = 260.0
	story.pivot_offset = Vector2(640, 116)
	story.scale = Vector2(1.75, 1.75)
	story.add_theme_font_size_override("font_size", 96)
	story.add_theme_constant_override("outline_size", 18)
	story.add_theme_color_override("font_color", Color(1, 0.95, 0.78))
	_shake_mag = maxf(_shake_mag, 16.0)
	flash.color = Color(1, 0.97, 0.88, 0.42)


func _tick_title(delta: float) -> void:
	_title_t += delta
	var punch := clampf(_title_t / 0.18, 0.0, 1.0)
	punch = 1.0 - pow(1.0 - punch, 3.0)
	var s := lerpf(1.75, 1.0, punch)
	story.scale = Vector2(s, s)
	if _title_t <= INTRO_TITLE_HOLD:
		story.modulate.a = 1.0
	else:
		var u := clampf((_title_t - INTRO_TITLE_HOLD) / INTRO_TITLE_FADE, 0.0, 1.0)
		story.modulate.a = 1.0 - smoothstep(0.0, 1.0, u)


func _set_bride(text: String) -> void:
	bride_line.text = text
	bride_line.visible = text != ""


func _set_rage(text: String) -> void:
	if rage.text == text and rage.visible:
		return
	rage.text = text
	rage.visible = text != ""


func _set_bar(value: float) -> void:
	var width := track.size.x
	if width < 2.0:
		width = 640.0
	fill.size = Vector2(width * clampf(value, 0.0, 1.0), maxf(track.size.y, 10.0))
	fill.position = Vector2.ZERO


func _show_pop() -> void:
	pop.visible = true
	pop.modulate = Color(1, 0.78, 0.84, 1)
	pop.scale = Vector2.ONE
	_pop_life = 0.95
	_pop_sfx.play()
	_place_world_label(pop, _kiss_tip.global_position + Vector2(10, -80))


func _place_world_label(label: Label, world: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_canvas_transform() * world
	label.position = screen - label.size * 0.5


func _set_veins(u: float) -> void:
	u = clampf(u, 0.0, 1.0)
	var i := 0
	for line in _veins:
		var vein := line as Line2D
		vein.width = lerpf(0.0, 8.0 + float(i) * 1.5, u)
		vein.default_color = Color(0.25, 0.5, 0.98, lerpf(0.0, 0.9, u))
		i += 1


func _burst(origin: Vector2) -> void:
	for i in 16:
		var spr := Sprite2D.new()
		spr.texture = petals.texture
		spr.scale = Vector2.ONE * randf_range(0.03, 0.06)
		spr.rotation = randf() * TAU
		spr.position = origin
		spr.z_index = 16
		add_child(spr)
		_bits.append({
			"node": spr,
			"vel": Vector2(randf_range(-260, 340), randf_range(-320, -20)),
			"spin": randf_range(-7.0, 7.0),
			"life": randf_range(0.8, 1.35),
		})


func _tick_bits(delta: float) -> void:
	if _bits.is_empty():
		return
	var alive: Array[Dictionary] = []
	for bit in _bits:
		var life := float(bit["life"]) - delta
		if life <= 0.0:
			(bit["node"] as Node).queue_free()
			continue
		bit["life"] = life
		var vel: Vector2 = bit["vel"]
		vel += Vector2(0, 640) * delta
		bit["vel"] = vel
		var spr := bit["node"] as Sprite2D
		spr.position += vel * delta
		spr.rotation += float(bit["spin"]) * delta
		spr.modulate.a = clampf(life / 0.35, 0.0, 1.0)
		alive.append(bit)
	_bits = alive


func _cache_clappers() -> void:
	for node in get_tree().get_nodes_in_group("clapper"):
		var spr := node as Sprite2D
		_claps.append({
			"node": spr,
			"pos": spr.position,
			"scl": spr.scale,
			"rot": spr.rotation,
			"phase": randf() * TAU,
		})


func _add_tip(sprite: Sprite2D, image_px: Vector2) -> Marker2D:
	var marker := Marker2D.new()
	marker.position = image_px - sprite.texture.get_size() * 0.5
	sprite.add_child(marker)
	return marker


func _load_tex(path: String) -> Texture2D:
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _build_ring() -> void:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path("res://asset/wedding/24_wedding_ring.png")) != OK:
		return
	_ring = Sprite2D.new()
	_ring.texture = ImageTexture.create_from_image(image)
	_ring.scale = Vector2.ONE * RING_WORN
	_ring.z_index = 6
	_ring.visible = false
	add_child(_ring)


func _build_veins() -> void:
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-190, -80), Vector2(-120, -30), Vector2(-40, 30), Vector2(20, 90)]),
		PackedVector2Array([Vector2(-170, -20), Vector2(-80, 30), Vector2(0, 100)]),
		PackedVector2Array([Vector2(-150, -110), Vector2(-70, -40), Vector2(10, 20)]),
	]
	for pts in paths:
		var line := Line2D.new()
		line.points = pts
		line.width = 0.0
		line.default_color = Color(0.25, 0.5, 0.98, 0.0)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.z_index = 2
		kiss.add_child(line)
		_veins.append(line)


func _build_arrow() -> void:
	var shape := PackedVector2Array([
		Vector2(0, -12), Vector2(40, -12), Vector2(40, -26),
		Vector2(72, 0), Vector2(40, 26), Vector2(40, 12), Vector2(0, 12),
	])
	_arrow = Node2D.new()
	_arrow.z_index = 18
	var back := Polygon2D.new()
	back.polygon = shape
	back.color = Color(0, 0, 0, 0.55)
	back.position = Vector2(3, 4)
	var front := Polygon2D.new()
	front.polygon = shape
	front.color = Color(1, 0.93, 0.72, 1)
	_arrow.add_child(back)
	_arrow.add_child(front)
	_arrow.visible = false
	add_child(_arrow)


func _build_shadows() -> void:
	var blob := _blob_texture()
	_shadow_g = Sprite2D.new()
	_shadow_g.texture = blob
	_shadow_g.scale = Vector2(2.1, 0.42)
	_shadow_g.z_index = -4
	_shadow_b = Sprite2D.new()
	_shadow_b.texture = blob
	_shadow_b.scale = Vector2(2.4, 0.46)
	_shadow_b.z_index = -4
	add_child(_shadow_g)
	add_child(_shadow_b)


func _blob_texture() -> Texture2D:
	var size := 96
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(47.5, 47.5)
	for y in size:
		for x in size:
			var dist := Vector2(x, y).distance_to(center) / 48.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha * 0.55
			image.set_pixel(x, y, Color(0, 0, 0, alpha))
	return ImageTexture.create_from_image(image)


func _setup_petals() -> void:
	petals.emitting = true
	petals.amount = 20
	petals.lifetime = 8.0
	petals.preprocess = 3.5
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(1900, 24)
	petals.direction = Vector2(0.25, 1)
	petals.spread = 26.0
	petals.gravity = Vector2(12, 20)
	petals.initial_velocity_min = 16.0
	petals.initial_velocity_max = 44.0
	petals.angular_velocity_min = -45.0
	petals.angular_velocity_max = 45.0
	petals.scale_amount_min = 0.028
	petals.scale_amount_max = 0.05
	petals.local_coords = false
	petals.z_index = 3


func _build_audio() -> void:
	_clink = _make_player(_synth([1480.0, 2100.0], 0.16, 18.0, 0.55, 0.0), -6.0)
	_whoosh = _make_player(_synth([180.0], 0.42, 6.0, 0.15, 0.85), -8.0)
	_pop_sfx = _make_player(_synth([210.0, 420.0], 0.18, 14.0, 0.7, 0.0), -4.0)
	_throb = _make_player(_synth([78.0, 46.0], 0.55, 4.5, 0.8, 0.05), -10.0)


func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _synth(freqs: Array, duration: float, decay: float, volume: float, noise: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(mix_rate)
		var env := exp(-t * decay)
		var sample := 0.0
		for freq in freqs:
			sample += sin(TAU * float(freq) * t)
		if freqs.size() > 0:
			sample /= float(freqs.size())
		sample = sample * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		sample *= env * volume
		var value := clampi(int(sample * 32767.0), -32767, 32767)
		if value < 0:
			value += 65536
		data[i * 2] = value & 255
		data[i * 2 + 1] = (value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _dress(label: Label, size: int) -> void:
	UIFonts.apply(label)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ease(amount: float) -> float:
	var u := clampf(amount, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)
