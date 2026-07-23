## InventoryUI – Kho đồ người chơi + Thư viện vật phẩm bên trái
class_name InventoryUI
extends Control

# ── Layout constants ──────────────────────────────────────────────────────────
const SLOT_SIZE: float = 68.0
const GAP: float = 7.0
const COLS: int = 9
const PAD: float = 26.0

const GRID_W: float = COLS * (SLOT_SIZE + GAP) - GAP
const STAT_W: float = 250.0
# Item Library panel bên trái
const LIB_W: float = 345.0
const LIB_PAD: float = 10.0
const LIB_SLOT: float = 50.0
const LIB_GAP: float = 5.0
const LIB_COLS: int = 6
const LIB_SEARCH_H: float = 38.0

const EQUIP_H: float = 270.0
const DETAIL_H: float = 140.0
const CONTENT_H: float = PAD + 40 + 4 * (SLOT_SIZE + GAP) + 10 + DETAIL_H + PAD
# Tổng chiều rộng = thư viện + khoảng cách + inventory gốc
const LIB_MARGIN: float = 16.0
const CONTENT_W: float = LIB_W + LIB_MARGIN + PAD + GRID_W + 12 + STAT_W + PAD

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

# ── Inventory slots ────────────────────────────────────────────────────────────
var _inventory: Inventory = null
var _player_ref: PlayerCharacter = null
var _slots: Array[Panel] = []
var _slot_faces: Array[ColorRect] = []
var _slot_icons: Array[TextureRect] = []
var _slot_count_labels: Array[Label] = []
var _selected_slot: int = -1

# ── Stats / equip labels ───────────────────────────────────────────────────────
var _tooltip: Label
var _tooltip_bg: ColorRect
var _hp_label: Label
var _mp_label: Label
var _atk_label: Label
var _def_label: Label
var _count_label: Label
var _equip_faces: Array[ColorRect] = []
var _equip_labels: Array[Label] = []
var _equip_item_labels: Array[Label] = []
var _equip_centers: Array[Vector2] = []
var _equip_line_pairs: Array[Array] = []
var _equip_line_time: float = 0.0
var _line_layer: Control
var _equip_name_keys: Array[String] = ["EQUIP_HEAD", "EQUIP_BODY", "EQUIP_LEGS", "EQUIP_HANDS", "EQUIP_BACK", "EQUIP_SUB"]
var _equip_name_labels: Array[Label] = []
var _title_label: Label
var _stat_title_label: Label
var _drop_hint_label: Label
var _equip_title_label: Label
var _lib_title_label: Label
var _lib_hint_label: Label

# ── Detail panel ────────────────────────────────────────────────────────────────
var _detail_bg: ColorRect
var _detail_item_name: Label
var _detail_desc: Label
var _detail_stats: Label
var _detail_use_btn: Button
var _detail_drop_btn: Button

# ── Item Library ───────────────────────────────────────────────────────────────
var _item_db: Dictionary = {}           # id -> ItemDef (tất cả items)
var _lib_filter: int = -1               # -1 = All, else ItemDef.Type
var _lib_items: Array[ItemDef] = []     # danh sách hiển thị theo filter
var _lib_panels: Array[Panel] = []      # panel slots thư viện
var _lib_faces: Array[ColorRect] = []
var _lib_icon_textures: Array[TextureRect] = []
var _lib_name_labels: Array[Label] = []
var _lib_scroll_offset: int = 0         # hàng đầu tiên hiển thị
var _lib_visible_rows: int = 0
var _lib_container: Control             # container chứa slots
var _lib_scroll_up: Button
var _lib_scroll_down: Button
var _lib_filter_buttons: Array[Button] = []
var _lib_filter_keys: Array[String] = []
var _lib_search_box: LineEdit

# ── Styles ─────────────────────────────────────────────────────────────────────
var _glass_style: StyleBoxFlat
var _slot_style: StyleBoxFlat
var _slot_hl_style: StyleBoxFlat
var _lib_slot_style: StyleBoxFlat
var _lib_slot_hover_style: StyleBoxFlat

func _ready() -> void:
	size = Vector2(CONTENT_W, CONTENT_H)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glass_style = StyleBoxFlat.new()
	_glass_style.bg_color = Color(0.10, 0.10, 0.16, 0.70)
	_glass_style.corner_radius_top_left = 14; _glass_style.corner_radius_top_right = 14
	_glass_style.corner_radius_bottom_left = 14; _glass_style.corner_radius_bottom_right = 14
	_glass_style.border_width_left = 2; _glass_style.border_width_right = 2
	_glass_style.border_width_top = 2; _glass_style.border_width_bottom = 2
	_glass_style.border_color = Color(0.35, 0.28, 0.50, 0.25)

	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.10, 0.07, 0.18, 0.70)
	_slot_style.corner_radius_top_left = 4; _slot_style.corner_radius_top_right = 4
	_slot_style.corner_radius_bottom_left = 4; _slot_style.corner_radius_bottom_right = 4
	_slot_style.border_width_left = 1; _slot_style.border_width_right = 1
	_slot_style.border_width_top = 1; _slot_style.border_width_bottom = 1
	_slot_style.border_color = Color(0.35, 0.28, 0.50, 0.20)

	_slot_hl_style = _slot_style.duplicate()
	_slot_hl_style.bg_color = Color(0.30, 0.20, 0.40, 0.75)
	_slot_hl_style.border_color = Color(0.55, 0.35, 0.90, 0.40)

	_lib_slot_style = StyleBoxFlat.new()
	_lib_slot_style.bg_color = Color(0.10, 0.07, 0.18, 0.75)
	_lib_slot_style.corner_radius_top_left = 5; _lib_slot_style.corner_radius_top_right = 5
	_lib_slot_style.corner_radius_bottom_left = 5; _lib_slot_style.corner_radius_bottom_right = 5
	_lib_slot_style.border_width_left = 1; _lib_slot_style.border_width_right = 1
	_lib_slot_style.border_width_top = 1; _lib_slot_style.border_width_bottom = 1
	_lib_slot_style.border_color = Color(0.85, 0.80, 0.95, 0.08)

	_lib_slot_hover_style = _lib_slot_style.duplicate()
	_lib_slot_hover_style.bg_color = Color(0.18, 0.25, 0.40, 0.85)
	_lib_slot_hover_style.border_color = Color(0.55, 0.35, 0.90, 0.55)

	ItemDatabase.ensure_db()
	_item_db = ItemDatabase.items_db
	_lib_filter = -1
	_lib_apply_filter()

	_setup_library_panel()
	_setup_background()
	_setup_title()
	_setup_grid()
	_setup_status_panel()
	_setup_equipment_panel()
	_setup_tooltip()
	_setup_detail_panel()
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _title_label:
		_refresh_texts()

