## ui/hud.gd
## HUD chính: skill bar + party HUD + party UI overlay.

extends CanvasLayer
class_name HUD

var _tracked: CharacterBase = null
var _dummy_label: Label
var _dummy_tracked: CharacterBase = null
var _skill_bar: SkillBar
var _hotbar: Hotbar
var _inventory_ui: InventoryUI
var _chest_ui
var _inventory_open: bool = false
var _chest_open: bool = false
var _switch_hint: Label
var _party_ui
var _settings_ui
var _settings_icon: Button
var _save_btn: Button
var _party_hud: Control
var _party_indicators: Array[Panel] = []
var _mgr: CharacterManager
var _portal_btn: Button
var _build_menu: BuildMenu
var _placement_sys: PlacementSystem
var _build_hint: Label
var _explore_map: ExploreMap
var _explore_sys: ExploreSystem
var _mini_map: MiniMap

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
var _oxygen_bar_bg: ColorRect
var _b_key_held: bool = false
var _oxygen_bar_fill: ColorRect
var _debug_open: bool = false
var _debug_panel: Panel
var _debug_ts_label: Label
var _debug_hour_slider: HSlider
var _debug_speed_slider: HSlider
var _debug_weather_btn: Button
var _time_label: Label
var _coords_label: Label
var _biome_label: Label  # hiển thị tên biome + continent value góc trái
# Cache texture để tránh load() blocking mỗi frame trong _refresh_party_hud
var _icon_cache: Dictionary = {}

const _Dim = preload("res://scripts/world/dimension_defs.gd")
const _ChestUI = preload("res://scripts/items/ui/chest_ui.gd")
const _PartyUI = preload("res://scripts/ui/party/party_ui.gd")

func _ready() -> void:
	_setup_ui()
	await get_tree().process_frame
	_find_and_track()
	var path := get_tree().current_scene.scene_file_path
	if path == "res://scenes/open_world.tscn":
		_load_scene = "res://scenes/open_world_real.tscn"
	elif path == "res://scenes/open_world_real.tscn":
		_load_scene = "res://scenes/open_world.tscn"

func _setup_ui() -> void:
	_dummy_label = Label.new()
	_dummy_label.position = Vector2(20, 56)
	_dummy_label.add_theme_font_size_override("font_size", 14)
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
	add_child(_hotbar)

	_inventory_ui = InventoryUI.new()
	add_child(_inventory_ui)

	_chest_ui = _ChestUI.new()
	add_child(_chest_ui)

	_switch_hint = Label.new()
	_switch_hint.position = Vector2(60, 16)
	_switch_hint.add_theme_font_size_override("font_size", 11)
	_switch_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.55))
	_switch_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_switch_hint.add_theme_constant_override("shadow_offset_x", 1)
	_switch_hint.add_theme_constant_override("shadow_offset_y", 1)
	_switch_hint.text = tr("SWITCH_HINT")
	add_child(_switch_hint)

	var dim_label := Label.new()
	dim_label.name = "DimensionLabel"
	dim_label.position = Vector2(12, 40)
	dim_label.add_theme_font_size_override("font_size", 10)
	dim_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65, 0.65))
	dim_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	dim_label.add_theme_constant_override("shadow_offset_x", 1)
	dim_label.add_theme_constant_override("shadow_offset_y", 1)
	var owm: OpenWorldManager = get_node_or_null("../WorldManager") as OpenWorldManager
	if owm:
		dim_label.text = owm.dimension_name
	else:
		dim_label.text = "REAL WORLD"
	add_child(dim_label)

	_setup_settings_icon()
	_setup_save_button()
	_setup_party_hud()

	_party_ui = _PartyUI.new()
	add_child(_party_ui)

	_settings_ui = SettingsUI.new()
	add_child(_settings_ui)

	_build_menu = BuildMenu.new()
	add_child(_build_menu)
	_build_menu.building_selected.connect(_on_build_selected)
	_build_menu.closed.connect(_on_build_menu_closed)

	_explore_map = ExploreMap.new()
	add_child(_explore_map)

	_mini_map = MiniMap.new()
	add_child(_mini_map)

	_build_hint = Label.new()
	_build_hint.position = Vector2(12, 56)
	_build_hint.add_theme_font_size_override("font_size", 11)
	_build_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.6))
	_build_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_build_hint.add_theme_constant_override("shadow_offset_x", 1)
	_build_hint.add_theme_constant_override("shadow_offset_y", 1)
	_build_hint.text = tr("BUILD_HINT_B")
	add_child(_build_hint)

	_portal_btn = Button.new()
	_portal_btn.position = Vector2(0, 0)
	_portal_btn.size = Vector2(220, 50)
	_portal_btn.text = tr("PORTAL_BUTTON")
	_portal_btn.add_theme_font_size_override("font_size", 18)
	_portal_btn.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95, 0.95))
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.10, 0.10, 0.18, 0.65)
	pb_bg.corner_radius_top_left = 10; pb_bg.corner_radius_top_right = 10
	pb_bg.corner_radius_bottom_left = 10; pb_bg.corner_radius_bottom_right = 10
	pb_bg.border_width_left = 1; pb_bg.border_width_right = 1
	pb_bg.border_width_top = 1; pb_bg.border_width_bottom = 1
	pb_bg.border_color = Color(1, 1, 1, 0.12)
	_portal_btn.add_theme_stylebox_override("normal", pb_bg)
	var pb_hover := pb_bg.duplicate()
	pb_hover.bg_color = Color(0.15, 0.18, 0.30, 0.75)
	pb_hover.border_color = Color(0.40, 0.55, 0.90, 0.40)
	_portal_btn.add_theme_stylebox_override("hover", pb_hover)
	_portal_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_portal_btn.pressed.connect(_on_portal_click)
	_portal_btn.visible = false
	add_child(_portal_btn)

	_setup_world_clock()

	_setup_loading_overlay()

	_setup_oxygen_bar()
	_setup_time_label()
	_setup_debug_menu()
	_setup_mobile_controls()

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

