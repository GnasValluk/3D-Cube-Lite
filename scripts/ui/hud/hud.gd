## ui/hud.gd
## HUD chính: skill bar, hotbar, inventory, map, phone, etc.

extends CanvasLayer
class_name HUD

const S: float = 1.6
const SS: float = 1.4

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.22, 0.62, 0.28)
const TEAL := Color(0.12, 0.52, 0.32)
const PINK := Color(0.88, 0.35, 0.32)
const ORANGE := Color(0.92, 0.62, 0.15)
const CYAN := Color(0.18, 0.72, 0.52)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

var _tracked: CharacterBase = null
var _dummy_label: Label
var _dummy_tracked: CharacterBase = null
var _skill_bar: SkillBar
var _hotbar: Hotbar
var _inventory_ui: InventoryUI
var _chest_ui
var _crafting_ui
var _recipe_library: Control
var _furnace_ui
var _inventory_open: bool = false
var _chest_open: bool = false
var _current_chest: Chest = null
var _crafting_open: bool = false
var _current_crafting: CraftingTable = null
var _furnace_open: bool = false
@onready var _current_furnace = null
var _switch_hint: Label
var _settings_ui
var _library
var _mgr: CharacterManager
var _portal_btn: Button
var _build_menu: BuildMenu
var _placement_sys: PlacementSystem
var _build_hint: Label
var _explore_map: ExploreMap
var _explore_sys: ExploreSystem
var _mini_map: MiniMap
var _phone_ui: PhoneUI
var _nearest_hint = null
var _chat_overlay: ChatOverlay = null

enum { LOAD_IDLE, LOAD_LOADING, LOAD_READY, LOAD_FADEOUT }
var _load_state: int = LOAD_IDLE
var _load_overlay: ColorRect
var _load_bar_fill: ColorRect
var _load_label: Label
var _load_progress: float = 0.0
var _load_elapsed: float = 0.0
var _load_scene: String = "res://scenes/open_world.tscn"
var _portal_timer: float = 0.0
var _world_clock: Label
var _debug_open: bool = false
var _debug_panel: Panel
var _debug_ts_label: Label
var _debug_hour_slider: HSlider
var _debug_speed_slider: HSlider
var _debug_weather_btn: Button
var _debug_hint_btn: Button
var _time_label: Label
var _coords_label: Label
var _temperature_label: Label  # hiển thị nhiệt độ góc phải
var _zoom_slider: VSlider
var _zoom_slider_timer: float = 0.0
var _zoom_slider_label: Label
var _last_tp_zoom: float = -1.0
var _hud_throttle: float = 0.0
var _crosshair: Control = null

const _Dim = preload("res://scripts/world/dimension_defs.gd")
const _Village = preload("res://scripts/world/chunk/village.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _ChestUI = preload("res://scripts/items/ui/chest_ui.gd")
const _CraftingUI = preload("res://scripts/items/ui/crafting_ui.gd")
const _RecipeLibrary = preload("res://scripts/items/ui/recipe_library_panel.gd")
const _FurnaceUI = preload("res://scripts/items/ui/furnace_ui.gd")
const _Library = preload("res://scripts/ui/library/creature_library.gd")
const _Debug = preload("debug_menu.gd")
const _NearestHint = preload("res://scripts/ui/hud/nearest_creature_hint.gd")
const _ChatOverlay = preload("res://scripts/ui/chat_overlay.gd")

func _ready() -> void:
	_setup_ui()
	await get_tree().process_frame
	_find_and_track()
	var rig := get_parent().get_node_or_null("CameraRig") as Node3D
	if rig and rig.has_signal("zoom_changed"):
		rig.zoom_changed.connect(func(v: float):
			var zmin: float = rig.zoom_min if "zoom_min" in rig else 4.0
			var zmax: float = rig.zoom_max if "zoom_max" in rig else 55.0
			_on_zoom_changed(v, zmin, zmax)
		)
	var tp_init := get_parent().get_node_or_null("TPCameraRig")
	if tp_init:
		_last_tp_zoom = tp_init.distance if "distance" in tp_init else 5.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if _switch_hint: _switch_hint.text = tr("SWITCH_HINT")
		if _portal_btn: _portal_btn.text = tr("PORTAL_BUTTON")
		if _load_label: _load_label.text = tr("GENERATE_LABEL")

	if what == NOTIFICATION_ENTER_TREE:
		var path := get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""
		if path == "res://scenes/open_world.tscn":
			_load_scene = "res://scenes/open_world_real.tscn"
		elif path == "res://scenes/open_world_real.tscn":
			_load_scene = "res://scenes/open_world.tscn"

func _setup_ui() -> void:
	_dummy_label = Label.new()
	_dummy_label.position = Vector2(28, 78)
	_dummy_label.add_theme_font_size_override("font_size", 22)
	_dummy_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 0.8))
	_dummy_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_dummy_label.add_theme_constant_override("shadow_offset_x", 1)
	_dummy_label.add_theme_constant_override("shadow_offset_y", 1)
	_dummy_label.text = ""
	add_child(_dummy_label)

	_skill_bar = SkillBar.new()
	add_child(_skill_bar)

	_hotbar = Hotbar.new()
	_hotbar.visible = false
	_hotbar.slot_changed.connect(_on_hotbar_slot_changed)
	add_child(_hotbar)

	_inventory_ui = InventoryUI.new()
	add_child(_inventory_ui)

	_chest_ui = _ChestUI.new()
	add_child(_chest_ui)

	_crafting_ui = _CraftingUI.new()
	add_child(_crafting_ui)

	_recipe_library = _RecipeLibrary.new()
	add_child(_recipe_library)

	_furnace_ui = _FurnaceUI.new()
	add_child(_furnace_ui)

	_switch_hint = Label.new()
	_switch_hint.position = Vector2(84, 22)
	_switch_hint.add_theme_font_size_override("font_size", 18)
	_switch_hint.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.55))
	_switch_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_switch_hint.add_theme_constant_override("shadow_offset_x", 1)
	_switch_hint.add_theme_constant_override("shadow_offset_y", 1)
	_switch_hint.text = tr("SWITCH_HINT")
	add_child(_switch_hint)

	_settings_ui = SettingsUI.new()
	add_child(_settings_ui)

	_build_menu = BuildMenu.new()
	add_child(_build_menu)
	_build_menu.building_selected.connect(_on_build_selected)
	_build_menu.closed.connect(_on_build_menu_closed)
	_build_menu.visible = false

	_explore_map = ExploreMap.new()
	add_child(_explore_map)

	_mini_map = MiniMap.new()
	_mini_map.gui_input.connect(func(event: InputEvent):
		if _explore_sys and event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if _explore_map and _explore_map.visible:
					_explore_map.close()
				else:
					_explore_map.open(_explore_sys)
	)
	add_child(_mini_map)

	_phone_ui = PhoneUI.new()
	add_child(_phone_ui)

	_nearest_hint = _NearestHint.new()
	_nearest_hint.player_getter = Callable(self, "_find_player_character")
	add_child(_nearest_hint)

	_chat_overlay = _ChatOverlay.new()
	_chat_overlay.message_submitted.connect(_on_chat_submitted)
	add_child(_chat_overlay)
	_chat_overlay.visible = true
	if Net != null:
		Net.chat_message_received.connect(_on_chat_message)

	_build_hint = Label.new()
	_build_hint.position = Vector2(17, 78)
	_build_hint.add_theme_font_size_override("font_size", 18)
	_build_hint.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.6))
	_build_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_build_hint.add_theme_constant_override("shadow_offset_x", 1)
	_build_hint.add_theme_constant_override("shadow_offset_y", 1)
	_build_hint.text = ""
	add_child(_build_hint)

	_portal_btn = Button.new()
	_portal_btn.position = Vector2(0, 0)
	_portal_btn.size = Vector2(308, 70)
	_portal_btn.text = tr("PORTAL_BUTTON")
	_portal_btn.add_theme_font_size_override("font_size", 28)
	_portal_btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.65)
	pb_bg.corner_radius_top_left = 10; pb_bg.corner_radius_top_right = 10
	pb_bg.corner_radius_bottom_left = 10; pb_bg.corner_radius_bottom_right = 10
	pb_bg.border_width_left = 1; pb_bg.border_width_right = 1
	pb_bg.border_width_top = 1; pb_bg.border_width_bottom = 1
	pb_bg.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.12)
	_portal_btn.add_theme_stylebox_override("normal", pb_bg)
	var pb_hover := pb_bg.duplicate()
	pb_hover.bg_color = Color(0.22, 0.18, 0.35, 0.75)
	pb_hover.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.40)
	_portal_btn.add_theme_stylebox_override("hover", pb_hover)
	_portal_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_portal_btn.pressed.connect(_on_portal_click)
	_portal_btn.visible = false
	add_child(_portal_btn)

	_setup_world_clock()

	_setup_loading_overlay()

	_setup_time_label()
	_setup_zoom_slider()
	_setup_debug_menu()
	_setup_mobile_controls()
	_setup_crosshair()

