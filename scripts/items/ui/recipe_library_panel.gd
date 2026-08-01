extends Control
class_name RecipeLibraryPanel

const _RecipeDB = preload("res://scripts/items/core/recipe_database.gd")

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
var _list_box: VBoxContainer

func _ready() -> void:
	_categories = [
		tr("LIB_CAT_ALL"),
		tr("LIB_CAT_WEAPONS"),
		tr("LIB_CAT_TOOLS"),
		tr("LIB_CAT_FOOD"),
		tr("LIB_CAT_POTIONS"),
		tr("LIB_CAT_MATERIALS"),
		"Công Trình",
	]

	_setup_bg()
	_setup_title()
	_setup_category_tabs()
	_setup_list()

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

func _setup_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 80)
	scroll.size = Vector2(PANEL_W - 20, 600 - 90)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

func _recipe_category_idx(cat: String) -> int:
	if cat == _RecipeDB.CAT_TOOLS:
		return 2
	if cat == _RecipeDB.CAT_MATERIALS:
		return 5
	if cat == _RecipeDB.CAT_STRUCTURES:
		return 6
	return -1

func _populate() -> void:
	_RecipeDB.ensure()
	for ch in _list_box.get_children():
		ch.queue_free()
	for r in _RecipeDB.recipes:
		if _selected_cat != 0 and _recipe_category_idx(r.get("category", "")) != _selected_cat:
			continue
		var card := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.10, 0.22, 0.85)
		style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
		style.border_width_left = 1; style.border_width_right = 1
		style.border_width_top = 1; style.border_width_bottom = 1
		style.border_color = Color(0.55, 0.57, 0.62, 0.15)
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(PANEL_W - 20, 0)
		_list_box.add_child(card)

		var title := Label.new()
		title.text = r.get("name", r.get("id", ""))
		title.add_theme_font_size_override("font_size", int(S * 12))
		title.add_theme_color_override("font_color", TEXT_BRIGHT)
		title.position = Vector2(12, 6)
		title.size = Vector2(PANEL_W - 44, 22)
		card.add_child(title)

		var cat := Label.new()
		cat.text = r.get("category", "")
		cat.add_theme_font_size_override("font_size", int(S * 8))
		cat.add_theme_color_override("font_color", TEXT_MUTED)
		cat.position = Vector2(PANEL_W - 130, 9)
		cat.size = Vector2(100, 18)
		cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(cat)

		var ing_text := ""
		var ing: Dictionary = r.get("ingredients", {})
		var first := true
		for ing_id in ing:
			if not first:
				ing_text += " + "
			first = false
			var def: ItemDef = ItemDatabase.items_db.get(ing_id) as ItemDef
			ing_text += "%s x%d" % [def.name if def != null else ing_id, ing[ing_id]]
		var ing_label := Label.new()
		ing_label.text = ing_text
		ing_label.add_theme_font_size_override("font_size", int(S * 9))
		ing_label.add_theme_color_override("font_color", TEXT_DIM)
		ing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ing_label.position = Vector2(12, 30)
		ing_label.size = Vector2(PANEL_W - 44, 20)
		card.add_child(ing_label)

		var res_def: ItemDef = ItemDatabase.items_db.get(r.get("result", "")) as ItemDef
		var res_label := Label.new()
		res_label.text = "→ %s x%d" % [res_def.name if res_def != null else r.get("result", ""), r.get("count", 1)]
		res_label.add_theme_font_size_override("font_size", int(S * 9))
		res_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
		res_label.position = Vector2(12, 50)
		res_label.size = Vector2(PANEL_W - 44, 20)
		card.add_child(res_label)
		card.custom_minimum_size = Vector2(0, 76)

func open() -> void:
	ItemDatabase.ensure_db()
	_populate()
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
		_populate()
