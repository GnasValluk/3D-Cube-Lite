class_name PhoneUI
extends Control

const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const PHONE_W: float = 1500
const PHONE_H: float = 860
const _Settings = preload("res://scripts/core/settings_storage.gd")

var _phone: Panel
var _hud: HUD
var _screen_container: Control
var _home_screen: Control
var _weather_screen: Control
var _settings_screen: Control
var _themes_screen: Control
var _map_holder: Control
var _status_time: Label
var _status_battery: Label
var _nav_dots: HBoxContainer
var _current_screen: Control = null
var _settings_current_tab: int = 0
var _settings_tab_btns: Array[Panel] = []
var _refresh_timer: float = 0.0
var _current_forecast: Array[Dictionary] = []

var _is_dark_theme: bool = true
var _tween: Tween

func _ready() -> void:
	_hud = get_parent() as HUD
	_build_ui()
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and get_parent():
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _tc(dark: Color, light: Color) -> Color:
	return dark if _is_dark_theme else light

func _bg_card() -> Color:
	return _tc(Color(0.10, 0.07, 0.18, 0.7), Color(0.85, 0.85, 0.92, 0.85))

func _bg_panel() -> Color:
	return _tc(Color(0.08, 0.06, 0.14, 0.5), Color(0.92, 0.92, 0.95, 0.6))

func _txt_bright() -> Color:
	return _tc(Color(0.85, 0.90, 0.98, 0.85), Color(0.08, 0.08, 0.12, 0.9))

func _txt_main() -> Color:
	return _tc(Color(0.70, 0.75, 0.90, 0.7), Color(0.20, 0.20, 0.30, 0.8))

func _txt_dim() -> Color:
	return _tc(Color(0.50, 0.58, 0.80, 0.5), Color(0.40, 0.40, 0.50, 0.6))

func _make_style(bg: Color, radius: float, border_w: float = 0, border_c: Color = Color(0,0,0,0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	if border_w > 0:
		s.set_border_width_all(int(border_w))
		s.border_color = border_c
	return s

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", max(8, int(font_size * PHONE_H / 680.0)))
	l.add_theme_color_override("font_color", color)
	return l

func _back_button(_screen: Control) -> Control:
	var btn := Control.new()
	btn.size = Vector2(60, 28)
	var lbl := _make_label("\u2190", 18, _txt_bright())
	lbl.position = Vector2(6, 2)
	btn.add_child(lbl)
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			show_screen(_home_screen)
	)
	return btn

func _section_title(text: String, _y: float) -> Label:
	return _make_label(text, 13, _txt_main())

func _fs(base: int) -> int:
	return clampi(int(base * PHONE_H / 680.0), base, base + 6)

func _build_ui() -> void:
	_phone = Panel.new()
	_phone.size = Vector2(PHONE_W, PHONE_H)
	_phone.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
	_apply_phone_style()
	var drop := Panel.new()
	drop.size = Vector2(PHONE_W + 8, PHONE_H + 8)
	drop.position = Vector2(-4, 2)
	drop.mouse_filter = Control.MOUSE_FILTER_PASS
	drop.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0.3), 30))
	_phone.add_child(drop)
	add_child(_phone)

	_status_time = _make_label("00:00", 12, _txt_bright())
	_status_time.position = Vector2(24, 14)
	_phone.add_child(_status_time)

	_status_battery = _make_label("\u2B24", 11, _tc(Color(0.50, 0.85, 0.50, 0.8), Color(0.20, 0.60, 0.20, 0.8)))
	_status_battery.position = Vector2(PHONE_W - 36, 14)
	_phone.add_child(_status_battery)

	var notch := Panel.new()
	notch.size = Vector2(80, 18)
	notch.position = Vector2(PHONE_W / 2 - 40, 0)
	notch.add_theme_stylebox_override("panel", _make_style(_tc(Color(0.04, 0.04, 0.08), Color(0.12, 0.12, 0.15)), 6))
	_phone.add_child(notch)

	_screen_container = Control.new()
	_screen_container.position = Vector2(8, 32)
	_screen_container.size = Vector2(PHONE_W - 16, PHONE_H - 72)
	_phone.add_child(_screen_container)

	_build_home_screen()
	_build_weather_screen()
	_build_settings_screen()
	_build_themes_screen()
	_build_map_holder()

	_nav_dots = HBoxContainer.new()
	_nav_dots.position = Vector2(PHONE_W / 2 - 24, PHONE_H - 28)
	_nav_dots.add_theme_constant_override("separation", 8)
	_phone.add_child(_nav_dots)
	_home_dot(0, true)
	_home_dot(1, false)

	show_screen(_home_screen)

	var home_btn := Control.new()
	home_btn.size = Vector2(90, 24)
	home_btn.position = Vector2(PHONE_W / 2 - 45, PHONE_H - 14)
	var home_bar := Panel.new()
	home_bar.size = Vector2(90, 3)
	home_bar.position = Vector2(0, 10)
	home_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	home_bar.add_theme_stylebox_override("panel", _make_style(_tc(Color(0.22, 0.50, 0.25, 0.5), Color(0.30, 0.30, 0.40, 0.4)), 1.5))
	home_btn.add_child(home_bar)
	home_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			show_screen(_home_screen)
	)
	_phone.add_child(home_btn)