## FPS-style crosshair (chỉ hiện khi đang ngắm vũ khí ở góc 3).
func _setup_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	add_child(_crosshair)

	var gap := 5.0
	var len := 7.0
	var th := 2.0
	var segs: Array[Array] = [
		[-gap - len, -th * 0.5, len, th],
		[gap, -th * 0.5, len, th],
		[-th * 0.5, -gap - len, th, len],
		[-th * 0.5, gap, th, len],
	]
	for s in segs:
		var r := ColorRect.new()
		r.position = Vector2(s[0], s[1])
		r.size = Vector2(s[2], s[3])
		r.color = Color(1.0, 1.0, 1.0, 0.9)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crosshair.add_child(r)
	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.3, 0.1, 0.9)
	dot.position = Vector2(-1.5, -1.5)
	dot.size = Vector2(3, 3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(dot)

## Ẩn con trỏ chuột khi đang chơi (không mở menu nào); hiện lại khi mở UI.
## Cam 3 (TPS): khóa chuột vào giữa màn hình (MOUSE_MODE_CAPTURED) để xoay
## camera bằng chuyển động chuột, tránh con trỏ trôi loạn; ISO giữ HIDDEN.
func _sync_mouse_visibility() -> void:
	var ui_open := false
	if _inventory_open or _chest_open or _crafting_open or _furnace_open or _debug_open:
		ui_open = true
	elif _settings_ui and _settings_ui.visible:
		ui_open = true
	elif _build_menu and _build_menu.visible:
		ui_open = true
	elif _explore_map and _explore_map.visible:
		ui_open = true
	elif _phone_ui and _phone_ui.visible:
		ui_open = true
	elif _library and _library.visible:
		ui_open = true
	if ui_open:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	var player := _find_player_character()
	if player != null and player._use_tp:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _setup_mobile_controls() -> void:
	const _MobCtrl = preload("res://scripts/ui/mobile/mobile_controls.gd")
	var mob: Node = _MobCtrl.new()
	mob.name = "MobileControls"
	get_parent().call_deferred("add_child", mob)
	mob.inventory_pressed.connect(func():
		var cur := _mgr.get_current_character() if _mgr else null
		if cur is PlayerCharacter:
			_toggle_inventory()
	)
	mob.interact_pressed.connect(func():
		var player := _find_player_character()
		if player:
			player.interact_with_nearby()
	)
	mob.map_pressed.connect(func():
		if _explore_map and _explore_map.visible:
			_explore_map.close()
		elif _explore_sys:
			_explore_map.open(_explore_sys)
	)
	mob.pinch_zoom.connect(func(factor: float):
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl._use_tp:
			var tp := get_parent().get_node_or_null("TPCameraRig")
			if tp:
				tp.pinch_zoom(1.0 / factor)
			return
		var rig := get_parent().get_node_or_null("CameraRig")
		if rig:
			rig.pinch_zoom(1.0 / factor)
	)

func _setup_loading_overlay() -> void:
	_load_overlay = ColorRect.new()
	_load_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_load_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.visible = false
	add_child(_load_overlay)

	_load_label = Label.new()
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.add_theme_font_size_override("font_size", 28)
	_load_label.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.9))
	_load_label.text = tr("GENERATE_LABEL")
	_load_label.visible = false
	add_child(_load_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.70)
	bar_bg.visible = false
	bar_bg.name = "LoadingBarBg"
	_load_overlay.add_child(bar_bg)

	_load_bar_fill = ColorRect.new()
	_load_bar_fill.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.80)
	
	_load_bar_fill.visible = false
	_load_overlay.add_child(_load_bar_fill)

	_library = _Library.new()
	add_child(_library)

func _on_save_pressed() -> void:
	if SaveManager:
		SaveManager.save_game()
	var player := _find_player_character()
	if player:
		player._scroll_inventory_message(tr("GAME_SAVED"))

## Nút Shutdown trên điện thoại: lưu game rồi về màn hình chính
func exit_to_main_menu() -> void:
	if _phone_ui and _phone_ui.visible:
		_phone_ui.close()
	if SaveManager:
		SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _on_library_pressed() -> void:
	if _library:
		_library.show_library()

func _toggle_settings() -> void:
	if _settings_ui and _settings_ui.visible:
		_settings_ui.hide_settings()
	else:
		_settings_ui.show_settings()

