extends Control

# Layout lives on the scene nodes. Drag Hand, the four labels, and Knife_* in the 2D view.
# Knife_* origin is the blade tip, so rotating a pose spins it around the tip.
# 3 Prong Tree only draws capital letters.
const USE_CARVED_FONT := true
const MENU_FONT := preload("res://asset/fonts/CarvedWood.fnt")

const DESIGN := Vector2(1920, 1080)
const KNIFE_BLADE_DEG := 112.91
const SAVE_PATH := "user://save.cfg"
const OPENING_PATH := "res://scenes/test/test.tscn"
const DIMMED := Color(0, 0, 0, 1)
const SLOT_IDS: PackedStringArray = ["new_game", "continue", "options", "exit"]
const DEV_LEVELS := [
	["tutorial", "res://scenes/tutorial/tutorial.tscn"],
	["level 1", "res://scenes/level_1/level_1.tscn"],
	["level 2", "res://scenes/level_2/level_2.tscn"],
	["japan", "res://scenes/japan/japan.tscn"],
	["boss", "res://scenes/boss_arena/boss_arena.tscn"],
	["test", "res://scenes/test/test.tscn"],
]

enum Motion { INTRO, IDLE, SLIDE, STAB, REJECT, HOLD, WITHDRAW }

var _index := 0
var _motion := Motion.INTRO
var _motion_t := 0.0
var _lift := 180.0
var _plunge := 0.0
var _plunge_from := 0.0
var _queued := false
var _impacted := false
var _has_save := false
var _continue_scene := ""
var _time := 0.0
var _shake := 0.0
var _shake_vec := Vector2.ZERO
var _draw_pos := Vector2.ZERO
var _draw_deg := 0.0
var _draw_scale := Vector2(0.78, 0.78)
var _from_pos := Vector2.ZERO
var _from_deg := 0.0
var _from_scale := Vector2(0.78, 0.78)
var _splinter_scale := Vector2.ONE
var _stick_dir := 0
var _loading := false

var _labels: Array[Label] = []
var _poses: Array[Sprite2D] = []
var _label_scale: Array[Vector2] = []

@onready var stage: Control = $Stage
@onready var hand: Node2D = $Stage/Hand
@onready var knife: Sprite2D = $Stage/Hand/Knife
@onready var splinter: TextureRect = $Stage/Hand/Splinter
@onready var flash: ColorRect = $Flash
var stab_player: AudioStreamPlayer
var dull_player: AudioStreamPlayer


func _ready() -> void:
	_has_save = _read_continue()
	if not PauseMenu.dismissed.is_connected(_on_options_closed):
		PauseMenu.dismissed.connect(_on_options_closed)
	for slot_id in SLOT_IDS:
		var label := hand.get_node(slot_id) as Label
		var center := label.position + label.pivot_offset
		label.pivot_offset = label.size * 0.5
		label.position = center - label.pivot_offset
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face: Font = MENU_FONT if USE_CARVED_FONT else UIFonts.get_font()
		label.add_theme_font_override("font", face)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		_labels.append(label)
		_label_scale.append(label.scale)
		_poses.append(hand.get_node("Knife_" + slot_id) as Sprite2D)
		var hit := label.get_node("Hit") as Button
		hit.focus_mode = Control.FOCUS_NONE
		var slot_index := _labels.size() - 1
		hit.mouse_entered.connect(_arm.bind(slot_index, false))
		hit.pressed.connect(_confirm_slot.bind(slot_index))
	for pose in _poses:
		pose.visible = false
	knife.visible = true
	_splinter_scale = splinter.scale
	splinter.visible = false
	_build_audio()
	_refresh_labels()
	resized.connect(_layout)
	_layout()
	var deg := _knife_deg(0)
	_sync_knife(_tip_of(0) - _blade_dir(deg) * _lift, deg, _knife_scale(0))
	_build_dev_levels()