func _setup_loading_overlay() -> void:
	_load_overlay = ColorRect.new()
	_load_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_load_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.visible = false
	add_child(_load_overlay)

	_load_label = Label.new()
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.add_theme_font_size_override("font_size", 18)
	_load_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.80, 0.9))
	_load_label.text = tr("GENERATE_LABEL")
	_load_label.visible = false
	add_child(_load_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.08, 0.14, 0.70)
	bar_bg.visible = false
	bar_bg.name = "LoadingBarBg"
	_load_overlay.add_child(bar_bg)

	_load_bar_fill = ColorRect.new()
	_load_bar_fill.color = Color(0.35, 0.55, 0.90, 0.80)
	
	_load_bar_fill.visible = false
	_load_overlay.add_child(_load_bar_fill)

func _setup_settings_icon() -> void:
	_settings_icon = Button.new()
	_settings_icon.position = Vector2(12, 10)
	_settings_icon.size = Vector2(40, 40)
	_settings_icon.text = "⚙"
	_settings_icon.add_theme_font_size_override("font_size", 22)
	_settings_icon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	var icon_bg := StyleBoxFlat.new()
	icon_bg.bg_color = Color(0.08, 0.08, 0.14, 0.65)
	icon_bg.corner_radius_top_left = 8; icon_bg.corner_radius_top_right = 8
	icon_bg.corner_radius_bottom_left = 8; icon_bg.corner_radius_bottom_right = 8
	icon_bg.border_width_left = 1; icon_bg.border_width_right = 1
	icon_bg.border_width_top = 1; icon_bg.border_width_bottom = 1
	icon_bg.border_color = Color(1, 1, 1, 0.10)
	_settings_icon.add_theme_stylebox_override("normal", icon_bg)
	var hover_bg := icon_bg.duplicate()
	hover_bg.bg_color = Color(0.15, 0.18, 0.30, 0.75)
	hover_bg.border_color = Color(0.40, 0.55, 0.90, 0.40)
	_settings_icon.add_theme_stylebox_override("hover", hover_bg)
	_settings_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_icon.pressed.connect(_toggle_settings)
	add_child(_settings_icon)

func _setup_save_button() -> void:
	_save_btn = Button.new()
	_save_btn.position = Vector2(58, 10)
	_save_btn.size = Vector2(40, 40)
	_save_btn.text = "💾"
	_save_btn.add_theme_font_size_override("font_size", 18)
	_save_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.08, 0.14, 0.65)
	sb_bg.corner_radius_top_left = 8; sb_bg.corner_radius_top_right = 8
	sb_bg.corner_radius_bottom_left = 8; sb_bg.corner_radius_bottom_right = 8
	sb_bg.border_width_left = 1; sb_bg.border_width_right = 1
	sb_bg.border_width_top = 1; sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(1, 1, 1, 0.10)
	_save_btn.add_theme_stylebox_override("normal", sb_bg)
	var sb_hover := sb_bg.duplicate()
	sb_hover.bg_color = Color(0.15, 0.18, 0.30, 0.75)
	sb_hover.border_color = Color(0.40, 0.55, 0.90, 0.40)
	_save_btn.add_theme_stylebox_override("hover", sb_hover)
	_save_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_btn.pressed.connect(_on_save_pressed)
	add_child(_save_btn)

func _on_save_pressed() -> void:
	if SaveManager:
		SaveManager.save_game()
	var player := _find_player_character()
	if player:
		player._scroll_inventory_message(tr("GAME_SAVED"))

func _toggle_settings() -> void:
	if _settings_ui and _settings_ui.visible:
		_settings_ui.hide_settings()
	else:
		if _party_ui and _party_ui.visible:
			_party_ui.hide_party()
		_settings_ui.show_settings()

