extends Control
class_name SettingsUI

const _Settings = preload("res://scripts/core/settings_storage.gd")
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

enum Tab { GENERAL, GRAPHICS, AUDIO, CONTROLS, MOBILE, DEVICE }

var _current_tab: int = Tab.GENERAL
var _rebinding_action: String = ""
var _rebinding_btn: Button = null
var _bg: Panel
var _content_vbox: VBoxContainer
var _tab_btns: Array[Button] = []
var _close_btn: Button
var _title_lbl: Label
var _scroll: ScrollContainer
var _tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	var W: float = min(vp.x * 0.75, 860.0)
	var H: float = vp.y * 0.7

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
	bg_style.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.95)
	bg_style.corner_radius_top_left = 12; bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12; bg_style.corner_radius_bottom_right = 12
	bg_style.border_width_left = 2; bg_style.border_width_right = 2
	bg_style.border_width_top = 2; bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.45, 0.35, 0.65, 0.5)
	_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg)

	var accent := ColorRect.new()
	accent.position = Vector2(2, 2)
	accent.size = Vector2(W - 4, 3)
	accent.color = PURPLE
	_bg.add_child(accent)

	_title_lbl = Label.new()
	_title_lbl.text = tr("SETTINGS_TITLE")
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 40)
	_title_lbl.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.95))
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_title_lbl.position = Vector2(0, 20)
	_title_lbl.size = Vector2(W, 50)
	_bg.add_child(_title_lbl)

	var line := ColorRect.new()
	line.position = Vector2(20, 68)
	line.size = Vector2(W - 40, 1)
	line.color = Color(0.40, 0.30, 0.60, 0.3)
	_bg.add_child(line)

	var tab_w: float = (W - 28 - 15.0) / 6.0
	var tab_names: Array[String] = ["SETTINGS_GENERAL", "SETTINGS_GRAPHICS", "SETTINGS_AUDIO", "SETTINGS_CONTROLS", "SETTINGS_MOBILE", "DEVICE_TAB"]
	for i in range(6):
		var btn := Button.new()
		btn.text = tr(tab_names[i])
		btn.position = Vector2(14 + i * (tab_w + 3), 72)
		btn.size = Vector2(tab_w, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.75))
		var tb_bg := StyleBoxFlat.new()
		tb_bg.corner_radius_top_left = 6; tb_bg.corner_radius_top_right = 6
		tb_bg.corner_radius_bottom_left = 6; tb_bg.corner_radius_bottom_right = 6
		tb_bg.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.7)
		tb_bg.border_width_left = 1; tb_bg.border_width_right = 1
		tb_bg.border_width_top = 1; tb_bg.border_width_bottom = 1
		tb_bg.border_color = Color(0.40, 0.30, 0.60, 0.4)
		btn.add_theme_stylebox_override("normal", tb_bg)
		var tb_hover := tb_bg.duplicate()
		tb_hover.bg_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.25)
		tb_hover.border_color = Color(0.55, 0.45, 0.82, 0.5)
		btn.add_theme_stylebox_override("hover", tb_hover)
		btn.pressed.connect(_on_tab.bind(i))
		_bg.add_child(btn)
		_tab_btns.append(btn)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(14, 120)
	_scroll.size = Vector2(W - 28, H - 190)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bg.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

	_close_btn = Button.new()
	_close_btn.position = Vector2(W * 0.5 - 100, H - 50)
	_close_btn.size = Vector2(200, 42)
	_close_btn.text = tr("CLOSE")
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.8))
	var close_bg := StyleBoxFlat.new()
	close_bg.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.8)
	close_bg.corner_radius_top_left = 6; close_bg.corner_radius_top_right = 6
	close_bg.corner_radius_bottom_left = 6; close_bg.corner_radius_bottom_right = 6
	close_bg.border_width_left = 1; close_bg.border_width_right = 1
	close_bg.border_width_top = 1; close_bg.border_width_bottom = 1
	close_bg.border_color = Color(0.40, 0.30, 0.60, 0.5)
	_close_btn.add_theme_stylebox_override("normal", close_bg)
	var close_hover := close_bg.duplicate()
	close_hover.bg_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.25)
	close_hover.border_color = Color(0.55, 0.45, 0.82, 0.5)
	_close_btn.add_theme_stylebox_override("hover", close_hover)
	_close_btn.pressed.connect(_on_close)
	_bg.add_child(_close_btn)

	_show_tab(Tab.GENERAL)

