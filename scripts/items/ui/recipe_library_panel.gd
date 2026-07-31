extends Control
class_name RecipeLibraryPanel

const S: float = 1.6

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

const PANEL_W: float = 320.0

var _categories: Array[String] = []
var _cat_buttons: Array[Button] = []
var _selected_cat: int = 0
var _tween: Tween

func _ready() -> void:
	_categories = [
		tr("LIB_CAT_ALL"),
		tr("LIB_CAT_WEAPONS"),
		tr("LIB_CAT_TOOLS"),
		tr("LIB_CAT_FOOD"),
		tr("LIB_CAT_POTIONS"),
		tr("LIB_CAT_MATERIALS"),
	]

	_setup_bg()
	_setup_title()
	_setup_category_tabs()
	_setup_empty_state()

	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _setup_bg() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BG_PANEL
	bg_style.corner_radius_top_left = 14
	bg_style.corner_radius_top_right = 14
	bg_style.corner_radius_bottom_left = 14
	bg_style.corner_radius_bottom_right = 14
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.85, 0.80, 0.95, 0.12)

	var bg := Panel.new()
	bg.size = Vector2(PANEL_W, 600)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	size = Vector2(PANEL_W, 600)
	position = Vector2(10, 40)

func _setup_title() -> void:
	var title := Label.new()
	title.text = tr("RECIPE_LIBRARY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(S * 15))
	title.add_theme_color_override("font_color", TEXT_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(0, 12)
	title.size = Vector2(PANEL_W, 30)
	add_child(title)

func _setup_category_tabs() -> void:
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.14, 0.10, 0.22, 0.6)
	tab_style.corner_radius_top_left = 4
	tab_style.corner_radius_top_right = 4
	tab_style.corner_radius_bottom_left = 4
	tab_style.corner_radius_bottom_right = 4
	tab_style.border_width_left = 1
	tab_style.border_width_right = 1
	tab_style.border_width_top = 1
	tab_style.border_width_bottom = 1
	tab_style.border_color = Color(0.55, 0.57, 0.62, 0.15)

	var sep: float = 4.0
	var bw: float = (PANEL_W - 14 - sep * (_categories.size() - 1)) / _categories.size()

	for i in range(_categories.size()):
		var btn := Button.new()
		btn.text = _categories[i]
		btn.flat = true
		btn.size = Vector2(max(bw, 40), 26)
		btn.position = Vector2(7 + i * (bw + sep), 48)
		btn.add_theme_font_size_override("font_size", int(S * 9))
		btn.add_theme_color_override("font_color", TEXT_DIM)
		btn.add_theme_stylebox_override("normal", tab_style)
		btn.toggle_mode = true
		btn.button_pressed = i == _selected_cat
		btn.toggled.connect(_on_cat_toggled.bind(i))
		add_child(btn)
		_cat_buttons.append(btn)

func _setup_empty_state() -> void:
	var lbl := Label.new()
	lbl.text = tr("NO_RECIPES")
	lbl.position = Vector2(10, 100)
	lbl.size = Vector2(PANEL_W - 20, 200)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", int(S * 11))
	lbl.add_theme_color_override("font_color", TEXT_MUTED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)

func open() -> void:
	_play_appear()

func close() -> void:
	_play_disappear()

func _play_appear() -> void:
	visible = true
	scale = Vector2.ZERO
	modulate.a = 0.0
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.15)

func _play_disappear() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.10)
	_tween.tween_callback(func():
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0
	)

func _on_cat_toggled(pressed: bool, idx: int) -> void:
	if pressed:
		_selected_cat = idx
		for i in _cat_buttons.size():
			_cat_buttons[i].button_pressed = i == idx