func _process(delta: float) -> void:
	if _dummy_tracked:
		_dummy_label.text = tr("DUMMY_FORMAT") % [_dummy_tracked.hp, _dummy_tracked.max_hp]
	else:
		_dummy_label.text = ""

	if _placement_sys and _placement_sys.is_placing():
		_placement_sys.update_placement()
		_build_hint.text = tr("BUILD_HINT_PLACING")
	else:
		_build_hint.text = ""

	# Crosshair FPS: chỉ hiện khi ngắm vũ khí tầm xa ở góc 3 (nỏ/cối/pháo dưa hấu).
	var _cross_player := _find_player_character()
	var _cross_show := false
	if _crosshair and _cross_player and _cross_player._use_tp and _cross_player._bow_aiming:
		if _cross_player.equipped_weapon != null:
			var _wid: String = _cross_player.equipped_weapon.id
			if _wid == "crossbow" or _wid == "watermelon_cannon" or _wid == "pumpkin_mortar":
				_cross_show = true
	if _crosshair:
		_crosshair.visible = _cross_show
		if _cross_show:
			_crosshair.position = get_viewport().get_visible_rect().size * 0.5

	_sync_mouse_visibility()

	var vp: Vector2 = get_viewport().get_visible_rect().size
	_hud_throttle -= delta

	if _hud_throttle <= 0:
		_hud_throttle = 0.08
		if TimeSystem:
			var h: int = TimeSystem.get_hour_int()
			var m: int = TimeSystem.get_minute()
			_world_clock.text = "%02d:%02d" % [h, m]
			_time_label.text = "%s %d  |  %s  |  %s" % [TimeSystem.get_month_name(), TimeSystem.get_day(), TimeSystem.get_season_name(), TimeSystem.get_weather_name()]
			var ts_player := _find_player_character()
			var ts_tracked: CharacterBase = _mgr.get_current_character() if _mgr else null
			var ts_src: Node3D = ts_player if ts_player else ts_tracked
			if ts_src and is_instance_valid(ts_src) and ts_src.is_inside_tree():
				_temperature_label.text = TimeSystem.get_temperature_string(ts_src.global_position.y)
			else:
				_temperature_label.text = TimeSystem.get_temperature_string()
		else:
			var env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
			if env and env.has_method("get_cycle_progress"):
				var prog: float = fmod(env.get_cycle_progress(), 1.0)
				var total_minutes: int = int(prog * 1440.0)
				var hours: int = total_minutes / 60
				var minutes: int = total_minutes % 60
				_world_clock.text = "%02d:%02d" % [hours, minutes]
		if _coords_label:
			var player := _find_player_character()
			var tracked_ch: CharacterBase = _mgr.get_current_character() if _mgr else null
			var pos_src: Node3D = player if player else tracked_ch
			if pos_src and is_instance_valid(pos_src) and pos_src.is_inside_tree():
				var p := pos_src.global_position
				_coords_label.text = "X %.1f  Y %.1f  Z %.1f" % [p.x, p.y, p.z]
			else:
				_coords_label.text = ""

	if _mini_map:
		_mini_map.visible = _explore_sys != null and get_parent().has_node("WorldManager") and not (_explore_map and _explore_map.visible)
		if _mini_map.visible:
			_mini_map.position = Vector2(vp.x - 227, vp.y - 227)

	_world_clock.position = Vector2(vp.x - _world_clock.size.x - 17, 17)
	_time_label.position = Vector2(vp.x - _time_label.size.x - 17, 42)

	if _coords_label:
		_coords_label.size = Vector2(308, 26)
		_coords_label.position = Vector2(vp.x - _coords_label.size.x - 17, 64)
	if _temperature_label:
		_temperature_label.position = Vector2(vp.x - _temperature_label.size.x - 17, 86)

	var tp_rig := get_parent().get_node_or_null("TPCameraRig")
	if tp_rig and is_instance_valid(tp_rig) and "distance" in tp_rig:
		var tp_dist: float = tp_rig.distance
		if tp_dist != _last_tp_zoom:
			_last_tp_zoom = tp_dist
			var tp_min: float = tp_rig.zoom_min if "zoom_min" in tp_rig else 2.0
			var tp_max: float = tp_rig.zoom_max if "zoom_max" in tp_rig else 22.0
			_on_zoom_changed(tp_dist, tp_min, tp_max)
	if _zoom_slider.visible:
		_zoom_slider.position = Vector2(vp.x - 48, (vp.y - _zoom_slider.size.y) * 0.5)
		_zoom_slider_label.position = Vector2(vp.x - 48, (vp.y - _zoom_slider.size.y) * 0.5 - 22)
		_zoom_slider_timer -= delta
		if _zoom_slider_timer <= 0.0:
			_zoom_slider.visible = false
			_zoom_slider_label.visible = false

	if _debug_open:
		_debug_panel.position = Vector2(vp.x * 0.5 - 228, vp.y * 0.5 - 169)
		_update_debug_menu()

	if _load_state == LOAD_IDLE:
		if Net and Net.is_active():
			_portal_btn.visible = false
			return
		var platform := _find_portal_gate()
		if platform and platform.is_player_on():
			var cur := get_tree().current_scene.scene_file_path
			if cur == "res://scenes/open_world.tscn":
				_load_scene = "res://scenes/open_world_real.tscn"
				_portal_btn.text = tr("REAL_WORLD_BTN")
			else:
				_load_scene = "res://scenes/open_world.tscn"
				_portal_btn.text = tr("TWILIGHT_BTN")
			_portal_btn.visible = true
			_portal_btn.position = Vector2((vp.x - _portal_btn.size.x) * 0.5, vp.y * 0.75)
			_portal_timer += delta
			if _portal_timer >= 1.5:
				_on_portal_click()
		else:
			_portal_btn.visible = false
			_portal_timer = 0.0
		return

	_load_elapsed += delta
	_update_loading_overlay(vp)

	if _load_state == LOAD_LOADING:
		var st: Array = []
		var ret := ResourceLoader.load_threaded_get_status(_load_scene, st)
		_load_progress = st[0] if st.size() > 0 else 0.0
		if ret == ResourceLoader.THREAD_LOAD_LOADED:
			_load_state = LOAD_READY
			_load_label.text = tr("ENTER_WORLD")
			_load_progress = 1.0
		elif _load_elapsed < 1.0:
			_load_progress = _load_elapsed * 0.3
	elif _load_state == LOAD_READY:
		if _load_elapsed >= 1.0:
			_load_state = LOAD_FADEOUT
			_load_elapsed = 0.0
	elif _load_state == LOAD_FADEOUT:
		var t: float = min(_load_elapsed / 0.5, 1.0)
		_load_overlay.color.a = 0.85 + t * 0.15
		if t >= 1.0:
			var packed := ResourceLoader.load_threaded_get(_load_scene)
			get_tree().change_scene_to_packed(packed)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			# Chat: chỉ Enter bật/tắt hộp nhập (không dùng ui_accept vì Space cũng khớp);
			# trong hộp nhập Enter gửi tin, Esc đóng.
			var is_enter: bool = k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER
			if _chat_overlay:
				if _chat_overlay.is_input_open():
					if k.is_action_pressed("ui_cancel") or is_enter:
						_chat_overlay.close_input()
						return
				elif is_enter:
					_chat_overlay.open_input()
					return

			if _chest_open:
				if k.is_action_pressed("controls/interact") or k.is_action_pressed("ui_cancel") or k.is_action_pressed("controls/inventory"):
					close_chest()
				return

			if _furnace_open:
				if k.is_action_pressed("controls/interact") or k.is_action_pressed("ui_cancel") or k.is_action_pressed("controls/inventory"):
					close_furnace()
				return

			if _crafting_open:
				if k.is_action_pressed("controls/interact") or k.is_action_pressed("ui_cancel") or k.is_action_pressed("controls/inventory"):
					close_crafting()
				return

			if _inventory_open:
				if k.is_action_pressed("controls/inventory") or k.is_action_pressed("ui_cancel"):
					_toggle_inventory()
				return

			if _placement_sys and _placement_sys.is_placing():
				if k.is_action_pressed("ui_cancel"):
					_placement_sys.cancel_placement()
					_build_hint.text = ""
				return

			for i in range(9):
				if k.is_action_pressed("hotbar_%d" % (i + 1)):
					var cur := _mgr.get_current_character() if _mgr else null
					if cur is PlayerCharacter and _hotbar.visible:
						_hotbar.select_slot(i)
						return

			if k.is_action_pressed("controls/interact"):
				var player := _find_player_character()
				if player:
					player.interact_with_nearby()
				return

			if k.is_action_pressed("controls/inventory"):
				var cur := _mgr.get_current_character() if _mgr else null
				if cur is PlayerCharacter:
					_toggle_inventory()
				return

			if k.is_action_pressed("controls/debug"):
				_toggle_debug()
				return

			if k.is_action_pressed("phone_toggle"):
				if _phone_ui:
					if _phone_ui.visible:
						_phone_ui.close()
					else:
						_phone_ui.open()
				return

			if k.is_action_pressed("ui_cancel"):
				if _explore_map and _explore_map.visible:
					_explore_map.close()
				elif _build_menu and _build_menu.visible:
					_build_menu.close()
				elif _settings_ui and _settings_ui.visible:
					_settings_ui.hide_settings()
				elif _library and _library.visible:
					_library.visible = false
				elif _inventory_open:
					_toggle_inventory()
				elif _phone_ui and _phone_ui.visible:
					_phone_ui.close()
				else:
					_toggle_settings()