func _refresh_texts() -> void:
	_title_label.text = tr("INVENTORY_TITLE")
	_stat_title_label.text = tr("STATS_TITLE")
	_drop_hint_label.text = tr("DROP_HINT")
	_equip_title_label.text = tr("EQUIPMENT_TITLE")
	_lib_title_label.text = tr("ITEM_LIBRARY_TITLE")
	_lib_hint_label.text = tr("LIB_CLICK_HINT")
	_lib_search_box.placeholder_text = "🔍 " + tr("LIB_SEARCH_HINT")
	_detail_use_btn.text = tr("USE_ITEM")
	_detail_drop_btn.text = tr("DROP_ITEM")
	for i in range(_equip_name_labels.size()):
		_equip_name_labels[i].text = tr(_equip_name_keys[i])
	for i in range(_lib_filter_buttons.size()):
		if i < _lib_filter_keys.size():
			_lib_filter_buttons[i].text = tr(_lib_filter_keys[i])

# ── Item Library: lọc danh sách ────────────────────────────────────────────────
func _lib_apply_filter() -> void:
	_lib_items.clear()
	var search: String = _lib_search_box.text.strip_edges().to_lower() if _lib_search_box else ""
	for id in _item_db:
		var item: ItemDef = _item_db[id]
		if _lib_filter != -1 and item.type != _lib_filter:
			continue
		if not search.is_empty() and not item.id.to_lower().contains(search) and not item.name.to_lower().contains(search):
			continue
		_lib_items.append(item)
	# Sắp xếp theo type rồi theo tên
	_lib_items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.type != b.type:
			return a.type < b.type
		return a.name < b.name)
	_lib_scroll_offset = 0
	_lib_refresh_display()

func _lib_refresh_display() -> void:
	if _lib_panels.is_empty():
		return
	var total_slots: int = _lib_panels.size()
	var visible_count: int = total_slots
	var start: int = _lib_scroll_offset * LIB_COLS

	for i in range(visible_count):
		var item_idx: int = start + i
		var panel: Panel = _lib_panels[i]
		var face: ColorRect = _lib_faces[i]
		var lbl: Label = _lib_name_labels[i]
		if item_idx < _lib_items.size():
			var item: ItemDef = _lib_items[item_idx]
			face.color = item.icon_color
			var icon_tex := _lib_icon_textures[i]
			var tex := ItemDatabase.load_icon_2d(item.id)
			if tex:
				icon_tex.texture = tex
				icon_tex.visible = true
			else:
				icon_tex.texture = null
				icon_tex.visible = false
			lbl.text = item.name
			panel.visible = true
			panel.set_meta("item_idx", item_idx)
		else:
			face.color = Color(0.14, 0.10, 0.22, 0.3)
			_lib_icon_textures[i].texture = null
			_lib_icon_textures[i].visible = false
			lbl.text = ""
			panel.visible = true
			panel.set_meta("item_idx", -1)

	# Cập nhật scroll buttons
	var max_row: int = ceili(float(_lib_items.size()) / float(LIB_COLS))
	var can_up: bool = _lib_scroll_offset > 0
	var can_down: bool = (_lib_scroll_offset + _lib_visible_rows) < max_row
	if _lib_scroll_up:
		_lib_scroll_up.modulate.a = 1.0 if can_up else 0.3
		_lib_scroll_up.disabled = not can_up
	if _lib_scroll_down:
		_lib_scroll_down.modulate.a = 1.0 if can_down else 0.3
		_lib_scroll_down.disabled = not can_down

