extends Control
class_name BuildMenu

const S: float = 1.6
const SS: float = 1.35

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

const PANEL_W: float = 300.0
const ITEM_H: float = 72.0
const TAB_H: float = 36.0

var _player_inv: Inventory = null
var _btns: Array[Button] = []
var _building_ids: Array[String] = []
var _building_names: Array[String] = []
var _categories: Array[Dictionary] = []
var _cur_cat: int = 0
var _tab_btns: Array[Button] = []
var _list_container: Control = null
var _tween: Tween

signal building_selected(item_id: String)
signal closed()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_categories()
	ItemDatabase.ensure_db()

func _setup_categories() -> void:
	_categories = [
		{"label": "Công Trình", "ids": ["twilight_gate", "chest", "crafting_table", "tool_table", "mech_table", "farm_table", "chem_table", "magic_table", "kitchen_table", "architecture_table", "furnace", "cooking_stove", "fishing_boat", "tractor", "rescue_helicopter"]},
		{"label": "Khối", "ids": []},
		{"label": "Quặng", "ids": []},
	]
	for item_id in ItemDatabase.items_db:
		var def: ItemDef = ItemDatabase.items_db[item_id] as ItemDef
		if not def or def.type != ItemDef.Type.BLOCK:
			continue
		if item_id in ["chest", "crafting_table", "furnace", "cooking_stove", "tool_table", "mech_table", "farm_table", "chem_table", "magic_table", "kitchen_table", "architecture_table"]:
			continue
		if item_id.ends_with("_ore"):
			_categories[2].ids.append(item_id)
		else:
			_categories[1].ids.append(item_id)

func open(initial_inv: Inventory) -> void:
	_player_inv = initial_inv
	_clear()
	_build_ui()
	_play_appear()

func close() -> void:
	_clear()
	_play_disappear()
	closed.emit()

func _clear() -> void:
	for ch in get_children():
		ch.queue_free()
	_btns.clear()
	_tab_btns.clear()
	_list_container = null

