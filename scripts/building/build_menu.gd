extends Control
class_name BuildMenu

const PANEL_W: float = 220.0
const ITEM_H: float = 56.0

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
	_building_names = ["Cổng Twilight", "Rương đồ"]

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
	pbg.bg_color = Color(0.06, 0.06, 0.12, 0.92)
	pbg.corner_radius_top_left = 12
	pbg.corner_radius_bottom_left = 12
	pbg.border_width_left = 1
	pbg.border_color = Color(0.25, 0.25, 0.40, 0.5)
	panel.add_theme_stylebox_override("panel", pbg)
	add_child(panel)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(PANEL_W - 36, 8)
	close_btn.size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	var cb_bg := StyleBoxFlat.new()
	cb_bg.bg_color = Color(0.15, 0.15, 0.22, 0.6)
	cb_bg.corner_radius_top_left = 6; cb_bg.corner_radius_top_right = 6
	cb_bg.corner_radius_bottom_left = 6; cb_bg.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", cb_bg)
	close_btn.add_theme_stylebox_override("hover", cb_bg)
	close_btn.pressed.connect(func(): close())
	panel.add_child(close_btn)

	var title := Label.new()
	title.text = "Xây dựng"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.95))
	title.position = Vector2(0, 10)
	title.size = Vector2(PANEL_W, 30)
	panel.add_child(title)

	var inv_info := Label.new()
	inv_info.text = "Vật phẩm trong túi:"
	inv_info.position = Vector2(14, 46)
	inv_info.add_theme_font_size_override("font_size", 11)
	inv_info.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 0.7))
	panel.add_child(inv_info)

	var y: float = 68.0
	for i in range(_building_ids.size()):
		var bid: String = _building_ids[i]
		var bname: String = _building_names[i]
		var count: int = _get_item_count(bid)
		var has_item: bool = count > 0

		var btn := Button.new()
		btn.position = Vector2(10, y)
		btn.size = Vector2(PANEL_W - 20, ITEM_H)
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var btn_bg := StyleBoxFlat.new()
		if not has_item:
			btn_bg.bg_color = Color(0.10, 0.10, 0.16, 0.5)
			btn_bg.border_color = Color(0.2, 0.2, 0.3, 0.25)
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.5))
			btn.disabled = true
		else:
			btn_bg.bg_color = Color(0.10, 0.10, 0.20, 0.85)
			btn_bg.border_color = Color(0.25, 0.30, 0.45, 0.5)
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9))
			var idx := i
			btn.pressed.connect(func(): _on_item_click(idx))
		var icon := TextureRect.new()
		icon.position = Vector2(8, 8)
		icon.size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex := ItemDatabase.load_icon_2d(bid)
		if icon_tex:
			icon.texture = icon_tex
		btn.add_child(icon)

		var name_label := Label.new()
		name_label.text = bname
		name_label.position = Vector2(56, 10)
		name_label.size = Vector2(PANEL_W - 120, 22)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9) if has_item else Color(0.4, 0.4, 0.5, 0.5))
		btn.add_child(name_label)

		btn_bg.corner_radius_top_left = 8; btn_bg.corner_radius_top_right = 8
		btn_bg.corner_radius_bottom_left = 8; btn_bg.corner_radius_bottom_right = 8
		btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
		btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", btn_bg)
		btn.add_theme_stylebox_override("disabled", btn_bg)
		panel.add_child(btn)

		var count_label := Label.new()
		count_label.text = "x" + str(count)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85, 0.8) if has_item else Color(0.35, 0.35, 0.45, 0.4))
		count_label.position = Vector2(PANEL_W - 70, 28)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.size = Vector2(55, 22)
		btn.add_child(count_label)

		_btns.append(btn)
		y += ITEM_H + 6

func _get_item_count(item_id: String) -> int:
	if _player_inv == null:
		return 0
	return _player_inv.get_item_count(item_id)

func _on_item_click(idx: int) -> void:
	if idx < 0 or idx >= _building_ids.size():
		return
	building_selected.emit(_building_ids[idx])