func _toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	if _inventory_open:
		_inventory_ui.open()
	else:
		_inventory_ui.close()
	if not _inventory_open:
		_release_focus(_inventory_ui)
	var player := _find_player_character()
	if player:
		player._inventory_open = _inventory_open
		if not _inventory_open:
			player._held_item = {}

func _release_focus(node: Node) -> void:
	if node is Control and node.has_focus():
		node.release_focus()
	for child in node.get_children():
		_release_focus(child)

func _on_chat_message(sender_name: String, sender_color: Color, text: String) -> void:
	if _chat_overlay:
		_chat_overlay.add_message(sender_name, sender_color, text)

func _on_chat_submitted(text: String) -> void:
	if Net != null and Net.is_active():
		Net.send_chat_message(text)
	else:
		var p := _find_player_character()
		var name_str := "You" if p == null else p.character_name
		_on_chat_message(name_str, Color(0.6, 0.9, 0.6), text)

func open_chest(chest) -> void:
	if _chest_open:
		return
	if _inventory_open:
		_toggle_inventory()
	_chest_open = true
	_current_chest = chest
	var player := _find_player_character()
	if player:
		_chest_ui.open(chest, player)

func close_chest() -> void:
	if not _chest_open:
		return
	_chest_open = false
	_chest_ui.close()
	if _current_chest and is_instance_valid(_current_chest):
		_current_chest.close_ui()
	_current_chest = null

func open_crafting(table) -> void:
	if _crafting_open:
		return
	if _inventory_open:
		_toggle_inventory()
	if _chest_open:
		close_chest()
	_crafting_open = true
	_current_crafting = table
	_recipe_library.visible = false
	var player := _find_player_character()
	if player:
		_crafting_ui.open(player)

func open_furnace(furnace) -> void:
	if _furnace_open:
		return
	if _inventory_open:
		_toggle_inventory()
	if _chest_open:
		close_chest()
	if _crafting_open:
		close_crafting()
	_furnace_open = true
	_current_furnace = furnace
	var player := _find_player_character()
	if player:
		_furnace_ui.open(furnace, player)

func close_furnace() -> void:
	if not _furnace_open:
		return
	_furnace_open = false
	_furnace_ui.close()
	if _current_furnace and is_instance_valid(_current_furnace):
		_current_furnace.close_ui()
	_current_furnace = null

func close_crafting() -> void:
	if not _crafting_open:
		return
	_crafting_open = false
	_recipe_library.close()
	_crafting_ui.close()
	if _current_crafting and is_instance_valid(_current_crafting):
		_current_crafting.close_ui()
	_current_crafting = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if Input.is_action_pressed("crouch") and _hotbar.visible:
					var cur := _mgr.get_current_character() if _mgr else null
					if cur is PlayerCharacter:
						var idx: int = _hotbar.get_selected()
						idx += -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
						idx = (idx + 9) % 9
						_hotbar.select_slot(idx)
						get_viewport().set_input_as_handled()
					return
			if _placement_sys and _placement_sys.is_placing():
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_placement_sys.confirm_placement()
					_build_hint.text = ""
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					_placement_sys.rotate_placement()
					_build_hint.text = ""

func _find_and_track() -> void:
	_mgr = _find_manager()
	if _mgr == null:
		await get_tree().create_timer(0.5).timeout
		_find_and_track()
		return
	_track_dummy(_mgr)
	_track_character(_mgr.get_current_character())
	_mgr.character_switched.connect(_track_character)

	_placement_sys = _find_placement_system()
	if _placement_sys == null:
		_placement_sys = PlacementSystem.new()
		var p := get_parent()
		if p:
			p.add_child(_placement_sys, true)
	var player := _find_player_character()
	if player:
		_placement_sys.set_player_inventory(player.inventory, player)
	_explore_sys = _find_explore_system()
	if _explore_sys:
		_explore_sys.set_player(_mgr.get_current_character())
		_mgr.character_switched.connect(_explore_sys.set_player)
		if _mini_map:
			_mini_map.setup(_explore_sys)

func _find_manager() -> CharacterManager:
	var root := get_parent()
	if root and root.has_node("CharacterManager"):
		return root.get_node("CharacterManager")
	return null