func _setup_party_hud() -> void:
	var W: float = 80.0
	var H: float = 78.0
	var G: float = 4.0
	var PLAYER_GAP: float = 16.0
	var slot_count: int = 4

	_party_hud = Control.new()
	_party_hud.size = Vector2(W, H * slot_count + G * (slot_count - 1) + PLAYER_GAP)
	var vp := get_viewport().get_visible_rect().size
	_party_hud.position = Vector2(vp.x - W, (vp.y - _party_hud.size.y) * 0.5)
	add_child(_party_hud)

	for i in range(slot_count):
		var y: float = i * (H + G)
		if i == 3:
			y += PLAYER_GAP

		var panel := Panel.new()
		panel.size = Vector2(W, H)
		panel.position = Vector2(0, y)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_party_indicator_input.bind(i))
		_party_hud.add_child(panel)

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.08, 0.14, 0.70)
		bg.corner_radius_top_left = 8
		bg.corner_radius_top_right = 8
		bg.corner_radius_bottom_left = 8
		bg.corner_radius_bottom_right = 8
		bg.border_width_left = 1
		bg.border_width_right = 1
		bg.border_width_top = 1
		bg.border_width_bottom = 1
		bg.border_color = Color(1, 1, 1, 0.12)
		panel.add_theme_stylebox_override("panel", bg)

		var icon := TextureRect.new()
		icon.position = Vector2(6, 6)
		icon.size = Vector2(60, 60)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(icon)

		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(6, 66)
		hp_bg.size = Vector2(60, 6)
		hp_bg.color = Color(0.06, 0.06, 0.10, 0.60)
		panel.add_child(hp_bg)

		var hp_bar := ColorRect.new()
		hp_bar.position = Vector2(6, 66)
		hp_bar.size = Vector2(60, 6)
		hp_bar.color = Color(0.30, 0.85, 0.30, 0.85)
		panel.add_child(hp_bar)

		var shield_bar := ColorRect.new()
		shield_bar.position = Vector2(6, 66)
		shield_bar.size = Vector2(0, 6)
		shield_bar.color = Color(1.0, 0.80, 0.20, 0.55)
		panel.add_child(shield_bar)

		var mana_bar := ColorRect.new()
		mana_bar.position = Vector2(6, 72)
		mana_bar.size = Vector2(0, 4)
		mana_bar.color = Color(0.30, 0.55, 0.95, 0.60)
		panel.add_child(mana_bar)

		var lbl := Label.new()
		lbl.position = Vector2(2, 4)
		lbl.size = Vector2(76, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 0.8))
		lbl.text = "P" if i == 3 else str(i + 1)
		panel.add_child(lbl)

		var d: Dictionary = { "panel": panel, "bg": bg, "icon": icon, "hp_bar": hp_bar, "shield_bar": shield_bar, "mana_bar": mana_bar, "lbl": lbl }
		panel.set_meta("data", d)
		_party_indicators.append(panel)

func _on_party_indicator_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _mgr:
			if idx == 3:
				_mgr.switch_by_name("Player")
			else:
				var party := _mgr.get_party_characters()
				if idx < party.size():
					_mgr.switch_by_name(party[idx].character_name)

func _process(delta: float) -> void:
	if _dummy_tracked:
		_dummy_label.text = tr("DUMMY_FORMAT") % [_dummy_tracked.hp, _dummy_tracked.max_hp]
	else:
		_dummy_label.text = ""

	if _placement_sys and _placement_sys.is_placing():
		_placement_sys.update_placement()
		_build_hint.text = tr("BUILD_HINT_PLACING")

	_b_key_held = Input.is_key_pressed(KEY_B)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _mgr:
		_refresh_party_hud()
		_party_hud.position = Vector2(vp.x - 72, (vp.y - _party_hud.size.y) * 0.5)

	if _mini_map:
		_mini_map.visible = _explore_sys != null and get_parent().has_node("WorldManager")
		if _mini_map.visible:
			_mini_map.position = Vector2(vp.x - 162, vp.y - 162)

	if TimeSystem:
		var h: int = TimeSystem.get_hour_int()
		var m: int = TimeSystem.get_minute()
		_world_clock.text = "%02d:%02d" % [h, m]
		_time_label.text = "%s %d  |  %s  |  %s" % [TimeSystem.get_month_name(), TimeSystem.get_day(), TimeSystem.get_season_name(), TimeSystem.get_weather_name()]
	else:
		var env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
		if env and env.has_method("get_cycle_progress"):
			var prog: float = fmod(env.get_cycle_progress(), 1.0)
			var total_minutes: int = int(prog * 1440.0)
			var hours: int = total_minutes / 60
			var minutes: int = total_minutes % 60
			_world_clock.text = "%02d:%02d" % [hours, minutes]
	_world_clock.position = Vector2(vp.x - _world_clock.size.x - 12, 12)
	_time_label.position = Vector2(vp.x - _time_label.size.x - 12, 30)

	# Tọa độ XYZ — lấy từ nhân vật đang được điều khiển
	if _coords_label:
		var player := _find_player_character()
		var tracked_ch: CharacterBase = _mgr.get_current_character() if _mgr else null
		var pos_src: Node3D = player if player else tracked_ch
		if pos_src and is_instance_valid(pos_src) and pos_src.is_inside_tree():
			var p := pos_src.global_position
			_coords_label.text = "X %.1f  Y %.1f  Z %.1f" % [p.x, p.y, p.z]
			# Cập nhật biome label — throttle 0.25s để không gọi noise mỗi frame
			if _biome_label:
				_biome_label.text = _get_biome_name_at(p.x, p.z)
				_biome_label.position = Vector2(12, 62)
		else:
			_coords_label.text = ""
			if _biome_label:
				_biome_label.text = ""
		_coords_label.size = Vector2(220, 18)
		_coords_label.position = Vector2(vp.x - _coords_label.size.x - 12, 46)

	if _debug_open:
		_debug_panel.position = Vector2(vp.x * 0.5 - 175, vp.y * 0.5 - 130)
		_update_debug_menu()

	if _oxygen_bar_bg.visible:
		var bx: float = (vp.x - 160.0) * 0.5
		var by: float = vp.y - 80.0
		_oxygen_bar_bg.position = Vector2(bx, by)
		_oxygen_bar_fill.position = Vector2(bx, by)

	if _load_state == LOAD_IDLE:
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