# ── Xây dựng Library Panel ────────────────────────────────────────────────────
func _setup_library_panel() -> void:
	# Panel nền thư viện
	var lib_bg_style := _glass_style.duplicate() as StyleBoxFlat
	lib_bg_style.bg_color = Color(0.10, 0.07, 0.18, 0.82)

	var lib_bg := Panel.new()
	lib_bg.position = Vector2(0, 0)
	lib_bg.size = Vector2(LIB_W, CONTENT_H)
	lib_bg.add_theme_stylebox_override("panel", lib_bg_style)
	lib_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lib_bg)

	# Tiêu đề
	_lib_title_label = Label.new()
	_lib_title_label.text = tr("ITEM_LIBRARY_TITLE")
	_lib_title_label.position = Vector2(LIB_PAD, LIB_PAD - 2)
	_lib_title_label.size = Vector2(LIB_W - LIB_PAD * 2, 22)
	_lib_title_label.add_theme_font_size_override("font_size", 22)
	_lib_title_label.add_theme_color_override("font_color", TEXT_MAIN)
	_lib_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_lib_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_lib_title_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_lib_title_label)

	_lib_hint_label = Label.new()
	_lib_hint_label.text = tr("LIB_CLICK_HINT")
	_lib_hint_label.position = Vector2(LIB_PAD, LIB_PAD + 26)
	_lib_hint_label.size = Vector2(LIB_W - LIB_PAD * 2, 18)
	_lib_hint_label.add_theme_font_size_override("font_size", 16)
	_lib_hint_label.add_theme_color_override("font_color", TEXT_MUTED)
	add_child(_lib_hint_label)

	# Filter buttons
	_setup_lib_filters()

	# Slots grid (title 30 + hint 18 + filters 2 rows 68 + gaps + search bar 38)
	var slots_y: float = LIB_PAD + 30 + 2 + 18 + 2 + 68 + 6
	var search_bar_h: float = LIB_SEARCH_H + 6
	_lib_visible_rows = int((CONTENT_H - slots_y - LIB_PAD - 30 - search_bar_h) / (LIB_SLOT + LIB_GAP))
	var total_lib_slots: int = _lib_visible_rows * LIB_COLS

	for i in range(total_lib_slots):
		var row: int = i / LIB_COLS
		var col: int = i % LIB_COLS
		var px: float = LIB_PAD + col * (LIB_SLOT + LIB_GAP)
		var py: float = slots_y + row * (LIB_SLOT + LIB_GAP)

		var panel := Panel.new()
		panel.position = Vector2(px, py)
		panel.size = Vector2(LIB_SLOT, LIB_SLOT)
		panel.add_theme_stylebox_override("panel", _lib_slot_style)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.set_meta("item_idx", -1)
		panel.gui_input.connect(_on_lib_slot_input.bind(i))
		panel.mouse_entered.connect(_on_lib_slot_entered.bind(i))
		panel.mouse_exited.connect(_on_lib_slot_exited)
		add_child(panel)
		_lib_panels.append(panel)

		var face := ColorRect.new()
		face.position = Vector2(2, 2)
		face.size = Vector2(LIB_SLOT - 4, LIB_SLOT - 25)
		face.color = Color(0.14, 0.10, 0.22, 0.3)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(face)
		_lib_faces.append(face)

		var lib_icon := TextureRect.new()
		lib_icon.position = Vector2(2, 2)
		lib_icon.size = Vector2(LIB_SLOT - 4, LIB_SLOT - 18)
		lib_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lib_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lib_icon.visible = false
		panel.add_child(lib_icon)
		_lib_icon_textures.append(lib_icon)

		var lbl := Label.new()
		lbl.position = Vector2(1, LIB_SLOT - 20)
		lbl.size = Vector2(LIB_SLOT - 2, 18)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
		lbl.clip_contents = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		_lib_name_labels.append(lbl)

	# Scroll buttons
	var scroll_y: float = slots_y + _lib_visible_rows * (LIB_SLOT + LIB_GAP) + 4
	_lib_scroll_up = _make_scroll_btn("▲", Vector2(LIB_PAD, scroll_y))
	_lib_scroll_up.pressed.connect(_on_lib_scroll.bind(-1))
	add_child(_lib_scroll_up)

	_lib_scroll_down = _make_scroll_btn("▼", Vector2(LIB_PAD + 56, scroll_y))
	_lib_scroll_down.pressed.connect(_on_lib_scroll.bind(1))
	add_child(_lib_scroll_down)

	var search_y: float = scroll_y + 38
	_lib_search_box = LineEdit.new()
	_lib_search_box.position = Vector2(LIB_PAD + 2, search_y)
	_lib_search_box.size = Vector2(LIB_W - LIB_PAD * 2 - 4, LIB_SEARCH_H)
	_lib_search_box.placeholder_text = "🔍 " + tr("LIB_SEARCH_HINT")
	_lib_search_box.add_theme_font_size_override("font_size", 18)
	_lib_search_box.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.90))
	_lib_search_box.add_theme_color_override("placeholder_color", Color(0.35, 0.32, 0.50, 0.70))
	_lib_search_box.caret_blink = true
	var search_bg := StyleBoxFlat.new()
	search_bg.bg_color = Color(0.06, 0.04, 0.12, 0.80)
	search_bg.corner_radius_top_left = 8; search_bg.corner_radius_top_right = 8
	search_bg.corner_radius_bottom_left = 8; search_bg.corner_radius_bottom_right = 8
	search_bg.border_width_left = 1; search_bg.border_width_right = 1
	search_bg.border_width_top = 1; search_bg.border_width_bottom = 1
	search_bg.border_color = Color(0.35, 0.28, 0.50, 0.25)
	_lib_search_box.add_theme_stylebox_override("normal", search_bg)
	var search_focus_bg := search_bg.duplicate() as StyleBoxFlat
	search_focus_bg.border_color = Color(0.55, 0.35, 0.90, 0.50)
	_lib_search_box.add_theme_stylebox_override("focus", search_focus_bg)
	_lib_search_box.text_changed.connect(_on_lib_search_changed)
	add_child(_lib_search_box)

	_lib_refresh_display()