func _apply_phone_style() -> void:
	var metal: Color = _tc(Color(0.55, 0.57, 0.62, 0.95), Color(0.55, 0.57, 0.62, 0.85))
	_phone.add_theme_stylebox_override("panel", _make_style(
		_tc(Color(0.04, 0.04, 0.08, 0.96), Color(0.88, 0.88, 0.92, 0.97)),
		28, 3, metal
	))

func _home_dot(_idx: int, active: bool) -> void:
	var dot := Panel.new()
	dot.size = Vector2(5, 5)
	dot.mouse_filter = Control.MOUSE_FILTER_PASS
	var ac: Color = _tc(Color(0.22, 0.62, 0.28, 0.6), Color(0.18, 0.50, 0.24, 0.7))
	var na: Color = _tc(Color(0.15, 0.30, 0.15, 0.3), Color(0.50, 0.50, 0.55, 0.3))
	dot.add_theme_stylebox_override("panel", _make_style(ac if active else na, 2.5))
	_nav_dots.add_child(dot)

func show_screen(screen: Control) -> void:
	if _current_screen == _map_holder and screen != _map_holder:
		_close_map_in_phone()
		return
	if _current_screen:
		_current_screen.visible = false
	_current_screen = screen
	_current_screen.visible = true
	_refresh_nav_dots()

func _refresh_nav_dots() -> void:
	var is_home: bool = _current_screen == _home_screen
	var idx := 0
	for c in _nav_dots.get_children():
		var active: bool = (idx == 0 and is_home) or (idx == 1 and not is_home)
		if c is Panel:
			var ac: Color = _tc(Color(0.22, 0.62, 0.28, 0.6), Color(0.18, 0.50, 0.24, 0.7))
			var na: Color = _tc(Color(0.15, 0.30, 0.15, 0.3), Color(0.50, 0.50, 0.55, 0.3))
			c.add_theme_stylebox_override("panel", _make_style(ac if active else na, 2.5))
		idx += 1

func _build_home_screen() -> void:
	_home_screen = Control.new()
	_home_screen.size = _screen_container.size
	_screen_container.add_child(_home_screen)

	var welcome := _make_label("My Device", 18, _txt_bright())
	welcome.position = Vector2(0, 8)
	_home_screen.add_child(welcome)

	var date_lbl := _make_label("", 12, _txt_dim())
	date_lbl.name = "HomeDate"
	date_lbl.position = Vector2(0, 30)
	_home_screen.add_child(date_lbl)

	var apps_grid := Control.new()
	apps_grid.position = Vector2(0, 58)
	apps_grid.size = Vector2(_screen_container.size.x, _screen_container.size.y - 58)
	_home_screen.add_child(apps_grid)

	_add_app_icon(apps_grid, 0, "\u2600", "Weather", Color(0.10, 0.55, 0.90), Color(0.30, 0.70, 1.0), func():
		show_screen(_weather_screen)
	)
	_add_app_icon(apps_grid, 1, "\u2699", "Settings", Color(0.40, 0.35, 0.55), Color(0.55, 0.50, 0.70), func():
		show_screen(_settings_screen)
	)
	_add_app_icon(apps_grid, 2, "\U0001F5FA", "Map", Color(0.55, 0.30, 0.20), Color(0.70, 0.45, 0.30), func():
		_show_map_in_phone()
	)
	_add_app_icon(apps_grid, 3, "\U0001F4BE", "Save", Color(0.20, 0.50, 0.30), Color(0.35, 0.65, 0.45), func():
		if _hud:
			_hud._on_save_pressed()
	)
	_add_app_icon(apps_grid, 4, "\U0001F3A8", "Themes", Color(0.30, 0.25, 0.50), Color(0.45, 0.40, 0.65), func():
		show_screen(_themes_screen)
	)

	_home_screen.visible = false

func _add_app_icon(parent: Control, idx: int, icon_text: String, name_text: String, color1: Color, color2: Color, callback: Callable) -> void:
	var x: float = 20 + (idx % 4) * 100
	var y: float = 10 + floori(idx / 4.0) * 90
	var icon_bg := Panel.new()
	icon_bg.size = Vector2(56, 56)
	icon_bg.position = Vector2(x + 8, y)
	icon_bg.add_theme_stylebox_override("panel", _make_style(color1, 14))
	var grad := Panel.new()
	grad.size = Vector2(56, 28)
	grad.position = Vector2(0, 28)
	grad.mouse_filter = Control.MOUSE_FILTER_PASS
	grad.add_theme_stylebox_override("panel", _make_style(Color(color2.r, color2.g, color2.b, 0.3), 14))
	icon_bg.add_child(grad)
	parent.add_child(icon_bg)

	var icon_lbl := _make_label(icon_text, 22, Color(1, 1, 1, 0.9))
	icon_lbl.position = Vector2(x + 20, y + 14)
	parent.add_child(icon_lbl)

	var name_lbl := _make_label(name_text, 11, _txt_dim())
	name_lbl.position = Vector2(x + 6, y + 62)
	parent.add_child(name_lbl)

	var touch := ColorRect.new()
	touch.color = Color(0, 0, 0, 0)
	touch.size = Vector2(80, 80)
	touch.position = Vector2(x, y)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			callback.call()
	)
	parent.add_child(touch)