func _load_icon(character_name: String) -> Texture2D:
	if _icon_cache.has(character_name):
		return _icon_cache[character_name]
	var tex_path: String = "res://assets/icon_character/" + character_name.to_lower() + ".png"
	var tex: Texture2D = load(tex_path) as Texture2D
	_icon_cache[character_name] = tex
	return tex

func _refresh_party_hud() -> void:
	var party: Array[CharacterBase] = _mgr.get_party_characters()
	var active: CharacterBase = _mgr.get_current_character()
	var player_ch: CharacterBase = null
	for ch in _mgr._characters:
		if ch.character_name == "Player":
			player_ch = ch
			break

	for i in range(_party_indicators.size()):
		var panel: Panel = _party_indicators[i]
		var d: Dictionary = panel.get_meta("data")
		var bg: StyleBoxFlat = d["bg"]

		if i == 3 and player_ch != null:
			var ch: CharacterBase = player_ch
			d["hp_bar"].visible = true
			d["shield_bar"].visible = true
			d["mana_bar"].visible = true

			var max_hp_val: int = max(ch.max_hp, 1)
			var hp_ratio: float = float(ch.hp) / float(max_hp_val)
			d["hp_bar"].color = Color(
				1.0 - hp_ratio,
				0.3 + hp_ratio * 0.7,
				0.2,
				0.85)
			d["hp_bar"].size.x = max(2.0, 60.0 * hp_ratio)

			var shield_ratio: float = clamp(float(ch.shield) / float(max_hp_val), 0.0, 1.0)
			if shield_ratio > 0.0:
				d["shield_bar"].size.x = max(2.0, 60.0 * shield_ratio)
				d["shield_bar"].position.x = 6.0 + 60.0 * hp_ratio
			else:
				d["shield_bar"].size.x = 0.0

			var mana_ratio: float = clamp(float(ch.mana) / float(max(ch.max_mana, 1)), 0.0, 1.0)
			d["mana_bar"].size.x = max(2.0, 60.0 * mana_ratio)

			d["lbl"].text = "Lv" + str(ch.level)

			var elem: Variant = ch.get("element")
			var ec: Color = Color(0.3, 0.3, 0.5)
			if elem is int and (elem as int) > 0:
				var tmp: Variant = CharacterBase.ELEMENT_COLORS.get(elem as int)
				if tmp is Color:
					ec = tmp as Color
			d["icon"].texture = _load_icon(ch.character_name)
			d["icon"].modulate = Color(1, 1, 1, 1)

			if active and ch.character_name == active.character_name:
				bg.border_color = Color(1, 1, 1, 0.50)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(ec.r * 0.15 + 0.08, ec.g * 0.15 + 0.08, ec.b * 0.15 + 0.14, 0.70)
			else:
				bg.border_color = Color(1, 1, 1, 0.12)
				bg.border_width_left = 1
				bg.border_width_right = 1
				bg.border_width_top = 1
				bg.border_width_bottom = 1
				bg.bg_color = Color(0.08, 0.08, 0.14, 0.55)
		elif i < party.size():
			var ch: CharacterBase = party[i]
			d["hp_bar"].visible = true
			d["shield_bar"].visible = true
			d["mana_bar"].visible = true

			var max_hp_val: int = max(ch.max_hp, 1)
			var hp_ratio: float = float(ch.hp) / float(max_hp_val)
			d["hp_bar"].color = Color(
				1.0 - hp_ratio,
				0.3 + hp_ratio * 0.7,
				0.2,
				0.85)
			d["hp_bar"].size.x = max(2.0, 60.0 * hp_ratio)

			var shield_ratio: float = clamp(float(ch.shield) / float(max_hp_val), 0.0, 1.0)
			if shield_ratio > 0.0:
				d["shield_bar"].size.x = max(2.0, 60.0 * shield_ratio)
				d["shield_bar"].position.x = 6.0 + 60.0 * hp_ratio
			else:
				d["shield_bar"].size.x = 0.0

			var mana_ratio: float = clamp(float(ch.mana) / float(max(ch.max_mana, 1)), 0.0, 1.0)
			d["mana_bar"].size.x = max(2.0, 60.0 * mana_ratio)

			d["lbl"].text = "Lv" + str(ch.level)

			var elem: Variant = ch.get("element")
			var ec: Color = Color(0.3, 0.3, 0.5)
			if elem is int and (elem as int) > 0:
				var tmp: Variant = CharacterBase.ELEMENT_COLORS.get(elem as int)
				if tmp is Color:
					ec = tmp as Color
			d["icon"].texture = _load_icon(ch.character_name)
			d["icon"].modulate = Color(1, 1, 1, 1)

			if active and ch.character_name == active.character_name:
				bg.border_color = Color(1, 1, 1, 0.50)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(ec.r * 0.15 + 0.08, ec.g * 0.15 + 0.08, ec.b * 0.15 + 0.14, 0.70)
			else:
				bg.border_color = Color(1, 1, 1, 0.12)
				bg.border_width_left = 1
				bg.border_width_right = 1
				bg.border_width_top = 1
				bg.border_width_bottom = 1
				bg.bg_color = Color(0.08, 0.08, 0.14, 0.55)
		else:
			d["hp_bar"].visible = false
			d["shield_bar"].visible = false
			d["mana_bar"].visible = false
			d["icon"].texture = null
			d["icon"].modulate = Color(0.08, 0.08, 0.14, 0.7)
			d["lbl"].text = "P" if i == 3 else str(i + 1)
			bg.border_color = Color(1, 1, 1, 0.06)
			bg.border_width_left = 1
			bg.border_width_right = 1
			bg.border_width_top = 1
			bg.border_width_bottom = 1
			bg.bg_color = Color(0.06, 0.06, 0.10, 0.45)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			var k_interact: int = ProjectSettings.get_setting("controls/interact", KEY_F)
			var k_inventory: int = ProjectSettings.get_setting("controls/inventory", KEY_I)
			var k_build: int = ProjectSettings.get_setting("controls/build", KEY_B)
			var k_party: int = ProjectSettings.get_setting("controls/party", KEY_P)
			var k_map: int = ProjectSettings.get_setting("controls/map", KEY_M)
			var k_debug: int = ProjectSettings.get_setting("controls/debug", KEY_F2)

			if _chest_open:
				if k.keycode == k_interact or k.keycode == KEY_ESCAPE or k.keycode == k_inventory or k.keycode == KEY_E:
					close_chest()
				return

			if _inventory_open:
				if k.keycode == k_inventory or k.keycode == KEY_E or k.keycode == KEY_ESCAPE:
					_toggle_inventory()
				return

			if _placement_sys and _placement_sys.is_placing():
				if k.keycode == KEY_ESCAPE or k.keycode == k_build:
					_placement_sys.cancel_placement()
					_build_hint.text = tr("BUILD_HINT_B")
				return

			if k.keycode >= KEY_1 and k.keycode <= KEY_9:
				var cur := _mgr.get_current_character() if _mgr else null
				if cur is PlayerCharacter and _hotbar.visible:
					_hotbar.select_slot(k.keycode - KEY_1)
					return

			if k.keycode == k_interact:
				var player := _find_player_character()
				if player:
					player.interact_with_nearby()
				return

			if k.keycode == k_inventory or k.keycode == KEY_E:
				var cur := _mgr.get_current_character() if _mgr else null
				if cur is PlayerCharacter:
					_toggle_inventory()
				return

			if k.keycode == k_debug:
				_toggle_debug()
				return

			if k.keycode == k_map:
				if _explore_map and _explore_map.visible:
					_explore_map.close()
				elif _explore_sys and not (_settings_ui and _settings_ui.visible) and not (_party_ui and _party_ui.visible):
					_explore_map.open(_explore_sys)
				return
			if k.keycode == k_build:
				if _build_menu and _build_menu.visible:
					_build_menu.close()
				else:
					if _placement_sys == null:
						_placement_sys = PlacementSystem.new()
						_placement_sys.name = "PlacementSystem"
						var p := get_parent()
						if p:
							p.add_child(_placement_sys)
					if not (_settings_ui and _settings_ui.visible) and not (_party_ui and _party_ui.visible):
						_build_menu.open(_placement_sys)
				return
			if k.keycode == k_party:
				if _party_ui and _party_ui.visible:
					_party_ui.hide_party()
				elif _mgr and not (_settings_ui and _settings_ui.visible):
					_party_ui.show_party(_mgr)
				return
			if k.keycode == KEY_ESCAPE:
				if _explore_map and _explore_map.visible:
					_explore_map.close()
				elif _build_menu and _build_menu.visible:
					_build_menu.close()
				elif _party_ui and _party_ui.visible:
					_party_ui.hide_party()
				elif _settings_ui and _settings_ui.visible:
					_settings_ui.hide_settings()
				else:
					_toggle_settings()

