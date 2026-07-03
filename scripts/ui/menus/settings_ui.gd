extends Control
class_name SettingsUI

enum Tab { GENERAL, GRAPHICS, AUDIO, CONTROLS, MOBILE, DEVICE }

var _current_tab: int = Tab.GENERAL
var _rebinding_action: String = ""
var _rebinding_btn: Button = null
var _bg: Panel
var _content: Control
var _tab_btns: Array[Button] = []
var _close_btn: Button
var _title_lbl: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_translations()
	_build()

func _load_translations() -> void:
	var path: String = "res://translations/game.csv"
	if not FileAccess.file_exists(path):
		return
	for locale in ["vi", "en"]:
		var col: int = 1 if locale == "en" else 2
		var t := Translation.new()
		t.locale = locale
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var header: bool = true
			while not f.eof_reached():
				var line = f.get_csv_line()
				if line.is_empty() or line[0].is_empty():
					continue
				if header:
					header = false
					continue
				if line.size() > col:
					t.add_message(line[0], line[col])
			f.close()
		TranslationServer.add_translation(t)

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 640.0
	var H: float = 500.0

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent): if e is InputEventMouseButton: get_viewport().set_input_as_handled())
	add_child(overlay)

	_bg = Panel.new()
	_bg.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	_bg.size = Vector2(W, H)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.3, 0.5, 0.6)
	_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg)

	_title_lbl = Label.new()
	_title_lbl.text = tr("SETTINGS_TITLE")
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 26)
	_title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_title_lbl.position = Vector2(0, 14)
	_title_lbl.size = Vector2(W, 36)
	_bg.add_child(_title_lbl)

	var line := ColorRect.new()
	line.position = Vector2(20, 52)
	line.size = Vector2(W - 40, 1)
	line.color = Color(0.3, 0.3, 0.5, 0.3)
	_bg.add_child(line)

	# Tab buttons
	var tab_w: float = 96.0
	var tab_names: Array[String] = ["SETTINGS_GENERAL", "SETTINGS_GRAPHICS", "SETTINGS_AUDIO", "SETTINGS_CONTROLS", "SETTINGS_MOBILE", "DEVICE_TAB"]
	for i in range(6):
		var btn := Button.new()
		btn.text = tr(tab_names[i])
		btn.position = Vector2(14 + i * (tab_w + 3), 58)
		btn.size = Vector2(tab_w, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		var tb_bg := StyleBoxFlat.new()
		tb_bg.corner_radius_top_left = 6; tb_bg.corner_radius_top_right = 6
		tb_bg.corner_radius_bottom_left = 6; tb_bg.corner_radius_bottom_right = 6
		tb_bg.bg_color = Color(0.12, 0.12, 0.22, 0.7)
		tb_bg.border_width_left = 1; tb_bg.border_width_right = 1
		tb_bg.border_width_top = 1; tb_bg.border_width_bottom = 1
		tb_bg.border_color = Color(0.3, 0.3, 0.5, 0.4)
		btn.add_theme_stylebox_override("normal", tb_bg)
		var tb_hover := tb_bg.duplicate()
		tb_hover.bg_color = Color(0.18, 0.22, 0.38, 0.85)
		tb_hover.border_color = Color(0.5, 0.6, 0.9, 0.5)
		btn.add_theme_stylebox_override("hover", tb_hover)
		btn.pressed.connect(_on_tab.bind(i))
		_bg.add_child(btn)
		_tab_btns.append(btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 92)
	scroll.size = Vector2(W - 28, H - 160)
	_bg.add_child(scroll)

	_content = Control.new()
	_content.size = Vector2(W - 48, 1)
	scroll.add_child(_content)

	_close_btn = Button.new()
	_close_btn.position = Vector2(W * 0.5 - 80, H - 38)
	_close_btn.size = Vector2(160, 30)
	_close_btn.text = tr("CLOSE")
	_close_btn.add_theme_font_size_override("font_size", 13)
	_close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	var close_bg := StyleBoxFlat.new()
	close_bg.bg_color = Color(0.12, 0.12, 0.22, 0.8)
	close_bg.corner_radius_top_left = 6; close_bg.corner_radius_top_right = 6
	close_bg.corner_radius_bottom_left = 6; close_bg.corner_radius_bottom_right = 6
	close_bg.border_width_left = 1; close_bg.border_width_right = 1
	close_bg.border_width_top = 1; close_bg.border_width_bottom = 1
	close_bg.border_color = Color(0.3, 0.3, 0.5, 0.5)
	_close_btn.add_theme_stylebox_override("normal", close_bg)
	var close_hover := close_bg.duplicate()
	close_hover.bg_color = Color(0.18, 0.22, 0.38, 0.85)
	close_hover.border_color = Color(0.5, 0.6, 0.9, 0.5)
	_close_btn.add_theme_stylebox_override("hover", close_hover)
	_close_btn.pressed.connect(_on_close)
	_bg.add_child(_close_btn)

	_show_tab(Tab.GENERAL)

func _on_tab(tab: int) -> void:
	_current_tab = tab
	_show_tab(tab)

func _show_tab(tab: int) -> void:
	for ch in _content.get_children():
		ch.queue_free()

	for i in range(_tab_btns.size()):
		var tb_bg := _tab_btns[i].get_theme_stylebox("normal") as StyleBoxFlat
		if tb_bg:
			tb_bg.bg_color = Color(0.18, 0.22, 0.38, 0.8) if i == tab else Color(0.12, 0.12, 0.22, 0.7)
			tb_bg.border_color = Color(0.5, 0.6, 0.9, 0.5) if i == tab else Color(0.3, 0.3, 0.5, 0.4)

	match tab:
		Tab.GENERAL: _build_general_tab()
		Tab.GRAPHICS: _build_graphics_tab()
		Tab.AUDIO: _build_audio_tab()
		Tab.CONTROLS: _build_controls_tab()
		Tab.MOBILE: _build_mobile_tab()
		Tab.DEVICE: _build_device_tab()

func _make_section_label(text: String, y: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.85))
	lbl.position = Vector2(0, y)
	lbl.size = Vector2(_content.size.x, 22)
	_content.add_child(lbl)
	return lbl

