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

var _name_input: LineEdit
var _seed_input: LineEdit
var _adv_panel: Control
var _adv_expanded: bool = false
var _create_btn: Button
var _back_btn: Button
var _title_lbl: Label
var _name_lbl: Label
var _seed_lbl: Label
var _adv_btn: Button

func _ready() -> void:
	_setup()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_texts()

func _refresh_texts() -> void:
	if not _title_lbl: return
	_title_lbl.text = tr("NEW_JOURNEY_TITLE")
	_name_lbl.text = tr("WORLD_NAME")
	_name_input.placeholder_text = tr("WORLD_NAME_PLACEHOLDER")
	_adv_btn.text = tr("ADVANCED_SETTINGS")
	_seed_lbl.text = tr("SEED_WORLD")
	_create_btn.text = tr("CREATE_JOURNEY")
	_back_btn.text = tr("BACK")

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
	var pw: float = min(vp.x * 0.5, 600.0)
	var ph: float = vp.y * 0.4
	var px: float = (vp.x - pw) * 0.5
	var py: float = (vp.y - ph) * 0.5

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.50)
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.95)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.28, 0.50, 0.25)

	var panel := Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(2, 2)
	accent.size = Vector2(pw - 4, 3)
	accent.color = PURPLE
	panel.add_child(accent)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.80)
	input_style.corner_radius_top_left = 6
	input_style.corner_radius_top_right = 6
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	input_style.border_width_left = 2
	input_style.border_width_right = 2
	input_style.border_width_top = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.35, 0.28, 0.50, 0.20)

	_title_lbl = Label.new()
	_title_lbl.text = tr("NEW_JOURNEY_TITLE")
	_title_lbl.add_theme_font_size_override("font_size", 34)
	_title_lbl.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
	_title_lbl.position = Vector2(px + 28, py + 24)
	_title_lbl.size = Vector2(pw - 56, 40)
	add_child(_title_lbl)

	_name_lbl = Label.new()
	_name_lbl.text = tr("WORLD_NAME")
	_name_lbl.add_theme_font_size_override("font_size", 20)
	_name_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.60))
	_name_lbl.position = Vector2(px + 28, py + 76)
	_name_lbl.size = Vector2(pw - 56, 26)
	add_child(_name_lbl)

	_name_input = LineEdit.new()
	_name_input.position = Vector2(px + 28, py + 104)
	_name_input.size = Vector2(pw - 56, 48)
	_name_input.placeholder_text = tr("WORLD_NAME_PLACEHOLDER")
	_name_input.add_theme_font_size_override("font_size", 22)
	_name_input.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
	_name_input.add_theme_color_override("placeholder_color", TEXT_MUTED)
	_name_input.add_theme_stylebox_override("normal", input_style)
	_name_input.max_length = 30
	add_child(_name_input)

	_adv_btn = Button.new()
	_adv_btn.text = tr("ADVANCED_SETTINGS")
	_adv_btn.flat = true
	_adv_btn.add_theme_font_size_override("font_size", 18)
	_adv_btn.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8))
	_adv_btn.add_theme_color_override("font_hover_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 1.0))
	_adv_btn.position = Vector2(px + 28, py + 162)
	_adv_btn.size = Vector2(280, 34)
	_adv_btn.pressed.connect(_toggle_advanced)
	add_child(_adv_btn)

	_adv_panel = Control.new()
	_adv_panel.position = Vector2(px + 28, py + 200)
	_adv_panel.size = Vector2(pw - 56, 80)
	_adv_panel.visible = false
	add_child(_adv_panel)

	_seed_lbl = Label.new()
	_seed_lbl.text = tr("SEED_WORLD")
	_seed_lbl.add_theme_font_size_override("font_size", 18)
	_seed_lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.50))
	_seed_lbl.position = Vector2(0, 0)
	_seed_lbl.size = Vector2(pw - 56, 26)
	_adv_panel.add_child(_seed_lbl)

	_seed_input = LineEdit.new()
	_seed_input.position = Vector2(0, 28)
	_seed_input.size = Vector2(pw - 56, 44)
	_seed_input.placeholder_text = str(WorldSeed.seed_value)
	_seed_input.add_theme_font_size_override("font_size", 22)
	_seed_input.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.85))
	_seed_input.add_theme_color_override("placeholder_color", TEXT_MUTED)
	_seed_input.add_theme_stylebox_override("normal", input_style)
	_seed_input.max_length = 10
	_adv_panel.add_child(_seed_input)

	var btn_w: float = pw * 0.4
	var btn_y: float = py + ph - 72

	_create_btn = Button.new()
	_create_btn.text = tr("CREATE_JOURNEY")
	_create_btn.position = Vector2(px + pw - btn_w - 28, btn_y)
	_create_btn.size = Vector2(btn_w, 52)
	var create_bg := StyleBoxFlat.new()
	create_bg.bg_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.20)
	create_bg.corner_radius_top_left = 8; create_bg.corner_radius_top_right = 8
	create_bg.corner_radius_bottom_left = 8; create_bg.corner_radius_bottom_right = 8
	create_bg.border_width_left = 2; create_bg.border_width_right = 2
	create_bg.border_width_top = 2; create_bg.border_width_bottom = 2
	create_bg.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.30)
	_create_btn.add_theme_stylebox_override("normal", create_bg)
	_create_btn.add_theme_font_size_override("font_size", 22)
	_create_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.95))
	var create_hover := create_bg.duplicate()
	create_hover.bg_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.35)
	create_hover.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.50)
	_create_btn.add_theme_stylebox_override("hover", create_hover)
	_create_btn.pressed.connect(_on_create)
	add_child(_create_btn)

	_back_btn = Button.new()
	_back_btn.text = tr("BACK")
	_back_btn.position = Vector2(px + 28, btn_y)
	_back_btn.size = Vector2(btn_w, 52)
	var back_bg := StyleBoxFlat.new()
	back_bg.bg_color = Color(0.40, 0.30, 0.55, 0.08)
	back_bg.corner_radius_top_left = 8; back_bg.corner_radius_top_right = 8
	back_bg.corner_radius_bottom_left = 8; back_bg.corner_radius_bottom_right = 8
	back_bg.border_width_left = 2; back_bg.border_width_right = 2
	back_bg.border_width_top = 2; back_bg.border_width_bottom = 2
	back_bg.border_color = Color(0.35, 0.28, 0.50, 0.15)
	_back_btn.add_theme_stylebox_override("normal", back_bg)
	_back_btn.add_theme_font_size_override("font_size", 22)
	_back_btn.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.70))
	var back_hover := back_bg.duplicate()
	back_hover.bg_color = Color(0.40, 0.30, 0.55, 0.15)
	back_hover.border_color = Color(0.40, 0.30, 0.55, 0.30)
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
