extends Control

var _name_input: LineEdit
var _seed_input: LineEdit
var _adv_panel: Control
var _adv_expanded: bool = false
var _create_btn: Button
var _back_btn: Button

func _ready() -> void:
	_setup()

func setup() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _name_input:
		_name_input.text = ""
		_seed_input.text = ""
		_adv_panel.visible = false
		_adv_expanded = false

func _setup() -> void:
	var vp := get_viewport().get_visible_rect().size
	var pw: float = 420.0
	var ph: float = 320.0
	var px: float = (vp.x - pw) * 0.5
	var py: float = (vp.y - ph) * 0.5

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.50)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1, 1, 1, 0.12)

	var panel := Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.12, 0.12, 0.18, 0.80)
	input_style.corner_radius_top_left = 4
	input_style.corner_radius_top_right = 4
	input_style.corner_radius_bottom_left = 4
	input_style.corner_radius_bottom_right = 4
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_width_top = 1
	input_style.border_width_bottom = 1
	input_style.border_color = Color(1, 1, 1, 0.10)

	var title := Label.new()
	title.text = "Hành trình mới"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	title.position = Vector2(px + 20, py + 16)
	title.size = Vector2(pw - 40, 28)
	add_child(title)

	var name_lbl := Label.new()
	name_lbl.text = "Tên thế giới"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.60))
	name_lbl.position = Vector2(px + 20, py + 56)
	name_lbl.size = Vector2(pw - 40, 18)
	add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.position = Vector2(px + 20, py + 76)
	_name_input.size = Vector2(pw - 40, 36)
	_name_input.placeholder_text = "Nhập tên thế giới..."
	_name_input.add_theme_font_size_override("font_size", 15)
	_name_input.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	_name_input.add_theme_color_override("placeholder_color", Color(1, 1, 1, 0.25))
	_name_input.add_theme_stylebox_override("normal", input_style)
	_name_input.max_length = 30
	add_child(_name_input)

	var adv_btn := Button.new()
	adv_btn.text = "Cài đặt nâng cao  ▸"
	adv_btn.flat = true
	adv_btn.add_theme_font_size_override("font_size", 12)
	adv_btn.add_theme_color_override("font_color", Color(0.45, 0.55, 0.70, 0.8))
	adv_btn.add_theme_color_override("font_hover_color", Color(0.55, 0.65, 0.80, 1.0))
	adv_btn.position = Vector2(px + 20, py + 120)
	adv_btn.size = Vector2(200, 24)
	adv_btn.pressed.connect(_toggle_advanced)
	add_child(adv_btn)

	_adv_panel = Control.new()
	_adv_panel.position = Vector2(px + 20, py + 148)
	_adv_panel.size = Vector2(pw - 40, 60)
	_adv_panel.visible = false
	add_child(_adv_panel)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed thế giới"
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.50))
	seed_lbl.position = Vector2(0, 0)
	seed_lbl.size = Vector2(pw - 40, 18)
	_adv_panel.add_child(seed_lbl)

	_seed_input = LineEdit.new()
	_seed_input.position = Vector2(0, 20)
	_seed_input.size = Vector2(pw - 40, 32)
	_seed_input.placeholder_text = str(WorldSeed.seed_value)
	_seed_input.add_theme_font_size_override("font_size", 14)
	_seed_input.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_seed_input.add_theme_color_override("placeholder_color", Color(1, 1, 1, 0.20))
	_seed_input.add_theme_stylebox_override("normal", input_style)
	_seed_input.max_length = 10
	_adv_panel.add_child(_seed_input)

	var btn_w: float = 160.0
	var btn_y: float = py + ph - 56

	_create_btn = Button.new()
	_create_btn.text = "Tạo hành trình"
	_create_btn.position = Vector2(px + pw - btn_w - 20, btn_y)
	_create_btn.size = Vector2(btn_w, 38)
	var create_bg := StyleBoxFlat.new()
	create_bg.bg_color = Color(0.35, 0.85, 1.0, 0.20)
	create_bg.corner_radius_top_left = 6; create_bg.corner_radius_top_right = 6
	create_bg.corner_radius_bottom_left = 6; create_bg.corner_radius_bottom_right = 6
	create_bg.border_width_left = 1; create_bg.border_width_right = 1
	create_bg.border_width_top = 1; create_bg.border_width_bottom = 1
	create_bg.border_color = Color(0.35, 0.85, 1.0, 0.30)
	_create_btn.add_theme_stylebox_override("normal", create_bg)
	_create_btn.add_theme_font_size_override("font_size", 14)
	_create_btn.add_theme_color_override("font_color", Color(0.80, 0.95, 1.0, 0.95))
	var create_hover := create_bg.duplicate()
	create_hover.bg_color = Color(0.35, 0.85, 1.0, 0.35)
	create_hover.border_color = Color(0.35, 0.85, 1.0, 0.50)
	_create_btn.add_theme_stylebox_override("hover", create_hover)
	_create_btn.pressed.connect(_on_create)
	add_child(_create_btn)

	_back_btn = Button.new()
	_back_btn.text = "Trở lại"
	_back_btn.position = Vector2(px + 20, btn_y)
	_back_btn.size = Vector2(btn_w, 38)
	var back_bg := StyleBoxFlat.new()
	back_bg.bg_color = Color(1, 1, 1, 0.04)
	back_bg.corner_radius_top_left = 6; back_bg.corner_radius_top_right = 6
	back_bg.corner_radius_bottom_left = 6; back_bg.corner_radius_bottom_right = 6
	back_bg.border_width_left = 1; back_bg.border_width_right = 1
	back_bg.border_width_top = 1; back_bg.border_width_bottom = 1
	back_bg.border_color = Color(1, 1, 1, 0.08)
	_back_btn.add_theme_stylebox_override("normal", back_bg)
	_back_btn.add_theme_font_size_override("font_size", 14)
	_back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
	var back_hover := back_bg.duplicate()
	back_hover.bg_color = Color(1, 1, 1, 0.10)
	back_hover.border_color = Color(1, 1, 1, 0.20)
	_back_btn.add_theme_stylebox_override("hover", back_hover)
	_back_btn.pressed.connect(_on_back)
	add_child(_back_btn)

	visible = false

func _toggle_advanced() -> void:
	_adv_expanded = not _adv_expanded
	_adv_panel.visible = _adv_expanded

func _validate_input() -> bool:
	var name_text: String = _name_input.text.strip_edges()
	if name_text.length() == 0:
		return false
	return true

func _on_create() -> void:
	if not _validate_input():
		return
	var name_text: String = _name_input.text.strip_edges()
	var seed_str: String = _seed_input.text.strip_edges()
	var seed_val: int = int(seed_str) if seed_str.is_valid_int() else randi() % 2147483647

	WorldSeed.start_new_journey(name_text, seed_val)
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_back() -> void:
	visible = false