func _build_settings_screen() -> void:
	var sw: float = _screen_container.size.x

	_settings_screen = Control.new()
	_settings_screen.size = _screen_container.size
	_screen_container.add_child(_settings_screen)

	var top_bar := Panel.new()
	top_bar.size = Vector2(sw, 30)
	top_bar.add_theme_stylebox_override("panel", _make_style(_bg_card(), 8))
	top_bar.add_child(_back_button(_settings_screen))
	var title := _make_label("Settings", _fs(16), _txt_bright())
	title.position = Vector2(sw * 0.5 - 30, 5)
	top_bar.add_child(title)
	_settings_screen.add_child(top_bar)

	_settings_tab_btns.clear()
	var tab_names: Array[String] = ["General", "Graphics", "Audio", "Controls", "Mobile", "Device"]
	var tab_w: float = (sw - 8.0) / tab_names.size()
	for i in tab_names.size():
		var btn := _make_tab_btn(tab_names[i], i == _settings_current_tab)
		btn.position = Vector2(2 + i * tab_w, 34)
		btn.size = Vector2(tab_w - 2, 24)
		var tab_idx := i
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_settings_current_tab = tab_idx
				_rebuild_settings()
		)
		_settings_screen.add_child(btn)
		_settings_tab_btns.append(btn)

	var content_y: float = 64
	var content_h: float = _screen_container.size.y - content_y - 4
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, content_y)
	scroll.size = Vector2(sw - 8, content_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_screen.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "SettingsVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	match _settings_current_tab:
		0: _build_settings_general(vbox, sw)
		1: _build_settings_graphics(vbox, sw)
		2: _build_settings_audio(vbox, sw)
		3: _build_settings_controls(vbox, sw)
		4: _build_settings_mobile(vbox, sw)
		5: _build_settings_device(vbox, sw)

	_settings_screen.visible = false

func _settings_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := _make_label(text, 12, _txt_main())
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)

func _settings_add_toggle(parent: VBoxContainer, label: String, initial: bool, cb: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var lbl := _make_label(label, 11, _txt_main())
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var btn := Panel.new()
	btn.size = Vector2(60, 22)
	btn.set_meta("toggled", initial)
	var btn_lbl := _make_label("ON" if initial else "OFF", 11, _txt_bright())
	btn_lbl.position = Vector2(10, 2)
	btn.add_child(btn_lbl)
	btn.add_theme_stylebox_override("panel", _make_style(
		_tc(Color(0.08, 0.30, 0.08, 0.7) if initial else Color(0.12, 0.09, 0.20, 0.5),
		   Color(0.50, 0.70, 0.50, 0.7) if initial else Color(0.80, 0.80, 0.85, 0.5)), 4))
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			var v: bool = not btn.get_meta("toggled")
			btn.set_meta("toggled", v)
			btn_lbl.text = "ON" if v else "OFF"
			btn.add_theme_stylebox_override("panel", _make_style(
				_tc(Color(0.08, 0.30, 0.08, 0.7) if v else Color(0.12, 0.09, 0.20, 0.5),
				   Color(0.50, 0.70, 0.50, 0.7) if v else Color(0.80, 0.80, 0.85, 0.5)), 4))
			cb.call(v)
	)
	hbox.add_child(btn)

func _settings_add_slider(parent: VBoxContainer, label: String, initial: float, min_v: float, max_v: float, step: float, cb: Callable, suffix: String = "") -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var lbl := _make_label(label, 11, _txt_main())
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.add_theme_color_override("slide_color", _tc(Color(0.22, 0.62, 0.28, 0.5), Color(0.18, 0.50, 0.24, 0.5)))
	slider.add_theme_color_override("grabber_color", _tc(Color(0.22, 0.62, 0.28), Color(0.18, 0.50, 0.24)))
	hbox.add_child(slider)
	var val_lbl := _make_label("%.0f%s" % [initial, suffix], 10, _txt_dim())
	val_lbl.custom_minimum_size = Vector2(30, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slider.value_changed.connect(func(v): val_lbl.text = "%.0f%s" % [v, suffix]; cb.call(v))
	hbox.add_child(val_lbl)

func _build_settings_general(parent: VBoxContainer, _sw: float) -> void:
	_settings_section_label(parent, "Language")
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var lang: String = _get_locale()
	for pair in [["VI", "VI"], ["EN", "EN"]]:
		var is_cur: bool = pair[1].to_lower() == lang
		var btn := _make_tab_btn(pair[0], is_cur)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 24)
		var loc: String = pair[1].to_lower()
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_set_locale(loc)
				_rebuild_settings()
		)
		hbox.add_child(btn)

func _build_settings_graphics(parent: VBoxContainer, _sw: float) -> void:
	_settings_section_label(parent, "Graphics Preset")
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var preset_names: Array[String] = ["Standard", "Enhanced", "Realistic"]
	var preset: int = _get_graphics_preset()
	for pi in preset_names.size():
		var is_cur: bool = pi == preset
		var btn := _make_tab_btn(preset_names[pi], is_cur)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 24)
		var p_idx := pi
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_set_graphics_preset(p_idx)
				_rebuild_settings()
		)
		hbox.add_child(btn)

	_settings_section_label(parent, "Display")
	_settings_add_toggle(parent, "Fullscreen", _is_fullscreen(), func(v): _set_fullscreen(v))
	_settings_add_toggle(parent, "VSync", _is_vsync(), func(v): _set_vsync(v))