func _on_tab(tab: int) -> void:
	_current_tab = tab
	_show_tab(tab)

func _show_tab(tab: int) -> void:
	for ch in _content_vbox.get_children():
		ch.queue_free()

	for i in range(_tab_btns.size()):
		var tb_bg := _tab_btns[i].get_theme_stylebox("normal") as StyleBoxFlat
		if tb_bg:
			tb_bg.bg_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.25) if i == tab else Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.7)
			tb_bg.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.5) if i == tab else Color(0.40, 0.30, 0.60, 0.4)

	match tab:
		Tab.GENERAL: _build_general_tab()
		Tab.GRAPHICS: _build_graphics_tab()
		Tab.AUDIO: _build_audio_tab()
		Tab.CONTROLS: _build_controls_tab()
		Tab.MOBILE: _build_mobile_tab()
		Tab.DEVICE: _build_device_tab()

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.85))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(lbl)
	return lbl

func _build_general_tab() -> void:
	_section_label(tr("LANGUAGE"))
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)

	var vi_btn := Button.new()
	vi_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vi_btn.text = tr("VIETNAMESE")
	vi_btn.add_theme_font_size_override("font_size", 20)
	vi_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.85))
	var vi_bg := StyleBoxFlat.new()
	vi_bg.corner_radius_top_left = 6; vi_bg.corner_radius_top_right = 6
	vi_bg.corner_radius_bottom_left = 6; vi_bg.corner_radius_bottom_right = 6
	vi_bg.border_width_left = 2; vi_bg.border_width_right = 2
	vi_bg.border_width_top = 2; vi_bg.border_width_bottom = 2
	vi_bg.border_color = Color(0.15, 0.65, 0.15, 0.7)
	vi_btn.add_theme_stylebox_override("normal", vi_bg)
	vi_btn.add_theme_stylebox_override("hover", vi_bg)
	vi_btn.pressed.connect(_on_set_language.bind("vi"))
	hbox.add_child(vi_btn)

	var en_btn := Button.new()
	en_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en_btn.text = tr("ENGLISH")
	en_btn.add_theme_font_size_override("font_size", 20)
	en_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.85))
	var en_bg := StyleBoxFlat.new()
	en_bg.corner_radius_top_left = 6; en_bg.corner_radius_top_right = 6
	en_bg.corner_radius_bottom_left = 6; en_bg.corner_radius_bottom_right = 6
	en_bg.border_width_left = 2; en_bg.border_width_right = 2
	en_bg.border_width_top = 2; en_bg.border_width_bottom = 2
	en_bg.border_color = Color(0.35, 0.25, 0.65, 0.7)
	en_btn.add_theme_stylebox_override("normal", en_bg)
	en_btn.add_theme_stylebox_override("hover", en_bg)
	en_btn.pressed.connect(_on_set_language.bind("en"))
	hbox.add_child(en_btn)

	_refresh_lang_btns()