func _toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	_inventory_ui.visible = _inventory_open
	var player := _find_player_character()
	if player:
		player._inventory_open = _inventory_open
		if not _inventory_open:
			player._held_item = {}

func open_chest(chest) -> void:
	if _chest_open:
		return
	if _inventory_open:
		_toggle_inventory()
	_chest_open = true
	var player := _find_player_character()
	if player:
		_chest_ui.open(chest, player)

func close_chest() -> void:
	if not _chest_open:
		return
	_chest_open = false
	_chest_ui.close()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _placement_sys and _placement_sys.is_placing():
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_placement_sys.confirm_placement()
					_build_hint.text = tr("BUILD_HINT_B")
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					_placement_sys.cancel_placement()
					_build_hint.text = tr("BUILD_HINT_B")

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
	if _tracked:
		if _tracked.hp_changed.is_connected(_on_hp_changed):
			_tracked.hp_changed.disconnect(_on_hp_changed)
		if _tracked.oxygen_changed.is_connected(_on_oxygen_changed):
			_tracked.oxygen_changed.disconnect(_on_oxygen_changed)
	_tracked = ch
	if ch == null:
		_dummy_label.text = ""
		return
	ch.hp_changed.connect(_on_hp_changed)
	ch.oxygen_changed.connect(_on_oxygen_changed)
	_on_hp_changed(ch.hp, ch.max_hp)
	_on_oxygen_changed(int(ch.oxygen), int(ch.max_oxygen))

	var is_player: bool = ch is PlayerCharacter
	_skill_bar.visible = not is_player
	_hotbar.visible = is_player
	_hotbar.set_inventory(null)
	if _inventory_open:
		_inventory_open = false
		_inventory_ui.visible = false
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
			_inventory_ui.set_inventory(player_ch.inventory)
			_inventory_ui.set_player(player_ch)
	else:
		_skill_bar.track(ch)

