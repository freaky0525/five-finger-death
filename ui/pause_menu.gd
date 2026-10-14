extends CanvasLayer

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const TITLE_FONT := preload("res://asset/fonts/3Dumb Pro 03.ttf")
const INTRO_PATHS := [
	"res://asset/ui/pause/frame_01.jpg",
	"res://asset/ui/pause/frame_02.jpg",
	"res://asset/ui/pause/frame_03.jpg",
	"res://asset/ui/pause/frame_04.jpg",
	"res://asset/ui/pause/frame_05.jpg",
]
const IDLE_PATHS := [
	"res://asset/ui/pause/frame_05.jpg",
	"res://asset/ui/pause/frame_06.jpg",
	"res://asset/ui/pause/frame_07.jpg",
	"res://asset/ui/pause/frame_08.jpg",
	"res://asset/ui/pause/frame_09.jpg",
]
const FRAME_HOLD := [0.18, 0.08, 0.09, 0.10, 0.11]
const RETRACT_HOLD := [0.05, 0.05, 0.05, 0.06, 0.08]
const IDLE_HOLD := 0.11
const SELECT_PATHS := {
	"thumb": [
		"res://asset/ui/pause/thumb_01.jpg",
		"res://asset/ui/pause/thumb_02.jpg",
		"res://asset/ui/pause/thumb_03.jpg",
		"res://asset/ui/pause/thumb_04.jpg",
	],
	"index": [
		"res://asset/ui/pause/index_01.jpg",
		"res://asset/ui/pause/index_02.jpg",
		"res://asset/ui/pause/index_03.jpg",
		"res://asset/ui/pause/index_04.jpg",
	],
	"middle": [
		"res://asset/ui/pause/middle_01.jpg",
		"res://asset/ui/pause/middle_02.jpg",
		"res://asset/ui/pause/middle_03.jpg",
		"res://asset/ui/pause/middle_04.jpg",
	],
	"ring": [
		"res://asset/ui/pause/ring_01.jpg",
		"res://asset/ui/pause/ring_02.jpg",
		"res://asset/ui/pause/ring_03.jpg",
		"res://asset/ui/pause/ring_04.jpg",
	],
	"pinky": [
		"res://asset/ui/pause/pinky_01.jpg",
		"res://asset/ui/pause/pinky_02.jpg",
		"res://asset/ui/pause/pinky_03.jpg",
		"res://asset/ui/pause/pinky_04.jpg",
	],
}
const SELECT_PULL_HOLD := [0.07, 0.055, 0.045, 0.04]
const SELECT_TUG_HOLD := 0.13

enum Page { HAND, VOLUME, DISPLAY, CONTROLS }

const FINGERS := [
	{
		"id": "index",
		"number": "01",
		"title": "音量",
		"subtitle": "VOLUME",
		"tag_pos": Vector2(220, 80),
		"hit_rect": Rect2(380, 40, 300, 380),
		"rotation": -8.0,
	},
	{
		"id": "middle",
		"number": "02",
		"title": "畫面",
		"subtitle": "DISPLAY",
		"tag_pos": Vector2(860, 4),
		"hit_rect": Rect2(780, 0, 300, 340),
		"rotation": 2.0,
	},
	{
		"id": "ring",
		"number": "03",
		"title": "操作",
		"subtitle": "CONTROLS",
		"tag_pos": Vector2(1440, 70),
		"hit_rect": Rect2(1120, 40, 300, 380),
		"rotation": 7.0,
	},
	{
		"id": "pinky",
		"number": "04",
		"title": "返回",
		"subtitle": "RESUME",
		"tag_pos": Vector2(1580, 460),
		"hit_rect": Rect2(1320, 400, 300, 340),
		"rotation": 10.0,
	},
	{
		"id": "thumb",
		"number": "05",
		"title": "離開",
		"subtitle": "EXIT",
		"tag_pos": Vector2(140, 580),
		"hit_rect": Rect2(240, 500, 320, 300),
		"rotation": -12.0,
	},
]

var _page := Page.HAND
var _player_was_locked := false
var _busy := false
var _idle := false
var _idle_index := 0
var _idle_dir := 1
var _idle_timer := 0.0
var _idle_hold := IDLE_HOLD
var _hover_id := ""
var _tags: Dictionary = {}
var _hits: Dictionary = {}
var _intro_frames: Array[Texture2D] = []
var _idle_frames: Array[Texture2D] = []
var _select_frames: Dictionary = {}
var _select_mode := ""
var _select_index := 0
var _select_dir := 1
var _select_timer := 0.0
var _hit_debug: Dictionary = {}

@export var show_hitboxes := false

