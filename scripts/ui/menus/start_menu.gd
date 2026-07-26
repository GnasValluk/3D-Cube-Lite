extends Control

const PURPLE := Color(0.22, 0.62, 0.28)
const TEAL := Color(0.12, 0.52, 0.32)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)

var _new_journey_ui: Control  = null
var _journey_list_ui: Control = null
var _settings_ui: Control     = null
var _about_ui: Control        = null
var _new_btn: Button
var _list_btn: Button
var _set_btn: Button
var _about_btn: Button
var _quit_btn: Button

var _panel: Panel
var _panel_w: float = 520.0
var _panel_h: float = 560.0
var _panel_base_pos: Vector2
var _mouse_offset: Vector2

func _ready() -> void:
	_setup_ui()

func _process(_delta: float) -> void:
	if not _panel: return
	var vp := get_viewport().get_visible_rect().size
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var mx: float = get_global_mouse_position().x
	var my: float = get_global_mouse_position().y
	var dx: float = (mx - cx) / cx
	var dy: float = (my - cy) / cy
	_mouse_offset = _mouse_offset.lerp(Vector2(dx * 18.0, dy * 12.0), 0.08)
	_panel.position = _panel_base_pos + _mouse_offset

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	if not _new_btn: return
	_new_btn.text = tr("NEW_JOURNEY")
	_list_btn.text = tr("CONTINUE_JOURNEY")
	_set_btn.text = tr("SETTINGS_TITLE")
	_about_btn.text = tr("ABOUT_US")
	_quit_btn.text = tr("QUIT_GAME")

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

func _make_style(bg: Color, radius: float, border_w: float = 0, border_c: Color = Color(0,0,0,0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	if border_w > 0:
		s.set_border_width_all(int(border_w))
		s.border_color = border_c
	return s

func _setup_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	# ── Background ─────────────────────────────────────────────────────────────
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/bg/bgbeta.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = vp
	add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.40)
	overlay.size = vp
	add_child(overlay)

	# ── Center panel ───────────────────────────────────────────────────────────
	var px: float = (vp.x - _panel_w) * 0.5
	var py: float = (vp.y - _panel_h) * 0.5

	_panel = Panel.new()
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(_panel_w, _panel_h)
	_panel_base_pos = Vector2(px, py)
	_panel.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.04, 0.08, 0.92), 28, 2, Color(0.55, 0.57, 0.62, 0.35)))
	add_child(_panel)

	var deco := CatDecoControl.new()
	deco.panel_ref = _panel
	deco.panel_w = _panel_w
	deco.panel_h = _panel_h
	deco.size = vp
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deco)

	var content := Control.new()
	content.position = Vector2(30, 30)
	content.size = Vector2(_panel_w - 60, _panel_h - 60)
	_panel.add_child(content)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Tila'Adventure"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", PURPLE)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.35, 0.20, 0.55, 0.5))
	title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	title_lbl.size = Vector2(content.size.x, 56)
	title_lbl.position = Vector2(0, 20)
	content.add_child(title_lbl)

	# Version
	var sub_lbl := Label.new()
	sub_lbl.text = "v0.1.0"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", TEXT_DIM)
	sub_lbl.size = Vector2(content.size.x, 22)
	sub_lbl.position = Vector2(0, 78)
	content.add_child(sub_lbl)

	# Divider
	var div := ColorRect.new()
	div.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.10)
	div.size = Vector2(200, 1)
	div.position = Vector2((content.size.x - 200) * 0.5, 118)
	content.add_child(div)

	# ── Buttons ────────────────────────────────────────────────────────────────
	var btn_w: float = content.size.x - 20
	var btn_h: float = 58.0
	var btn_gap: float = 12.0
	var btn_x: float = (content.size.x - btn_w) * 0.5
	var btn_y: float = 150.0

	_new_btn = _make_button(tr("NEW_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.12), Color(TEAL.r, TEAL.g, TEAL.b, 0.25),
		Color(TEAL.r, TEAL.g, TEAL.b, 0.35))
	_new_btn.pressed.connect(_on_new_journey)
	content.add_child(_new_btn)
	btn_y += btn_h + btn_gap

	_list_btn = _make_button(tr("CONTINUE_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(0.15, 0.40, 0.18, 0.08), Color(0.15, 0.40, 0.18, 0.20),
		Color(0.15, 0.40, 0.18, 0.28))
	_list_btn.pressed.connect(_on_journey_list)
	content.add_child(_list_btn)
	btn_y += btn_h + btn_gap

	_set_btn = _make_button(tr("SETTINGS_TITLE"), btn_x, btn_y, btn_w, btn_h,
		Color(0.15, 0.40, 0.18, 0.08), Color(0.15, 0.40, 0.18, 0.20),
		Color(0.15, 0.40, 0.18, 0.28))
	_set_btn.pressed.connect(_on_settings)
	content.add_child(_set_btn)
	btn_y += btn_h + btn_gap

	_about_btn = _make_button(tr("ABOUT_US"), btn_x, btn_y, btn_w, btn_h,
		Color(0.15, 0.40, 0.18, 0.08), Color(0.15, 0.40, 0.18, 0.20),
		Color(0.15, 0.40, 0.18, 0.28))
	_about_btn.pressed.connect(_on_about)
	content.add_child(_about_btn)
	btn_y += btn_h + btn_gap + 6

	# Separator before quit
	var sep := ColorRect.new()
	sep.color = Color(0.12, 0.35, 0.15, 0.10)
	sep.size = Vector2(btn_w, 1)
	sep.position = Vector2(btn_x, btn_y)
	content.add_child(sep)
	btn_y += 20

	_quit_btn = _make_button(tr("QUIT_GAME"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 0.35, 0.20, 0.06), Color(1.0, 0.35, 0.20, 0.15),
		Color(1.0, 0.35, 0.20, 0.22))
	_quit_btn.pressed.connect(_on_quit)
	content.add_child(_quit_btn)

func _make_button(text: String, x: float, y: float, w: float, h: float,
		normal_color: Color, hover_color: Color, pressed_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.85))
	btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)
	btn.add_theme_stylebox_override("normal", _make_style(normal_color, 10, 1, Color(0.12, 0.35, 0.15, 0.15)))
	btn.add_theme_stylebox_override("hover", _make_style(hover_color, 10, 1, Color(TEAL.r, TEAL.g, TEAL.b, 0.25)))
	btn.add_theme_stylebox_override("pressed", _make_style(pressed_color, 10, 1, Color(TEAL.r, TEAL.g, TEAL.b, 0.40)))
	return btn

# ── Handlers ──────────────────────────────────────────────────────────────────
func _on_new_journey() -> void:
	if _new_journey_ui == null:
		_new_journey_ui = preload("res://scripts/ui/menus/new_journey_ui.gd").new()
		add_child(_new_journey_ui)
	_new_journey_ui.visible = true
	_new_journey_ui.setup()

func _on_journey_list() -> void:
	if _journey_list_ui == null:
		_journey_list_ui = preload("res://scripts/ui/menus/journey_list_ui.gd").new()
		add_child(_journey_list_ui)
	(_journey_list_ui as Control).call("open")

func _on_settings() -> void:
	if _settings_ui == null:
		_settings_ui = preload("res://scripts/ui/menus/settings_ui.gd").new()
		add_child(_settings_ui)
	(_settings_ui as SettingsUI).show_settings()

func _on_about() -> void:
	if _about_ui == null:
		_about_ui = preload("res://scripts/ui/menus/about_us_ui.gd").new()
		add_child(_about_ui)
	_about_ui.visible = true

func _on_quit() -> void:
	get_tree().quit()

# ── Cat decoration (ears + eyes, drawn on top of everything) ──────────────────
class CatDecoControl:
	extends Control

	var panel_ref: Panel
	var panel_w: float
	var panel_h: float
	var _mouse: Vector2

	func _process(_delta: float) -> void:
		_mouse = get_global_mouse_position()
		queue_redraw()

	func _draw() -> void:
		if not panel_ref: return
		var p := panel_ref.position

		# ── Ears ──
		var ew: float = 50.0
		var eh: float = 44.0
		var ex1: float = p.x + panel_w * 0.5 - 175.0
		var ex2: float = p.x + panel_w * 0.5 + 175.0
		var ear_col := Color(0.04, 0.04, 0.08, 0.92)
		var inner_col := Color(0.10, 0.07, 0.18, 0.55)

		for cx in [ex1, ex2]:
			draw_polygon(PackedVector2Array([
				Vector2(cx, p.y),
				Vector2(cx + ew * 0.5, p.y - eh),
				Vector2(cx + ew, p.y),
			]), [ear_col])

			var iw: float = ew * 0.55
			var ih: float = eh * 0.6
			draw_polygon(PackedVector2Array([
				Vector2(cx + (ew - iw) * 0.5, p.y - 1),
				Vector2(cx + ew * 0.5, p.y - ih),
				Vector2(cx + ew - (ew - iw) * 0.5, p.y - 1),
			]), [inner_col])

		# ── Eyes ──
		var ey: float = p.y + 22.0
		var cx: float = p.x + panel_w * 0.5
		var sp: float = 100.0

		for side in [-1.0, 1.0]:
			var ex: float = cx + side * sp * 0.5
			var ec := Vector2(ex, ey)

			draw_set_transform(ec, 0.0, Vector2(1.5, 1.0))
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.95))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			var d: Vector2 = _mouse - ec
			var dist: float = d.length()
			var md: float = 6.0
			var pupil: Vector2
			if dist < 0.01:
				pupil = Vector2.ZERO
			else:
				pupil = d / dist * min(dist, md)

			draw_circle(ec + pupil, 8.0, Color(0.15, 0.45, 0.18, 0.9))
			draw_circle(ec + pupil, 5.0, Color(0, 0, 0, 1))
			draw_circle(ec + pupil + Vector2(-2.5, -2.5), 2.5, Color(1, 1, 1, 0.7))