func _find_placement_system() -> PlacementSystem:
	var root := get_parent()
	if root and root.has_node("PlacementSystem"):
		return root.get_node("PlacementSystem") as PlacementSystem
	var scene := get_tree().current_scene
	if scene and scene.has_node("PlacementSystem"):
		return scene.get_node("PlacementSystem") as PlacementSystem
	return null

func _find_explore_system() -> ExploreSystem:
	var root := get_parent()
	if root and root.has_node("ExploreSystem"):
		return root.get_node("ExploreSystem") as ExploreSystem
	return null

func _track_dummy(mgr: CharacterManager) -> void:
	for ch in mgr.get_children():
		if ch is CharacterBase and not ch._is_player:
			_dummy_tracked = ch
			if not ch.hp_changed.is_connected(_update_dummy_label):
				ch.hp_changed.connect(_update_dummy_label)
			return
	_dummy_tracked = null

func _update_dummy_label(_a: int = 0, _b: int = 0) -> void:
	if _dummy_tracked:
		_dummy_label.text = tr("DUMMY_FORMAT") % [_dummy_tracked.hp, _dummy_tracked.max_hp]

func _find_player_character() -> PlayerCharacter:
	if _mgr == null:
		return null
	for ch in _mgr._characters:
		if ch is PlayerCharacter:
			return ch as PlayerCharacter
	return null

func _track_character(ch: CharacterBase) -> void:
	_tracked = ch
	if ch == null:
		_dummy_label.text = ""
		return

	var is_player: bool = ch is PlayerCharacter
	_skill_bar.visible = not is_player
	_hotbar.visible = is_player
	_hotbar.set_inventory(null)
	if _inventory_open:
		_inventory_open = false
		_inventory_ui.close()
		var player := _find_player_character()
		if player:
			player._inventory_open = false
			player._held_item = {}
	if _chest_open:
		close_chest()
	if is_player:
		var player_ch := ch as PlayerCharacter
		player_ch._inventory_open = _inventory_open
		player_ch._held_item = {}
		if player_ch.inventory:
			_hotbar.set_inventory(player_ch.inventory)
			_hotbar.set_player(player_ch)
			_on_hotbar_slot_changed(_hotbar.get_selected())
			_inventory_ui.set_inventory(player_ch.inventory)
			_inventory_ui.set_player(player_ch)
	else:
		_skill_bar.track(ch)

func _find_portal_gate() -> PortalGate:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is PortalGate and child.is_player_on():
			return child as PortalGate
	var wm := parent.get_node_or_null("WorldManager") as OpenWorldManager
	if wm:
		for child in wm.get_children():
			if child is PortalGate and child.is_player_on():
				return child as PortalGate
	return null

func _on_build_selected(item_id: String) -> void:
	if _placement_sys:
		_build_menu.close()
		var player := _find_player_character()
		if player:
			_placement_sys.set_player_inventory(player.inventory, player)
		_placement_sys.start_placement(item_id)

func _on_build_menu_closed() -> void:
	_build_hint.text = ""

func _on_hotbar_slot_changed(idx: int) -> void:
	var def: ItemDef = _hotbar.get_selected_item()
	var player := _find_player_character()
	if player:
		player._selected_slot = idx
	if _placement_sys and _placement_sys.is_placing():
		_placement_sys.cancel_placement()
		_build_hint.text = ""
	if def != null and _is_building_item(def):
		if _placement_sys == null:
			return
		if player:
			_placement_sys.set_player_inventory(player.inventory, player)
		_placement_sys.start_placement(def.id)
		_build_hint.text = tr("BUILD_HINT_PLACING")

func _is_building_item(def: ItemDef) -> bool:
	if def.type == ItemDef.Type.BLOCK:
		return true
	if def.id in ["twilight_gate", "chest", "crafting_table", "water_bucket", "fishing_boat", "tractor", "rescue_helicopter"]:
		return true
	if def.id in ["coconut_seed", "taro_seed", "seaweed_seed", "seagrass_seed", "eggplant_seed", "watermelon_seed", "pumpkin_seed"]:
		return true
	return false

func _setup_world_clock() -> void:
	_world_clock = Label.new()
	_world_clock.add_theme_font_size_override("font_size", 22)
	_world_clock.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8))
	_world_clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_world_clock.add_theme_constant_override("shadow_offset_x", 1)
	_world_clock.add_theme_constant_override("shadow_offset_y", 1)
	_world_clock.text = "06:00"
	add_child(_world_clock)

func _setup_time_label() -> void:
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 18)
	_time_label.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	_time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_time_label.add_theme_constant_override("shadow_offset_x", 1)
	_time_label.add_theme_constant_override("shadow_offset_y", 1)
	_time_label.text = ""
	add_child(_time_label)

	_coords_label = Label.new()
	_coords_label.add_theme_font_size_override("font_size", 18)
	_coords_label.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65, 0.75))
	_coords_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_coords_label.add_theme_constant_override("shadow_offset_x", 1)
	_coords_label.add_theme_constant_override("shadow_offset_y", 1)
	_coords_label.text = ""
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_coords_label)

	_temperature_label = Label.new()
	_temperature_label.add_theme_font_size_override("font_size", 18)
	_temperature_label.add_theme_color_override("font_color", Color(0.95, 0.60, 0.30, 0.80))
	_temperature_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_temperature_label.add_theme_constant_override("shadow_offset_x", 1)
	_temperature_label.add_theme_constant_override("shadow_offset_y", 1)
	_temperature_label.text = ""
	add_child(_temperature_label)

func _setup_zoom_slider() -> void:
	_zoom_slider = VSlider.new()
	_zoom_slider.name = "ZoomSlider"
	_zoom_slider.visible = false
	_zoom_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_slider.min_value = 4.0
	_zoom_slider.max_value = 55.0
	_zoom_slider.step = 1.0
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.10, 0.07, 0.18, 0.70)
	ss.corner_radius_top_left = 6; ss.corner_radius_top_right = 6
	ss.corner_radius_bottom_left = 6; ss.corner_radius_bottom_right = 6
	ss.border_width_left = 1; ss.border_width_right = 1
	ss.border_width_top = 1; ss.border_width_bottom = 1
	ss.border_color = Color(0.40, 0.30, 0.60, 0.5)
	_zoom_slider.add_theme_stylebox_override("slider", ss)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.22, 0.62, 0.28, 0.85)
	grabber.corner_radius_top_left = 4; grabber.corner_radius_top_right = 4
	grabber.corner_radius_bottom_left = 4; grabber.corner_radius_bottom_right = 4
	_zoom_slider.add_theme_stylebox_override("grabber", grabber)
	_zoom_slider.add_theme_color_override("grabber_color", Color(0.22, 0.62, 0.28))
	_zoom_slider.add_theme_constant_override("grabber_ratio", 0.15)
	_zoom_slider.size = Vector2(28, 160)
	add_child(_zoom_slider)

	_zoom_slider_label = Label.new()
	_zoom_slider_label.name = "ZoomSliderLabel"
	_zoom_slider_label.visible = false
	_zoom_slider_label.add_theme_font_size_override("font_size", 14)
	_zoom_slider_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
	_zoom_slider_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_zoom_slider_label.add_theme_constant_override("shadow_offset_x", 1)
	_zoom_slider_label.add_theme_constant_override("shadow_offset_y", 1)
	_zoom_slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_slider_label.text = "4"
	add_child(_zoom_slider_label)