func _build_graphics_tab() -> void:
	_section_label(tr("GRAPHICS_PRESET"))
	var cur_preset: int = SettingsManager.graphics_preset if SettingsManager else 0
	var preset_data: Array[Dictionary] = [
		{ "label": tr("PRESET_STANDARD"), "mode": 0, "col": Color(TEAL.r, TEAL.g, TEAL.b, 0.75) },
		{ "label": tr("PRESET_ENHANCED"), "mode": 1, "col": Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.75) },
		{ "label": tr("PRESET_REALISTIC"), "mode": 2, "col": Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.75) },
	]
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)
	for i in range(3):
		var d: Dictionary = preset_data[i]
		var btn := Button.new()
		btn.text = d["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
		var sty := StyleBoxFlat.new()
		if cur_preset == d["mode"]:
			sty.bg_color = d["col"]
			sty.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.45)
		else:
			sty.bg_color = Color(d["col"].r * 0.35, d["col"].g * 0.35, d["col"].b * 0.35, 0.55)
			sty.border_color = Color(0.35, 0.28, 0.50, 0.25)
		sty.corner_radius_top_left = 6; sty.corner_radius_top_right = 6
		sty.corner_radius_bottom_left = 6; sty.corner_radius_bottom_right = 6
		sty.border_width_left = 2; sty.border_width_right = 2
		sty.border_width_top = 2; sty.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", sty)
		var sty_h := sty.duplicate()
		sty_h.bg_color = d["col"]
		sty_h.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.55)
		btn.add_theme_stylebox_override("hover", sty_h)
		var mode_val: int = d["mode"]
		btn.pressed.connect(func():
			if SettingsManager:
				SettingsManager.set_graphics_preset(mode_val)
			_show_tab(Tab.GRAPHICS)
		)
		hbox.add_child(btn)

	var preset_names: Array[String] = [tr("PRESET_DESC_STANDARD"), tr("PRESET_DESC_ENHANCED"), tr("PRESET_DESC_REALISTIC")]
	var desc := Label.new()
	desc.text = preset_names[cur_preset] if cur_preset < preset_names.size() else ""
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.70))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(desc)

	_section_label(tr("DISPLAY"))
	_add_toggle(tr("FULLSCREEN"), _is_fullscreen(), func(v): _set_fullscreen(v))
	_add_toggle(tr("VSYNC"), _is_vsync(), func(v): _set_vsync(v))

	_section_label(tr("FRAMERATE"))
	var cur_fps: int = SettingsManager.framerate_limit if SettingsManager else 0
	var fps_data: Array[Dictionary] = [
		{ "label": "60", "mode": 0, "col": Color(TEAL.r, TEAL.g, TEAL.b, 0.75) },
		{ "label": "120", "mode": 1, "col": Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.75) },
		{ "label": tr("FPS_UNLIMITED"), "mode": 2, "col": Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.75) },
	]
	var fps_hbox := HBoxContainer.new()
	fps_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(fps_hbox)
	for i in range(3):
		var d: Dictionary = fps_data[i]
		var btn := Button.new()
		btn.text = d["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
		var sty := StyleBoxFlat.new()
		if cur_fps == d["mode"]:
			sty.bg_color = d["col"]
			sty.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.45)
		else:
			sty.bg_color = Color(d["col"].r * 0.35, d["col"].g * 0.35, d["col"].b * 0.35, 0.55)
			sty.border_color = Color(0.35, 0.28, 0.50, 0.25)
		sty.corner_radius_top_left = 6; sty.corner_radius_top_right = 6
		sty.corner_radius_bottom_left = 6; sty.corner_radius_bottom_right = 6
		sty.border_width_left = 2; sty.border_width_right = 2
		sty.border_width_top = 2; sty.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", sty)
		var sty_h := sty.duplicate()
		sty_h.bg_color = d["col"]
		sty_h.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.55)
		btn.add_theme_stylebox_override("hover", sty_h)
		var mode_val: int = d["mode"]
		btn.pressed.connect(func():
			_set_framerate(mode_val)
			_show_tab(Tab.GRAPHICS)
		)
		fps_hbox.add_child(btn)

func _build_audio_tab() -> void:
	_section_label(tr("MASTER_VOLUME"))
	_add_slider(_get_master_volume(), func(v): _set_master_volume(v))
	_section_label(tr("MUSIC_VOLUME"))
	_add_slider(_get_music_volume(), func(v): _set_music_volume(v))
	_section_label(tr("SFX_VOLUME"))
	_add_slider(_get_sfx_volume(), func(v): _set_sfx_volume(v))