func _build_general_tab() -> void:
	var y: float = 0
	_make_section_label(tr("LANGUAGE"), y); y += 28

	var vi_btn := Button.new()
	vi_btn.position = Vector2(0, y)
	vi_btn.size = Vector2(140, 36)
	vi_btn.text = tr("VIETNAMESE")
	vi_btn.add_theme_font_size_override("font_size", 13)
	vi_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var vi_bg := StyleBoxFlat.new()
	vi_bg.corner_radius_top_left = 6; vi_bg.corner_radius_top_right = 6
	vi_bg.corner_radius_bottom_left = 6; vi_bg.corner_radius_bottom_right = 6
	vi_bg.border_width_left = 2; vi_bg.border_width_right = 2
	vi_bg.border_width_top = 2; vi_bg.border_width_bottom = 2
	vi_bg.border_color = Color(0.2, 0.5, 0.2, 0.7)
	vi_btn.add_theme_stylebox_override("normal", vi_bg)
	vi_btn.add_theme_stylebox_override("hover", vi_bg)
	vi_btn.pressed.connect(_on_set_language.bind("vi"))
	_content.add_child(vi_btn)

	var en_btn := Button.new()
	en_btn.position = Vector2(150, y)
	en_btn.size = Vector2(140, 36)
	en_btn.text = tr("ENGLISH")
	en_btn.add_theme_font_size_override("font_size", 13)
	en_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var en_bg := StyleBoxFlat.new()
	en_bg.corner_radius_top_left = 6; en_bg.corner_radius_top_right = 6
	en_bg.corner_radius_bottom_left = 6; en_bg.corner_radius_bottom_right = 6
	en_bg.border_width_left = 2; en_bg.border_width_right = 2
	en_bg.border_width_top = 2; en_bg.border_width_bottom = 2
	en_bg.border_color = Color(0.2, 0.2, 0.5, 0.7)
	en_btn.add_theme_stylebox_override("normal", en_bg)
	en_btn.add_theme_stylebox_override("hover", en_bg)
	en_btn.pressed.connect(_on_set_language.bind("en"))
	_content.add_child(en_btn)

	y += 46
	_refresh_lang_btns()
	_content.size.y = y + 20