func _on_zoom_changed(value: float, v_min: float = 4.0, v_max: float = 55.0) -> void:
	if not is_instance_valid(_zoom_slider):
		return
	_zoom_slider.visible = true
	_zoom_slider_label.visible = true
	_zoom_slider.min_value = v_min
	_zoom_slider.max_value = v_max
	_zoom_slider.value = clamp(value, v_min, v_max)
	_zoom_slider_label.text = str(int(value))
	_zoom_slider_timer = 2.0

func _setup_debug_menu() -> void:
	_debug_panel = Panel.new()
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(BG_DEEP.r, BG_DEEP.g, BG_DEEP.b, 0.90)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.15)
	_debug_panel.add_theme_stylebox_override("panel", bg)

	var vp := get_viewport().get_visible_rect().size
	_debug_panel.position = Vector2(vp.x * 0.5 - 228, vp.y * 0.5 - 296)
	_debug_panel.size = Vector2(455, 590)

	var title := Label.new()
	title.position = Vector2(17, 11)
	title.size = Vector2(424, 39)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.9))
	title.text = "DEBUG MENU"
	_debug_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(416, 8)
	close_btn.size = Vector2(31, 31)
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_toggle_debug)
	_debug_panel.add_child(close_btn)

	var y: float = 57
	var line_h: float = 47

	var ts_label := Label.new()
	ts_label.position = Vector2(17, y)
	ts_label.size = Vector2(424, 26)
	ts_label.add_theme_font_size_override("font_size", 20)
	ts_label.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	ts_label.text = "Game Time:"
	_debug_panel.add_child(ts_label)
	y += 28

	_debug_ts_label = Label.new()
	_debug_ts_label.position = Vector2(17, y)
	_debug_ts_label.size = Vector2(424, 26)
	_debug_ts_label.add_theme_font_size_override("font_size", 20)
	_debug_ts_label.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.9))
	_debug_ts_label.text = ""
	_debug_panel.add_child(_debug_ts_label)
	y += line_h

	var hour_lbl := Label.new()
	hour_lbl.position = Vector2(17, y)
	hour_lbl.size = Vector2(104, 26)
	hour_lbl.add_theme_font_size_override("font_size", 20)
	hour_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	hour_lbl.text = "Hour:"
	_debug_panel.add_child(hour_lbl)

	_debug_hour_slider = HSlider.new()
	_debug_hour_slider.position = Vector2(126, y)
	_debug_hour_slider.size = Vector2(312, 26)
	_debug_hour_slider.min_value = 0.0
	_debug_hour_slider.max_value = 24.0
	_debug_hour_slider.step = 0.5
	_debug_hour_slider.value = 6.0
	_debug_hour_slider.value_changed.connect(_on_debug_hour_changed)
	_debug_panel.add_child(_debug_hour_slider)
	y += line_h

	var speed_lbl := Label.new()
	speed_lbl.position = Vector2(17, y)
	speed_lbl.size = Vector2(104, 26)
	speed_lbl.add_theme_font_size_override("font_size", 20)
	speed_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	speed_lbl.text = "Speed:"
	_debug_panel.add_child(speed_lbl)

	_debug_speed_slider = HSlider.new()
	_debug_speed_slider.position = Vector2(126, y)
	_debug_speed_slider.size = Vector2(312, 26)
	_debug_speed_slider.min_value = 0.0
	_debug_speed_slider.max_value = 50.0
	_debug_speed_slider.step = 0.5
	_debug_speed_slider.value = 1.0
	_debug_speed_slider.value_changed.connect(_on_debug_speed_changed)
	_debug_panel.add_child(_debug_speed_slider)
	y += line_h

	var weather_lbl := Label.new()
	weather_lbl.position = Vector2(17, y)
	weather_lbl.size = Vector2(104, 26)
	weather_lbl.add_theme_font_size_override("font_size", 20)
	weather_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	weather_lbl.text = "Weather:"
	_debug_panel.add_child(weather_lbl)

	_debug_weather_btn = Button.new()
	_debug_weather_btn.position = Vector2(126, y - 2)
	_debug_weather_btn.size = Vector2(168, 34)
	_debug_weather_btn.add_theme_font_size_override("font_size", 20)
	_debug_weather_btn.text = "Clear"
	_debug_weather_btn.pressed.connect(_on_debug_weather_toggle)
	_debug_panel.add_child(_debug_weather_btn)
	y += line_h

	# ── Teleport to Biome ─────────────────────────────────────────────────────
	var tp_lbl := Label.new()
	tp_lbl.position = Vector2(17, y)
	tp_lbl.size = Vector2(424, 26)
	tp_lbl.add_theme_font_size_override("font_size", 20)
	tp_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	tp_lbl.text = "Teleport to Biome:"
	_debug_panel.add_child(tp_lbl)
	y += 34

	var tp_plains_btn := Button.new()
	tp_plains_btn.position = Vector2(17, y - 2)
	tp_plains_btn.size = Vector2(202, 34)
	tp_plains_btn.add_theme_font_size_override("font_size", 20)
	tp_plains_btn.text = "🌿 Đồng Bằng"
	tp_plains_btn.pressed.connect(_on_teleport_biome.bind("plains"))
	_debug_panel.add_child(tp_plains_btn)

	var tp_ocean_btn := Button.new()
	tp_ocean_btn.position = Vector2(234, y - 2)
	tp_ocean_btn.size = Vector2(202, 34)
	tp_ocean_btn.add_theme_font_size_override("font_size", 20)
	tp_ocean_btn.text = "🌊 Biển Khơi"
	tp_ocean_btn.pressed.connect(_on_teleport_biome.bind("ocean"))
	_debug_panel.add_child(tp_ocean_btn)

	y += 34
	var tp_desert_btn := Button.new()
	tp_desert_btn.position = Vector2(17, y - 2)
	tp_desert_btn.size = Vector2(202, 34)
	tp_desert_btn.add_theme_font_size_override("font_size", 20)
	tp_desert_btn.text = "🏜️ Sa Mạc"
	tp_desert_btn.pressed.connect(_on_teleport_biome.bind("desert"))
	_debug_panel.add_child(tp_desert_btn)

	# ── Teleport to Công Trình ───────────────────────────────────────────────
	y += 34
	var tp_c_lbl := Label.new()
	tp_c_lbl.position = Vector2(17, y)
	tp_c_lbl.size = Vector2(424, 26)
	tp_c_lbl.add_theme_font_size_override("font_size", 20)
	tp_c_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	tp_c_lbl.text = "Teleport to Công Trình:"
	_debug_panel.add_child(tp_c_lbl)
	y += 34

	var tp_tavern_btn := Button.new()
	tp_tavern_btn.position = Vector2(17, y - 2)
	tp_tavern_btn.size = Vector2(202, 34)
	tp_tavern_btn.add_theme_font_size_override("font_size", 20)
	tp_tavern_btn.text = "🍺 Quán Rượu (gần nhất)"
	tp_tavern_btn.pressed.connect(_on_teleport_tavern)
	_debug_panel.add_child(tp_tavern_btn)

	var tp_mountain_btn := Button.new()
	tp_mountain_btn.position = Vector2(234, y - 2)
	tp_mountain_btn.size = Vector2(202, 34)
	tp_mountain_btn.add_theme_font_size_override("font_size", 20)
	tp_mountain_btn.text = "⛰️ Núi (gần nhất)"
	tp_mountain_btn.pressed.connect(_on_teleport_mountain)
	_debug_panel.add_child(tp_mountain_btn)

	y += 34

	# ── Bật/tắt info hint (góc trái trên: sinh vật gần nhất + block mục tiêu) ──
	y += 47
	var hint_lbl := Label.new()
	hint_lbl.position = Vector2(17, y)
	hint_lbl.size = Vector2(424, 26)
	hint_lbl.add_theme_font_size_override("font_size", 20)
	hint_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	hint_lbl.text = "Info Hint:"
	_debug_panel.add_child(hint_lbl)

	_debug_hint_btn = Button.new()
	_debug_hint_btn.toggle_mode = true
	_debug_hint_btn.position = Vector2(126, y - 2)
	_debug_hint_btn.size = Vector2(168, 34)
	_debug_hint_btn.add_theme_font_size_override("font_size", 20)
	_debug_hint_btn.toggled.connect(_on_debug_hint_toggled)
	_debug_panel.add_child(_debug_hint_btn)

	add_child(_debug_panel)

