extends Control

var _new_journey_ui: Control = null

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10)
	bg.size = vp
	add_child(bg)

	var grid := ColorRect.new()
	grid.color = Color(0.10, 0.10, 0.16, 0.4)
	grid.size = vp
	grid.material = _make_grid_mat(vp)
	add_child(grid)

	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	var title := Label.new()
	title.text = "CubeLife Zero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.95))
	title.add_theme_color_override("font_shadow_color", Color(0, 0.3, 0.6, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(0, cy - 200)
	title.size = Vector2(vp.x, 50)
	add_child(title)

	var btn_w: float = 320.0
	var btn_h: float = 48.0
	var btn_gap: float = 14.0
	var btn_x: float = cx - btn_w * 0.5
	var btn_start_y: float = cy - 60.0

	var new_btn := _make_button("Hành trình mới", btn_x, btn_start_y, btn_w, btn_h, Color(0.35, 0.85, 1.0, 0.15), Color(0.35, 0.85, 1.0, 0.30))
	new_btn.pressed.connect(_on_new_journey)
	add_child(new_btn)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.size = Vector2(btn_w, 1)
	sep.position = Vector2(btn_x, btn_start_y + btn_h + btn_gap * 0.5)
	add_child(sep)

	var list_y: float = btn_start_y + btn_h + btn_gap + 8
	var saves_label := Label.new()
	saves_label.text = "Các hành trình đã chơi"
	saves_label.add_theme_font_size_override("font_size", 13)
	saves_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.70, 0.7))
	saves_label.position = Vector2(btn_x, list_y)
	saves_label.size = Vector2(btn_w, 20)
	add_child(saves_label)
	list_y += 24

	var saves: Array = WorldSeed.get_saves()
	if saves.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Chưa có hành trình nào"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.20))
		empty_lbl.position = Vector2(btn_x, list_y)
		empty_lbl.size = Vector2(btn_w, 20)
		add_child(empty_lbl)
		list_y += 24
	else:
		for i in range(min(saves.size(), 6)):
			var s: Dictionary = saves[i]
			var s_btn := _make_button(s.get("name", "Unknown"), btn_x, list_y, btn_w, 36, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.10))
			var idx: int = i
			s_btn.pressed.connect(_on_load_journey.bind(idx))
			add_child(s_btn)

			var seed_lbl := Label.new()
			seed_lbl.text = "Seed: " + str(s.get("seed", 0))
			seed_lbl.add_theme_font_size_override("font_size", 10)
			seed_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.15))
			seed_lbl.position = Vector2(btn_x + 12, list_y + 20)
			seed_lbl.size = Vector2(btn_w - 24, 14)
			add_child(seed_lbl)

			var del_btn := Button.new()
			del_btn.text = "×"
			del_btn.position = Vector2(btn_x + btn_w - 32, list_y + 4)
			del_btn.size = Vector2(28, 28)
			del_btn.add_theme_font_size_override("font_size", 16)
			del_btn.add_theme_color_override("font_color", Color(1, 0.35, 0.35, 0.60))
			del_btn.add_theme_color_override("font_hover_color", Color(1, 0.35, 0.35, 1.0))
			var del_bg := StyleBoxFlat.new()
			del_bg.bg_color = Color(0, 0, 0, 0.0)
			del_bg.corner_radius_top_left = 4
			del_bg.corner_radius_top_right = 4
			del_bg.corner_radius_bottom_left = 4
			del_bg.corner_radius_bottom_right = 4
			del_btn.add_theme_stylebox_override("normal", del_bg)
			var del_hover := del_bg.duplicate()
			del_hover.bg_color = Color(1, 0.20, 0.20, 0.15)
			del_btn.add_theme_stylebox_override("hover", del_hover)
			del_btn.pressed.connect(_on_delete_journey.bind(idx))
			add_child(del_btn)

			list_y += 36 + 4

	var quit_btn := _make_button("Thoát game", btn_x, list_y + 16, btn_w, btn_h, Color(1, 0.30, 0.30, 0.08), Color(1, 0.30, 0.30, 0.18))
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

func _make_button(text: String, x: float, y: float, w: float, h: float, normal_color: Color, hover_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var bg := StyleBoxFlat.new()
	bg.bg_color = normal_color
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(1, 1, 1, 0.08)
	btn.add_theme_stylebox_override("normal", bg)
	var h_bg := bg.duplicate()
	h_bg.bg_color = hover_color
	h_bg.border_color = Color(1, 1, 1, 0.20)
	btn.add_theme_stylebox_override("hover", h_bg)
	return btn

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
	vec2 g = fract(uv * 30.0);
	float l = min(g.x, g.y);
	float a = smoothstep(0.04, 0.02, l) * 0.15;
	COLOR = vec4(0.2, 0.6, 1.0, a);
}
"""
	return s

func _on_delete_journey(idx: int) -> void:
	var saves: Array = WorldSeed.get_saves()
	if idx < 0 or idx >= saves.size():
		return
	var name: String = saves[idx].get("name", "Unknown")
	var confirm := AcceptDialog.new()
	confirm.dialog_text = "Xoá hành trình \"" + name + "\"?"
	confirm.ok_button_text = "Xoá"
	add_child(confirm)
	confirm.popup_centered()
	confirm.add_cancel_button("Huỷ")
	confirm.confirmed.connect(_do_delete.bind(idx))

func _do_delete(idx: int) -> void:
	WorldSeed.delete_save(idx)
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _on_new_journey() -> void:
	if _new_journey_ui == null:
		_new_journey_ui = preload("res://scripts/ui/new_journey_ui.gd").new()
		add_child(_new_journey_ui)
	_new_journey_ui.visible = true
	_new_journey_ui.setup()

func _on_load_journey(idx: int) -> void:
	if WorldSeed.load_journey(idx):
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_quit() -> void:
	get_tree().quit()