func _process(delta: float) -> void:
	_time += delta
	if not _loading:
		_advance(delta)
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 2.4)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.3)
		var mag := _shake * 18.0
		_shake_vec = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	else:
		_shake_vec = Vector2.ZERO
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if _loading or event.is_echo():
		return
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		_on_stick(event.axis_value)
		return
	if _motion == Motion.HOLD:
		return
	if _motion == Motion.STAB or _motion == Motion.REJECT or _motion == Motion.WITHDRAW:
		return

	if event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("move_up"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_step(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step(1)
	elif event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER or event.physical_keycode == KEY_SPACE:
			_confirm_current()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_confirm_current()
		get_viewport().set_input_as_handled()


func _advance(delta: float) -> void:
	_motion_t += delta
	match _motion:
		Motion.INTRO:
			var u := clampf(_motion_t / 0.52, 0.0, 1.0)
			_lift = lerpf(180.0, 0.0, 1.0 - pow(1.0 - u, 3.0))
			_plunge = 0.0
			_sync_knife(_tip_of(_index) + _blade_dir(_knife_deg(_index)) * (_plunge - _lift), _knife_deg(_index), _knife_scale(_index))
			if u >= 1.0:
				_finish_travel()
		Motion.IDLE:
			_lift = 0.0
			_plunge = 0.0
			var bob := sin(_time * 2.5) * 8.0
			var deg := _knife_deg(_index)
			_sync_knife(_tip_of(_index) - _blade_dir(deg) * bob, deg, _knife_scale(_index))
		Motion.SLIDE:
			var u := clampf(_motion_t / 0.26, 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			var deg := rad_to_deg(lerp_angle(deg_to_rad(_from_deg), deg_to_rad(_knife_deg(_index)), e))
			var pos := _from_pos.lerp(_tip_of(_index), e)
			pos.y -= sin(e * PI) * 116.0
			var scl := _from_scale.lerp(_knife_scale(_index), e)
			_lift = 0.0
			_plunge = 0.0
			_sync_knife(pos, deg, scl)
			if u >= 1.0:
				_finish_travel()
		Motion.STAB:
			_play_thrust(delta, 46.0, 70.0, true)
		Motion.REJECT:
			_play_thrust(delta, 28.0, 26.0, false)
		Motion.HOLD:
			var deg := _knife_deg(_index)
			_sync_knife(_tip_of(_index) + _blade_dir(deg) * _plunge, deg, _knife_scale(_index))
		Motion.WITHDRAW:
			var u := clampf(_motion_t / 0.2, 0.0, 1.0)
			_plunge = lerpf(_plunge_from, 0.0, u)
			var deg := _knife_deg(_index)
			_sync_knife(_tip_of(_index) + _blade_dir(deg) * _plunge, deg, _knife_scale(_index))
			if u >= 1.0:
				_motion = Motion.IDLE
				_motion_t = 0.0
				_plunge = 0.0


func _play_thrust(_delta: float, pull: float, depth: float, hard: bool) -> void:
	var pull_t := 0.09
	var stab_t := 0.07
	var hold_t := 0.34 if hard else 0.16
	var deg := _knife_deg(_index)
	if _motion_t < pull_t:
		var u := _motion_t / pull_t
		_lift = lerpf(0.0, pull, u)
		_plunge = 0.0
	elif _motion_t < pull_t + stab_t:
		var u := (_motion_t - pull_t) / stab_t
		u = u * u
		_lift = lerpf(pull, 0.0, u)
		_plunge = lerpf(0.0, depth, u)
	else:
		_lift = 0.0
		_plunge = depth
		if not _impacted:
			_impacted = true
			_on_impact(hard)
	_sync_knife(_tip_of(_index) + _blade_dir(deg) * (_plunge - _lift), deg, _knife_scale(_index))
	if _motion_t >= pull_t + stab_t + hold_t:
		_resolve(hard)


func _finish_travel() -> void:
	_motion_t = 0.0
	if _queued:
		_queued = false
		_start_action()
	else:
		_motion = Motion.IDLE


func _step(direction: int) -> void:
	_arm(wrapi(_index + direction, 0, _poses.size()), false)


func _on_stick(axis_value: float) -> void:
	var dir := 0
	if axis_value > 0.55:
		dir = 1
	elif axis_value < -0.55:
		dir = -1
	if dir != 0 and dir != _stick_dir and _motion != Motion.HOLD:
		_step(dir)
	_stick_dir = dir if absf(axis_value) >= 0.4 else 0


func _arm(slot: int, confirm_after: bool) -> void:
	if _motion == Motion.STAB or _motion == Motion.REJECT or _motion == Motion.HOLD or _motion == Motion.WITHDRAW:
		return
	if slot == _index and _motion != Motion.SLIDE and _motion != Motion.INTRO:
		if confirm_after:
			_start_action()
		return
	_from_pos = _draw_pos
	_from_deg = _draw_deg
	_from_scale = _draw_scale
	_index = slot
	_motion = Motion.SLIDE
	_motion_t = 0.0
	_queued = confirm_after
	_refresh_labels()


func _confirm_current() -> void:
	if _motion == Motion.SLIDE or _motion == Motion.INTRO:
		_queued = true
		return
	if _motion != Motion.IDLE:
		return
	_start_action()


func _confirm_slot(slot: int) -> void:
	if _loading:
		return
	if _motion == Motion.STAB or _motion == Motion.REJECT or _motion == Motion.HOLD or _motion == Motion.WITHDRAW:
		return
	if slot != _index or _motion == Motion.SLIDE or _motion == Motion.INTRO:
		_arm(slot, true)
	else:
		_start_action()


func _start_action() -> void:
	_motion_t = 0.0
	_impacted = false
	_queued = false
	if SLOT_IDS[_index] == "continue" and not _has_save:
		_motion = Motion.REJECT
	else:
		_motion = Motion.STAB


func _on_impact(hard: bool) -> void:
	if hard:
		stab_player.play()
		_shake = 1.0
		flash.color = Color(1.0, 0.94, 0.82, 0.34)
		_burst(_draw_pos)
	else:
		dull_player.play()
		_shake = 0.45
		flash.color = Color(1.0, 0.94, 0.82, 0.12)


func _resolve(hard: bool) -> void:
	if not hard:
		_plunge_from = _plunge
		_motion = Motion.WITHDRAW
		_motion_t = 0.0
		return
	_motion = Motion.HOLD
	match SLOT_IDS[_index]:
		"new_game":
			_play_new_game_load()
		"continue":
			GameState.reset()
			SceneTransition.change_scene(_continue_scene)
		"options":
			_open_options()
		"exit":
			get_tree().quit()


func _play_new_game_load() -> void:
	if _loading:
		return
	_loading = true
	var gaps: PackedStringArray = ["Knife_new_game", "Knife_continue", "Knife_options", "Knife_exit"]
	var beats: Array[Dictionary] = []
	for gap_name in gaps:
		var pose := hand.get_node(gap_name) as Sprite2D
		beats.append({
			"tip": pose.position,
			"deg": KNIFE_BLADE_DEG + pose.rotation_degrees,
			"scl": pose.scale,
			"finger": false,
		})
	var finger := hand.get_node("MiddleFinger") as Marker2D
	beats.append({
		"tip": finger.position,
		"deg": KNIFE_BLADE_DEG + finger.rotation_degrees,
		"scl": _knife_scale(1),
		"finger": true,
	})
	for beat in beats:
		var tip: Vector2 = beat.tip
		var deg: float = beat.deg
		var knife_scl: Vector2 = beat.scl
		await _travel_knife(tip, deg, knife_scl, 0.16)
		await _thrust_knife(tip, deg, knife_scl, bool(beat.finger))
	await get_tree().create_timer(0.16).timeout
	GameState.reset()
	SceneTransition.change_scene(OPENING_PATH)


func _travel_knife(tip: Vector2, deg: float, scl: Vector2, duration: float) -> void:
	var from_pos := _draw_pos
	var from_deg := _draw_deg
	var from_scl := _draw_scale
	var t := 0.0
	while t < duration:
		await get_tree().process_frame
		t += get_process_delta_time()
		var e := clampf(t / duration, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		var pos := from_pos.lerp(tip, e)
		pos.y -= sin(e * PI) * 90.0
		var blade := rad_to_deg(lerp_angle(deg_to_rad(from_deg), deg_to_rad(deg), e))
		_sync_knife(pos, blade, from_scl.lerp(scl, e))


func _thrust_knife(tip: Vector2, deg: float, scl: Vector2, finger: bool) -> void:
	var pull_t := 0.07
	var stab_t := 0.05
	var hold_t := 0.2 if finger else 0.08
	var pull := 40.0
	var depth := 96.0 if finger else 58.0
	var t := 0.0
	var impacted := false
	var total := pull_t + stab_t + hold_t
	while t < total:
		await get_tree().process_frame
		t += get_process_delta_time()
		var lift := 0.0
		var plunge := 0.0
		if t < pull_t:
			lift = lerpf(0.0, pull, t / pull_t)
		elif t < pull_t + stab_t:
			var u := (t - pull_t) / stab_t
			u = u * u
			lift = lerpf(pull, 0.0, u)
			plunge = lerpf(0.0, depth, u)
		else:
			plunge = depth
			if not impacted:
				impacted = true
				_on_impact(true)
				if finger:
					_shake = 1.4
					flash.color = Color(0.55, 0.04, 0.02, 0.62)
		_sync_knife(tip + _blade_dir(deg) * (plunge - lift), deg, scl)


func _burst(at: Vector2) -> void:
	splinter.visible = true
	splinter.pivot_offset = splinter.size * 0.5
	splinter.position = at - splinter.pivot_offset
	splinter.rotation = randf_range(-0.2, 0.2)
	splinter.modulate = Color(1, 1, 1, 1)
	var full := _splinter_scale
	splinter.scale = full * 0.72
	var pop := create_tween()
	pop.tween_property(splinter, "scale", full, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(splinter, "modulate:a", 0.0, 0.42).set_delay(0.06)


func _open_options() -> void:
	stage.modulate = DIMMED
	PauseMenu.open_from_main_menu()


func _on_options_closed() -> void:
	stage.modulate = Color.WHITE
	_plunge_from = _plunge
	_motion = Motion.WITHDRAW
	_motion_t = 0.0


func _refresh_labels() -> void:
	for i in _labels.size():
		var selected := i == _index
		var missing := SLOT_IDS[i] == "continue" and not _has_save
		var label := _labels[i]
		var base := _label_scale[i] if i < _label_scale.size() else Vector2.ONE
		if selected:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.scale = base * 1.08
		else:
			var ink_alpha := 0.4 if missing else 0.92
			label.add_theme_color_override("font_color", Color(1, 1, 1, ink_alpha))
			label.scale = base



func _build_dev_levels() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.anchor_left = 1.0
	box.anchor_top = 1.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -132.0
	box.offset_top = -156.0
	box.offset_right = -8.0
	box.offset_bottom = -6.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.z_index = 20
	add_child(box)
	for entry in DEV_LEVELS:
		var button := Button.new()
		button.text = str(entry[0])
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
		var path := str(entry[1])
		button.pressed.connect(_jump_level.bind(path))
		box.add_child(button)


func _jump_level(path: String) -> void:
	if _loading:
		return
	_loading = true
	GameState.reset()
	SceneTransition.change_scene(path)


func _build_audio() -> void:
	stab_player = AudioStreamPlayer.new()
	stab_player.stream = _make_wave(true)
	stab_player.volume_db = -3.0
	add_child(stab_player)
	dull_player = AudioStreamPlayer.new()
	dull_player.stream = _make_wave(false)
	dull_player.volume_db = -8.0
	add_child(dull_player)


func _layout() -> void:
	if stage == null or size.x < 2.0:
		return
	var fit := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	stage.scale = Vector2.ONE * fit
	stage.pivot_offset = Vector2.ZERO
	stage.position = (size - DESIGN * fit) * 0.5 + _shake_vec
	stage.size = DESIGN


func _sync_knife(tip: Vector2, blade_deg: float, knife_scale: Vector2) -> void:
	_draw_pos = tip
	_draw_deg = blade_deg
	_draw_scale = knife_scale
	knife.position = tip
	knife.rotation_degrees = blade_deg - KNIFE_BLADE_DEG
	knife.scale = knife_scale


func _tip_of(slot: int) -> Vector2:
	return _poses[slot].position


func _knife_deg(slot: int) -> float:
	return KNIFE_BLADE_DEG + _poses[slot].rotation_degrees


func _knife_scale(slot: int) -> Vector2:
	return _poses[slot].scale


func _blade_dir(blade_deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(blade_deg))


func _read_continue() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	var scene_path := str(cfg.get_value("continue", "scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	_continue_scene = scene_path
	return true


func _make_wave(hard: bool) -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.34 if hard else 0.16
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4812 if hard else 902
	for i in count:
		var t := float(i) / float(rate)
		var body := sin(t * TAU * (72.0 if hard else 110.0)) * exp(-t * (9.0 if hard else 18.0))
		var knock := sin(t * TAU * (190.0 if hard else 240.0)) * exp(-t * 26.0)
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * (18.0 if hard else 34.0))
		var sample := body * 0.62 + knock * (0.42 if hard else 0.16) + crack * (0.55 if hard else 0.2)
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 255
		data[i * 2 + 1] = (s16 >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