func _on_debug_hint_toggled(pressed: bool) -> void:
	if _nearest_hint and _nearest_hint.has_method("set_enabled"):
		_nearest_hint.set_enabled(pressed)
	_refresh_debug_hint_btn()

func _refresh_debug_hint_btn() -> void:
	if _debug_hint_btn == null:
		return
	var on := false
	if _nearest_hint:
		on = bool(_nearest_hint.hint_enabled)
	_debug_hint_btn.button_pressed = on
	_debug_hint_btn.text = "ON" if on else "OFF"

func _toggle_debug() -> void:
	_debug_open = _Debug.toggle_debug(_debug_open, _debug_panel)
	if _debug_open:
		_update_debug_menu()

func _on_debug_hour_changed(value: float) -> void:
	_Debug.on_hour_changed(value)

func _on_debug_speed_changed(value: float) -> void:
	_Debug.on_speed_changed(value)

func _on_debug_weather_toggle() -> void:
	_Debug.on_weather_toggle(_debug_weather_btn)
	if not TimeSystem:
		return
	var player := _find_player_character()
	if not player:
		return
	var rm := get_tree().current_scene.find_child("RainManager", true, false) as RainManager
	if not rm:
		return
	if TimeSystem.get_weather() == TimeSystem.Weather.RAIN:
		rm.add_zone(Vector2(player.global_position.x, player.global_position.z), 80.0, TimeSystem.CYCLE_DURATION)
	else:
		rm.clear_zones()