func _build_settings_audio(parent: VBoxContainer, _sw: float) -> void:
	_settings_add_slider(parent, "Master Volume", _get_master_volume(), 0, 100, 1, func(v): _set_master_volume(v), "%")
	_settings_add_slider(parent, "Music Volume", _get_music_volume(), 0, 100, 1, func(v): _set_music_volume(v), "%")
	_settings_add_slider(parent, "SFX Volume", _get_sfx_volume(), 0, 100, 1, func(v): _set_sfx_volume(v), "%")

func _build_settings_controls(parent: VBoxContainer, _sw: float) -> void:
	_settings_add_slider(parent, "Mouse Sensitivity", _get_mouse_sensitivity(), 0.1, 5.0, 0.05, func(v): _set_mouse_sensitivity(v))
	_settings_add_toggle(parent, "Invert Y", _is_invert_y(), func(v): _set_invert_y(v))

	parent.add_spacer(false)
	_settings_section_label(parent, "Key Bindings")
	var keys: Array[Dictionary] = [
		{ "action": "Interact", "key": "controls/interact", "default": KEY_F },
		{ "action": "Inventory", "key": "controls/inventory", "default": KEY_E },
		{ "action": "Build", "key": "controls/build", "default": KEY_B },
		{ "action": "Map", "key": "controls/map", "default": KEY_M },
		{ "action": "Debug", "key": "controls/debug", "default": KEY_F2 },
	]
	for entry in keys:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(row)
		var lbl := _make_label(entry.action, 11, _txt_main())
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var key_val: int = _get_keybinding(entry.key, entry.default)
		var key_lbl := _make_label(_keycode_name(key_val), 11, _txt_bright())
		key_lbl.custom_minimum_size = Vector2(80, 0)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.name = "KB_" + entry.key.replace("/", "_")
		var key_bg := _make_style(_bg_card(), 4, 1, _tc(Color(0.40, 0.30, 0.60, 0.4), Color(0.30, 0.25, 0.50, 0.4)))
		key_lbl.add_theme_stylebox_override("normal", key_bg)
		row.add_child(key_lbl)
		var touch := ColorRect.new()
		touch.color = Color(0, 0, 0, 0)
		touch.size = key_lbl.size
		touch.mouse_filter = Control.MOUSE_FILTER_STOP
		touch.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_start_rebind(entry.key, key_lbl)
		)
		key_lbl.add_child(touch)

func _build_settings_mobile(parent: VBoxContainer, _sw: float) -> void:
	_settings_add_toggle(parent, "Touch Controls", _is_touch_enabled(), func(v): _set_touch_enabled(v))
	_settings_add_slider(parent, "Joystick Sensitivity", _get_joystick_sensitivity(), 0.1, 5.0, 0.1, func(v): _set_joystick_sensitivity(v))
	_settings_add_slider(parent, "Button Size", _get_button_scale(), 0.5, 3.0, 0.1, func(v): _set_button_scale(v))

func _build_settings_device(parent: VBoxContainer, _sw: float) -> void:
	_settings_section_label(parent, "Device Type")
	var cur_device: int = _get_device_mode()
	var device_names: Array[String] = ["Auto", "PC", "Mobile"]
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	for di in device_names.size():
		var is_cur: bool = di == cur_device
		var btn := _make_tab_btn(device_names[di], is_cur)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		var d_idx := di
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_set_device_mode(d_idx)
				_rebuild_settings()
		)
		hbox.add_child(btn)

	var status := _make_label("Current: " + device_names[cur_device], 10, _txt_dim())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(status)

func _rebuild_settings() -> void:
	if _settings_screen:
		if _current_screen == _settings_screen:
			_current_screen = null
		if _settings_screen.get_parent():
			_settings_screen.get_parent().remove_child(_settings_screen)
		_settings_screen.queue_free()
	_build_settings_screen()
	if _current_screen == null:
		show_screen(_settings_screen)

func _make_tab_btn(text: String, active: bool) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _make_style(
		_tc(Color(0.22, 0.62, 0.28, 0.6) if active else Color(0.12, 0.09, 0.20, 0.5),
		   Color(0.18, 0.50, 0.24, 0.7) if active else Color(0.80, 0.80, 0.85, 0.5)),
		6))
	var l := _make_label(text, 11, _tc(Color(0.95, 0.92, 1.0, 0.85), Color(0.10, 0.10, 0.15, 0.85)))
	l.position = Vector2(6, 4)
	p.add_child(l)
	return p

# ── Settings helpers (delegates to shared module) ──

func _get_master_volume() -> float: return _Settings.get_master_volume()
func _set_master_volume(v: float) -> void: _Settings.set_master_volume(v); SettingsManager._apply_all()
func _get_music_volume() -> float: return _Settings.get_music_volume()
func _set_music_volume(v: float) -> void: _Settings.set_music_volume(v); SettingsManager._apply_all()
func _get_sfx_volume() -> float: return _Settings.get_sfx_volume()
func _set_sfx_volume(v: float) -> void: _Settings.set_sfx_volume(v); SettingsManager._apply_all()

func _get_graphics_preset() -> int: return SettingsData.graphics_preset if SettingsData else 0
func _set_graphics_preset(p: int) -> void:
	if SettingsData:
		SettingsData.graphics_preset = p
		SettingsManager._apply_all()

func _get_locale() -> String: return SettingsData.locale if SettingsData else "en"
func _set_locale(loc: String) -> void:
	if SettingsData:
		SettingsData.locale = loc
		SettingsManager._apply_all()

func _is_fullscreen() -> bool: return _Settings.is_fullscreen()
func _set_fullscreen(v: bool) -> void: _Settings.set_fullscreen(v)
func _is_vsync() -> bool: return _Settings.is_vsync()
func _set_vsync(v: bool) -> void: _Settings.set_vsync(v)
func _get_mouse_sensitivity() -> float: return _Settings.get_mouse_sensitivity()
func _set_mouse_sensitivity(v: float) -> void: _Settings.set_mouse_sensitivity(v)
func _is_invert_y() -> bool: return _Settings.is_invert_y()
func _set_invert_y(v: bool) -> void: _Settings.set_invert_y(v)
func _is_touch_enabled() -> bool: return _Settings.is_touch_enabled()
func _set_touch_enabled(v: bool) -> void: _Settings.set_touch_enabled(v)
func _get_joystick_sensitivity() -> float: return _Settings.get_joystick_sensitivity()
func _set_joystick_sensitivity(v: float) -> void: _Settings.set_joystick_sensitivity(v)
func _get_button_scale() -> float: return _Settings.get_button_scale()
func _set_button_scale(v: float) -> void: _Settings.set_button_scale(v)

func _get_device_mode() -> int: return SettingsData.device_mode if SettingsData else 0
func _set_device_mode(v: int) -> void:
	if SettingsData:
		SettingsData.device_mode = v
		SettingsManager.save_settings()
	if DeviceManager:
		DeviceManager.set_device(v as DeviceManager.Device)

func _get_keybinding(action: String, default_key: int) -> int: return _Settings.get_keybinding(action, default_key)

func _keycode_name(code: int) -> String:
	if code >= KEY_A and code <= KEY_Z: return char(code)
	if code >= KEY_F1 and code <= KEY_F12: return "F%d" % (code - KEY_F1 + 1)
	if code >= KEY_0 and code <= KEY_9: return char(code)
	match code:
		KEY_ESCAPE: return "ESC"
		KEY_SPACE: return "Space"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ENTER: return "Enter"
		KEY_BACKSPACE: return "Bksp"
		KEY_LEFT: return "L_Arrow"
		KEY_RIGHT: return "R_Arrow"
		KEY_UP: return "U_Arrow"
		KEY_DOWN: return "D_Arrow"
	return "Key%d" % code

var _rebinding_action: String = ""
var _rebinding_lbl: Label = null

func _start_rebind(action: String, lbl: Label) -> void:
	_rebinding_action = action
	_rebinding_lbl = lbl
	lbl.text = "..."

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _rebinding_action.is_empty() or _rebinding_lbl == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			get_viewport().set_input_as_handled()
			if k.is_action_pressed("ui_cancel"):
				_cancel_rebind()
				return
			var conflict: String = ""
			if SettingsData:
				for existing in SettingsData.key_bindings:
					if SettingsData.key_bindings[existing] == k.keycode and existing != _rebinding_action:
						conflict = existing
						break
			if not conflict.is_empty():
				_rebinding_lbl.text = _keycode_name(k.keycode) + " *"
				await get_tree().create_timer(0.8).timeout
				if _rebinding_lbl and is_instance_valid(_rebinding_lbl):
					_rebinding_lbl.text = "..."
				return
			_Settings.set_keybinding(_rebinding_action, k.keycode)
			_rebinding_lbl.text = _keycode_name(k.keycode)
			_rebinding_action = ""
			_rebinding_lbl = null

func _cancel_rebind() -> void:
	if _rebinding_lbl and is_instance_valid(_rebinding_lbl):
		var def: int = _Settings.get_keybinding(_rebinding_action, KEY_F)
		_rebinding_lbl.text = _keycode_name(def)
		_rebinding_lbl = null
		_rebinding_action = ""

func _build_themes_screen() -> void:
	var sw: float = _screen_container.size.x
	var sh: float = _screen_container.size.y

	_themes_screen = Control.new()
	_themes_screen.size = _screen_container.size
	_screen_container.add_child(_themes_screen)

	var top := Panel.new()
	top.size = Vector2(sw, 30)
	top.add_theme_stylebox_override("panel", _make_style(_bg_card(), 8))
	top.add_child(_back_button(_themes_screen))
	var title := _make_label("Themes", 14, _txt_bright())
	title.position = Vector2(sw * 0.5 - 30, 5)
	top.add_child(title)
	_themes_screen.add_child(top)

	var cy: float = 60
	var lbl_sz: int = clampi(int(sh * 0.03), 12, 16)

	var prompt := _make_label("Select Theme", lbl_sz, _txt_bright())
	prompt.position = Vector2(sw * 0.5 - 55, cy)
	_themes_screen.add_child(prompt)
	cy += 50

	var dark_preview := Panel.new()
	dark_preview.size = Vector2(sw * 0.35, sh * 0.35)
	dark_preview.position = Vector2(sw * 0.08, cy)
	dark_preview.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.04, 0.08, 0.96), 14, 2, Color(0.15, 0.40, 0.18, 0.6)))
	var dark_lbl := _make_label("\U0001F311 Dark", 14, Color(0.85, 0.90, 0.98, 0.85))
	dark_lbl.position = Vector2(20, 30)
	dark_preview.add_child(dark_lbl)
	if _is_dark_theme:
		var sel := _make_label("\u2713", 22, Color(0.50, 0.85, 0.50, 0.9))
		sel.position = Vector2(dark_preview.size.x - 30, dark_preview.size.y - 30)
		dark_preview.add_child(sel)
	_dark_preview_input(dark_preview)
	_themes_screen.add_child(dark_preview)

	var light_preview := Panel.new()
	light_preview.size = Vector2(sw * 0.35, sh * 0.35)
	light_preview.position = Vector2(sw * 0.57, cy)
	light_preview.add_theme_stylebox_override("panel", _make_style(Color(0.88, 0.88, 0.92, 0.97), 14, 2, Color(0.50, 0.50, 0.60, 0.4)))
	var light_lbl := _make_label("\U0001F31E Light", 14, Color(0.08, 0.08, 0.12, 0.9))
	light_lbl.position = Vector2(20, 30)
	light_preview.add_child(light_lbl)
	if not _is_dark_theme:
		var sel := _make_label("\u2713", 22, Color(0.20, 0.60, 0.20, 0.9))
		sel.position = Vector2(light_preview.size.x - 30, light_preview.size.y - 30)
		light_preview.add_child(sel)
	_light_preview_input(light_preview)
	_themes_screen.add_child(light_preview)

	_themes_screen.visible = false

func _dark_preview_input(p: Panel) -> void:
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and not _is_dark_theme:
			_is_dark_theme = true
			_rebuild_themes()
	)

func _light_preview_input(p: Panel) -> void:
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and _is_dark_theme:
			_is_dark_theme = false
			_rebuild_themes()
	)

func _rebuild_themes() -> void:
	_apply_phone_style()
	if _themes_screen:
		if _current_screen == _themes_screen:
			_current_screen = null
		if _themes_screen.get_parent():
			_themes_screen.get_parent().remove_child(_themes_screen)
		_themes_screen.queue_free()
	_build_themes_screen()
	if _current_screen == null:
		show_screen(_themes_screen)

func _build_map_holder() -> void:
	var sw: float = _screen_container.size.x
	_map_holder = Control.new()
	_map_holder.size = _screen_container.size
	_screen_container.add_child(_map_holder)
	_map_holder.visible = false

	var top := Panel.new()
	top.size = Vector2(sw, 30)
	top.add_theme_stylebox_override("panel", _make_style(_bg_card(), 8))
	var back_btn := Control.new()
	back_btn.size = Vector2(60, 28)
	var lbl := _make_label("\u2190", 18, _txt_bright())
	lbl.position = Vector2(6, 2)
	back_btn.add_child(lbl)
	back_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_map_in_phone()
	)
	top.add_child(back_btn)
	var ttl := _make_label("Map", 14, _txt_bright())
	ttl.position = Vector2(sw * 0.5 - 20, 5)
	top.add_child(ttl)
	_map_holder.add_child(top)

func _show_map_in_phone() -> void:
	if not _hud or not _hud._explore_map or not _hud._explore_sys:
		return
	var em = _hud._explore_map
	if em.get_parent():
		em.get_parent().remove_child(em)
	_map_holder.add_child(em)
	em.anchor_left = 0.0
	em.anchor_top = 0.0
	em.anchor_right = 1.0
	em.anchor_bottom = 1.0
	em.offset_left = 0
	em.offset_top = 0
	em.offset_right = 0
	em.offset_bottom = 0
	em.size = _map_holder.size
	if em.closed.is_connected(_close_map_in_phone):
		em.closed.disconnect(_close_map_in_phone)
	em.closed.connect(_close_map_in_phone, CONNECT_ONE_SHOT)
	em.open(_hud._explore_sys)
	show_screen(_map_holder)

func _close_map_in_phone() -> void:
	var em = _hud._explore_map if _hud else null
	if not em:
		return
	if em.closed.is_connected(_close_map_in_phone):
		em.closed.disconnect(_close_map_in_phone)
	em.close()
	if _map_holder and em.get_parent() == _map_holder:
		_map_holder.remove_child(em)
	if _hud:
		_hud.add_child(em)
		em.anchor_left = 0.0
		em.anchor_top = 0.0
		em.anchor_right = 1.0
		em.anchor_bottom = 1.0
		em.offset_left = 0
		em.offset_top = 0
		em.offset_right = 0
		em.offset_bottom = 0
	if _current_screen == _map_holder:
		_current_screen.visible = false
		_current_screen = _home_screen
		_current_screen.visible = true
		_refresh_nav_dots()

func _build_weather_screen() -> void:
	var sw: float = _screen_container.size.x
	var sh: float = _screen_container.size.y

	_weather_screen = Control.new()
	_weather_screen.size = _screen_container.size
	_screen_container.add_child(_weather_screen)

	var top := Panel.new()
	top.size = Vector2(sw, 30)
	top.add_theme_stylebox_override("panel", _make_style(_bg_card(), 8))
	top.add_child(_back_button(_weather_screen))
	var ttl := _make_label("Weather", 14, _txt_bright())
	ttl.position = Vector2(sw * 0.5 - 30, 5)
	top.add_child(ttl)
	_weather_screen.add_child(top)

	var header_h: float = sh * 0.27
	var header := Panel.new()
	header.position = Vector2(0, 30)
	header.size = Vector2(sw, header_h)
	header.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.22, 0.7), 12))

	var temp_size: int = clampi(int(sh * 0.08), 24, 48)
	var icon_size: int = clampi(int(sh * 0.06), 20, 36)
	var label_size: int = clampi(int(sh * 0.03), 11, 16)
	var small_size: int = clampi(int(sh * 0.025), 9, 13)

	var w_temp := _make_label("--\u00b0", temp_size, Color(1, 1, 1, 0.95))
	w_temp.name = "W_Temp"
	w_temp.position = Vector2(sw * 0.035, header_h * 0.12)
	header.add_child(w_temp)

	var w_icon := _make_label("\u2600", icon_size, Color(0.95, 0.80, 0.30, 0.9))
	w_icon.name = "W_Icon"
	w_icon.position = Vector2(sw * 0.27, header_h * 0.15)
	header.add_child(w_icon)

	var w_cond := _make_label("--", label_size, Color(0.70, 0.78, 0.95, 0.8))
	w_cond.name = "W_Cond"
	w_cond.position = Vector2(sw * 0.275, header_h * 0.52)
	header.add_child(w_cond)

	var w_date := _make_label("--", small_size, Color(0.50, 0.58, 0.80, 0.5))
	w_date.name = "W_Date"
	w_date.position = Vector2(sw * 0.275, header_h * 0.75)
	header.add_child(w_date)

	var w_highlow := _make_label("", small_size, Color(0.65, 0.72, 0.90, 0.5))
	w_highlow.name = "W_HighLow"
	w_highlow.position = Vector2(sw * 0.035, header_h * 0.74)
	header.add_child(w_highlow)

	_weather_screen.add_child(header)

	var cal_y: float = 30 + header_h + sh * 0.02
	var cal_title := _make_label("Calendar", label_size, Color(0.60, 0.68, 0.88, 0.7))
	cal_title.position = Vector2(0, cal_y)
	_weather_screen.add_child(cal_title)

	var cal_lbl := _make_label("", small_size, Color(0.45, 0.52, 0.72, 0.5))
	cal_lbl.name = "CalMonth"
	cal_lbl.position = Vector2(sw * 0.13, cal_y + 2)
	_weather_screen.add_child(cal_lbl)

	var cal_grid_y: float = cal_y + sh * 0.035
	var cal_grid_h: float = sh * 0.28
	var cal_grid := GridContainer.new()
	cal_grid.name = "CalGrid"
	cal_grid.columns = 7
	cal_grid.position = Vector2(0, cal_grid_y)
	cal_grid.size = Vector2(sw, cal_grid_h)
	cal_grid.add_theme_constant_override("h_separation", 2)
	cal_grid.add_theme_constant_override("v_separation", 1)
	for d in DAY_NAMES:
		var l := _make_label(d, small_size, Color(0.40, 0.48, 0.68, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND
		cal_grid.add_child(l)
	_weather_screen.add_child(cal_grid)

	var fc_y: float = cal_grid_y + cal_grid_h + sh * 0.015
	var fc_title := _make_label("7-Day Forecast", label_size, Color(0.60, 0.68, 0.88, 0.7))
	fc_title.position = Vector2(0, fc_y)
	_weather_screen.add_child(fc_title)

	var fc_container_y: float = fc_y + sh * 0.03
	var fc_container_h: float = sh - fc_container_y - sh * 0.02
	var fc_container := VBoxContainer.new()
	fc_container.name = "FC_Container"
	fc_container.position = Vector2(4, fc_container_y)
	fc_container.size = Vector2(sw - 8, fc_container_h)
	fc_container.add_theme_constant_override("separation", 2)
	_weather_screen.add_child(fc_container)

	_weather_screen.visible = false

func _update_weather_ui() -> void:
	if not TimeSystem:
		return
	var w: int = TimeSystem.get_weather()
	var temp: float = TimeSystem.get_temperature()
	var hour: int = TimeSystem.get_hour_int()
	var minute_val: int = TimeSystem.get_minute()
	var day: int = TimeSystem.get_day()
	var month_name: String = TimeSystem.get_month_name()
	var year: int = TimeSystem.get_year()
	var season: int = TimeSystem.get_season()
	var total_days: int = TimeSystem.get_total_days()

	_status_time.text = "%02d:%02d" % [hour, minute_val]

	var weather_icon: String = "\u2600"
	var weather_color: Color = Color(0.95, 0.80, 0.30)
	var weather_cond: String = "Clear"
	var header_bg: Color = Color(0.08, 0.12, 0.22, 0.7)
	if w == TimeSystem.Weather.RAIN:
		weather_icon = "\u2602"
		weather_color = Color(0.55, 0.70, 0.90)
		weather_cond = "Rain"
		header_bg = Color(0.08, 0.10, 0.18, 0.7)

	_find("W_Temp", _weather_screen).text = "%.0f\u00b0" % [temp]
	_find("W_Icon", _weather_screen).text = weather_icon
	_find("W_Icon", _weather_screen).add_theme_color_override("font_color", weather_color)
	_find("W_Cond", _weather_screen).text = weather_cond

	var season_str: String = ""
	match season:
		TimeSystem.Season.SPRING: season_str = "Spring"
		TimeSystem.Season.SUMMER: season_str = "Summer"
		TimeSystem.Season.AUTUMN: season_str = "Autumn"
		TimeSystem.Season.WINTER: season_str = "Winter"
	var dow: int = total_days % 7
	_find("W_Date", _weather_screen).text = "%s %s %d" % [DAY_NAMES[dow], month_name, day]
	_find("W_HighLow", _weather_screen).text = season_str

	var header: Panel = _weather_screen.get_child(0)
	header.add_theme_stylebox_override("panel", _make_style(header_bg, 12))

	_find("CalMonth", _weather_screen).text = "%s %d" % [month_name, year + 1]
	_build_cal_grid(day)

	_generate_forecast(w, total_days, season)
	_build_forecast()

	var dow_name: String = DAY_NAMES[dow]
	var home_date := _find("HomeDate", _home_screen)
	if home_date:
		home_date.text = "%s, %s %d, Year %d" % [dow_name, month_name, day, year + 1]

func _find(node_name: String, parent: Node) -> Node:
	var result := parent.get_node_or_null(node_name)
	if result:
		return result
	for c in parent.get_children():
		result = _find(node_name, c)
		if result:
			return result
	return null

func _build_cal_grid(today: int) -> void:
	var grid := _find("CalGrid", _weather_screen) as GridContainer
	if not grid:
		return
	while grid.get_child_count() > 7:
		var c := grid.get_child(grid.get_child_count() - 1)
		grid.remove_child(c)
		c.queue_free()

	var total_days: int = TimeSystem.get_total_days() if TimeSystem else 0
	var first_dow: int = (total_days - today + 1) % 7
	if first_dow < 0:
		first_dow += 7

	var sh: float = _screen_container.size.y
	var date_size: int = clampi(int(sh * 0.022), 8, 11)

	for i in range(first_dow):
		var l := _make_label("", date_size, Color(1, 1, 1, 0))
		l.size_flags_horizontal = Control.SIZE_EXPAND
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)

	for d in range(1, 31):
		var l := _make_label(str(d), date_size, Color(0.60, 0.68, 0.88, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND
		if d == today:
			l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40, 1))
			l.add_theme_font_size_override("font_size", date_size + 2)
			l.add_theme_stylebox_override("normal", _make_style(Color(0.18, 0.22, 0.35, 0.6), 4))
		grid.add_child(l)

	var total_cells: int = first_dow + 30
	var remainder: int = total_cells % 7
	if remainder > 0:
		var fill: int = 7 - remainder
		for i in range(1, fill + 1):
			var l := _make_label(str(i), date_size, Color(0.40, 0.45, 0.60, 0.35))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size_flags_horizontal = Control.SIZE_EXPAND
			grid.add_child(l)

func _build_forecast() -> void:
	var fc := _find("FC_Container", _weather_screen) as VBoxContainer
	if not fc:
		return
	for c in fc.get_children():
		c.queue_free()
	var total_days: int = TimeSystem.get_total_days() if TimeSystem else 0
	var first: bool = true
	for f in _current_forecast:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND
		var di: int = total_days + (len(fc.get_children())) % 7
		var dname: String = DAY_NAMES[di % 7]
		var dl := _make_label(dname, 11, Color(0.55, 0.62, 0.82, 0.7))
		dl.custom_minimum_size = Vector2(36, 0)
		hbox.add_child(dl)
		var w_icon: String = "\u2602" if f["weather"] == TimeSystem.Weather.RAIN else "\u2600"
		var wl := _make_label(w_icon, 13, Color(0.80, 0.85, 0.95, 0.8))
		wl.custom_minimum_size = Vector2(24, 0)
		hbox.add_child(wl)
		var hl := _make_label("%.0f\u00b0 %.0f\u00b0" % [f["temp_high"], f["temp_low"]], 11, Color(0.70, 0.60, 0.45, 0.6))
		hl.size_flags_horizontal = Control.SIZE_EXPAND
		hbox.add_child(hl)
		if first:
			var tag := _make_label("Today", 9, Color(0.40, 0.65, 0.45, 0.6))
			hbox.add_child(tag)
			first = false
		fc.add_child(hbox)

func _generate_forecast(current_weather: int, total_days: int, season: int) -> void:
	_current_forecast.clear()
	for i in range(7):
		var day_offset: int = total_days + i
		var prev_w: int = current_weather if i == 0 else _current_forecast[i - 1]["weather"]
		var hash_val: int = (day_offset * 7919 + season * 104729) % 100
		var w: int
		if prev_w == TimeSystem.Weather.CLEAR:
			w = TimeSystem.Weather.RAIN if hash_val < 10 else TimeSystem.Weather.CLEAR
		else:
			w = TimeSystem.Weather.CLEAR
		var base: float = _season_base(season)
		var high: float = base + (hash_val % 10) * 0.3 - 1.5
		var low: float = high - (4.0 + (hash_val % 7) * 0.5)
		if w == TimeSystem.Weather.RAIN:
			high -= 4.0
			low -= 2.0
		_current_forecast.append({"weather": w, "temp_high": high, "temp_low": low})

func _season_base(season: int) -> float:
	match season:
		TimeSystem.Season.SPRING: return 20.0
		TimeSystem.Season.SUMMER: return 30.0
		TimeSystem.Season.AUTUMN: return 18.0
		TimeSystem.Season.WINTER: return 8.0
	return 20.0

func open() -> void:
	if not TimeSystem:
		return
	_update_weather_ui()
	_play_appear()

func close() -> void:
	if _current_screen == _map_holder:
		_close_map_in_phone()
	_play_disappear()

func _play_appear() -> void:
	visible = true
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.20)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.20)

func _play_disappear() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.12)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func():
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0
	)

func _process(delta: float) -> void:
	if not visible or not TimeSystem:
		return
	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		_update_weather_ui()