func _on_hp_changed(_current: int, _max_hp_val: int) -> void:
	pass

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

func _on_build_selected(idx: int) -> void:
	if _placement_sys:
		_build_menu.close()
		_placement_sys.start_placement(idx)

func _on_build_menu_closed() -> void:
	_build_hint.text = tr("BUILD_HINT_B")

func _setup_world_clock() -> void:
	_world_clock = Label.new()
	_world_clock.add_theme_font_size_override("font_size", 14)
	_world_clock.add_theme_color_override("font_color", Color(0.60, 0.60, 0.70, 0.8))
	_world_clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_world_clock.add_theme_constant_override("shadow_offset_x", 1)
	_world_clock.add_theme_constant_override("shadow_offset_y", 1)
	_world_clock.text = "06:00"
	add_child(_world_clock)

func _setup_time_label() -> void:
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 11)
	_time_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.65, 0.7))
	_time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_time_label.add_theme_constant_override("shadow_offset_x", 1)
	_time_label.add_theme_constant_override("shadow_offset_y", 1)
	_time_label.text = ""
	add_child(_time_label)

	_coords_label = Label.new()
	_coords_label.add_theme_font_size_override("font_size", 11)
	_coords_label.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65, 0.75))
	_coords_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_coords_label.add_theme_constant_override("shadow_offset_x", 1)
	_coords_label.add_theme_constant_override("shadow_offset_y", 1)
	_coords_label.text = ""
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_coords_label)

	# Biome label — góc trái, dưới coords
	_biome_label = Label.new()
	_biome_label.add_theme_font_size_override("font_size", 11)
	_biome_label.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55, 0.85))
	_biome_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_biome_label.add_theme_constant_override("shadow_offset_x", 1)
	_biome_label.add_theme_constant_override("shadow_offset_y", 1)
	_biome_label.text = ""
	add_child(_biome_label)

