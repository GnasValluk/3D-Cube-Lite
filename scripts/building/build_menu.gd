extends Control
class_name BuildMenu

const S: float = 1.6
const SS: float = 1.35

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

const PANEL_W: float = 300.0
const ITEM_H: float = 72.0

var _player_inv: Inventory = null

var _btns: Array[Button] = []
var _building_names: Array[String] = []
var _building_ids: Array[String] = []

signal building_selected(item_id: String)
signal closed()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_building_ids = ["twilight_gate", "chest"]
	ItemDatabase.ensure_db()
	_building_names = []
	for item_id in _building_ids:
		var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
		_building_names.append(def.name if def else item_id)
	# Add blocks from ItemDatabase
	for item_id in ItemDatabase.items_db:
		var def: ItemDef = ItemDatabase.items_db[item_id] as ItemDef
		if def and def.type == ItemDef.Type.BLOCK and item_id.begins_with("block_"):
			_building_ids.append(item_id)
			_building_names.append(def.name)

func open(initial_inv: Inventory) -> void:
	_player_inv = initial_inv
	_clear()
	_build_ui()
	visible = true

func close() -> void:
	visible = false
	_clear()
	closed.emit()

func _clear() -> void:
	for ch in get_children():
		ch.queue_free()
	_btns.clear()

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

	var inv_info := Label.new()
	inv_info.text = tr("BUILD_INV_LABEL")
	inv_info.position = Vector2(14, 66)
	inv_info.add_theme_font_size_override("font_size", int(S * 11))
	inv_info.add_theme_color_override("font_color", TEXT_DIM)
	panel.add_child(inv_info)

	var y: float = 96.0
	for i in range(_building_ids.size()):
		var bid: String = _building_ids[i]
		var bname: String = _building_names[i]
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
			btn.pressed.connect(func(): _on_item_click(idx))
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
		panel.add_child(btn)

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

func _get_item_count(item_id: String) -> int:
	if _player_inv == null:
		return 0
	return _player_inv.get_item_count(item_id)

func _on_item_click(idx: int) -> void:
	if idx < 0 or idx >= _building_ids.size():
		return
	building_selected.emit(_building_ids[idx])
