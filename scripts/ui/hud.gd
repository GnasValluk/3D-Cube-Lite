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
var _party_ui: PartyUI
var _settings_ui
var _settings_icon: Button
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
var _oxygen_bar_fill: ColorRect

const _Dim = preload("res://scripts/world/dimension_defs.gd")
const _ChestUI = preload("res://scripts/ui/chest_ui.gd")

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
	_dummy_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.7))
	_dummy_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
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
	_switch_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6, 0.5))
	_switch_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_switch_hint.add_theme_constant_override("shadow_offset_x", 1)
	_switch_hint.add_theme_constant_override("shadow_offset_y", 1)
	_switch_hint.text = "Tab=Cycle  1/2/3=Pick  4=Player  I=Inventory  P=Team  M=Map  ESC=Settings  F1=Camera"
	add_child(_switch_hint)

	var dim_label := Label.new()
	dim_label.name = "DimensionLabel"
	dim_label.position = Vector2(12, 40)
	dim_label.add_theme_font_size_override("font_size", 10)
	dim_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.7, 0.6))
	dim_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	dim_label.add_theme_constant_override("shadow_offset_x", 1)
	dim_label.add_theme_constant_override("shadow_offset_y", 1)
	var owm: OpenWorldManager = get_node_or_null("../WorldManager") as OpenWorldManager
	if owm:
		dim_label.text = owm.dimension_name
	else:
		dim_label.text = "THẾ GIỚI THỰC TẠI"
	add_child(dim_label)

	_setup_settings_icon()
	_setup_party_hud()

	_party_ui = PartyUI.new()
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
	_build_hint.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 0.5))
	_build_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_build_hint.add_theme_constant_override("shadow_offset_x", 1)
	_build_hint.add_theme_constant_override("shadow_offset_y", 1)
	_build_hint.text = "B=Xây dựng"
	add_child(_build_hint)

	_portal_btn = Button.new()
	_portal_btn.position = Vector2(0, 0)
	_portal_btn.size = Vector2(220, 50)
	_portal_btn.text = "ẤN/BƯỚC VÀO ĐỂ DỊCH CHUYỂN"
	_portal_btn.add_theme_font_size_override("font_size", 18)
	_portal_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.35, 0.60, 0.90)
	pb_bg.corner_radius_top_left = 10; pb_bg.corner_radius_top_right = 10
	pb_bg.corner_radius_bottom_left = 10; pb_bg.corner_radius_bottom_right = 10
	pb_bg.border_width_left = 2; pb_bg.border_width_right = 2
	pb_bg.border_width_top = 2; pb_bg.border_width_bottom = 2
	pb_bg.border_color = Color(0.30, 0.70, 1.0, 0.7)
	_portal_btn.add_theme_stylebox_override("normal", pb_bg)
	var pb_hover := pb_bg.duplicate()
	pb_hover.bg_color = Color(0.18, 0.45, 0.75, 0.95)
	pb_hover.border_color = Color(0.50, 0.90, 1.0, 0.9)
	_portal_btn.add_theme_stylebox_override("hover", pb_hover)
	_portal_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_portal_btn.pressed.connect(_on_portal_click)
	_portal_btn.visible = false
	add_child(_portal_btn)

	_setup_world_clock()

	_setup_loading_overlay()

	_setup_oxygen_bar()

func _setup_loading_overlay() -> void:
	_load_overlay = ColorRect.new()
	_load_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_load_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_overlay.visible = false
	add_child(_load_overlay)

	_load_label = Label.new()
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.add_theme_font_size_override("font_size", 18)
	_load_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.9))
	_load_label.text = "ĐANG TẠO THẾ GIỚI..."
	_load_label.visible = false
	add_child(_load_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.12, 0.18, 0.9)
	bar_bg.visible = false
	bar_bg.name = "LoadingBarBg"
	_load_overlay.add_child(bar_bg)

	_load_bar_fill = ColorRect.new()
	_load_bar_fill.color = Color(0.30, 0.85, 1.0, 0.85)
	_load_bar_fill.visible = false
	_load_overlay.add_child(_load_bar_fill)

func _setup_settings_icon() -> void:
	_settings_icon = Button.new()
	_settings_icon.position = Vector2(12, 10)
	_settings_icon.size = Vector2(40, 40)
	_settings_icon.text = "⚙"
	_settings_icon.add_theme_font_size_override("font_size", 22)
	_settings_icon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.6))
	var icon_bg := StyleBoxFlat.new()
	icon_bg.bg_color = Color(0.06, 0.06, 0.10, 0.55)
	icon_bg.corner_radius_top_left = 8; icon_bg.corner_radius_top_right = 8
	icon_bg.corner_radius_bottom_left = 8; icon_bg.corner_radius_bottom_right = 8
	icon_bg.border_width_left = 1; icon_bg.border_width_right = 1
	icon_bg.border_width_top = 1; icon_bg.border_width_bottom = 1
	icon_bg.border_color = Color(0.35, 0.35, 0.45, 0.4)
	_settings_icon.add_theme_stylebox_override("normal", icon_bg)
	var hover_bg := icon_bg.duplicate()
	hover_bg.bg_color = Color(0.1, 0.1, 0.18, 0.7)
	hover_bg.border_color = Color(0.5, 0.5, 0.7, 0.6)
	_settings_icon.add_theme_stylebox_override("hover", hover_bg)
	_settings_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_icon.pressed.connect(_toggle_settings)
	add_child(_settings_icon)

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
		bg.bg_color = Color(0.06, 0.06, 0.10, 0.92)
		bg.corner_radius_top_left = 10
		bg.corner_radius_top_right = 0
		bg.corner_radius_bottom_left = 10
		bg.corner_radius_bottom_right = 0
		bg.border_width_left = 3
		bg.border_width_right = 0
		bg.border_width_top = 2
		bg.border_width_bottom = 2
		bg.border_color = Color(0.5, 0.5, 0.6, 0.7)
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
		hp_bg.color = Color(0.04, 0.04, 0.08, 0.85)
		panel.add_child(hp_bg)

		var hp_bar := ColorRect.new()
		hp_bar.position = Vector2(6, 66)
		hp_bar.size = Vector2(60, 6)
		hp_bar.color = Color(0.3, 1.0, 0.3, 0.9)
		panel.add_child(hp_bar)

		var shield_bar := ColorRect.new()
		shield_bar.position = Vector2(6, 66)
		shield_bar.size = Vector2(0, 6)
		shield_bar.color = Color(1.0, 0.85, 0.0, 0.55)
		panel.add_child(shield_bar)

		var mana_bar := ColorRect.new()
		mana_bar.position = Vector2(6, 72)
		mana_bar.size = Vector2(0, 4)
		mana_bar.color = Color(0.20, 0.50, 1.0, 0.55)
		panel.add_child(mana_bar)

		var lbl := Label.new()
		lbl.position = Vector2(2, 4)
		lbl.size = Vector2(76, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
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
		_dummy_label.text = "DUMMY: %d / %d" % [_dummy_tracked.hp, _dummy_tracked.max_hp]
	else:
		_dummy_label.text = ""

	if _placement_sys and _placement_sys.is_placing():
		_placement_sys.update_placement()
		_build_hint.text = "Chuột Trái=Đặt  |  Chuột Phải=Hủy"

	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _mgr:
		_refresh_party_hud()
		_party_hud.position = Vector2(vp.x - 72, (vp.y - _party_hud.size.y) * 0.5)

	if _inventory_open:
		_inventory_ui.size = vp
		_inventory_ui.position = Vector2.ZERO

	if _mini_map:
		_mini_map.visible = _explore_sys != null and get_parent().has_node("WorldManager")
		if _mini_map.visible:
			_mini_map.position = Vector2(vp.x - 162, vp.y - 162)

	var env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env and env.has_method("get_cycle_progress"):
		var prog: float = env.get_cycle_progress()
		var total_minutes: int = int(prog * 1440.0)
		var hours: int = total_minutes / 60
		var minutes: int = total_minutes % 60
		_world_clock.text = "%02d:%02d" % [hours, minutes]
	_world_clock.position = Vector2(vp.x - _world_clock.size.x - 12, 12)

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
				_portal_btn.text = "THẾ GIỚI THỰC TẠI"
			else:
				_load_scene = "res://scenes/open_world.tscn"
				_portal_btn.text = "CHẠNG VẠNG"
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
			_load_label.text = "VÀO THẾ GIỚI..."
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
			var tex_path: String = "res://assets/icon_character/" + ch.character_name.to_lower() + ".png"
			d["icon"].texture = load(tex_path) as Texture2D
			d["icon"].modulate = Color(1, 1, 1, 1)

			if active and ch.character_name == active.character_name:
				bg.border_color = Color(1, 1, 1, 0.95)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(ec.r * 0.25, ec.g * 0.25, ec.b * 0.25, 0.9)
			else:
				bg.border_color = Color(ec.r, ec.g, ec.b, 0.7)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)
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
			var tex_path: String = "res://assets/icon_character/" + ch.character_name.to_lower() + ".png"
			d["icon"].texture = load(tex_path) as Texture2D
			d["icon"].modulate = Color(1, 1, 1, 1)

			if active and ch.character_name == active.character_name:
				bg.border_color = Color(1, 1, 1, 0.95)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(ec.r * 0.25, ec.g * 0.25, ec.b * 0.25, 0.9)
			else:
				bg.border_color = Color(ec.r, ec.g, ec.b, 0.7)
				bg.border_width_left = 2
				bg.border_width_right = 2
				bg.border_width_top = 2
				bg.border_width_bottom = 2
				bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)
		else:
			d["hp_bar"].visible = false
			d["shield_bar"].visible = false
			d["mana_bar"].visible = false
			d["icon"].texture = null
			d["icon"].modulate = Color(0.15, 0.15, 0.2, 1)
			d["lbl"].text = "P" if i == 3 else str(i + 1)
			bg.border_color = Color(0.2, 0.2, 0.3, 0.3)
			bg.border_width_left = 1
			bg.border_width_right = 1
			bg.border_width_top = 1
			bg.border_width_bottom = 1
			bg.bg_color = Color(0.06, 0.06, 0.10, 0.6)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			# Chest UI close (F, I, E, or ESC)
			if _chest_open:
				if k.keycode == KEY_F or k.keycode == KEY_ESCAPE or k.keycode == KEY_I or k.keycode == KEY_E:
					close_chest()
				return

			# Inventory close (I/E or ESC when inventory open)
			if _inventory_open:
				if k.keycode == KEY_I or k.keycode == KEY_E or k.keycode == KEY_ESCAPE:
					_toggle_inventory()
				elif k.keycode == KEY_Q:
					_drop_selected_item()
				return

			if _placement_sys and _placement_sys.is_placing():
				if k.keycode == KEY_ESCAPE:
					_placement_sys.cancel_placement()
				return

			# Hotbar selection (Player only)
			if k.keycode >= KEY_1 and k.keycode <= KEY_9:
				var cur := _mgr.get_current_character() if _mgr else null
				if cur is PlayerCharacter and _hotbar.visible:
					_hotbar.select_slot(k.keycode - KEY_1)
					return

			if k.keycode == KEY_F:
				var player := _find_player_character()
				if player:
					player.interact_with_nearby()
				return

			if k.keycode == KEY_I or k.keycode == KEY_E:
				var cur := _mgr.get_current_character() if _mgr else null
				if cur is PlayerCharacter:
					_toggle_inventory()
				return

			if k.keycode == KEY_M:
				if _explore_map and _explore_map.visible:
					_explore_map.close()
				elif _explore_sys and not (_settings_ui and _settings_ui.visible) and not (_party_ui and _party_ui.visible):
					_explore_map.open(_explore_sys)
				return
			if k.keycode == KEY_B:
				if _build_menu and _build_menu.visible:
					_build_menu.close()
				elif _placement_sys and not _build_menu.visible and not (_settings_ui and _settings_ui.visible) and not (_party_ui and _party_ui.visible):
					_build_menu.open(_placement_sys)
				return
			if k.keycode == KEY_P:
				if _party_ui and _party_ui.visible:
					_party_ui.hide_party()
				elif _mgr and not (_settings_ui and _settings_ui.visible):
					_party_ui.show_party(_mgr)
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
					_build_hint.text = "B=Xây dựng"
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					_placement_sys.cancel_placement()
					_build_hint.text = "B=Xây dựng"

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
		_dummy_label.text = "DUMMY: %d / %d" % [_dummy_tracked.hp, _dummy_tracked.max_hp]

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
	_build_hint.text = "B=Xây dựng"

func _drop_selected_item() -> void:
	var player := _find_player_character()
	if player == null or player.inventory == null:
		return
	var idx: int = _inventory_ui._selected_slot
	if idx >= 0 and idx < player.inventory.slots.size():
		player.drop_item(idx)
		_inventory_ui._selected_slot = -1
		_inventory_ui._clear_selection()
	else:
		var hotbar_idx: int = _hotbar.get_selected()
		player.drop_item(hotbar_idx)

func _setup_world_clock() -> void:
	_world_clock = Label.new()
	_world_clock.add_theme_font_size_override("font_size", 14)
	_world_clock.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
	_world_clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_world_clock.add_theme_constant_override("shadow_offset_x", 1)
	_world_clock.add_theme_constant_override("shadow_offset_y", 1)
	_world_clock.text = "06:00"
	add_child(_world_clock)

func _setup_oxygen_bar() -> void:
	_oxygen_bar_bg = ColorRect.new()
	_oxygen_bar_bg.color = Color(0.06, 0.06, 0.10, 0.85)
	_oxygen_bar_bg.size = Vector2(160, 14)
	_oxygen_bar_bg.visible = false
	add_child(_oxygen_bar_bg)

	_oxygen_bar_fill = ColorRect.new()
	_oxygen_bar_fill.color = Color(0.20, 0.55, 0.80, 0.90)
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
	_load_label.text = "ĐANG TẠO THẾ GIỚI..."
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