@onready var frames: TextureRect = $Frames
@onready var flash: ColorRect = $Flash
@onready var interact: Control = $Interact
@onready var subpage: Control = $SubPage
@onready var sub_title: Label = $SubPage/Card/VBox/Title
@onready var volume_box: VBoxContainer = $SubPage/Card/VBox/VolumeBox
@onready var display_box: VBoxContainer = $SubPage/Card/VBox/DisplayBox
@onready var controls_box: VBoxContainer = $SubPage/Card/VBox/ControlsBox
@onready var volume_slider: HSlider = $SubPage/Card/VBox/VolumeBox/Slider
@onready var volume_value: Label = $SubPage/Card/VBox/VolumeBox/Value
@onready var fullscreen_button: Button = $SubPage/Card/VBox/DisplayBox/FullscreenButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	_load_frames()
	if not _intro_frames.is_empty():
		frames.texture = _intro_frames[0]
	_style_text()
	_build_finger_ui()
	_hide_subpage()
	_set_menu_ui_visible(false)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	$SubPage/Card/VBox/Back.pressed.connect(_show_hand)
	volume_slider.set_value_no_signal(0.0)
	_on_volume_changed(0.0)
	_update_fullscreen_label()


func _load_frames() -> void:
	_intro_frames.clear()
	for path in INTRO_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			_intro_frames.append(tex)
	_idle_frames.clear()
	for path in IDLE_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			_idle_frames.append(tex)
	_select_frames.clear()
	for finger_id in SELECT_PATHS.keys():
		var loaded: Array[Texture2D] = []
		for path in SELECT_PATHS[finger_id]:
			var tex := load(path) as Texture2D
			if tex != null:
				loaded.append(tex)
		if not loaded.is_empty():
			_select_frames[finger_id] = loaded


func _process(delta: float) -> void:
	if not visible or _busy:
		return
	if _select_mode != "":
		_process_select(delta)
		return
	if not _idle or _hover_id != "":
		return

	_idle_timer += delta
	if _idle_timer < _idle_hold:
		return

	_idle_timer = 0.0
	_idle_hold = IDLE_HOLD + randf_range(-0.025, 0.04)
	_idle_index += _idle_dir
	if _idle_index >= _idle_frames.size() - 1:
		_idle_index = _idle_frames.size() - 1
		_idle_dir = -1
	elif _idle_index <= 0:
		_idle_index = 0
		_idle_dir = 1
	frames.texture = _idle_frames[_idle_index]


func _input(event: InputEvent) -> void:
	if event.is_echo() or _busy:
		return

	if event.is_action_pressed("pause"):
		_on_pause_pressed()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
		show_hitboxes = not show_hitboxes
		_refresh_hitbox_vis()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1:
				_activate_finger("index")
			KEY_2:
				_activate_finger("middle")
			KEY_3:
				_activate_finger("ring")
			KEY_4:
				_activate_finger("pinky")
			KEY_5:
				_activate_finger("thumb")


func open() -> void:
	if visible or not _can_pause():
		return

	var player := get_tree().get_first_node_in_group("player")
	_player_was_locked = player != null and ("menu_locked" in player) and player.menu_locked
	visible = true
	get_tree().paused = true
	_lock_player(true)
	_set_health_hud_visible(false)
	_hide_subpage()
	_play_jumpscare()


func close() -> void:
	if not visible or _busy:
		return
	_play_retract()


func _finish_close() -> void:
	_stop_idle()
	visible = false
	_busy = false
	_hover_id = ""
	_hide_subpage()
	_set_menu_ui_visible(false)
	if not _intro_frames.is_empty():
		frames.texture = _intro_frames[0]
	_set_health_hud_visible(true)
	get_tree().paused = false
	_lock_player(_player_was_locked)


func _on_pause_pressed() -> void:
	if visible:
		if _page != Page.HAND:
			_show_hand()
		else:
			close()
	elif _can_pause():
		open()


func _can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var path := String(scene.scene_file_path)
	if path.ends_with("main_menu.tscn") or path.ends_with("MainMenu.tscn"):
		return false
	return get_tree().get_first_node_in_group("player") != null


