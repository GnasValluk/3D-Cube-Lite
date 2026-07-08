## InventoryUI – Kho đồ người chơi + Thư viện vật phẩm bên trái
class_name InventoryUI
extends Control

# ── Layout constants ──────────────────────────────────────────────────────────
const SLOT_SIZE: float = 50.0
const GAP: float = 5.0
const COLS: int = 9
const PAD: float = 18.0

const GRID_W: float = COLS * (SLOT_SIZE + GAP) - GAP
const STAT_W: float = 190.0
# Item Library panel bên trái
const LIB_W: float = 256.0
const LIB_PAD: float = 10.0
const LIB_SLOT: float = 36.0
const LIB_GAP: float = 3.0
const LIB_COLS: int = 6

const EQUIP_H: float = 154.0
const DETAIL_H: float = 110.0
const CONTENT_H: float = PAD + 40 + 4 * (SLOT_SIZE + GAP) + 10 + DETAIL_H + PAD
# Tổng chiều rộng = thư viện + khoảng cách + inventory gốc
const LIB_MARGIN: float = 12.0
const CONTENT_W: float = LIB_W + LIB_MARGIN + PAD + GRID_W + 12 + STAT_W + PAD

# ── Inventory slots ────────────────────────────────────────────────────────────
var _inventory: Inventory = null
var _player_ref: PlayerCharacter = null
var _slots: Array[Panel] = []
var _slot_faces: Array[ColorRect] = []
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
var _equip_names: Array[String] = ["Head", "Body", "Legs", "Feet"]

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
var _lib_name_labels: Array[Label] = []
var _lib_scroll_offset: int = 0         # hàng đầu tiên hiển thị
var _lib_visible_rows: int = 0
var _lib_container: Control             # container chứa slots
var _lib_scroll_up: Button
var _lib_scroll_down: Button
var _lib_filter_buttons: Array[Button] = []

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
	_glass_style.corner_radius_top_left = 10; _glass_style.corner_radius_top_right = 10
	_glass_style.corner_radius_bottom_left = 10; _glass_style.corner_radius_bottom_right = 10
	_glass_style.border_width_left = 1; _glass_style.border_width_right = 1
	_glass_style.border_width_top = 1; _glass_style.border_width_bottom = 1
	_glass_style.border_color = Color(1, 1, 1, 0.12)

	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.08, 0.08, 0.14, 0.70)
	_slot_style.corner_radius_top_left = 4; _slot_style.corner_radius_top_right = 4
	_slot_style.corner_radius_bottom_left = 4; _slot_style.corner_radius_bottom_right = 4
	_slot_style.border_width_left = 1; _slot_style.border_width_right = 1
	_slot_style.border_width_top = 1; _slot_style.border_width_bottom = 1
	_slot_style.border_color = Color(1, 1, 1, 0.10)

	_slot_hl_style = _slot_style.duplicate()
	_slot_hl_style.bg_color = Color(0.20, 0.22, 0.34, 0.75)
	_slot_hl_style.border_color = Color(0.40, 0.55, 0.90, 0.40)

	_lib_slot_style = StyleBoxFlat.new()
	_lib_slot_style.bg_color = Color(0.08, 0.10, 0.16, 0.75)
	_lib_slot_style.corner_radius_top_left = 5; _lib_slot_style.corner_radius_top_right = 5
	_lib_slot_style.corner_radius_bottom_left = 5; _lib_slot_style.corner_radius_bottom_right = 5
	_lib_slot_style.border_width_left = 1; _lib_slot_style.border_width_right = 1
	_lib_slot_style.border_width_top = 1; _lib_slot_style.border_width_bottom = 1
	_lib_slot_style.border_color = Color(1, 1, 1, 0.08)

	_lib_slot_hover_style = _lib_slot_style.duplicate()
	_lib_slot_hover_style.bg_color = Color(0.18, 0.25, 0.40, 0.85)
	_lib_slot_hover_style.border_color = Color(0.45, 0.65, 1.0, 0.55)

	_item_db = Inventory.create_item_db()
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

# ── Item Library: lọc danh sách ────────────────────────────────────────────────
func _lib_apply_filter() -> void:
	_lib_items.clear()
	for id in _item_db:
		var item: ItemDef = _item_db[id]
		if _lib_filter == -1 or item.type == _lib_filter:
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
			lbl.text = item.name
			panel.visible = true
			panel.set_meta("item_idx", item_idx)
		else:
			face.color = Color(0.12, 0.12, 0.18, 0.3)
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
	lib_bg_style.bg_color = Color(0.08, 0.09, 0.15, 0.82)

	var lib_bg := Panel.new()
	lib_bg.position = Vector2(0, 0)
	lib_bg.size = Vector2(LIB_W, CONTENT_H)
	lib_bg.add_theme_stylebox_override("panel", lib_bg_style)
	lib_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lib_bg)

	# Tiêu đề
	var lib_title := Label.new()
	lib_title.text = tr("ITEM_LIBRARY_TITLE")
	lib_title.position = Vector2(LIB_PAD, LIB_PAD - 2)
	lib_title.size = Vector2(LIB_W - LIB_PAD * 2, 22)
	lib_title.add_theme_font_size_override("font_size", 14)
	lib_title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 0.95))
	lib_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lib_title.add_theme_constant_override("shadow_offset_x", 1)
	lib_title.add_theme_constant_override("shadow_offset_y", 1)
	add_child(lib_title)

	var hint := Label.new()
	hint.text = tr("LIB_CLICK_HINT")
	hint.position = Vector2(LIB_PAD, LIB_PAD + 20)
	hint.size = Vector2(LIB_W - LIB_PAD * 2, 14)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.30))
	add_child(hint)

	# Filter buttons
	_setup_lib_filters()

	# Slots grid (title 22 + hint 14 + filters 2 rows 52 + gaps)
	var slots_y: float = LIB_PAD + 22 + 2 + 14 + 2 + 52 + 6
	_lib_visible_rows = int((CONTENT_H - slots_y - LIB_PAD - 30) / (LIB_SLOT + LIB_GAP))
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
		face.size = Vector2(LIB_SLOT - 4, LIB_SLOT - 18)
		face.color = Color(0.12, 0.12, 0.18, 0.3)
		panel.add_child(face)
		_lib_faces.append(face)

		var lbl := Label.new()
		lbl.position = Vector2(1, LIB_SLOT - 15)
		lbl.size = Vector2(LIB_SLOT - 2, 14)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
		lbl.clip_contents = true
		panel.add_child(lbl)
		_lib_name_labels.append(lbl)

	# Scroll buttons
	var scroll_y: float = slots_y + _lib_visible_rows * (LIB_SLOT + LIB_GAP) + 4
	_lib_scroll_up = _make_scroll_btn("▲", Vector2(LIB_PAD, scroll_y))
	_lib_scroll_up.pressed.connect(_on_lib_scroll.bind(-1))
	add_child(_lib_scroll_up)

	_lib_scroll_down = _make_scroll_btn("▼", Vector2(LIB_PAD + 46, scroll_y))
	_lib_scroll_down.pressed.connect(_on_lib_scroll.bind(1))
	add_child(_lib_scroll_down)

	_lib_refresh_display()

func _setup_lib_filters() -> void:
	var filter_y: float = LIB_PAD + 38
	var filter_keys: Array[String] = ["FILTER_ALL", "FILTER_BLOCK", "FILTER_WEAPON", "FILTER_ARMOR", "FILTER_FOOD", "FILTER_MATERIAL", "FILTER_TOOL"]
	var filter_types: Array = [-1, ItemDef.Type.BLOCK, ItemDef.Type.WEAPON, ItemDef.Type.ARMOR, ItemDef.Type.FOOD, ItemDef.Type.MATERIAL, ItemDef.Type.TOOL]
	var filter_colors: Array[Color] = [Color(0.55, 0.55, 0.65), Color(0.54, 0.32, 0.12), Color(0.75, 0.30, 0.30), Color(0.40, 0.60, 0.85), Color(0.30, 0.80, 0.30), Color(0.80, 0.75, 0.30), Color(0.65, 0.55, 0.40)]
	var filters: Array = []
	for fi in range(filter_keys.size()):
		filters.append([tr(filter_keys[fi]), filter_types[fi], filter_colors[fi]])

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
		btn.add_theme_font_size_override("font_size", 9)

		var is_row2: bool = fi >= row1_count
		var row_idx: int = 1 if is_row2 else 0
		var col_idx: int = fi - (row1_count if is_row2 else 0)
		var bw: float = btn_w2 if is_row2 else btn_w1
		btn.position = Vector2(LIB_PAD + col_idx * (bw + gap), filter_y + row_idx * 26)
		btn.size = Vector2(bw, 22)

		var btn_type: int = f[1]
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.10, 0.10, 0.18, 0.75)
		bg.corner_radius_top_left = 4; bg.corner_radius_top_right = 4
		bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
		bg.border_width_left = 1; bg.border_width_right = 1
		bg.border_width_top = 1; bg.border_width_bottom = 1
		bg.border_color = (f[2] as Color).darkened(0.3)
		btn.add_theme_stylebox_override("normal", bg)

		var bg_hover := bg.duplicate() as StyleBoxFlat
		bg_hover.bg_color = Color(0.18, 0.22, 0.38, 0.90)
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
	btn.size = Vector2(40, 22)
	btn.add_theme_font_size_override("font_size", 13)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.20, 0.75)
	bg.corner_radius_top_left = 4; bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(1, 1, 1, 0.15)
	btn.add_theme_stylebox_override("normal", bg)
	var bg_h := bg.duplicate() as StyleBoxFlat
	bg_h.bg_color = Color(0.20, 0.25, 0.40, 0.85)
	bg_h.border_color = Color(0.45, 0.65, 1.0, 0.50)
	btn.add_theme_stylebox_override("hover", bg_h)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
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
	if item.atk_bonus > 0: tt += "\nATK: +" + str(item.atk_bonus)
	if item.def_bonus > 0: tt += "\nDEF: +" + str(item.def_bonus)
	if item.heal_amount > 0: tt += "\nHồi: +" + str(item.heal_amount) + " HP"
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

	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(ox + PAD, PAD - 2)
	title.size = Vector2(200, 28)
	add_child(title)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_count_label.position = Vector2(ox + PAD + 220, PAD + 1)
	_count_label.size = Vector2(180, 16)
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
			face.color = Color(0.15, 0.15, 0.22, 0.4)
			panel.add_child(face)
			_slot_faces.append(face)

			var cnt := Label.new()
			cnt.position = Vector2(2, SLOT_SIZE - 18)
			cnt.size = Vector2(SLOT_SIZE - 4, 14)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.add_theme_font_size_override("font_size", 11)
			cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
			panel.add_child(cnt)
			_slot_count_labels.append(cnt)

			_slots.append(panel)

func _setup_status_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var sx: float = ox + PAD + GRID_W + 12
	var sy: float = PAD + 40

	var stat := Panel.new()
	stat.position = Vector2(sx, sy)
	stat.size = Vector2(STAT_W, 140)
	var st_style := _glass_style.duplicate() as StyleBoxFlat
	st_style.bg_color = Color(0.08, 0.08, 0.14, 0.45)
	st_style.corner_radius_top_left = 8; st_style.corner_radius_top_right = 8
	st_style.corner_radius_bottom_left = 8; st_style.corner_radius_bottom_right = 8
	stat.add_theme_stylebox_override("panel", st_style)
	add_child(stat)

	var stat_title := Label.new()
	stat_title.text = "Stats"
	stat_title.position = Vector2(sx + 12, sy + 8)
	stat_title.add_theme_font_size_override("font_size", 15)
	stat_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	add_child(stat_title)

	_hp_label = Label.new(); _hp_label.position = Vector2(sx + 12, sy + 34)
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.30)); add_child(_hp_label)

	_mp_label = Label.new(); _mp_label.position = Vector2(sx + 12, sy + 54)
	_mp_label.add_theme_font_size_override("font_size", 13)
	_mp_label.add_theme_color_override("font_color", Color(0.30, 0.55, 0.95)); add_child(_mp_label)

	_atk_label = Label.new(); _atk_label.position = Vector2(sx + 12, sy + 74)
	_atk_label.add_theme_font_size_override("font_size", 13)
	_atk_label.add_theme_color_override("font_color", Color(0.85, 0.60, 0.25)); add_child(_atk_label)

	_def_label = Label.new(); _def_label.position = Vector2(sx + 12, sy + 94)
	_def_label.add_theme_font_size_override("font_size", 13)
	_def_label.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55)); add_child(_def_label)

	var dh := Label.new()
	dh.text = tr("DROP_HINT")
	dh.position = Vector2(sx + 12, sy + 120)
	dh.add_theme_font_size_override("font_size", 10)
	dh.add_theme_color_override("font_color", Color(1, 1, 1, 0.30))
	add_child(dh)

func _setup_equipment_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var sx: float = ox + PAD + GRID_W + 12
	var sy: float = PAD + 40 + 140 + 10

	var eq := Panel.new()
	eq.position = Vector2(sx, sy)
	eq.size = Vector2(STAT_W, EQUIP_H)
	var eq_style := _glass_style.duplicate() as StyleBoxFlat
	eq_style.bg_color = Color(0.08, 0.08, 0.14, 0.45)
	eq_style.corner_radius_top_left = 8; eq_style.corner_radius_top_right = 8
	eq_style.corner_radius_bottom_left = 8; eq_style.corner_radius_bottom_right = 8
	eq.add_theme_stylebox_override("panel", eq_style)
	add_child(eq)

	var eq_title := Label.new()
	eq_title.text = "Equipment"
	eq_title.position = Vector2(sx + 12, sy + 8)
	eq_title.add_theme_font_size_override("font_size", 15)
	eq_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	add_child(eq_title)

	var esize: float = 48.0; var egap: float = 6.0; var ecols: int = 2
	var gx: float = sx + 14.0; var gy: float = sy + 34.0
	var equip_colors: Array[Color] = [Color(0.40,0.70,0.95),Color(0.55,0.80,0.55),Color(0.75,0.60,0.85),Color(0.90,0.70,0.40)]
	var lx: float = gx + 2 * (esize + egap) + 8

	for i in range(4):
		var row: int = i / ecols; var col: int = i % ecols
		var px: float = gx + col * (esize + egap); var py: float = gy + row * (esize + 18)
		var panel := Panel.new(); panel.position = Vector2(px, py); panel.size = Vector2(esize, esize)
		panel.add_theme_stylebox_override("panel", _slot_style); add_child(panel)
		var face := ColorRect.new(); face.position = Vector2(2,2); face.size = Vector2(esize-4,esize-4)
		face.color = Color(0.15,0.15,0.22,0.4); panel.add_child(face); _equip_faces.append(face)
		var name_lbl := Label.new(); name_lbl.text = _equip_names[i]
		name_lbl.position = Vector2(px, py + esize + 1); name_lbl.size = Vector2(esize, 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(1,1,1,0.35)); add_child(name_lbl)
		var item_label := Label.new(); item_label.position = Vector2(lx, py + 4)
		item_label.size = Vector2(STAT_W - (lx - sx), 18)
		item_label.add_theme_font_size_override("font_size", 11)
		item_label.add_theme_color_override("font_color", equip_colors[i]); add_child(item_label)
		_equip_labels.append(item_label)

func _setup_tooltip() -> void:
	_tooltip_bg = ColorRect.new()
	_tooltip_bg.color = Color(0.06, 0.06, 0.10, 0.90)
	_tooltip_bg.visible = false
	_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_bg)

	_tooltip = Label.new()
	_tooltip.position = Vector2.ZERO
	_tooltip.size = Vector2(280, 80)
	_tooltip.add_theme_font_size_override("font_size", 13)
	_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
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
	_detail_bg.color = Color(0.08, 0.08, 0.14, 0.50)
	_detail_bg.visible = false
	_detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_bg)

	_detail_item_name = Label.new()
	_detail_item_name.position = Vector2(dx + 8, dy + 6)
	_detail_item_name.size = Vector2(dw - 16, 22)
	_detail_item_name.add_theme_font_size_override("font_size", 17)
	_detail_item_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_detail_item_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_detail_item_name.add_theme_constant_override("shadow_offset_x", 1)
	_detail_item_name.add_theme_constant_override("shadow_offset_y", 1)
	_detail_item_name.visible = false
	add_child(_detail_item_name)

	_detail_desc = Label.new()
	_detail_desc.position = Vector2(dx + 8, dy + 30)
	_detail_desc.size = Vector2(dw - 16, 36)
	_detail_desc.add_theme_font_size_override("font_size", 12)
	_detail_desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.85))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.visible = false
	add_child(_detail_desc)

	_detail_stats = Label.new()
	_detail_stats.position = Vector2(dx + 8, dy + 62)
	_detail_stats.size = Vector2(dw - 16, 16)
	_detail_stats.add_theme_font_size_override("font_size", 11)
	_detail_stats.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70, 0.80))
	_detail_stats.visible = false
	add_child(_detail_stats)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.18, 0.30, 0.85)
	btn_style.corner_radius_top_left = 4; btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4; btn_style.corner_radius_bottom_right = 4
	btn_style.border_width_left = 1; btn_style.border_width_right = 1
	btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.40, 0.55, 0.90, 0.35)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.22, 0.28, 0.45, 0.95)
	btn_hover.border_color = Color(0.45, 0.65, 1.0, 0.55)

	var btn_y: float = dy + DETAIL_H - 32

	_detail_use_btn = Button.new()
	_detail_use_btn.text = tr("USE_ITEM")
	_detail_use_btn.position = Vector2(dx + dw - 170, btn_y)
	_detail_use_btn.size = Vector2(75, 24)
	_detail_use_btn.add_theme_font_size_override("font_size", 12)
	_detail_use_btn.add_theme_color_override("font_color", Color(0.80, 0.95, 0.80, 0.90))
	_detail_use_btn.add_theme_stylebox_override("normal", btn_style)
	_detail_use_btn.add_theme_stylebox_override("hover", btn_hover)
	_detail_use_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_use_btn.pressed.connect(_on_detail_use)
	_detail_use_btn.visible = false
	add_child(_detail_use_btn)

	_detail_drop_btn = Button.new()
	_detail_drop_btn.text = tr("DROP_ITEM")
	_detail_drop_btn.position = Vector2(dx + dw - 88, btn_y)
	_detail_drop_btn.size = Vector2(80, 24)
	_detail_drop_btn.add_theme_font_size_override("font_size", 12)
	_detail_drop_btn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.55, 0.90))
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
			if item.atk_bonus > 0:  stats_text += "ATK: +" + str(item.atk_bonus) + "  "
			if item.def_bonus > 0:  stats_text += "DEF: +" + str(item.def_bonus) + "  "
			if item.heal_amount > 0: stats_text += "Heal: +" + str(item.heal_amount) + " HP"
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
	if slot.item.atk_bonus > 0: tt += "\nATK: +" + str(slot.item.atk_bonus)
	if slot.item.def_bonus > 0: tt += "\nDEF: +" + str(slot.item.def_bonus)
	if slot.item.heal_amount > 0: tt += "\nHeal: " + str(slot.item.heal_amount)
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

func _process(_delta: float) -> void:
	if _inventory == null: return
	for i in range(_inventory.slots.size()):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			var col = Color(0.15,0.15,0.22,0.4) if i != _selected_slot else Color(0.25,0.28,0.40,0.5)
			_slot_faces[i].color = col; _slot_count_labels[i].text = ""
		else:
			_slot_faces[i].color = slot.item.icon_color
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

	if _tooltip.visible:
		var mp: Vector2 = get_global_mouse_position()
		_tooltip.position = mp + Vector2(16, 16)
		_tooltip_bg.position = mp + Vector2(14, 14)

func _update_equipment_display(player: PlayerCharacter) -> void:
	var equipped: Array = [player.equipped_head, player.equipped_body, player.equipped_legs, player.equipped_feet]
	for i in range(4):
		var item: ItemDef = equipped[i] as ItemDef
		if item != null:
			_equip_faces[i].color = item.icon_color; _equip_labels[i].text = item.name
		else:
			_equip_faces[i].color = Color(0.15, 0.15, 0.22, 0.4); _equip_labels[i].text = ""
