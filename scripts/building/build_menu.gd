extends Control
class_name BuildMenu

var _sys: PlacementSystem
var _btns: Array[Button] = []

signal building_selected(idx: int)
signal closed()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open(sys: PlacementSystem) -> void:
	_sys = sys
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
	bg.color = Color(0.0, 0.0, 0.0, 0.50)
	bg.position = Vector2.ZERO
	bg.size = vp_size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := Panel.new()
	var pw: float = 360.0
	var buildings: Array[Dictionary] = _sys.get_buildings()
	var inv: Dictionary = _sys.get_inventory()
	var item_count: int = 0
	for b in buildings:
		if b.type == "tile":
			var cnt: int = inv.get(b.key, 0)
			if cnt > 0:
				item_count += 1
		elif b.type == "unique" and not b.placed:
			item_count += 1
	var rows: int = max(item_count, 1)
	var ph: float = 50.0 + rows * 58.0 + 20.0

	panel.position = Vector2((vp_size.x - pw) * 0.5, (vp_size.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.07, 0.07, 0.12, 0.95)
	pbg.corner_radius_top_left = 12; pbg.corner_radius_top_right = 12
	pbg.corner_radius_bottom_left = 12; pbg.corner_radius_bottom_right = 12
	pbg.border_width_left = 2; pbg.border_width_right = 2
	pbg.border_width_top = 2; pbg.border_width_bottom = 2
	pbg.border_color = Color(0.3, 0.3, 0.45, 0.6)
	panel.add_theme_stylebox_override("panel", pbg)
	add_child(panel)

	var title := Label.new()
	title.text = tr("BUILD_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title.position = Vector2(0, 12)
	title.size = Vector2(pw, 28)
	panel.add_child(title)

	var y: float = 52.0
	for i in range(buildings.size()):
		var data: Dictionary = buildings[i]
		var is_tile: bool = data.type == "tile"
		var tile_count: int = inv.get(data.key, 0) if is_tile else 0
		var disabled: bool = false

		if data.type == "unique" and data.placed:
			disabled = true
		if is_tile and tile_count <= 0:
			disabled = true

		if not disabled or data.type == "unique":
			var btn := Button.new()
			btn.position = Vector2(20, y)
			btn.size = Vector2(pw - 70, 50)
			var label_text: String = tr(data.get("name_key", data.get("name", "")))
			if is_tile:
				label_text += " [" + str(tile_count) + "]"
			btn.text = label_text
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var btn_bg := StyleBoxFlat.new()
			if disabled:
				btn_bg.bg_color = Color(0.12, 0.12, 0.18, 0.6)
				btn_bg.border_color = Color(0.3, 0.3, 0.35, 0.3)
				btn.disabled = true
			else:
				btn_bg.bg_color = Color(0.10, 0.10, 0.18, 0.85)
				btn_bg.border_color = Color(0.25, 0.25, 0.35, 0.5)
				btn.pressed.connect(_on_building_click.bind(i))
			btn_bg.corner_radius_top_left = 8; btn_bg.corner_radius_top_right = 8
			btn_bg.corner_radius_bottom_left = 8; btn_bg.corner_radius_bottom_right = 8
			btn_bg.border_width_left = 1; btn_bg.border_width_right = 1
			btn_bg.border_width_top = 1; btn_bg.border_width_bottom = 1
			btn.add_theme_stylebox_override("normal", btn_bg)
			btn.add_theme_stylebox_override("disabled", btn_bg)
			panel.add_child(btn)

			var desc := Label.new()
			desc.text = tr(data.get("desc_key", data.get("desc", "")))
			desc.position = Vector2(12, 30)
			desc.add_theme_font_size_override("font_size", 11)
			desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 0.7))
			btn.add_child(desc)
			_btns.append(btn)
			y += 58.0

	if _btns.size() == 0:
		var empty := Label.new()
		empty.text = tr("EMPTY_BUILD")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7, 0.6))
		empty.position = Vector2(0, 52)
		empty.size = Vector2(pw, 40)
		panel.add_child(empty)

func _on_building_click(idx: int) -> void:
	building_selected.emit(idx)