func _setup_lib_filters() -> void:
	var filter_y: float = LIB_PAD + 50
	_lib_filter_keys = ["FILTER_ALL", "FILTER_BLOCK", "FILTER_WEAPON", "FILTER_ARMOR", "FILTER_FOOD", "FILTER_MATERIAL", "FILTER_TOOL"]
	var filter_types: Array = [-1, ItemDef.Type.BLOCK, ItemDef.Type.WEAPON, ItemDef.Type.ARMOR, ItemDef.Type.FOOD, ItemDef.Type.MATERIAL, ItemDef.Type.TOOL]
	var filter_colors: Array[Color] = [Color(0.55, 0.55, 0.65), Color(0.54, 0.32, 0.12), Color(0.75, 0.30, 0.30), Color(0.40, 0.60, 0.85), Color(0.30, 0.80, 0.30), Color(0.80, 0.75, 0.30), Color(0.65, 0.55, 0.40)]
	var filters: Array = []
	for fi in range(_lib_filter_keys.size()):
		filters.append([tr(_lib_filter_keys[fi]), filter_types[fi], filter_colors[fi]])

	var usable_w: float = LIB_W - LIB_PAD * 2
	var row1_count: int = 4
	var row2_count: int = 3
	var btn_w1: float = (usable_w - 3.0 * 4.0) / float(row1_count)
	var btn_w2: float = (usable_w - 2.0 * 4.0) / float(row2_count)
	var gap: float = 4.0

	for fi in range(filters.size()):
		var f: Array = filters[fi]
		var btn := Button.new()
		btn.text = f[0]
		btn.add_theme_font_size_override("font_size", 14)

		var is_row2: bool = fi >= row1_count
		var row_idx: int = 1 if is_row2 else 0
		var col_idx: int = fi - (row1_count if is_row2 else 0)
		var bw: float = btn_w2 if is_row2 else btn_w1
		btn.position = Vector2(LIB_PAD + col_idx * (bw + gap), filter_y + row_idx * 34)
		btn.size = Vector2(bw, 28)

		var btn_type: int = f[1]
		var bg := StyleBoxFlat.new()
		bg.bg_color = BG_CARD
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		bg.border_color = (f[2] as Color).darkened(0.3)
		btn.add_theme_stylebox_override("normal", bg)

		var bg_hover := bg.duplicate() as StyleBoxFlat
		bg_hover.bg_color = Color(0.35, 0.22, 0.50, 0.90)
		bg_hover.border_color = f[2]
		btn.add_theme_stylebox_override("hover", bg_hover)
		btn.add_theme_stylebox_override("pressed", bg_hover)
		btn.add_theme_color_override("font_color", f[2])

		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_lib_filter.bind(btn_type))
		add_child(btn)
		_lib_filter_buttons.append(btn)

func _make_scroll_btn(txt: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.position = pos
	btn.size = Vector2(50, 28)
	btn.add_theme_font_size_override("font_size", 20)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.10, 0.22, 0.75)
	bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.40, 0.32, 0.55, 0.25)
	btn.add_theme_stylebox_override("normal", bg)
	var bg_h := bg.duplicate() as StyleBoxFlat
	bg_h.bg_color = Color(0.30, 0.20, 0.40, 0.85)
	bg_h.border_color = Color(0.55, 0.35, 0.90, 0.50)
	btn.add_theme_stylebox_override("hover", bg_h)
	btn.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return btn

# ── Library events ─────────────────────────────────────────────────────────────
func _on_lib_filter(type: int) -> void:
	_lib_filter = type
	_lib_apply_filter()

func _on_lib_scroll(dir: int) -> void:
	var max_row: int = ceili(float(_lib_items.size()) / float(LIB_COLS))
	_lib_scroll_offset = clampi(_lib_scroll_offset + dir, 0, max(0, max_row - _lib_visible_rows))
	_lib_refresh_display()

func _on_lib_search_changed(text: String) -> void:
	_lib_apply_filter()

func _on_lib_slot_input(event: InputEvent, slot_i: int) -> void:
	if not visible or _inventory == null or _player_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Panel = _lib_panels[slot_i]
		var item_idx: int = panel.get_meta("item_idx", -1)
		if item_idx < 0 or item_idx >= _lib_items.size():
			return
		var item: ItemDef = _lib_items[item_idx]
		var remaining: int = _inventory.add_item(item, 1)
		if remaining == 0:
			# Hiệu ứng flash xanh nhẹ
			panel.add_theme_stylebox_override("panel", _lib_slot_hover_style)
			var tween := create_tween()
			tween.tween_interval(0.15)
			tween.tween_callback(func(): panel.add_theme_stylebox_override("panel", _lib_slot_style))
		accept_event()

func _on_lib_slot_entered(slot_i: int) -> void:
	var panel: Panel = _lib_panels[slot_i]
	var item_idx: int = panel.get_meta("item_idx", -1)
	if item_idx < 0 or item_idx >= _lib_items.size():
		_tooltip.visible = false; _tooltip_bg.visible = false
		return
	panel.add_theme_stylebox_override("panel", _lib_slot_hover_style)
	var item: ItemDef = _lib_items[item_idx]
	var tt: String = item.name
	if item.desc.length() > 0: tt += "\n" + item.desc
	if item.atk_bonus > 0: tt += "\n" + tr("STAT_ATK_BONUS") % item.atk_bonus
	if item.def_bonus > 0: tt += "\n" + tr("STAT_DEF_BONUS") % item.def_bonus
	if item.heal_amount > 0: tt += "\n" + tr("STAT_HEAL") % item.heal_amount
	tt += "\n[" + item.get_type_name() + "]"
	if item.type == ItemDef.Type.ARMOR: tt += " [" + item.get_armor_slot_name() + "]"
	tt += "\n" + tr("TOOLTIP_CLICK_ADD")
	_tooltip.text = tt
	_tooltip_bg.size = _tooltip.size + Vector2(8, 8)
	_tooltip_bg.visible = true
	_tooltip.visible = true