func _build_graphics_tab() -> void:
	var y: float = 0
	_make_section_label(tr("DISPLAY"), y); y += 28

	_add_toggle(tr("FULLSCREEN"), y, _is_fullscreen(), func(v): _set_fullscreen(v))
	y += 36

	_add_toggle(tr("VSYNC"), y, _is_vsync(), func(v): _set_vsync(v))
	y += 36
	_content.size.y = y + 20

func _build_audio_tab() -> void:
	var y: float = 0
	_make_section_label(tr("MASTER_VOLUME"), y); y += 28
	_add_slider(y, _get_master_volume(), func(v): _set_master_volume(v))
	y += 44
	_make_section_label(tr("MUSIC_VOLUME"), y); y += 28
	_add_slider(y, _get_music_volume(), func(v): _set_music_volume(v))
	y += 44
	_make_section_label(tr("SFX_VOLUME"), y); y += 28
	_add_slider(y, _get_sfx_volume(), func(v): _set_sfx_volume(v))
	_content.size.y = y + 44

func _build_controls_tab() -> void:
	var y: float = 0
	_make_section_label(tr("MOUSE_SENSITIVITY"), y); y += 28

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(0, y)
	hbox.size = Vector2(_content.size.x, 36)
	_content.add_child(hbox)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.1
	slider.max_value = 5.0
	slider.step = 0.05
	slider.value = _get_mouse_sensitivity()
	slider.value_changed.connect(_set_mouse_sensitivity)
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	val_lbl.size = Vector2(40, 36)
	val_lbl.text = str(snapped(slider.value, 0.1))
	slider.value_changed.connect(func(v): val_lbl.text = str(snapped(v, 0.1)))
	hbox.add_child(val_lbl)

	y += 44
	_add_toggle(tr("INVERT_Y"), y, _is_invert_y(), func(v): _set_invert_y(v)); y += 36

	y += 8
	_make_section_label(tr("KEY_BINDINGS"), y); y += 28

	var keys: Array[Dictionary] = [
		{ "action": "Interact", "key": "controls/interact", "default": KEY_F },
		{ "action": "Inventory", "key": "controls/inventory", "default": KEY_I },
		{ "action": "Build", "key": "controls/build", "default": KEY_B },
		{ "action": "Party", "key": "controls/party", "default": KEY_P },
		{ "action": "Map", "key": "controls/map", "default": KEY_M },
		{ "action": "Debug", "key": "controls/debug", "default": KEY_F2 },
	]
	for entry in keys:
		var lbl := Label.new()
		lbl.text = entry.action
		lbl.position = Vector2(0, y)
		lbl.size = Vector2(140, 28)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.8))
		_content.add_child(lbl)

		var key_btn := Button.new()
		key_btn.text = _keycode_name(_get_keybinding(entry.key, entry.default))
		key_btn.position = Vector2(150, y)
		key_btn.size = Vector2(130, 28)
		key_btn.add_theme_font_size_override("font_size", 13)
		key_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		var kb_bg := StyleBoxFlat.new()
		kb_bg.corner_radius_top_left = 4; kb_bg.corner_radius_top_right = 4
		kb_bg.corner_radius_bottom_left = 4; kb_bg.corner_radius_bottom_right = 4
		kb_bg.border_width_left = 1; kb_bg.border_width_right = 1
		kb_bg.border_width_top = 1; kb_bg.border_width_bottom = 1
		kb_bg.border_color = Color(0.3, 0.3, 0.5, 0.4)
		kb_bg.bg_color = Color(0.12, 0.12, 0.22, 0.7)
		key_btn.add_theme_stylebox_override("normal", kb_bg)
		key_btn.pressed.connect(_start_rebind.bind(entry.key, entry.default, key_btn))
		_content.add_child(key_btn)

		y += 32

	_content.size.y = y + 20