func _build_controls_tab() -> void:
	_section_label(tr("MOUSE_SENSITIVITY"))
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.1; slider.max_value = 5.0; slider.step = 0.05
	slider.value = _get_mouse_sensitivity()
	slider.value_changed.connect(_set_mouse_sensitivity)
	hbox.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	val_lbl.text = str(snapped(slider.value, 0.1))
	slider.value_changed.connect(func(v): val_lbl.text = str(snapped(v, 0.1)))
	hbox.add_child(val_lbl)

	_add_toggle(tr("INVERT_Y"), _is_invert_y(), func(v): _set_invert_y(v))

	_content_vbox.add_spacer(false)
	_section_label(tr("KEY_BINDINGS"))

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
		_content_vbox.add_child(row)
		var lbl := Label.new()
		lbl.text = entry.action
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.8))
		row.add_child(lbl)
		var key_btn := Button.new()
		key_btn.text = _keycode_name(_get_keybinding(entry.key, entry.default))
		key_btn.add_theme_font_size_override("font_size", 20)
		key_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.85))
		var kb_bg := StyleBoxFlat.new()
		kb_bg.corner_radius_top_left = 4; kb_bg.corner_radius_top_right = 4
		kb_bg.corner_radius_bottom_left = 4; kb_bg.corner_radius_bottom_right = 4
		kb_bg.border_width_left = 1; kb_bg.border_width_right = 1
		kb_bg.border_width_top = 1; kb_bg.border_width_bottom = 1
		kb_bg.border_color = Color(0.40, 0.30, 0.60, 0.4)
		kb_bg.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.7)
		key_btn.add_theme_stylebox_override("normal", kb_bg)
		key_btn.pressed.connect(_start_rebind.bind(entry.key, entry.default, key_btn))
		key_btn.custom_minimum_size = Vector2(120, 0)
		row.add_child(key_btn)

func _add_toggle(label: String, initial: bool, cb: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.8))
	hbox.add_child(lbl)
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.text = tr("ON") if initial else tr("OFF")
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.8))
	var btn_bg := StyleBoxFlat.new()
	btn_bg.corner_radius_top_left = 4; btn_bg.corner_radius_top_right = 4
	btn_bg.corner_radius_bottom_left = 4; btn_bg.corner_radius_bottom_right = 4
	btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
	btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
	btn_bg.border_color = Color(0.40, 0.30, 0.60, 0.4)
	btn.add_theme_stylebox_override("normal", btn_bg)
	btn.toggled.connect(func(toggled: bool):
		btn.text = tr("ON") if toggled else tr("OFF")
		cb.call(toggled)
	)
	btn.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(btn)

func _add_slider(initial: float, cb: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0; slider.max_value = 100.0; slider.step = 1.0
	slider.value = initial
	slider.value_changed.connect(cb)
	hbox.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	val_lbl.text = "%d%%" % initial
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % v)
	hbox.add_child(val_lbl)

# ── Settings storage (delegates to shared module) ──────────────────────────

func _is_fullscreen() -> bool: return _Settings.is_fullscreen()
func _set_fullscreen(v: bool) -> void: _Settings.set_fullscreen(v)
func _is_vsync() -> bool: return _Settings.is_vsync()
func _set_vsync(v: bool) -> void: _Settings.set_vsync(v)
func _set_framerate(mode: int) -> void: _Settings.set_framerate(mode)
func _get_master_volume() -> float: return _Settings.get_master_volume()
func _set_master_volume(v: float) -> void: _Settings.set_master_volume(v)
func _get_music_volume() -> float: return _Settings.get_music_volume()
func _set_music_volume(v: float) -> void: _Settings.set_music_volume(v)
func _get_sfx_volume() -> float: return _Settings.get_sfx_volume()
func _set_sfx_volume(v: float) -> void: _Settings.set_sfx_volume(v)
func _get_mouse_sensitivity() -> float: return _Settings.get_mouse_sensitivity()
func _set_mouse_sensitivity(v: float) -> void: _Settings.set_mouse_sensitivity(v)
func _is_invert_y() -> bool: return _Settings.is_invert_y()
func _set_invert_y(v: bool) -> void: _Settings.set_invert_y(v)