func _setup_debug_menu() -> void:
	_debug_panel = Panel.new()
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12, 0.90)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(1, 1, 1, 0.15)
	_debug_panel.add_theme_stylebox_override("panel", bg)

	var vp := get_viewport().get_visible_rect().size
	_debug_panel.position = Vector2(vp.x * 0.5 - 175, vp.y * 0.5 - 160)
	_debug_panel.size = Vector2(350, 320)

	var title := Label.new()
	title.position = Vector2(12, 8)
	title.size = Vector2(326, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.80, 0.80, 0.90, 0.9))
	title.text = "DEBUG MENU"
	_debug_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(320, 6)
	close_btn.size = Vector2(24, 24)
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_toggle_debug)
	_debug_panel.add_child(close_btn)

	var y: float = 44
	var line_h: float = 36

	var ts_label := Label.new()
	ts_label.position = Vector2(12, y)
	ts_label.size = Vector2(326, 20)
	ts_label.add_theme_font_size_override("font_size", 13)
	ts_label.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	ts_label.text = "Game Time:"
	_debug_panel.add_child(ts_label)
	y += 20

	_debug_ts_label = Label.new()
	_debug_ts_label.position = Vector2(12, y)
	_debug_ts_label.size = Vector2(326, 20)
	_debug_ts_label.add_theme_font_size_override("font_size", 13)
	_debug_ts_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.90, 0.9))
	_debug_ts_label.text = ""
	_debug_panel.add_child(_debug_ts_label)
	y += line_h

	var hour_lbl := Label.new()
	hour_lbl.position = Vector2(12, y)
	hour_lbl.size = Vector2(80, 20)
	hour_lbl.add_theme_font_size_override("font_size", 13)
	hour_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	hour_lbl.text = "Hour:"
	_debug_panel.add_child(hour_lbl)

	_debug_hour_slider = HSlider.new()
	_debug_hour_slider.position = Vector2(90, y)
	_debug_hour_slider.size = Vector2(240, 20)
	_debug_hour_slider.min_value = 0.0
	_debug_hour_slider.max_value = 24.0
	_debug_hour_slider.step = 0.5
	_debug_hour_slider.value = 6.0
	_debug_hour_slider.value_changed.connect(_on_debug_hour_changed)
	_debug_panel.add_child(_debug_hour_slider)
	y += line_h

	var speed_lbl := Label.new()
	speed_lbl.position = Vector2(12, y)
	speed_lbl.size = Vector2(80, 20)
	speed_lbl.add_theme_font_size_override("font_size", 13)
	speed_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	speed_lbl.text = "Speed:"
	_debug_panel.add_child(speed_lbl)

	_debug_speed_slider = HSlider.new()
	_debug_speed_slider.position = Vector2(90, y)
	_debug_speed_slider.size = Vector2(240, 20)
	_debug_speed_slider.min_value = 0.0
	_debug_speed_slider.max_value = 50.0
	_debug_speed_slider.step = 0.5
	_debug_speed_slider.value = 1.0
	_debug_speed_slider.value_changed.connect(_on_debug_speed_changed)
	_debug_panel.add_child(_debug_speed_slider)
	y += line_h

	var weather_lbl := Label.new()
	weather_lbl.position = Vector2(12, y)
	weather_lbl.size = Vector2(80, 20)
	weather_lbl.add_theme_font_size_override("font_size", 13)
	weather_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	weather_lbl.text = "Weather:"
	_debug_panel.add_child(weather_lbl)

	_debug_weather_btn = Button.new()
	_debug_weather_btn.position = Vector2(90, y - 2)
	_debug_weather_btn.size = Vector2(120, 24)
	_debug_weather_btn.add_theme_font_size_override("font_size", 13)
	_debug_weather_btn.text = "Clear"
	_debug_weather_btn.pressed.connect(_on_debug_weather_toggle)
	_debug_panel.add_child(_debug_weather_btn)
	y += line_h

	# ── Teleport to Biome ─────────────────────────────────────────────────────
	var tp_lbl := Label.new()
	tp_lbl.position = Vector2(12, y)
	tp_lbl.size = Vector2(326, 20)
	tp_lbl.add_theme_font_size_override("font_size", 13)
	tp_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.75, 0.85))
	tp_lbl.text = "Teleport to Biome:"
	_debug_panel.add_child(tp_lbl)
	y += 24

	var tp_plains_btn := Button.new()
	tp_plains_btn.position = Vector2(12, y - 2)
	tp_plains_btn.size = Vector2(155, 26)
	tp_plains_btn.add_theme_font_size_override("font_size", 13)
	tp_plains_btn.text = "🌿 Đồng Bằng"
	tp_plains_btn.pressed.connect(_on_teleport_biome.bind("plains"))
	_debug_panel.add_child(tp_plains_btn)

	var tp_ocean_btn := Button.new()
	tp_ocean_btn.position = Vector2(176, y - 2)
	tp_ocean_btn.size = Vector2(155, 26)
	tp_ocean_btn.add_theme_font_size_override("font_size", 13)
	tp_ocean_btn.text = "🌊 Biển Khơi"
	tp_ocean_btn.pressed.connect(_on_teleport_biome.bind("ocean"))
	_debug_panel.add_child(tp_ocean_btn)

	add_child(_debug_panel)

func _toggle_debug() -> void:
	_debug_open = not _debug_open
	_debug_panel.visible = _debug_open
	if _debug_open:
		_update_debug_menu()

func _on_debug_hour_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_hour(value)

func _on_debug_speed_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_time_scale(value)

func _on_debug_weather_toggle() -> void:
	if not TimeSystem:
		return
	if TimeSystem.get_weather() == TimeSystem.Weather.CLEAR:
		TimeSystem.force_weather(TimeSystem.Weather.RAIN)
		_debug_weather_btn.text = "Rain"
	else:
		TimeSystem.force_weather(TimeSystem.Weather.CLEAR)
		_debug_weather_btn.text = "Clear"

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

	var r: float = STEP
	while r <= MAX_R and not found_ok:
		var samples: int = max(8, int(r / STEP * TAU))
		for i in range(samples):
			var angle: float = float(i) / float(samples) * TAU
			var wx: float = origin.x + cos(angle) * r
			var wz: float = origin.y + sin(angle) * r

			match biome_type:
				"plains":
					var n_ocean: FastNoiseLite = nd.get("ocean")
					var n_lake: FastNoiseLite  = nd.get("lake")
					var n_bio: FastNoiseLite   = nd.get("biome")
					var n_warp: FastNoiseLite  = nd.get("warp")
					var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0 if n_warp else 0.0
					var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0 if n_warp else 0.0
					var bio_n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5 if n_bio else 0.0
					var ov: float = (n_ocean.get_noise_2d(wx, wz) + 1.0) * 0.5 if n_ocean else 0.0
					var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5 if n_lake else 0.0
					# GRASS, không phải biển, không phải hồ
					if bio_n < 0.40 and ov <= 0.50 and lv <= 0.45:
						found = Vector2(wx, wz); found_ok = true; break
				"ocean":
					var n_ocean: FastNoiseLite = nd.get("ocean")
					var n_bio: FastNoiseLite   = nd.get("biome")
					var n_warp: FastNoiseLite  = nd.get("warp")
					if n_ocean and n_bio and n_warp:
						var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
						var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
						var bio_n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5
						var ov: float = (n_ocean.get_noise_2d(wx, wz) + 1.0) * 0.5
						# GRASS + ocean noise cao — đây mới thực sự là biển
						if bio_n < 0.40 and ov > 0.55:
							found = Vector2(wx, wz); found_ok = true; break
		r += STEP

	if found_ok:
		player.global_position = Vector3(found.x, 5.0, found.y)
		player._scroll_inventory_message("Teleport → " + ("Đồng Bằng" if biome_type == "plains" else "Biển Khơi"))
	else:
		player._scroll_inventory_message("Không tìm thấy " + biome_type + " trong bán kính 6km!")