func _add_toggle(label: String, y: float, initial: bool, cb: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(0, y)
	hbox.size = Vector2(_content.size.x, 32)
	_content.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.8))
	lbl.size = Vector2(200, 32)
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.text = tr("ON") if initial else tr("OFF")
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	var btn_bg := StyleBoxFlat.new()
	btn_bg.corner_radius_top_left = 4; btn_bg.corner_radius_top_right = 4
	btn_bg.corner_radius_bottom_left = 4; btn_bg.corner_radius_bottom_right = 4
	btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
	btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
	btn_bg.border_color = Color(0.3, 0.3, 0.5, 0.4)
	btn.add_theme_stylebox_override("normal", btn_bg)
	btn.toggled.connect(func(toggled: bool):
		btn.text = tr("ON") if toggled else tr("OFF")
		cb.call(toggled)
	)
	btn.size = Vector2(70, 30)
	hbox.add_child(btn)

func _add_slider(y: float, initial: float, cb: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(0, y)
	hbox.size = Vector2(_content.size.x, 36)
	_content.add_child(hbox)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial
	slider.value_changed.connect(cb)
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	val_lbl.size = Vector2(36, 36)
	val_lbl.text = "%d%%" % initial
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % v)
	hbox.add_child(val_lbl)

# ── Settings storage (project settings) ──────────────────────────────────────

func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)

func _is_vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

func _set_vsync(v: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)

func _get_master_volume() -> float:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0: return 50.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	return (db + 80.0) / 80.0 * 100.0

func _set_master_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0: return
	var db: float = v / 100.0 * 80.0 - 80.0
	AudioServer.set_bus_volume_db(idx, db)

func _get_music_volume() -> float:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0: return 50.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	return (db + 80.0) / 80.0 * 100.0

func _set_music_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0: return
	var db: float = v / 100.0 * 80.0 - 80.0
	AudioServer.set_bus_volume_db(idx, db)

func _get_sfx_volume() -> float:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0: return 50.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	return (db + 80.0) / 80.0 * 100.0

func _set_sfx_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0: return
	var db: float = v / 100.0 * 80.0 - 80.0
	AudioServer.set_bus_volume_db(idx, db)

func _get_mouse_sensitivity() -> float:
	return ProjectSettings.get_setting("input/pointing/mouse_sensitivity_modifier", 1.0)

func _set_mouse_sensitivity(v: float) -> void:
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_modifier", v)

func _is_invert_y() -> bool:
	return ProjectSettings.get_setting("controls/invert_y", false)

func _set_invert_y(v: bool) -> void:
	ProjectSettings.set_setting("controls/invert_y", v)

# ── Language ─────────────────────────────────────────────────────────────────

func _refresh_lang_btns() -> void:
	var cur: String = TranslationServer.get_locale()
	var children = _content.get_children()
	for child in children:
		if child is Button:
			var btn := child as Button
			var bg := btn.get_theme_stylebox("normal") as StyleBoxFlat
			if bg and (btn.text == tr("VIETNAMESE") or btn.text == tr("ENGLISH")):
				var is_active: bool = (cur == "vi" and btn.text == tr("VIETNAMESE")) or (cur == "en" and btn.text == tr("ENGLISH"))
				bg.border_color = Color(0.3, 0.75, 0.3, 0.9) if is_active else Color(0.2, 0.2, 0.4, 0.6)
				bg.bg_color = Color(0.1, 0.25, 0.1, 0.6) if is_active else Color(0.08, 0.08, 0.15, 0.6)

