extends Control

var _new_journey_ui: Control  = null
var _journey_list_ui: Control = null
var _settings_ui: Control     = null
var _about_ui: Control        = null

func _ready() -> void:
	_load_translations()
	_setup_ui()

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
	bg.color = Color(0.06, 0.07, 0.12)
	bg.size = vp
	add_child(bg)

	var grid := ColorRect.new()
	grid.color = Color(0.10, 0.10, 0.16, 0.35)
	grid.size = vp
	grid.material = _make_grid_mat(vp)
	add_child(grid)

	# ── Tiêu đề game ──────────────────────────────────────────────────────────
	var title_block := Control.new()
	title_block.position = Vector2(0, cy - 210)
	title_block.size = Vector2(vp.x, 100)
	add_child(title_block)

	var title_main := Label.new()
	title_main.text = "CUPY"
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main.add_theme_font_size_override("font_size", 72)
	title_main.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	title_main.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.6, 0.7))
	title_main.add_theme_constant_override("shadow_offset_x", 3)
	title_main.add_theme_constant_override("shadow_offset_y", 4)
	title_main.size = Vector2(vp.x, 80)
	title_main.position = Vector2(0, 0)
	title_block.add_child(title_main)

	var title_sub := Label.new()
	title_sub.text = "Cozy Daily"
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.add_theme_font_size_override("font_size", 22)
	title_sub.add_theme_color_override("font_color", Color(0.72, 0.88, 0.95, 0.80))
	title_sub.add_theme_color_override("font_shadow_color", Color(0, 0.2, 0.4, 0.5))
	title_sub.add_theme_constant_override("shadow_offset_x", 1)
	title_sub.add_theme_constant_override("shadow_offset_y", 2)
	title_sub.size = Vector2(vp.x, 30)
	title_sub.position = Vector2(0, 72)
	title_block.add_child(title_sub)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color = Color(0.35, 0.70, 0.95, 0.18)
	div.size = Vector2(200, 1)
	div.position = Vector2(cx - 100, cy - 100)
	add_child(div)

	# ── Nút menu chính ────────────────────────────────────────────────────────
	var btn_w: float = 300.0
	var btn_h: float = 52.0
	var btn_gap: float = 12.0
	var btn_x: float = cx - btn_w * 0.5
	var btn_y: float = cy - 82.0

	# 1. New Journey
	var new_btn := _make_button(tr("NEW_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(0.30, 0.80, 1.0, 0.14), Color(0.30, 0.80, 1.0, 0.28),
		Color(0.30, 0.80, 1.0, 0.35))
	new_btn.pressed.connect(_on_new_journey)
	add_child(new_btn)
	btn_y += btn_h + btn_gap

	# 2. Journey List
	var list_btn := _make_button(tr("CONTINUE_JOURNEY"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 1.0, 1.0, 0.06), Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.18))
	list_btn.pressed.connect(_on_journey_list)
	add_child(list_btn)
	btn_y += btn_h + btn_gap

	# 3. Settings
	var set_btn := _make_button(tr("SETTINGS_TITLE"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 1.0, 1.0, 0.06), Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.18))
	set_btn.pressed.connect(_on_settings)
	add_child(set_btn)
	btn_y += btn_h + btn_gap

	# 4. About Us
	var about_btn := _make_button(tr("ABOUT_US"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 1.0, 1.0, 0.06), Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.18))
	about_btn.pressed.connect(_on_about)
	add_child(about_btn)
	btn_y += btn_h + btn_gap + 4

	# ── Separator trước Exit ──────────────────────────────────────────────────
	var sep2 := ColorRect.new()
	sep2.color = Color(1, 1, 1, 0.07)
	sep2.size = Vector2(btn_w, 1)
	sep2.position = Vector2(btn_x, btn_y)
	add_child(sep2)
	btn_y += 12

	# 5. Exit
	var quit_btn := _make_button(tr("QUIT_GAME"), btn_x, btn_y, btn_w, btn_h,
		Color(1.0, 0.28, 0.28, 0.08), Color(1.0, 0.28, 0.28, 0.18),
		Color(1.0, 0.28, 0.28, 0.28))
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

	# ── Version label ─────────────────────────────────────────────────────────
	var ver_lbl := Label.new()
	ver_lbl.text = "v0.1.0"
	ver_lbl.add_theme_font_size_override("font_size", 11)
	ver_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
	ver_lbl.position = Vector2(vp.x - 60, vp.y - 24)
	ver_lbl.size = Vector2(52, 18)
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver_lbl)

# ── Button factory ────────────────────────────────────────────────────────────
func _make_button(text: String, x: float, y: float, w: float, h: float,
		normal_color: Color, hover_color: Color, pressed_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

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
	sty.border_color = Color(1.0, 1.0, 1.0, 0.10)
	btn.add_theme_stylebox_override("normal", sty)

	var sty_h := sty.duplicate()
	sty_h.bg_color = hover_color
	sty_h.border_color = Color(0.40, 0.85, 1.0, 0.30)
	btn.add_theme_stylebox_override("hover", sty_h)

	var sty_p := sty.duplicate()
	sty_p.bg_color = pressed_color
	sty_p.border_color = Color(0.40, 0.85, 1.0, 0.50)
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
	COLOR = vec4(0.25, 0.65, 1.0, a);
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