## Trả về tên biome tại world pos — dùng đúng logic giống compute_chunk
func _get_biome_name_at(wx: float, wz: float) -> String:
	var nd: Dictionary = WorldChunk._noise_for_dim(1)
	if nd.is_empty():
		return ""

	# Phải check theo đúng thứ tự pipeline của compute_chunk:
	# 1. biome_at → GRASS hay DARK_GRASS?
	# 2. Nếu GRASS → check ocean, rồi lake
	var n_bio: FastNoiseLite  = nd.get("biome")
	var n_warp: FastNoiseLite = nd.get("warp")
	if n_bio == null:
		return ""

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0 if n_warp else 0.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0 if n_warp else 0.0
	var bio_n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	# DARK_GRASS (threshold = 0.40) → đồi, không thể là biển/hồ
	if bio_n >= 0.40:
		return "🌿 Đồng Bằng (đồi)"

	# GRASS — check ocean trước (patch to hơn hồ)
	var n_ocean: FastNoiseLite = nd.get("ocean")
	if n_ocean:
		var ov: float = (n_ocean.get_noise_2d(wx, wz) + 1.0) * 0.5
		if ov > 0.50:
			return "🌊 Biển"

	# GRASS — check lake
	var n_lake: FastNoiseLite = nd.get("lake")
	if n_lake:
		var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
		if lv > 0.50:
			return "🏞 Hồ / Sông"

	return "🌿 Đồng Bằng"

func _update_debug_menu() -> void:
	if not _debug_open or not TimeSystem:
		return
	var h: float = TimeSystem.get_hour_int()
	var m: int = TimeSystem.get_minute()
	var day: int = TimeSystem.get_day()
	var month: String = TimeSystem.get_month_name()
	var year: int = TimeSystem.get_year() + 1
	var season: String = TimeSystem.get_season_name()
	var weather: String = TimeSystem.get_weather_name()
	_debug_ts_label.text = "%02d:%02d  %s %d, Year %d  |  %s  |  %s" % [h, m, month, day, year, season, weather]
	_debug_hour_slider.value = h
	_debug_speed_slider.value = TimeSystem.get_time_scale()
	if TimeSystem.get_weather() == TimeSystem.Weather.RAIN:
		_debug_weather_btn.text = "Rain"
	else:
		_debug_weather_btn.text = "Clear"

func _setup_oxygen_bar() -> void:
	_oxygen_bar_bg = ColorRect.new()
	_oxygen_bar_bg.color = Color(0.08, 0.08, 0.14, 0.70)
	_oxygen_bar_bg.size = Vector2(160, 14)
	_oxygen_bar_bg.visible = false
	add_child(_oxygen_bar_bg)

	_oxygen_bar_fill = ColorRect.new()
	_oxygen_bar_fill.color = Color(0.25, 0.55, 0.90, 0.80)
	_oxygen_bar_fill.size = Vector2(160, 14)
	_oxygen_bar_fill.visible = false
	add_child(_oxygen_bar_fill)

func _on_oxygen_changed(current: int, max_oxy: int) -> void:
	if max_oxy <= 0:
		return
	var ratio: float = clamp(float(current) / float(max_oxy), 0.0, 1.0)
	_oxygen_bar_fill.size.x = 160.0 * ratio
	_oxygen_bar_fill.color = Color(
		0.2 + (1.0 - ratio) * 0.5,
		0.55 - (1.0 - ratio) * 0.35,
		0.80 - (1.0 - ratio) * 0.6,
		0.90)
	if current < max_oxy:
		_oxygen_bar_bg.visible = true
		_oxygen_bar_fill.visible = true
	else:
		_oxygen_bar_bg.visible = false
		_oxygen_bar_fill.visible = false

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
	var bw: float = 300.0
	var bh: float = 14.0
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	if _load_elapsed < 0.4:
		_load_overlay.color.a = min(_load_elapsed / 0.4, 1.0) * 0.85

	_load_label.position = Vector2(cx - 100, cy - 30)
	_load_label.size = Vector2(200, 24)
	_load_label.visible = true

	var bar_x: float = cx - bw * 0.5
	var bar_y: float = cy + 4
	var bar_bg := _load_overlay.get_node("LoadingBarBg") as ColorRect
	if bar_bg:
		bar_bg.position = Vector2(bar_x, bar_y)
		bar_bg.size = Vector2(bw, bh)
		bar_bg.visible = true

	var fill_w: float = max(0.0, bw - 4.0) * _load_progress
	_load_bar_fill.position = Vector2(bar_x + 2, bar_y + 2)
	_load_bar_fill.size = Vector2(fill_w, bh - 4.0)
	_load_bar_fill.visible = true