func _on_set_language(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_current_tab = Tab.GENERAL
	_rebuild_texts()

func _rebuild_texts() -> void:
	_title_lbl.text = tr("SETTINGS_TITLE")
	_close_btn.text = tr("CLOSE")
	var tab_names: Array[String] = ["SETTINGS_GENERAL", "SETTINGS_GRAPHICS", "SETTINGS_AUDIO", "SETTINGS_CONTROLS", "SETTINGS_MOBILE", "DEVICE_TAB"]
	for i in range(min(_tab_btns.size(), tab_names.size())):
		_tab_btns[i].text = tr(tab_names[i])
	_show_tab(_current_tab)

func _on_close() -> void:
	hide_settings()

func show_settings() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_tab(_current_tab)

func hide_settings() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_mobile_tab() -> void:
	var y: float = 0
	_make_section_label(tr("TOUCH_CONTROLS"), y); y += 28
	_add_toggle(tr("TOUCH_ENABLED"), y, _is_touch_enabled(), func(v): _set_touch_enabled(v)); y += 36

	_make_section_label(tr("JOYSTICK"), y); y += 28
	var js_hbox := HBoxContainer.new()
	js_hbox.position = Vector2(0, y)
	js_hbox.size = Vector2(_content.size.x, 36)
	_content.add_child(js_hbox)
	var js_slider := HSlider.new()
	js_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	js_slider.min_value = 0.3
	js_slider.max_value = 2.0
	js_slider.step = 0.05
	js_slider.value = _get_joystick_sensitivity()
	js_slider.value_changed.connect(_set_joystick_sensitivity)
	js_hbox.add_child(js_slider)
	var js_lbl := Label.new()
	js_lbl.add_theme_font_size_override("font_size", 12)
	js_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	js_lbl.size = Vector2(40, 36)
	js_lbl.text = str(snapped(js_slider.value, 0.1))
	js_slider.value_changed.connect(func(v): js_lbl.text = str(snapped(v, 0.1)))
	js_hbox.add_child(js_lbl)
	y += 44

	_make_section_label(tr("BUTTON_SIZE"), y); y += 28
	var bs_hbox := HBoxContainer.new()
	bs_hbox.position = Vector2(0, y)
	bs_hbox.size = Vector2(_content.size.x, 36)
	_content.add_child(bs_hbox)
	var bs_slider := HSlider.new()
	bs_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bs_slider.min_value = 0.5
	bs_slider.max_value = 2.0
	bs_slider.step = 0.1
	bs_slider.value = _get_button_scale()
	bs_slider.value_changed.connect(_set_button_scale)
	bs_hbox.add_child(bs_slider)
	var bs_lbl := Label.new()
	bs_lbl.add_theme_font_size_override("font_size", 12)
	bs_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8, 0.7))
	bs_lbl.size = Vector2(40, 36)
	bs_lbl.text = str(snapped(bs_slider.value, 0.1))
	bs_slider.value_changed.connect(func(v): bs_lbl.text = str(snapped(v, 0.1)))
	bs_hbox.add_child(bs_lbl)
	y += 44
	_content.size.y = y + 20

# ── Mobile settings ──────────────────────────────────────────────────────────

func _is_touch_enabled() -> bool:
	return ProjectSettings.get_setting("mobile/touch_controls_enabled", true)

func _set_touch_enabled(v: bool) -> void:
	ProjectSettings.set_setting("mobile/touch_controls_enabled", v)

func _get_joystick_sensitivity() -> float:
	return ProjectSettings.get_setting("mobile/joystick_sensitivity", 1.0)

func _set_joystick_sensitivity(v: float) -> void:
	ProjectSettings.set_setting("mobile/joystick_sensitivity", v)

func _get_button_scale() -> float:
	return ProjectSettings.get_setting("mobile/button_scale", 1.0)

func _set_button_scale(v: float) -> void:
	ProjectSettings.set_setting("mobile/button_scale", v)

# ── Key bindings ─────────────────────────────────────────────────────────────

func _get_keybinding(key: String, default_key: int) -> int:
	return ProjectSettings.get_setting(key, default_key)