# ── Language ─────────────────────────────────────────────────────────────────

func _refresh_lang_btns() -> void:
	var cur: String = TranslationServer.get_locale()
	for child in _content_vbox.get_children():
		if child is HBoxContainer:
			for btn in child.get_children():
				if btn is Button:
					var b := btn as Button
					var bg := b.get_theme_stylebox("normal") as StyleBoxFlat
					if bg:
						var is_vi: bool = b.text == tr("VIETNAMESE")
						var is_en: bool = b.text == tr("ENGLISH")
						if is_vi or is_en:
							var is_active: bool = (cur == "vi" and is_vi) or (cur == "en" and is_en)
							bg.border_color = Color(0.2, 0.8, 0.2, 0.9) if is_active else Color(0.30, 0.20, 0.55, 0.6)
							bg.bg_color = Color(0.08, 0.30, 0.08, 0.6) if is_active else Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.6)

func _on_set_language(locale: String) -> void: _Settings.set_locale(locale)

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
	_show_tab(_current_tab)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_play_appear()

func hide_settings() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_disappear()

func _build_mobile_tab() -> void:
	_section_label(tr("TOUCH_CONTROLS"))
	_add_toggle(tr("TOUCH_ENABLED"), _is_touch_enabled(), func(v): _set_touch_enabled(v))
	_section_label(tr("JOYSTICK"))
	_add_slider(_get_joystick_sensitivity(), func(v): _set_joystick_sensitivity(v))
	_section_label(tr("BUTTON_SIZE"))
	_add_slider(_get_button_scale(), func(v): _set_button_scale(v))

# ── Mobile settings ──────────────────────────────────────────────────────────

func _is_touch_enabled() -> bool: return _Settings.is_touch_enabled()
func _set_touch_enabled(v: bool) -> void: _Settings.set_touch_enabled(v)
func _get_joystick_sensitivity() -> float: return _Settings.get_joystick_sensitivity()
func _set_joystick_sensitivity(v: float) -> void: _Settings.set_joystick_sensitivity(v)
func _get_button_scale() -> float: return _Settings.get_button_scale()
func _set_button_scale(v: float) -> void: _Settings.set_button_scale(v)

# ── Key bindings ─────────────────────────────────────────────────────────────

func _get_keybinding(key: String, default_key: int) -> int: return _Settings.get_keybinding(key, default_key)

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
			var conflict: String = ""
			for existing in SettingsManager.key_bindings:
				if SettingsManager.key_bindings[existing] == k.keycode and existing != _rebinding_action:
					conflict = existing
					break
			if not conflict.is_empty():
				_rebinding_btn.text = _keycode_name(k.keycode) + " *"
				await get_tree().create_timer(0.8).timeout
				if _rebinding_btn and is_instance_valid(_rebinding_btn):
					_rebinding_btn.text = "..."
				return
			ProjectSettings.set_setting(_rebinding_action, k.keycode)
			SettingsManager.key_bindings[_rebinding_action] = k.keycode
			SettingsData.save_settings()
			_rebinding_btn.text = _keycode_name(k.keycode)
			_rebinding_btn.disabled = false
			_rebinding_action = ""
			_rebinding_btn = null

func _cancel_rebind() -> void:
	if _rebinding_btn and is_instance_valid(_rebinding_btn):
		var def: int = SettingsManager.key_bindings.get(_rebinding_action, KEY_F)
		_rebinding_btn.text = _keycode_name(ProjectSettings.get_setting(_rebinding_action, def))
		_rebinding_btn.disabled = false
		_rebinding_btn = null
		_rebinding_action = ""