func _on_lib_slot_exited() -> void:
	# Reset hover style cho tất cả
	for i in range(_lib_panels.size()):
		_lib_panels[i].add_theme_stylebox_override("panel", _lib_slot_style)
	_tooltip.visible = false
	_tooltip_bg.visible = false

# ── Inventory background & title (offset sang phải LIB_W + LIB_MARGIN) ────────
func _setup_background() -> void:
	var ox: float = LIB_W + LIB_MARGIN  # offset X cho phần inventory
	var inv_w: float = PAD + GRID_W + 12 + STAT_W + PAD

	var bg := Panel.new()
	bg.position = Vector2(ox, 0)
	bg.size = Vector2(inv_w, CONTENT_H)
	bg.add_theme_stylebox_override("panel", _glass_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	var ox: float = LIB_W + LIB_MARGIN

	_title_label = Label.new()
	_title_label.text = tr("INVENTORY_TITLE")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0, 0.90))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.position = Vector2(ox + PAD, PAD - 2)
	_title_label.size = Vector2(260, 36)
	add_child(_title_label)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", Color(0.35, 0.32, 0.50, 0.70))
	_count_label.position = Vector2(ox + PAD + 286, PAD + 1)
	_count_label.size = Vector2(230, 20)
	add_child(_count_label)

func _setup_grid() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var grid_y: float = PAD + 40
	var rows: int = 4

	for row in range(rows):
		for col in range(COLS):
			var i: int = row * COLS + col
			var px: float = ox + PAD + col * (SLOT_SIZE + GAP)
			var py: float = grid_y + row * (SLOT_SIZE + GAP)

			var panel := Panel.new()
			panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			panel.position = Vector2(px, py)
			panel.add_theme_stylebox_override("panel", _slot_style)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.gui_input.connect(_on_slot_gui_input.bind(i))
			panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
			panel.mouse_exited.connect(_on_slot_mouse_exited)
			add_child(panel)

			var face := ColorRect.new()
			face.position = Vector2(2, 2)
			face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
			face.color = Color(0.20, 0.15, 0.30, 0.4)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(face)
			_slot_faces.append(face)

			var slot_icon := TextureRect.new()
			slot_icon.position = Vector2(2, 2)
			slot_icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
			slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_icon.visible = false
			panel.add_child(slot_icon)
			_slot_icons.append(slot_icon)

			var cnt := Label.new()
			cnt.position = Vector2(2, SLOT_SIZE - 24)
			cnt.size = Vector2(SLOT_SIZE - 4, 18)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.add_theme_font_size_override("font_size", 18)
			cnt.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.70))
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(cnt)
			_slot_count_labels.append(cnt)

			_slots.append(panel)

func _setup_status_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var sx: float = ox + PAD + GRID_W + 12
	var sy: float = PAD + 40

	var stat := Panel.new()
	stat.position = Vector2(sx, sy)
	stat.size = Vector2(STAT_W, 180)
	var st_style := _glass_style.duplicate() as StyleBoxFlat
	st_style.bg_color = Color(0.10, 0.07, 0.18, 0.45)
	st_style.corner_radius_top_left = 12; st_style.corner_radius_top_right = 12
	st_style.corner_radius_bottom_left = 12; st_style.corner_radius_bottom_right = 12
	stat.add_theme_stylebox_override("panel", st_style)
	add_child(stat)

	_stat_title_label = Label.new()
	_stat_title_label.text = tr("STATS_TITLE")
	_stat_title_label.position = Vector2(sx + 12, sy + 8)
	_stat_title_label.add_theme_font_size_override("font_size", 24)
	_stat_title_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
	add_child(_stat_title_label)

	_hp_label = Label.new(); _hp_label.position = Vector2(sx + 12, sy + 44)
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", TEAL); add_child(_hp_label)

	_mp_label = Label.new(); _mp_label.position = Vector2(sx + 12, sy + 70)
	_mp_label.add_theme_font_size_override("font_size", 20)
	_mp_label.add_theme_color_override("font_color", PURPLE); add_child(_mp_label)

	_atk_label = Label.new(); _atk_label.position = Vector2(sx + 12, sy + 96)
	_atk_label.add_theme_font_size_override("font_size", 20)
	_atk_label.add_theme_color_override("font_color", PINK); add_child(_atk_label)

	_def_label = Label.new(); _def_label.position = Vector2(sx + 12, sy + 122)
	_def_label.add_theme_font_size_override("font_size", 20)
	_def_label.add_theme_color_override("font_color", ORANGE); add_child(_def_label)

	_drop_hint_label = Label.new()
	_drop_hint_label.text = tr("DROP_HINT")
	_drop_hint_label.position = Vector2(sx + 12, sy + 156)
	_drop_hint_label.add_theme_font_size_override("font_size", 16)
	_drop_hint_label.add_theme_color_override("font_color", TEXT_MUTED)
	add_child(_drop_hint_label)

func _setup_equipment_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var sx: float = ox + PAD + GRID_W + 12
	var sy: float = PAD + 40 + 180 + 6

	var eq := Panel.new()
	eq.position = Vector2(sx, sy)
	eq.size = Vector2(STAT_W, EQUIP_H)
	eq.clip_contents = true
	var eq_style := _glass_style.duplicate() as StyleBoxFlat
	eq_style.bg_color = Color(0.10, 0.07, 0.18, 0.45)
	eq_style.corner_radius_top_left = 12; eq_style.corner_radius_top_right = 12
	eq_style.corner_radius_bottom_left = 12; eq_style.corner_radius_bottom_right = 12
	eq.add_theme_stylebox_override("panel", eq_style)
	add_child(eq)

	_equip_title_label = Label.new()
	_equip_title_label.text = tr("EQUIPMENT_TITLE")
	_equip_title_label.position = Vector2(16, 10)
	_equip_title_label.add_theme_font_size_override("font_size", 24)
	_equip_title_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
	eq.add_child(_equip_title_label)

	var esize: float = 60.0
	var egap: float = 6.0
	var slot_w: float = esize + egap
	var row_h: float = esize + 18
	var gx: float = (STAT_W - slot_w * 2) * 0.5
	var gy: float = 34.0

	var hex_colors: Array[Color] = [
		PURPLE,
		TEAL,
		PINK,
		ORANGE,
		Color(0.70, 0.50, 0.90),
		CYAN,
	]

	var slot_positions: Array[Vector2] = [
		Vector2(gx, gy),
		Vector2(gx + slot_w, gy),
		Vector2(gx, gy + row_h),
		Vector2(gx + slot_w, gy + row_h),
		Vector2(gx, gy + row_h * 2),
		Vector2(gx + slot_w, gy + row_h * 2),
	]

	var face_style := StyleBoxFlat.new()
	face_style.bg_color = Color(0.14, 0.10, 0.22, 0.7)
	face_style.corner_radius_top_left = 8
	face_style.corner_radius_top_right = 8
	face_style.corner_radius_bottom_left = 8
	face_style.corner_radius_bottom_right = 8
	face_style.border_width_left = 2
	face_style.border_width_right = 2
	face_style.border_width_top = 2
	face_style.border_width_bottom = 2
	face_style.border_color = Color(0.40, 0.32, 0.55, 0.25)

	_equip_item_labels.clear()
	for i in range(6):
		var px: float = slot_positions[i].x
		var py: float = slot_positions[i].y

		var panel := Panel.new()
		panel.position = Vector2(px, py)
		panel.size = Vector2(esize, esize)
		panel.add_theme_stylebox_override("panel", face_style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eq.add_child(panel)

		var face := ColorRect.new()
		face.position = Vector2(2, 2)
		face.size = Vector2(esize - 4, esize - 4)
		face.color = Color(0.25, 0.18, 0.35, 0.6)
		face.pivot_offset = Vector2((esize - 4) * 0.5, (esize - 4) * 0.5)
		face.rotation = deg_to_rad(45)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(face)
		_equip_faces.append(face)

		var item_lbl := Label.new()
		item_lbl.position = Vector2.ZERO
		item_lbl.size = Vector2(esize, esize)
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_lbl.add_theme_font_size_override("font_size", 14)
		item_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0, 0.90))
		item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(item_lbl)
		_equip_item_labels.append(item_lbl)

		var name_lbl := Label.new()
		name_lbl.text = tr(_equip_name_keys[i])
		name_lbl.position = Vector2(px, py + esize + 2)
		name_lbl.size = Vector2(esize, 16)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.55))
		eq.add_child(name_lbl)
		_equip_name_labels.append(name_lbl)

	# ── Connecting lines ───────────────────────────────────────────
	var line_layer := Control.new()
	_line_layer = line_layer
	line_layer.name = "EquipLineLayer"
	line_layer.position = Vector2.ZERO
	line_layer.size = Vector2(STAT_W, EQUIP_H)
	line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq.add_child(line_layer)

	for sp in slot_positions:
		_equip_centers.append(sp + Vector2(esize * 0.5, esize * 0.5))
	_equip_line_pairs = [
		[0, 1], [2, 3], [4, 5],
		[0, 2], [2, 4], [1, 3], [3, 5],
	]

	line_layer.draw.connect(func():
		if _equip_centers.is_empty(): return
		var lc := Color(0.55, 0.35, 0.90, 0.60)
		var dl: float = 6.0; var gl: float = 5.0; var tl: float = dl + gl
		var ph: float = fmod(_equip_line_time, tl)
		for pair in _equip_line_pairs:
			var a: Vector2 = _equip_centers[pair[0]]
			var b: Vector2 = _equip_centers[pair[1]]
			var dv: Vector2 = b - a
			var sl: float = dv.length()
			var dn: Vector2 = dv / sl
			var d: float = -ph
			while d < sl:
				var ds: float = max(d, 0.0)
				var de: float = min(d + dl, sl)
				if de > ds:
					line_layer.draw_line(a + dn * ds, a + dn * de, lc, 2.5, true)
				d += tl
	)

func _setup_tooltip() -> void:
	_tooltip_bg = ColorRect.new()
	_tooltip_bg.color = Color(0.06, 0.04, 0.12, 0.90)
	_tooltip_bg.visible = false
	_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_bg)

	_tooltip = Label.new()
	_tooltip.position = Vector2.ZERO
	_tooltip.size = Vector2(360, 100)
	_tooltip.add_theme_font_size_override("font_size", 20)
	_tooltip.add_theme_color_override("font_color", TEXT_BRIGHT)
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

# ── Detail panel ────────────────────────────────────────────────────────────────
func _setup_detail_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var grid_y: float = PAD + 40
	var dy: float = grid_y + 4 * (SLOT_SIZE + GAP) + 10
	var dw: float = GRID_W
	var dx: float = ox + PAD

	_detail_bg = ColorRect.new()
	_detail_bg.position = Vector2(dx, dy)
	_detail_bg.size = Vector2(dw, DETAIL_H)
	_detail_bg.color = Color(0.10, 0.07, 0.18, 0.50)
	_detail_bg.visible = false
	_detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_bg)

	_detail_item_name = Label.new()
	_detail_item_name.position = Vector2(dx + 8, dy + 6)
	_detail_item_name.size = Vector2(dw - 16, 28)
	_detail_item_name.add_theme_font_size_override("font_size", 26)
	_detail_item_name.add_theme_color_override("font_color", TEXT_BRIGHT)
	_detail_item_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_detail_item_name.add_theme_constant_override("shadow_offset_x", 1)
	_detail_item_name.add_theme_constant_override("shadow_offset_y", 1)
	_detail_item_name.visible = false
	add_child(_detail_item_name)

	_detail_desc = Label.new()
	_detail_desc.position = Vector2(dx + 8, dy + 38)
	_detail_desc.size = Vector2(dw - 16, 46)
	_detail_desc.add_theme_font_size_override("font_size", 18)
	_detail_desc.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.85))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.visible = false
	add_child(_detail_desc)

	_detail_stats = Label.new()
	_detail_stats.position = Vector2(dx + 8, dy + 80)
	_detail_stats.size = Vector2(dw - 16, 20)
	_detail_stats.add_theme_font_size_override("font_size", 18)
	_detail_stats.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.80))
	_detail_stats.visible = false
	add_child(_detail_stats)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.10, 0.22, 0.85)
	btn_style.corner_radius_top_left = 6; btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6; btn_style.corner_radius_bottom_right = 6
	btn_style.border_width_left = 1; btn_style.border_width_right = 1
	btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.40, 0.32, 0.58, 0.35)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.35, 0.22, 0.50, 0.95)
	btn_hover.border_color = Color(0.55, 0.35, 0.90, 0.55)

	var btn_y: float = dy + DETAIL_H - 40

	_detail_use_btn = Button.new()
	_detail_use_btn.text = tr("USE_ITEM")
	_detail_use_btn.position = Vector2(dx + dw - 200, btn_y)
	_detail_use_btn.size = Vector2(90, 30)
	_detail_use_btn.add_theme_font_size_override("font_size", 18)
	_detail_use_btn.add_theme_color_override("font_color", TEAL)
	_detail_use_btn.add_theme_stylebox_override("normal", btn_style)
	_detail_use_btn.add_theme_stylebox_override("hover", btn_hover)
	_detail_use_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_use_btn.pressed.connect(_on_detail_use)
	_detail_use_btn.visible = false
	add_child(_detail_use_btn)

	_detail_drop_btn = Button.new()
	_detail_drop_btn.text = tr("DROP_ITEM")
	_detail_drop_btn.position = Vector2(dx + dw - 105, btn_y)
	_detail_drop_btn.size = Vector2(95, 30)
	_detail_drop_btn.add_theme_font_size_override("font_size", 18)
	_detail_drop_btn.add_theme_color_override("font_color", Color(0.82, 0.28, 0.52, 0.90))
	_detail_drop_btn.add_theme_stylebox_override("normal", btn_style)
	_detail_drop_btn.add_theme_stylebox_override("hover", btn_hover)
	_detail_drop_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_drop_btn.pressed.connect(_on_detail_drop)
	_detail_drop_btn.visible = false
	add_child(_detail_drop_btn)

func _update_detail_panel() -> void:
	var has_selection: bool = false
	if _inventory != null and _selected_slot >= 0 and _selected_slot < _inventory.slots.size():
		var slot: ItemSlot = _inventory.slots[_selected_slot]
		if not slot.is_empty():
			has_selection = true
			var item: ItemDef = slot.item
			_detail_item_name.text = item.name
			_detail_desc.text = item.desc if item.desc.length() > 0 else "(" + item.get_type_name() + ")"
			var stats_text: String = ""
			if item.atk_bonus > 0:  stats_text += tr("STAT_ATK_BONUS") % item.atk_bonus + "  "
			if item.def_bonus > 0:  stats_text += tr("STAT_DEF_BONUS") % item.def_bonus + "  "
			if item.heal_amount > 0: stats_text += tr("STAT_HEAL") % item.heal_amount
			_detail_stats.text = stats_text
			var can_use: bool = item.type in [ItemDef.Type.FOOD, ItemDef.Type.WEAPON, ItemDef.Type.TOOL, ItemDef.Type.ARMOR]
			_detail_use_btn.visible = can_use
			_detail_item_name.visible = true
			_detail_desc.visible = true
			_detail_stats.visible = true
			_detail_drop_btn.visible = true
			_detail_bg.visible = true

	if not has_selection:
		_detail_bg.visible = false
		_detail_item_name.visible = false
		_detail_desc.visible = false
		_detail_stats.visible = false
		_detail_use_btn.visible = false
		_detail_drop_btn.visible = false

func _on_detail_use() -> void:
	if _player_ref == null or _inventory == null: return
	var idx: int = _selected_slot
	if idx < 0 or idx >= _inventory.slots.size(): return
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty(): return
	_player_ref.use_item_from_inventory(idx)
	# After use, the slot may be empty (e.g. food consumed)
	if slot.is_empty():
		_selected_slot = -1
		_clear_selection()

func _on_detail_drop() -> void:
	if _player_ref == null or _inventory == null: return
	var idx: int = _selected_slot
	if idx < 0 or idx >= _inventory.slots.size(): return
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty(): return
	_player_ref.drop_item(idx)
	_selected_slot = -1
	_clear_selection()

# ── Inventory slot events ──────────────────────────────────────────────────────
func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not visible or _inventory == null: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(idx); accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(idx); accept_event()

func _handle_left_click(idx: int) -> void:
	if _inventory.slots[idx].is_empty():
		_selected_slot = -1; _clear_selection(); return
	var player := _player_ref
	if player == null or not player._inventory_open: return
	var held: Dictionary = player._held_item
	if held.is_empty():
		player._held_item = {"from_idx": idx}; _selected_slot = idx; _highlight_slot(idx)
	else:
		var from_idx: int = held.from_idx
		if from_idx == idx:
			player._held_item = {}; _selected_slot = -1; _clear_selection(); return
		if _inventory.can_transfer(from_idx, idx): _inventory.transfer(from_idx, idx)
		else: _inventory.swap(from_idx, idx)
		player._held_item = {}; _selected_slot = -1; _clear_selection()

func _handle_right_click(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty(): return
	var player := _player_ref
	if player == null: return
	_selected_slot = idx; _highlight_slot(idx)
	player.use_item_from_inventory(idx)

func _on_slot_mouse_entered(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty(): _tooltip.visible = false; _tooltip_bg.visible = false; return
	var tt: String = slot.item.name
	if slot.item.desc.length() > 0: tt += "\n" + slot.item.desc
	if slot.item.atk_bonus > 0: tt += "\n" + tr("STAT_ATK_BONUS") % slot.item.atk_bonus
	if slot.item.def_bonus > 0: tt += "\n" + tr("STAT_DEF_BONUS") % slot.item.def_bonus
	if slot.item.heal_amount > 0: tt += "\n" + tr("STAT_HEAL") % slot.item.heal_amount
	var tn: String = slot.item.get_type_name()
	if tn.length() > 0: tt += "\n[" + tn + "]"
	if slot.item.type == ItemDef.Type.ARMOR: tt += "\n[" + slot.item.get_armor_slot_name() + "]"
	_tooltip.text = tt
	_tooltip_bg.size = _tooltip.size + Vector2(8, 8)
	_tooltip_bg.visible = true; _tooltip.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false; _tooltip_bg.visible = false

func _highlight_slot(idx: int) -> void:
	for i in range(_slots.size()):
		_slots[i].add_theme_stylebox_override("panel", _slot_hl_style if i == idx else _slot_style)

func _clear_selection() -> void:
	for i in range(_slots.size()):
		_slots[i].add_theme_stylebox_override("panel", _slot_style)

func set_inventory(inv: Inventory) -> void:
	_inventory = inv

func set_player(p: PlayerCharacter) -> void:
	_player_ref = p

func _process(delta: float) -> void:
	if _inventory == null: return
	for i in range(_inventory.slots.size()):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			var col = Color(0.20,0.15,0.30,0.4) if i != _selected_slot else Color(0.30,0.20,0.40,0.5)
			_slot_faces[i].color = col; _slot_count_labels[i].text = ""
			_slot_icons[i].texture = null; _slot_icons[i].visible = false
		else:
			_slot_faces[i].color = slot.item.icon_color
			var tex := ItemDatabase.load_icon_2d(slot.item.id)
			if tex:
				_slot_icons[i].texture = tex
				_slot_icons[i].visible = true
			else:
				_slot_icons[i].texture = null
				_slot_icons[i].visible = false
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""

	if _player_ref:
		_hp_label.text  = "HP: %d / %d"   % [_player_ref.hp, _player_ref.max_hp]
		_mp_label.text  = "MANA: %d / %d" % [_player_ref.mana, _player_ref.max_mana]
		_atk_label.text = "ATK: %d"        % _player_ref.get_total_atk()
		_def_label.text = "DEF: %d"        % _player_ref.get_total_def()
		_update_equipment_display(_player_ref)

	_update_detail_panel()

	var filled: int = _inventory.count_filled_slots()
	_count_label.text = "Used: %d / %d" % [filled, _inventory.slots.size()]

	_equip_line_time += delta * 2.0
	if _line_layer:
		_line_layer.queue_redraw()

	if _tooltip.visible:
		var mp: Vector2 = get_global_mouse_position()
		_tooltip.position = mp + Vector2(16, 16)
		_tooltip_bg.position = mp + Vector2(14, 14)

func _update_equipment_display(player: PlayerCharacter) -> void:
	var equipped: Array = [player.equipped_head, player.equipped_body, player.equipped_legs, player.equipped_hands, player.equipped_back, player.equipped_sub]
	for i in range(6):
		var item: ItemDef = equipped[i] as ItemDef
		if item != null:
			_equip_faces[i].color = item.icon_color
			_equip_item_labels[i].text = item.name.substr(0, 6)
		else:
			_equip_faces[i].color = Color(0.25, 0.18, 0.35, 0.6)
			_equip_item_labels[i].text = ""