func _keycode_name(code: int) -> String:
	if code >= KEY_A and code <= KEY_Z:
		return char(code)
	if code >= KEY_F1 and code <= KEY_F12:
		return "F%d" % (code - KEY_F1 + 1)
	if code >= KEY_0 and code <= KEY_9:
		return char(code)
	if code == KEY_ESCAPE:
		return "ESC"
	if code == KEY_SPACE:
		return "Space"
	if code == KEY_SHIFT:
		return "Shift"
	if code == KEY_CTRL:
		return "Ctrl"
	if code == KEY_ALT:
		return "Alt"
	if code == KEY_TAB:
		return "Tab"
	if code == KEY_ENTER:
		return "Enter"
	if code == KEY_BACKSPACE:
		return "Bksp"
	if code == KEY_LEFT:
		return "L_Arrow"
	if code == KEY_RIGHT:
		return "R_Arrow"
	if code == KEY_UP:
		return "U_Arrow"
	if code == KEY_DOWN:
		return "D_Arrow"
	return "Key%d" % code

func _start_rebind(setting: String, default_key: int, btn: Button) -> void:
	_rebinding_action = setting
	_rebinding_btn = btn
	btn.text = "..."
	btn.disabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if not visible or _rebinding_action.is_empty() or _rebinding_btn == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			get_viewport().set_input_as_handled()
			if k.keycode == KEY_ESCAPE:
				_cancel_rebind()
				return
			var defaults: Dictionary = { "controls/interact": KEY_F, "controls/inventory": KEY_I, "controls/build": KEY_B, "controls/party": KEY_P, "controls/map": KEY_M, "controls/debug": KEY_F2 }
			var saved: Dictionary = {}
			for existing in defaults:
				saved[existing] = ProjectSettings.get_setting(existing, defaults[existing])
			var conflict: String = ""
			for existing in saved:
				if saved[existing] == k.keycode and existing != _rebinding_action:
					conflict = existing
					break
			if not conflict.is_empty():
				_rebinding_btn.text = _keycode_name(k.keycode) + " *"
				await get_tree().create_timer(0.8).timeout
				if _rebinding_btn and is_instance_valid(_rebinding_btn):
					_rebinding_btn.text = "..."
				return
			ProjectSettings.set_setting(_rebinding_action, k.keycode)
			_rebinding_btn.text = _keycode_name(k.keycode)
			_rebinding_btn.disabled = false
			_rebinding_action = ""
			_rebinding_btn = null

func _cancel_rebind() -> void:
	if _rebinding_btn and is_instance_valid(_rebinding_btn):
		var defaults: Dictionary = { "controls/interact": KEY_F, "controls/inventory": KEY_I, "controls/build": KEY_B, "controls/party": KEY_P, "controls/map": KEY_M, "controls/debug": KEY_F2 }
		var def: int = defaults.get(_rebinding_action, KEY_F)
		_rebinding_btn.text = _keycode_name(ProjectSettings.get_setting(_rebinding_action, def))
		_rebinding_btn.disabled = false
		_rebinding_btn = null
		_rebinding_action = ""