func _lock_player(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and "menu_locked" in player:
		player.menu_locked = locked


func _play_jumpscare() -> void:
	_busy = true
	_stop_idle()
	_page = Page.HAND
	_set_menu_ui_visible(false)
	_set_hits_enabled(false)
	if not _intro_frames.is_empty():
		frames.texture = _intro_frames[0]
	frames.scale = Vector2.ONE
	await get_tree().process_frame
	frames.pivot_offset = frames.size * 0.5
	flash.color = Color(1, 1, 1, 0)

	for i in _intro_frames.size():
		frames.texture = _intro_frames[i]
		if i == 1:
			flash.color = Color(1, 1, 1, 0.5)
			var punch := _tween()
			punch.tween_property(flash, "color:a", 0.0, 0.18)
			punch.parallel().tween_property(frames, "scale", Vector2(1.04, 1.04), 0.08)
			punch.tween_property(frames, "scale", Vector2.ONE, 0.12)
		if FRAME_HOLD[i] > 0.0:
			await get_tree().create_timer(FRAME_HOLD[i], true).timeout

	_set_menu_ui_visible(true)
	var fade := _tween()
	for tag in _tags.values():
		fade.parallel().tween_property(tag, "modulate:a", 1.0, 0.2)
	if fade.is_running():
		await fade.finished
	_busy = false
	_set_hits_enabled(true)
	_start_idle()


func _play_retract() -> void:
	_busy = true
	_stop_idle()
	_page = Page.HAND
	_hover_id = ""
	_set_hits_enabled(false)
	_hide_subpage()
	_set_menu_ui_visible(false)

	for i in range(_intro_frames.size() - 1, -1, -1):
		frames.texture = _intro_frames[i]
		await get_tree().create_timer(RETRACT_HOLD[_intro_frames.size() - 1 - i], true).timeout

	_finish_close()


func _start_idle() -> void:
	_idle = true
	_idle_index = 0
	_idle_dir = 1
	_idle_timer = 0.0
	_idle_hold = IDLE_HOLD
	frames.texture = _idle_frames[0]


func _stop_idle() -> void:
	_idle = false
	_idle_timer = 0.0
	_select_mode = ""
	_select_timer = 0.0


func _activate_finger(finger_id: String) -> void:
	if _busy or not visible or _page != Page.HAND:
		return

	match finger_id:
		"pinky":
			close()
		"thumb":
			_exit_to_menu()
		"index":
			_open_page(Page.VOLUME)
		"middle":
			_open_page(Page.DISPLAY)
		"ring":
			_open_page(Page.CONTROLS)


func _open_page(page: Page) -> void:
	_page = page
	subpage.visible = true
	_set_hits_enabled(false)
	volume_box.visible = page == Page.VOLUME
	display_box.visible = page == Page.DISPLAY
	controls_box.visible = page == Page.CONTROLS
	match page:
		Page.VOLUME:
			sub_title.text = "VOLUME"
		Page.DISPLAY:
			sub_title.text = "DISPLAY"
			_update_fullscreen_label()
		Page.CONTROLS:
			sub_title.text = "CONTROLS"
	$SubPage/Card/VBox/Back.grab_focus()


func _show_hand() -> void:
	_page = Page.HAND
	_hide_subpage()


func _hide_subpage() -> void:
	_page = Page.HAND
	subpage.visible = false
	if visible and not _busy:
		_set_hits_enabled(true)


func _set_hits_enabled(enabled: bool) -> void:
	for hit in _hits.values():
		hit.disabled = not enabled


func _set_health_hud_visible(show_hud: bool) -> void:
	for hud in get_tree().get_nodes_in_group("finger_health_ui"):
		if hud is CanvasItem:
			hud.visible = show_hud


func _set_menu_ui_visible(show_ui: bool) -> void:
	var alpha := 1.0 if show_ui else 0.0
	for tag in _tags.values():
		tag.modulate.a = alpha


func _exit_to_menu() -> void:
	if _busy:
		return
	_busy = true
	_stop_idle()
	_hover_id = ""
	_set_hits_enabled(false)
	_hide_subpage()
	_set_menu_ui_visible(false)
	for i in range(_intro_frames.size() - 1, -1, -1):
		frames.texture = _intro_frames[i]
		await get_tree().create_timer(RETRACT_HOLD[_intro_frames.size() - 1 - i], true).timeout
	visible = false
	_busy = false
	if not _intro_frames.is_empty():
		frames.texture = _intro_frames[0]
	get_tree().paused = false
	_lock_player(_player_was_locked)
	GameState.reset()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_volume_changed(value: float) -> void:
	var linear := clampf(value / 100.0, 0.0, 1.0)
	var silent := linear <= 0.0
	var db := -80.0 if silent else linear_to_db(linear)
	for i in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, silent)
		AudioServer.set_bus_volume_db(i, db)
	volume_value.text = "%d%%" % int(value)


func _toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode == Window.MODE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
	else:
		win.mode = Window.MODE_FULLSCREEN
	_update_fullscreen_label()


func _update_fullscreen_label() -> void:
	if get_window().mode == Window.MODE_FULLSCREEN:
		fullscreen_button.text = "Fullscreen  ON"
	else:
		fullscreen_button.text = "Fullscreen  OFF"