func _build_ui() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.35)
	bg.position = Vector2.ZERO
	bg.size = vp_size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(vp_size.x - PANEL_W, 0)
	panel.size = Vector2(PANEL_W, vp_size.y)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.08, 0.06, 0.16, 0.92)
	pbg.corner_radius_top_left = 16
	pbg.corner_radius_bottom_left = 16
	pbg.border_width_left = 2
	pbg.border_color = Color(0.38, 0.28, 0.55, 0.5)
	panel.add_theme_stylebox_override("panel", pbg)
	add_child(panel)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(PANEL_W - 50, 12)
	close_btn.size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", int(S * 16))
	close_btn.add_theme_color_override("font_color", TEXT_DIM)
	var cb_bg := StyleBoxFlat.new()
	cb_bg.bg_color = BG_CARD
	cb_bg.corner_radius_top_left = 8; cb_bg.corner_radius_top_right = 8
	cb_bg.corner_radius_bottom_left = 8; cb_bg.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", cb_bg)
	close_btn.add_theme_stylebox_override("hover", cb_bg)
	close_btn.pressed.connect(func(): close())
	panel.add_child(close_btn)

	var title := Label.new()
	title.text = tr("BUILD_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(S * 18))
	title.add_theme_color_override("font_color", TEXT_MAIN)
	title.position = Vector2(0, 14)
	title.size = Vector2(PANEL_W, 44)
	panel.add_child(title)

	# ── Tabs ──
	var tab_y: float = 60.0
	var tab_w: float = PANEL_W / _categories.size()
	for ci in range(_categories.size()):
		var cat: Dictionary = _categories[ci]
		var tab := Button.new()
		tab.text = cat.label
		tab.position = Vector2(tab_w * ci, tab_y)
		tab.size = Vector2(tab_w, TAB_H)
		tab.add_theme_font_size_override("font_size", int(S * 12))
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = BG_CARD if ci == _cur_cat else BG_PANEL
		tab_style.corner_radius_top_left = 8; tab_style.corner_radius_top_right = 8
		tab_style.border_width_bottom = 2
		tab_style.border_color = PURPLE if ci == _cur_cat else Color(0.25, 0.20, 0.35, 0.3)
		tab.add_theme_stylebox_override("normal", tab_style)
		tab.add_theme_stylebox_override("hover", tab_style)
		var tc := ci
		tab.pressed.connect(func(): _switch_tab(tc))
		_tab_btns.append(tab)
		panel.add_child(tab)

	# ── Scrollable list ──
	var list_y: float = tab_y + TAB_H + 4
	var list_h: float = vp_size.y - list_y - 10
	_list_container = Control.new()
	_list_container.position = Vector2(0, list_y)
	_list_container.size = Vector2(PANEL_W, list_h)
	panel.add_child(_list_container)

	_populate_list()

func _switch_tab(ci: int) -> void:
	_cur_cat = ci
	for i in range(_tab_btns.size()):
		var tab := _tab_btns[i]
		var ts := StyleBoxFlat.new()
		ts.bg_color = BG_CARD if i == ci else BG_PANEL
		ts.corner_radius_top_left = 8; ts.corner_radius_top_right = 8
		ts.border_width_bottom = 2
		ts.border_color = PURPLE if i == ci else Color(0.25, 0.20, 0.35, 0.3)
		tab.add_theme_stylebox_override("normal", ts)
		tab.add_theme_stylebox_override("hover", ts)
	_populate_list()

func _populate_list() -> void:
	_clear_list()
	if _cur_cat < 0 or _cur_cat >= _categories.size():
		return
	var ids: Array = _categories[_cur_cat].ids
	var names: Array = []
	for item_id in ids:
		var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
		names.append(def.name if def else item_id)

	var y: float = 4.0
	for i in range(ids.size()):
		var bid: String = ids[i]
		var bname: String = names[i]
		var count: int = _get_item_count(bid)
		var has_item: bool = count > 0

		var btn := Button.new()
		btn.position = Vector2(12, y)
		btn.size = Vector2(PANEL_W - 24, ITEM_H)
		btn.add_theme_font_size_override("font_size", int(S * 14))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var btn_bg := StyleBoxFlat.new()
		if not has_item:
			btn_bg.bg_color = Color(0.08, 0.06, 0.14, 0.5)
			btn_bg.border_color = Color(0.25, 0.20, 0.35, 0.25)
			btn.add_theme_color_override("font_color", TEXT_MUTED)
			btn.disabled = true
		else:
			btn_bg.bg_color = BG_CARD
			btn_bg.border_color = Color(0.40, 0.32, 0.60, 0.5)
			btn.add_theme_color_override("font_color", TEXT_MAIN)
			var idx := i
			btn.pressed.connect(func(): _on_item_click(ids[idx]))
		var icon := TextureRect.new()
		icon.position = Vector2(10, 10)
		icon.size = Vector2(54, 54)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex := ItemDatabase.load_icon_2d(bid)
		if icon_tex:
			icon.texture = icon_tex
		btn.add_child(icon)

		var name_label := Label.new()
		name_label.text = bname
		name_label.position = Vector2(74, 14)
		name_label.size = Vector2(PANEL_W - 160, 30)
		name_label.add_theme_font_size_override("font_size", int(S * 14))
		name_label.add_theme_color_override("font_color", TEXT_MAIN if has_item else TEXT_MUTED)
		btn.add_child(name_label)

		btn_bg.corner_radius_top_left = 10; btn_bg.corner_radius_top_right = 10
		btn_bg.corner_radius_bottom_left = 10; btn_bg.corner_radius_bottom_right = 10
		btn_bg.border_width_left = 2; btn_bg.border_width_right = 2
		btn_bg.border_width_top = 2; btn_bg.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", btn_bg)
		btn.add_theme_stylebox_override("disabled", btn_bg)
		_list_container.add_child(btn)

		var count_label := Label.new()
		count_label.text = "x" + str(count)
		count_label.add_theme_font_size_override("font_size", int(S * 12))
		count_label.add_theme_color_override("font_color", TEXT_MAIN if has_item else TEXT_MUTED)
		count_label.position = Vector2(PANEL_W - 90, 40)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.size = Vector2(75, 22)
		btn.add_child(count_label)

		_btns.append(btn)
		y += ITEM_H + 10

func _clear_list() -> void:
	if _list_container == null:
		return
	for ch in _list_container.get_children():
		ch.queue_free()
	_btns.clear()

func _get_item_count(item_id: String) -> int:
	if _player_inv == null:
		return 0
	return _player_inv.get_item_count(item_id)

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

func _on_item_click(item_id: String) -> void:
	building_selected.emit(item_id)
