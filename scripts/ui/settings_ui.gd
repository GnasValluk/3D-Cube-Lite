## ui/settings_ui.gd
## Màn hình Cài đặt — ấn ESC hoặc icon góc trên trái để mở.

extends Control
class_name SettingsUI

var _vi_btn: Button
var _en_btn: Button
var _close_btn: Button
var _title_lbl: Label
var _lang_lbl: Label

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
	var W: float = 480.0
	var H: float = 360.0

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	add_child(overlay)

	var bg := Panel.new()
	bg.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	bg.size = Vector2(W, H)
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
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	_title_lbl = Label.new()
	_title_lbl.text = tr("SETTINGS_TITLE")
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 26)
	_title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_title_lbl.position = Vector2(0, 18)
	_title_lbl.size = Vector2(W, 36)
	bg.add_child(_title_lbl)

	var line := ColorRect.new()
	line.position = Vector2(40, 58)
	line.size = Vector2(W - 80, 2)
	line.color = Color(0.3, 0.3, 0.5, 0.4)
	bg.add_child(line)

	_lang_lbl = Label.new()
	_lang_lbl.text = tr("LANGUAGE")
	_lang_lbl.add_theme_font_size_override("font_size", 15)
	_lang_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	_lang_lbl.position = Vector2(60, 80)
	_lang_lbl.size = Vector2(360, 24)
	bg.add_child(_lang_lbl)

	_vi_btn = Button.new()
	_vi_btn.position = Vector2(60, 116)
	_vi_btn.size = Vector2(168, 44)
	_vi_btn.text = tr("VIETNAMESE")
	_vi_btn.add_theme_font_size_override("font_size", 15)
	_vi_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_vi_btn.pressed.connect(_on_set_language.bind("vi"))
	var vi_bg := StyleBoxFlat.new()
	vi_bg.corner_radius_top_left = 6; vi_bg.corner_radius_top_right = 6
	vi_bg.corner_radius_bottom_left = 6; vi_bg.corner_radius_bottom_right = 6
	vi_bg.border_width_left = 2; vi_bg.border_width_right = 2
	vi_bg.border_width_top = 2; vi_bg.border_width_bottom = 2
	vi_bg.border_color = Color(0.2, 0.5, 0.2, 0.7)
	_vi_btn.add_theme_stylebox_override("normal", vi_bg)
	_vi_btn.add_theme_stylebox_override("hover", vi_bg)
	bg.add_child(_vi_btn)

	_en_btn = Button.new()
	_en_btn.position = Vector2(252, 116)
	_en_btn.size = Vector2(168, 44)
	_en_btn.text = tr("ENGLISH")
	_en_btn.add_theme_font_size_override("font_size", 15)
	_en_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_en_btn.pressed.connect(_on_set_language.bind("en"))
	var en_bg := StyleBoxFlat.new()
	en_bg.corner_radius_top_left = 6; en_bg.corner_radius_top_right = 6
	en_bg.corner_radius_bottom_left = 6; en_bg.corner_radius_bottom_right = 6
	en_bg.border_width_left = 2; en_bg.border_width_right = 2
	en_bg.border_width_top = 2; en_bg.border_width_bottom = 2
	en_bg.border_color = Color(0.2, 0.2, 0.5, 0.7)
	_en_btn.add_theme_stylebox_override("normal", en_bg)
	_en_btn.add_theme_stylebox_override("hover", en_bg)
	bg.add_child(_en_btn)

	_close_btn = Button.new()
	_close_btn.position = Vector2(120, 200)
	_close_btn.size = Vector2(240, 44)
	_close_btn.text = tr("CLOSE")
	_close_btn.add_theme_font_size_override("font_size", 15)
	_close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var close_bg := StyleBoxFlat.new()
	close_bg.bg_color = Color(0.12, 0.12, 0.22, 0.9)
	close_bg.corner_radius_top_left = 6; close_bg.corner_radius_top_right = 6
	close_bg.corner_radius_bottom_left = 6; close_bg.corner_radius_bottom_right = 6
	close_bg.border_width_left = 1; close_bg.border_width_right = 1
	close_bg.border_width_top = 1; close_bg.border_width_bottom = 1
	close_bg.border_color = Color(0.3, 0.3, 0.5, 0.6)
	_close_btn.add_theme_stylebox_override("normal", close_bg)
	_close_btn.add_theme_stylebox_override("hover", close_bg)
	_close_btn.pressed.connect(_on_close)
	bg.add_child(_close_btn)

	_refresh_lang_btns()

func _refresh_lang_btns() -> void:
	var cur: String = TranslationServer.get_locale()
	var vi_bg = _vi_btn.get_theme_stylebox("normal")
	var en_bg = _en_btn.get_theme_stylebox("normal")
	if vi_bg and en_bg:
		var active := Color(0.3, 0.75, 0.3, 0.9)
		var inactive := Color(0.2, 0.2, 0.4, 0.6)
		vi_bg.border_color = active if cur == "vi" else inactive
		vi_bg.bg_color = Color(0.1, 0.25, 0.1, 0.6) if cur == "vi" else Color(0.08, 0.08, 0.15, 0.6)
		en_bg.border_color = active if cur == "en" else inactive
		en_bg.bg_color = Color(0.1, 0.1, 0.25, 0.6) if cur == "en" else Color(0.08, 0.08, 0.15, 0.6)

func _on_set_language(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_refresh_lang_btns()
	_rebuild_texts()

func _rebuild_texts() -> void:
	_title_lbl.text = tr("SETTINGS_TITLE")
	_lang_lbl.text = tr("LANGUAGE")
	_vi_btn.text = tr("VIETNAMESE")
	_en_btn.text = tr("ENGLISH")
	_close_btn.text = tr("CLOSE")

func _on_close() -> void:
	hide_settings()

func show_settings() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func hide_settings() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