func _build_finger_ui() -> void:
	for data in FINGERS:
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.position = data.hit_rect.position
		hit.size = data.hit_rect.size
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		hit.add_theme_stylebox_override("normal", empty)
		hit.add_theme_stylebox_override("hover", empty)
		hit.add_theme_stylebox_override("pressed", empty)
		hit.add_theme_stylebox_override("focus", empty)
		hit.pressed.connect(_activate_finger.bind(data.id))
		hit.mouse_entered.connect(_set_hover.bind(data.id, true))
		hit.mouse_exited.connect(_set_hover.bind(data.id, false))
		interact.add_child(hit)
		_hits[data.id] = hit
		_hit_debug[data.id] = _make_hit_debug(hit, data)

		var tag := _make_tag(data)
		tag.position = data.tag_pos
		tag.rotation_degrees = data.rotation
		tag.pivot_offset = Vector2(8, 16)
		interact.add_child(tag)
		_tags[data.id] = tag


func _make_tag(data: Dictionary) -> Label:
	var tag := Label.new()
	tag.text = String(data.subtitle)
	tag.add_theme_font_override("font", TITLE_FONT)
	tag.add_theme_font_size_override("font_size", 36)
	tag.add_theme_color_override("font_color", Color(0.96, 0.96, 0.92))
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	_ignore_mouse(tag)
	return tag


func _has_select_anim(finger_id: String) -> bool:
	return _select_frames.has(finger_id) and not _select_frames[finger_id].is_empty()


func _process_select(delta: float) -> void:
	if not _has_select_anim(_hover_id):
		_select_mode = ""
		return

	var clips: Array = _select_frames[_hover_id]
	_select_timer += delta
	var hold := SELECT_TUG_HOLD
	if _select_mode == "pull" or _select_mode == "release":
		var hold_index := clampi(_select_index, 0, SELECT_PULL_HOLD.size() - 1)
		hold = SELECT_PULL_HOLD[hold_index]
	if _select_timer < hold:
		return

	_select_timer = 0.0
	var last_i: int = clips.size() - 1

	if _select_mode == "pull":
		_select_index = mini(_select_index + 1, last_i)
		frames.texture = clips[_select_index]
		if _select_index >= last_i:
			_select_mode = "tug"
			_select_dir = -1
	elif _select_mode == "tug":
		_select_index += _select_dir
		if _select_index >= last_i:
			_select_index = last_i
			_select_dir = -1
		elif _select_index <= maxi(last_i - 1, 0):
			_select_index = maxi(last_i - 1, 0)
			_select_dir = 1
		frames.texture = clips[_select_index]
	elif _select_mode == "release":
		_select_index = maxi(_select_index - 1, 0)
		frames.texture = clips[_select_index]
		if _select_index <= 0:
			_select_mode = ""
			_hover_id = ""
			if not _idle_frames.is_empty():
				frames.texture = _idle_frames[_idle_index]


func _set_hover(finger_id: String, hovering: bool) -> void:
	if _busy:
		return

	if hovering:
		_hover_id = finger_id
		if _has_select_anim(finger_id):
			_select_mode = "pull"
			_select_index = 0
			_select_dir = 1
			_select_timer = 0.0
			frames.texture = _select_frames[finger_id][0]
		elif not _idle_frames.is_empty():
			_select_mode = ""
			frames.texture = _idle_frames[_idle_frames.size() - 1]
	else:
		if _has_select_anim(finger_id) and (_select_mode == "pull" or _select_mode == "tug"):
			_hover_id = finger_id
			_select_mode = "release"
			_select_timer = 0.0
		else:
			_hover_id = ""
			_select_mode = ""

	for id in _tags.keys():
		var tag: Control = _tags[id]
		var selected: bool = hovering and String(id) == finger_id
		var tween := _tween()
		tween.tween_property(tag, "scale", Vector2(1.12, 1.12) if selected else Vector2.ONE, 0.1)
		tag.modulate = Color(1.15, 1.1, 0.95) if selected else Color.WHITE


func _make_hit_debug(hit: Button, data: Dictionary) -> ColorRect:
	var box := ColorRect.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.color = Color(1.0, 0.85, 0.15, 0.28)
	box.visible = show_hitboxes
	var label := Label.new()
	label.text = "%s\n%s" % [data.number, data.id]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	UIFonts.apply(label)
	box.add_child(label)
	hit.add_child(box)
	return box


func _refresh_hitbox_vis() -> void:
	for box in _hit_debug.values():
		box.visible = show_hitboxes


func _style_text() -> void:
	sub_title.add_theme_font_override("font", TITLE_FONT)
	sub_title.add_theme_font_size_override("font_size", 42)
	UIFonts.apply(volume_value)
	UIFonts.apply($SubPage/Card/VBox/Back)
	UIFonts.apply($SubPage/Card/VBox/VolumeBox/Hint)
	UIFonts.apply($SubPage/Card/VBox/DisplayBox/Hint)
	UIFonts.apply($SubPage/Card/VBox/ControlsBox/Hint)
	UIFonts.apply(fullscreen_button)


func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child)


func _tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween
