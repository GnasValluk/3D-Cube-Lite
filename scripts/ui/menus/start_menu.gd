extends Control

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.55, 0.35, 0.90)
const TEAL := Color(0.15, 0.72, 0.68)
const PINK := Color(0.82, 0.28, 0.52)
const ORANGE := Color(0.92, 0.52, 0.12)
const CYAN := Color(0.15, 0.62, 0.92)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

var _new_journey_ui: Control  = null
var _journey_list_ui: Control = null
var _settings_ui: Control     = null
var _about_ui: Control        = null
var _new_btn: Button
var _list_btn: Button
var _set_btn: Button
var _about_btn: Button
var _quit_btn: Button

func _ready() -> void:
	_setup_ui()

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

func _setup_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	# ── Background ────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = BG_DEEP
	bg.size = vp
	add_child(bg)

	var grid := ColorRect.new()
	grid.color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.35)
	grid.size = vp
	grid.material = _make_grid_mat(vp)
	add_child(grid)

	# ── Tiêu đề game ──────────────────────────────────────────────────────────
	var title_block := Control.new()
	title_block.position = Vector2(0, cy - 280)
	title_block.size = Vector2(vp.x, 140)
	add_child(title_block)

	var title_main := Label.new()
	title_main.text = "Tila'Adventure"
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main.add_theme_font_size_override("font_size", 96)
	title_main.add_theme_color_override("font_color", PURPLE)
	title_main.add_theme_color_override("font_shadow_color", Color(0.35, 0.20, 0.55, 0.7))
	title_main.add_theme_constant_override("shadow_offset_x", 3)
	title_main.add_theme_constant_override("shadow_offset_y", 4)
	title_main.size = Vector2(vp.x, 80)
	title_main.position = Vector2(0, 0)
	title_block.add_child(title_main)

	var title_sub := Label.new()
	title_sub.visible = false
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.add_theme_font_size_override("font_size", 34)
	title_sub.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.80))
	title_sub.add_theme_color_override("font_shadow_color", Color(0.20, 0.10, 0.35, 0.5))
	title_sub.add_theme_constant_override("shadow_offset_x", 1)
	title_sub.add_theme_constant_override("shadow_offset_y", 2)
	title_sub.size = Vector2(vp.x, 30)
	title_sub.position = Vector2(0, 100)
	title_block.add_child(title_sub)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.18)
	div.size = Vector2(280, 1)
	div.position = Vector2(cx - 140, cy - 130)
	add_child(div)

	# ── Nút menu chính ────────────────────────────────────────────────────────
	var btn_w: float = 400.0
	var btn_h: float = 72.0
	var btn_gap: float = 18.0
	var btn_x: float = cx - btn_w * 0.5
	var btn_y: float = cy - 112.0

	# 1. New Journey
	_new_btn = _make_button(tr("NEW_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.14), Color(TEAL.r, TEAL.g, TEAL.b, 0.28),
		Color(TEAL.r, TEAL.g, TEAL.b, 0.35))
	_new_btn.pressed.connect(_on_new_journey)
	add_child(_new_btn)
	btn_y += btn_h + btn_gap

	# 2. Journey List
	_list_btn = _make_button(tr("CONTINUE_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(0.40, 0.30, 0.55, 0.10), Color(0.40, 0.30, 0.55, 0.22),
		Color(0.40, 0.30, 0.55, 0.30))
	_list_btn.pressed.connect(_on_journey_list)
	add_child(_list_btn)
	btn_y += btn_h + btn_gap

	# 3. Settings
	_set_btn = _make_button(tr("SETTINGS_TITLE"), btn_x, btn_y, btn_w, btn_h,
		Color(0.40, 0.30, 0.55, 0.10), Color(0.40, 0.30, 0.55, 0.22),
		Color(0.40, 0.30, 0.55, 0.30))
	_set_btn.pressed.connect(_on_settings)
	add_child(_set_btn)
	btn_y += btn_h + btn_gap

	# 4. About Us
	_about_btn = _make_button(tr("ABOUT_US"), btn_x, btn_y, btn_w, btn_h,
		Color(0.40, 0.30, 0.55, 0.10), Color(0.40, 0.30, 0.55, 0.22),
		Color(0.40, 0.30, 0.55, 0.30))
	_about_btn.pressed.connect(_on_about)
	add_child(_about_btn)
	btn_y += btn_h + btn_gap + 4

	# ── Separator trước Exit ──────────────────────────────────────────────────
	var sep2 := ColorRect.new()
	sep2.color = Color(0.35, 0.28, 0.50, 0.12)
	sep2.size = Vector2(btn_w, 1)
	sep2.position = Vector2(btn_x, btn_y)
	add_child(sep2)
	btn_y += 18

	# 5. Exit
	_quit_btn = _make_button(tr("QUIT_GAME"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 0.35, 0.20, 0.08), Color(1.0, 0.35, 0.20, 0.18),
		Color(1.0, 0.35, 0.20, 0.28))
	_quit_btn.pressed.connect(_on_quit)
	add_child(_quit_btn)

	# ── Version label ─────────────────────────────────────────────────────────
	var ver_lbl := Label.new()
	ver_lbl.text = "v0.1.0"
	ver_lbl.add_theme_font_size_override("font_size", 16)
	ver_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	ver_lbl.position = Vector2(vp.x - 60, vp.y - 32)
	ver_lbl.size = Vector2(60, 24)
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver_lbl)

# ── Button factory ────────────────────────────────────────────────────────────
func _make_button(text: String, x: float, y: float, w: float, h: float,
		normal_color: Color, hover_color: Color, pressed_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
	btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)

	var sty := StyleBoxFlat.new()
	sty.bg_color = normal_color
	sty.corner_radius_top_left    = 8
	sty.corner_radius_top_right   = 8
	sty.corner_radius_bottom_left = 8
	sty.corner_radius_bottom_right = 8
	sty.border_width_left   = 1
	sty.border_width_right  = 1
	sty.border_width_top    = 1
	sty.border_width_bottom = 1
	sty.border_color = Color(0.35, 0.28, 0.50, 0.20)
	btn.add_theme_stylebox_override("normal", sty)

	var sty_h := sty.duplicate()
	sty_h.bg_color = hover_color
	sty_h.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.30)
	btn.add_theme_stylebox_override("hover", sty_h)

	var sty_p := sty.duplicate()
	sty_p.bg_color = pressed_color
	sty_p.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.50)
	btn.add_theme_stylebox_override("pressed", sty_p)

	return btn

# ── Grid background ───────────────────────────────────────────────────────────
func _make_grid_mat(vp: Vector2) -> Material:
	var m := ShaderMaterial.new()
	m.shader = _grid_shader()
	m.set_shader_parameter("vp", vp)
	return m

static func _grid_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform vec2 vp;
void fragment() {
	vec2 uv = FRAGCOORD.xy / vp;
	vec2 g = fract(uv * 28.0);
	float l = min(g.x, g.y);
	float a = smoothstep(0.05, 0.02, l) * 0.12;
	COLOR = vec4(0.40, 0.25, 0.70, a);
}
"""
	return s

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