# ── Device Tab ────────────────────────────────────────────────────────────────
func _build_device_tab() -> void:
	_section_label(tr("DEVICE_TYPE"))
	var desc := Label.new()
	desc.text = tr("DEVICE_DESC")
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.70))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(desc)

	var cur_device: int = DeviceManager.get_device() if DeviceManager else 0
	var btn_data: Array[Dictionary] = [
		{ "label": tr("DEVICE_AUTO"), "mode": 0, "col": Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.75) },
		{ "label": "💻  " + tr("DEVICE_PC"),   "mode": 1, "col": Color(TEAL.r, TEAL.g, TEAL.b, 0.75) },
		{ "label": "📱  " + tr("DEVICE_MOBILE"), "mode": 2, "col": Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.75) },
	]
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(hbox)
	for i in range(3):
		var d: Dictionary = btn_data[i]
		var btn := Button.new()
		btn.text = d["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
		var sty := StyleBoxFlat.new()
		sty.bg_color = d["col"] if cur_device == d["mode"] else Color(d["col"].r * 0.4, d["col"].g * 0.4, d["col"].b * 0.4, 0.55)
		sty.corner_radius_top_left = 8; sty.corner_radius_top_right = 8
		sty.corner_radius_bottom_left = 8; sty.corner_radius_bottom_right = 8
		sty.border_width_left = 2; sty.border_width_right = 2
		sty.border_width_top = 2; sty.border_width_bottom = 2
		sty.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.30) if cur_device == d["mode"] else Color(0.35, 0.28, 0.50, 0.20)
		btn.add_theme_stylebox_override("normal", sty)
		var sty_h := sty.duplicate() as StyleBoxFlat
		sty_h.bg_color = d["col"]
		sty_h.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.55)
		btn.add_theme_stylebox_override("hover", sty_h)
		var mode_val: int = d["mode"]
		btn.pressed.connect(func():
			if DeviceManager: DeviceManager.set_device(mode_val)
			SettingsManager.device_mode = mode_val
			SettingsData.save_settings()
			_show_tab(Tab.DEVICE)
		)
		btn.custom_minimum_size = Vector2(0, 70)
		hbox.add_child(btn)

	var status_lbl := Label.new()
	var is_mob: bool = DeviceManager.is_mobile() if DeviceManager else false
	var detected: String = tr("DEVICE_MOBILE") if DeviceManager._detect_mobile() else tr("DEVICE_PC")
	status_lbl.text = tr("DEVICE_CURRENT") % [tr("DEVICE_MOBILE") if is_mob else tr("DEVICE_PC"), detected]
	status_lbl.add_theme_font_size_override("font_size", 18)
	status_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.70, 0.85))
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(status_lbl)

	var div := ColorRect.new()
	div.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.20)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	div.custom_minimum_size = Vector2(0, 1)
	_content_vbox.add_child(div)

	if is_mob:
		_section_label("📱 " + tr("MOBILE_FEATURES"))
		var features: Array[String] = ["✓  " + tr("FEAT_JOYSTICK"), "✓  " + tr("FEAT_CAM_DRAG"), "✓  " + tr("FEAT_TOUCH_BTNS"), "✓  " + tr("FEAT_CHUNK_LOW")]
		for ft in features:
			var fl := Label.new()
			fl.text = ft
			fl.add_theme_font_size_override("font_size", 18)
			fl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.65, 0.80))
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content_vbox.add_child(fl)
	else:
		_section_label("💻 " + tr("PC_FEATURES"))
		var features: Array[String] = ["✓  " + tr("FEAT_WASD"), "✓  " + tr("FEAT_MOUSE_CAM"), "✓  " + tr("FEAT_KEYBOARD"), "✓  " + tr("FEAT_CHUNK_HIGH")]
		for ft in features:
			var fl := Label.new()
			fl.text = ft
			fl.add_theme_font_size_override("font_size", 18)
			fl.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.80))
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content_vbox.add_child(fl)