func _on_teleport_biome(biome_type: String) -> void:
	var player := _find_player_character()
	if player == null:
		return

	var origin: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	const STEP:  float = 120.0
	const MAX_R: float = 15000.0

	var found: Vector2 = Vector2.ZERO
	var found_ok: bool = false
	var nd: Dictionary = WorldChunk._noise_for_dim(1)
	var n_lake: FastNoiseLite = nd.get("lake")

	# Dùng ĐÚNG nguồn sự thật với địa hình: biome theo _biome_at (có spawn-bias),
	# ocean theo _ocean_mask_at, hồ theo n_lake ngưỡng thật (GRASS 0.70).
	var r: float = STEP
	while r <= MAX_R and not found_ok:
		var samples: int = max(8, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var wx: float = origin.x + cos(angle) * r
			var wz: float = origin.y + sin(angle) * r
			var is_oc: bool = WorldChunk._ocean_mask_at(nd, wx, wz)
			var bio: int = WorldChunk.biome_at(wx, wz, 1)

			match biome_type:
				"plains":
# Đồng bằng cỏ (đã hợp nhất đồng bằng + cao nguyên): toàn bộ
					# đất cỏ là GRASS_DIRT, địa hình đồi thoải; không biển,
					# không hồ.
					var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5 if n_lake else 0.0
					if bio == _Data.TileType.GRASS_DIRT \
							and not is_oc and lv <= 0.70:
						found = Vector2(wx, wz); found_ok = true; break
				"ocean":
					# Biển thật = ocean mask; thả trên nước, không cần biome
					if is_oc:
						found = Vector2(wx, wz); found_ok = true; break
				"desert":
					# Sa mạc đúng — DESERT (đã bỏ cao nguyên sa mạc)
					if bio == _Data.TileType.DESERT:
						found = Vector2(wx, wz); found_ok = true; break
		r += STEP

	if found_ok:
		var biome_name: String = "Đồng Bằng Cỏ"
		if biome_type == "ocean":
			biome_name = "Biển Khơi"
		elif biome_type == "desert":
			biome_name = "Sa Mạc"
		# Build chunk chứa điểm đích đồng bộ → lấy đúng cao độ mặt đất, tránh
		# thả rơi từ cao hoặc chui xuống đất khi vùng chưa được stream.
		WorldChunk.ensure_chunk_built(found.x, found.y)
		# Hạ cánh cao (rơi xuống) — nền đồi thoải cao 3-11.5m nên không hạ ở
		# y=5 kẻo chui vào lòng đất. Chỉ dùng cao độ thật nếu mặt đất TRÊN mặt
		# nước (WATER_Y=0.5) — chỗ biển sâu thì thả từ trên cao.
		var gy: float = WorldChunk.sample_ground_height(found.x, found.y)
		var spawn_y: float = 5.0
		if gy != -INF and gy > 0.5:
			spawn_y = gy + 3.0
		player.global_position = Vector3(found.x, spawn_y, found.y)
		player._scroll_inventory_message("Teleport → " + biome_name)
	else:
		player._scroll_inventory_message("Không tìm thấy " + biome_type + " trong bán kính 6km!")

## Teleport tới quán rượu gần nhất (tính định danh qua mạng đường, không cần chunk).
func _on_teleport_tavern() -> void:
	var player := _find_player_character()
	if player == null:
		return
	var origin: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	const RADIUS: float = 3000.0
	var taverns: Array = _Village.scan_taverns(origin, RADIUS)
	if taverns.is_empty():
		player._scroll_inventory_message("Không tìm thấy quán rượu trong bán kính 3km!")
		return
	# Sắp gần→xa rồi duyệt: với mỗi ứng viên build chunk chứa nó để biết quán có
	# THẬT được dựng hay chỉ nằm trong scan (footprint đất fail → không có nhà).
	# Lấy quán gần nhất đã thật sự dựng — không bao giờ tele vào khoảng trống.
	taverns.sort_custom(func(a, b):
		return origin.distance_squared_to(Vector2(a.x, a.z)) < origin.distance_squared_to(Vector2(b.x, b.z)))
	var best: Dictionary = {}
	for t in taverns:
		var tx: float = float(t.x)
		var tz: float = float(t.z)
		WorldChunk.ensure_chunk_built(tx, tz)
		if WorldChunk.is_tavern_built_at(tx, tz):
			best = t
			break
	if best.is_empty():
		player._scroll_inventory_message("Quán gần nhất chưa sẵn sàng — di chuyển gần hơn rồi thử lại!")
		return
	var bx: float = float(best.x)
	var bz: float = float(best.z)
	# Hạ cánh phía trước hiên (về phía con đường), cao hơn mặt đất để rơi xuống
	var node_pt: Vector2 = _Road.intersection_point(int(best.gx), int(best.gz))
	var toward := (node_pt - Vector2(bx, bz))
	if toward.length() < 0.1:
		toward = Vector2(0, 1)
	toward = toward.normalized()
	var land := WorldChunk.tavern_landing_point(bx, bz, toward)
	# Build chunk chứa điểm hạ cánh đồng bộ → lấy đúng cao độ, không thả từ cao.
	WorldChunk.ensure_chunk_built(land.x, land.y)
	var gy: float = WorldChunk.sample_ground_height(land.x, land.y)
	if gy == -INF:
		gy = 50.0
	player.global_position = Vector3(land.x, gy + 3.0, land.y)
	var best_d2: float = origin.distance_squared_to(Vector2(bx, bz))
	player._scroll_inventory_message("Teleport → 🍺 Quán Rượu (cách %.0fm)" % sqrt(best_d2))

## Teleport tới vùng NÚI CAO gần nhất (mountain noise), hạ cánh đúng cao độ.
func _on_teleport_mountain() -> void:
	var player := _find_player_character()
	if player == null:
		return
	var origin: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var hit: Dictionary = WorldChunk.find_mountain(origin.x, origin.y)
	if not hit.get("ok", false):
		player._scroll_inventory_message("Không tìm thấy núi trong bán kính 15km!")
		return
	var mx: float = float(hit["x"])
	var mz: float = float(hit["z"])
	WorldChunk.ensure_chunk_built(mx, mz)
	var gy: float = WorldChunk.sample_ground_height(mx, mz)
	var spawn_y: float = 5.0
	if gy != -INF and gy > 0.5:
		spawn_y = gy + 8.0  # thả từ trên đỉnh xuống (núi cao 4~12 block)
	player.global_position = Vector3(mx, spawn_y, mz)
	player._scroll_inventory_message("Teleport → ⛰️ Núi (cách %.0fm)" % (
		Vector2(player.global_position.x, player.global_position.z).distance_to(origin)))

## Trả về tên biome tại world pos — dùng đúng logic giống compute_chunk
func _get_biome_name_at(wx: float, wz: float) -> String:
	var nd: Dictionary = WorldChunk._noise_for_dim(1)
	if nd.is_empty():
		return ""

	# Thứ tự khớp pipeline compute_chunk: sa mạc (DESERT) ghi đè trước;
	# toàn bộ đất liền còn lại là ĐỒNG BẰNG CỎ (GRASS_DIRT/GRASS/DARK_GRASS/
	# YOUNG_GRASS) — chỉ còn phân biệt biển/hồ.
	var n_desert: FastNoiseLite = nd.get("desert")
	if n_desert:
		var dv: float = (n_desert.get_noise_2d(wx, wz) + 1.0) * 0.5
		if dv > 0.55:
			if WorldChunk._ocean_mask_at(nd, wx, wz):
				return "🌊 " + tr("BIOME_OCEAN")
			return "🏜️ " + tr("BIOME_DESERT")

	# Đồng bằng cỏ (đã hợp nhất cao nguyên): toàn bộ đất cỏ còn lại — chỉ phân
	# biệt biển và hồ.
	if WorldChunk._ocean_mask_at(nd, wx, wz):
		return "🌊 " + tr("BIOME_OCEAN")

	var n_lake: FastNoiseLite = nd.get("lake")
	if n_lake:
		var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
		if lv > 0.70:
			return "🏞 " + tr("BIOME_LAKE_RIVER")

	return "🌿 " + tr("BIOME_GRASSPLAINS")

func _update_debug_menu() -> void:
	if not _debug_open:
		return
	_Debug.update_debug_menu(_debug_ts_label, _debug_hour_slider, _debug_speed_slider, _debug_weather_btn)
	_refresh_debug_hint_btn()

func _on_portal_click() -> void:
	_load_state = LOAD_LOADING
	_load_progress = 0.0
	_load_elapsed = 0.0
	_load_label.text = tr("GENERATING_WORLD")
	_portal_btn.visible = false
	var vp := get_viewport().get_visible_rect().size
	_load_overlay.position = Vector2.ZERO
	_load_overlay.size = vp
	_load_overlay.color.a = 0.0
	_load_overlay.visible = true
	ResourceLoader.load_threaded_request(_load_scene)

func _update_loading_overlay(vp: Vector2) -> void:
	_load_overlay.size = vp
	var bw: float = 420.0
	var bh: float = 20.0
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	if _load_elapsed < 0.4:
		_load_overlay.color.a = min(_load_elapsed / 0.4, 1.0) * 0.85

	_load_label.position = Vector2(cx - 140, cy - 42)
	_load_label.size = Vector2(280, 34)
	_load_label.visible = true

	var bar_x: float = cx - bw * 0.5
	var bar_y: float = cy + 6
	var bar_bg := _load_overlay.get_node("LoadingBarBg") as ColorRect
	if bar_bg:
		bar_bg.position = Vector2(bar_x, bar_y)
		bar_bg.size = Vector2(bw, bh)
		bar_bg.visible = true

	var fill_w: float = max(0.0, bw - 6.0) * _load_progress
	_load_bar_fill.position = Vector2(bar_x + 3, bar_y + 3)
	_load_bar_fill.size = Vector2(fill_w, bh - 6.0)
	_load_bar_fill.visible = true