# ── Device Tab ────────────────────────────────────────────────────────────────
func _build_device_tab() -> void:
	var y: float = 0

	# ── Tiêu đề mô tả ────────────────────────────────────────────────────────
	_make_section_label(tr("DEVICE_TYPE"), y); y += 28

	var desc := Label.new()
	desc.text = tr("DEVICE_DESC")
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.60, 0.65, 0.75, 0.70))
	desc.position = Vector2(0, y)
	desc.size = Vector2(_content.size.x, 36)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(desc)
	y += 42

	# ── 3 nút chọn: Auto / PC / Mobile ───────────────────────────────────────
	var cur_device: int = DeviceManager.get_device() if DeviceManager else 0
	var btn_data: Array[Dictionary] = [
		{ "label": tr("DEVICE_AUTO"), "mode": 0, "col": Color(0.35, 0.55, 0.80, 0.75) },
		{ "label": "💻  " + tr("DEVICE_PC"),   "mode": 1, "col": Color(0.30, 0.70, 0.50, 0.75) },
		{ "label": "📱  " + tr("DEVICE_MOBILE"), "mode": 2, "col": Color(0.80, 0.45, 0.20, 0.75) },
	]

	var btn_w: float = (_content.size.x - 16.0) / 3.0
	var device_btns: Array[Button] = []

	for i in range(3):
		var d: Dictionary = btn_data[i]
		var btn := Button.new()
		btn.text = d["label"]
		btn.position = Vector2(i * (btn_w + 8.0), y)
		btn.size = Vector2(btn_w, 52)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
		var sty := StyleBoxFlat.new()
		sty.bg_color = d["col"] if cur_device == d["mode"] \
			else Color(d["col"].r * 0.4, d["col"].g * 0.4, d["col"].b * 0.4, 0.55)
		sty.corner_radius_top_left    = 8
		sty.corner_radius_top_right   = 8
		sty.corner_radius_bottom_left = 8
		sty.corner_radius_bottom_right = 8
		sty.border_width_left   = 2; sty.border_width_right  = 2
		sty.border_width_top    = 2; sty.border_width_bottom = 2
		sty.border_color = Color(1, 1, 1, 0.30) if cur_device == d["mode"] else Color(1, 1, 1, 0.10)
		btn.add_theme_stylebox_override("normal", sty)
		var sty_h := sty.duplicate() as StyleBoxFlat
		sty_h.bg_color = d["col"]
		sty_h.border_color = Color(1, 1, 1, 0.55)
		btn.add_theme_stylebox_override("hover", sty_h)
		var mode_val: int = d["mode"]
		btn.pressed.connect(func():
			if DeviceManager:
				DeviceManager.set_device(mode_val)
			# Refresh toàn bộ tab để highlight nút mới
			_show_tab(Tab.DEVICE)
		)
		_content.add_child(btn)
		device_btns.append(btn)
	y += 68

	# ── Trạng thái hiện tại ───────────────────────────────────────────────────
	var status_lbl := Label.new()
	var is_mob: bool = DeviceManager.is_mobile() if DeviceManager else false
	var detected: String = tr("DEVICE_MOBILE") if DeviceManager._detect_mobile() else tr("DEVICE_PC")
	status_lbl.text = tr("DEVICE_CURRENT") % [
		tr("DEVICE_MOBILE") if is_mob else tr("DEVICE_PC"),
		detected
	]
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.70, 0.85))
	status_lbl.position = Vector2(0, y)
	status_lbl.size = Vector2(_content.size.x, 22)
	_content.add_child(status_lbl)
	y += 30

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color = Color(0.30, 0.40, 0.60, 0.20)
	div.position = Vector2(0, y); div.size = Vector2(_content.size.x, 1)
	_content.add_child(div)
	y += 14

	# ── Tóm tắt tối ưu theo thiết bị ─────────────────────────────────────────
	if is_mob:
		_make_section_label("📱 " + tr("MOBILE_FEATURES"), y); y += 26
		var features: Array[String] = [
			"✓  " + tr("FEAT_JOYSTICK"),
			"✓  " + tr("FEAT_CAM_DRAG"),
			"✓  " + tr("FEAT_TOUCH_BTNS"),
			"✓  " + tr("FEAT_CHUNK_LOW"),
		]
		for ft in features:
			var fl := Label.new()
			fl.text = ft
			fl.add_theme_font_size_override("font_size", 12)
			fl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.65, 0.80))
			fl.position = Vector2(8, y); fl.size = Vector2(_content.size.x - 8, 20)
			_content.add_child(fl)
			y += 22
	else:
		_make_section_label("💻 " + tr("PC_FEATURES"), y); y += 26
		var features: Array[String] = [
			"✓  " + tr("FEAT_WASD"),
			"✓  " + tr("FEAT_MOUSE_CAM"),
			"✓  " + tr("FEAT_KEYBOARD"),
			"✓  " + tr("FEAT_CHUNK_HIGH"),
		]
		for ft in features:
			var fl := Label.new()
			fl.text = ft
			fl.add_theme_font_size_override("font_size", 12)
			fl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.90, 0.80))
			fl.position = Vector2(8, y); fl.size = Vector2(_content.size.x - 8, 20)
			_content.add_child(fl)
			y += 22

	_content.size.y = y + 20
