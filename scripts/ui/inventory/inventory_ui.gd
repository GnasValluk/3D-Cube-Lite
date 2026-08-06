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
const _Library := preload("item_library_panel.gd")
const _Detail := preload("item_detail_panel.gd")

const EQUIP_H: float = 270.0
const DETAIL_H: float = 140.0
const STAT_PANEL_H: float = 296.0
const CONTENT_H: float = PAD + 40 + STAT_PANEL_H + 10 + EQUIP_H + PAD
# Tổng chiều rộng = thư viện + khoảng cách + inventory gốc
const LIB_MARGIN: float = 16.0
const CONTENT_W: float = LIB_W + LIB_MARGIN + PAD + GRID_W + 12 + STAT_W + PAD

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
var _atk_label: Label
var _def_label: Label
var _weight_label: Label
var _crit_rate_label: Label
var _crit_dmg_label: Label
var _speed_label: Label
var _count_label: Label
var _equip_faces: Array[ColorRect] = []
var _equip_labels: Array[Label] = []
var _equip_item_labels: Array[Label] = []
var _equip_centers: Array[Vector2] = []
var _equip_line_pairs: Array[Array] = []
var _equip_line_time: float = 0.0
var _line_layer: Control
var _opening: bool = false
var _tween: Tween
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

# ── Item Library categories ────────────────────────────────────────────────────
# ── Item Library ───────────────────────────────────────────────────────────────
var _item_db: Dictionary = {}           # id -> ItemDef (tất cả items)
var _lib_items: Array[ItemDef] = []     # danh sách hiển thị theo search
var _lib_panels: Array[Panel] = []      # panel slots thư viện
var _lib_faces: Array[ColorRect] = []
var _lib_icon_textures: Array[TextureRect] = []
var _lib_name_labels: Array[Label] = []
var _lib_scroll_offset: int = 0         # hàng đầu tiên hiển thị
var _lib_visible_rows: int = 0
var _lib_container: Control             # container chứa slots
var _lib_scroll_up: Button
var _lib_scroll_down: Button
var _lib_search_box: LineEdit
var _lib_sort_buttons: Array[Button] = []

enum SortMode { NAME_ASC, NAME_DESC, TYPE, ATK, DEF, HEAL }
var _lib_sort_mode: int = SortMode.NAME_ASC

# ── Styles ─────────────────────────────────────────────────────────────────────
var _glass_style: StyleBoxFlat
var _slot_style: StyleBoxFlat
var _slot_hl_style: StyleBoxFlat
var _slot_hover_style: StyleBoxFlat
var _slot_drop_style: StyleBoxFlat
var _lib_slot_style: StyleBoxFlat
var _lib_slot_hover_style: StyleBoxFlat

var _slot_script: GDScript = null

func _make_slot_script() -> GDScript:
	if _slot_script != null:
		return _slot_script
	var s := GDScript.new()
	s.source_code = """
extends Panel
var _inv_ui = null
var _slot_idx = -1
func _get_drag_data(at_position):
	return _inv_ui._slot_get_drag_data(_slot_idx, at_position) if _inv_ui else null
func _can_drop_data(position, data):
	return _inv_ui._slot_can_drop_data(_slot_idx, position, data) if _inv_ui else false
func _drop_data(position, data):
	if _inv_ui: _inv_ui._slot_drop_data(_slot_idx, position, data)
"""
	s.reload()
	_slot_script = s
	return s

func _ready() -> void:
	size = Vector2(CONTENT_W, CONTENT_H)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glass_style = StyleBoxFlat.new()
	_glass_style.bg_color = Color(0.10, 0.10, 0.16, 0.85)
	_glass_style.corner_radius_top_left = 14; _glass_style.corner_radius_top_right = 14
	_glass_style.corner_radius_bottom_left = 14; _glass_style.corner_radius_bottom_right = 14
	_glass_style.border_width_left = 3; _glass_style.border_width_right = 3
	_glass_style.border_width_top = 3; _glass_style.border_width_bottom = 3
	_glass_style.border_color = Color(0.55, 0.57, 0.62, 0.85)

	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.10, 0.07, 0.18, 0.70)
	_slot_style.corner_radius_top_left = 4; _slot_style.corner_radius_top_right = 4
	_slot_style.corner_radius_bottom_left = 4; _slot_style.corner_radius_bottom_right = 4
	_slot_style.border_width_left = 1; _slot_style.border_width_right = 1
	_slot_style.border_width_top = 1; _slot_style.border_width_bottom = 1
	_slot_style.border_color = Color(0.55, 0.57, 0.62, 0.40)

	_slot_hl_style = _slot_style.duplicate()
	_slot_hl_style.bg_color = Color(0.30, 0.20, 0.40, 0.75)
	_slot_hl_style.border_color = Color(0.55, 0.57, 0.62, 0.70)

	_slot_hover_style = _slot_style.duplicate()
	_slot_hover_style.bg_color = Color(0.22, 0.18, 0.35, 0.80)
	_slot_hover_style.border_color = Color(0.55, 0.57, 0.62, 0.60)

	_slot_drop_style = _slot_style.duplicate()
	_slot_drop_style.bg_color = Color(0.18, 0.35, 0.22, 0.75)
	_slot_drop_style.border_color = Color(0.22, 0.62, 0.28, 0.60)

	_lib_slot_style = StyleBoxFlat.new()
	_lib_slot_style.bg_color = Color(0.10, 0.07, 0.18, 0.75)
	_lib_slot_style.corner_radius_top_left = 5; _lib_slot_style.corner_radius_top_right = 5
	_lib_slot_style.corner_radius_bottom_left = 5; _lib_slot_style.corner_radius_bottom_right = 5
	_lib_slot_style.border_width_left = 1; _lib_slot_style.border_width_right = 1
	_lib_slot_style.border_width_top = 1; _lib_slot_style.border_width_bottom = 1
	_lib_slot_style.border_color = Color(0.55, 0.57, 0.62, 0.30)

	_lib_slot_hover_style = _lib_slot_style.duplicate()
	_lib_slot_hover_style.bg_color = Color(0.18, 0.25, 0.40, 0.85)
	_lib_slot_hover_style.border_color = Color(0.55, 0.57, 0.62, 0.65)

	ItemDatabase.ensure_db()
	_item_db = ItemDatabase.items_db
	_Library.apply_filter(self)

	_Library.setup_library_panel(self)
	_setup_background()
	_setup_title()
	_setup_grid()
	_setup_status_panel()
	_setup_equipment_panel()
	_setup_tooltip()
	_Detail.setup_detail_panel(self)
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
	_detail_use_btn.text = tr("EQUIP_ITEM")
	_detail_drop_btn.text = tr("DROP_ITEM")
	for i in range(_equip_name_labels.size()):
		_equip_name_labels[i].text = tr(_equip_name_keys[i])

# ── Item Library: all logic extracted to item_library_panel.gd ─────────────────

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
	var slot_scr := _make_slot_script()

	for row in range(rows):
		for col in range(COLS):
			var i: int = row * COLS + col
			var px: float = ox + PAD + col * (SLOT_SIZE + GAP)
			var py: float = grid_y + row * (SLOT_SIZE + GAP)

			var panel := Panel.new()
			panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			panel.position = Vector2(px, py)
			panel.clip_contents = true
			panel.add_theme_stylebox_override("panel", _slot_style)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.set_script(slot_scr)
			panel._inv_ui = self
			panel._slot_idx = i
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
			slot_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
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
	stat.size = Vector2(STAT_W, STAT_PANEL_H)
	var st_style := _glass_style.duplicate() as StyleBoxFlat
	st_style.bg_color = Color(0.10, 0.07, 0.18, 0.65)
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

	_hp_label = Label.new()
	_hp_label.position = Vector2(sx + 16, sy + 46)
	_hp_label.add_theme_font_size_override("font_size", 22)
	_hp_label.add_theme_color_override("font_color", TEAL)
	add_child(_hp_label)

	_atk_label = Label.new()
	_atk_label.position = Vector2(sx + 16, sy + 76)
	_atk_label.add_theme_font_size_override("font_size", 22)
	_atk_label.add_theme_color_override("font_color", PINK)
	add_child(_atk_label)

	_def_label = Label.new()
	_def_label.position = Vector2(sx + 16, sy + 106)
	_def_label.add_theme_font_size_override("font_size", 22)
	_def_label.add_theme_color_override("font_color", ORANGE)
	add_child(_def_label)

	_weight_label = Label.new()
	_weight_label.position = Vector2(sx + 16, sy + 136)
	_weight_label.add_theme_font_size_override("font_size", 22)
	_weight_label.add_theme_color_override("font_color", Color(0.72, 0.56, 0.30))
	add_child(_weight_label)

	_crit_rate_label = Label.new()
	_crit_rate_label.position = Vector2(sx + 16, sy + 166)
	_crit_rate_label.add_theme_font_size_override("font_size", 22)
	_crit_rate_label.add_theme_color_override("font_color", Color(0.88, 0.22, 0.55))
	add_child(_crit_rate_label)

	_crit_dmg_label = Label.new()
	_crit_dmg_label.position = Vector2(sx + 16, sy + 196)
	_crit_dmg_label.add_theme_font_size_override("font_size", 22)
	_crit_dmg_label.add_theme_color_override("font_color", Color(0.95, 0.30, 0.30))
	add_child(_crit_dmg_label)

	_speed_label = Label.new()
	_speed_label.position = Vector2(sx + 16, sy + 226)
	_speed_label.add_theme_font_size_override("font_size", 22)
	_speed_label.add_theme_color_override("font_color", CYAN)
	add_child(_speed_label)

	_drop_hint_label = Label.new()
	_drop_hint_label.text = tr("DROP_HINT")
	_drop_hint_label.position = Vector2(sx + 16, sy + 260)
	_drop_hint_label.add_theme_font_size_override("font_size", 15)
	_drop_hint_label.add_theme_color_override("font_color", TEXT_MUTED)
	add_child(_drop_hint_label)

func _setup_equipment_panel() -> void:
	var ox: float = LIB_W + LIB_MARGIN
	var sx: float = ox + PAD + GRID_W + 12
	var sy: float = PAD + 40 + STAT_PANEL_H + 10

	var eq := Panel.new()
	eq.position = Vector2(sx, sy)
	eq.size = Vector2(STAT_W, EQUIP_H)
	eq.clip_contents = true
	var eq_style := _glass_style.duplicate() as StyleBoxFlat
	eq_style.bg_color = Color(0.10, 0.07, 0.18, 0.65)
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
		var lc := Color(0.22, 0.62, 0.28, 0.60)
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

# ── Detail panel: all logic extracted to item_detail_panel.gd ─────────────────

# ── Inventory slot events ──────────────────────────────────────────────────────
func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not visible or _inventory == null: return
	if event is InputEventMouseButton and event.pressed:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_LEFT:
			_on_slot_left_click(idx); accept_event()
		elif btn == MOUSE_BUTTON_RIGHT:
			_on_slot_right_click(idx); accept_event()

func _on_slot_left_click(idx: int) -> void:
	if _inventory.slots[idx].is_empty():
		_selected_slot = -1; _reset_slot_styles(); return
	if _selected_slot != idx:
		_reset_slot_styles()
	_selected_slot = idx
	_slots[idx].add_theme_stylebox_override("panel", _slot_hl_style)

func _on_slot_right_click(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty(): return
	# If count > 1, pick half
	if slot.count > 1 and slot.item.stackable:
		var half: int = slot.count / 2
		var new_idx := _inventory.split_stack(idx, half)
		if new_idx >= 0:
			_selected_slot = new_idx
		return
	# Single item: chỉ chọn ô — không còn "dùng" bằng chuột phải
	# (ăn = cầm tay + giữ chuột phải; trang bị = nút Trang bị)
	_selected_slot = idx

func _on_slot_mouse_entered(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	# Don't override selected slot highlight
	if idx != _selected_slot:
		_slots[idx].add_theme_stylebox_override("panel", _slot_hover_style)
	if slot.is_empty():
		_tooltip.visible = false; _tooltip_bg.visible = false
		return
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
	_reset_slot_styles()

func _reset_slot_styles() -> void:
	for i in range(_slots.size()):
		_slots[i].add_theme_stylebox_override("panel", _slot_style)
	if _selected_slot >= 0 and _selected_slot < _slots.size():
		_slots[_selected_slot].add_theme_stylebox_override("panel", _slot_hl_style)

# ── Drag & Drop ────────────────────────────────────────────────────────────────
func _slot_get_drag_data(idx: int, _at_position: Vector2):
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		return null
	var data := { "from_idx": idx, "from_inv": _inventory, "item_id": slot.item.id, "count": slot.count }
	# Build drag preview
	var preview := Panel.new()
	preview.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var preview_style := _slot_style.duplicate()
	preview_style.bg_color = Color(0.14, 0.10, 0.22, 0.90)
	preview_style.border_color = Color(0.22, 0.62, 0.28, 0.70)
	preview.add_theme_stylebox_override("panel", preview_style)
	var face := ColorRect.new()
	face.position = Vector2(2, 2)
	face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	face.color = slot.item.icon_color
	preview.add_child(face)
	var lbl := Label.new()
	lbl.position = Vector2(2, SLOT_SIZE - 24)
	lbl.size = Vector2(SLOT_SIZE - 4, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0, 0.90))
	lbl.text = str(slot.count) if slot.count > 1 else ""
	preview.add_child(lbl)
	set_drag_preview(preview)
	return data

func _slot_can_drop_data(idx: int, _position: Vector2, data) -> bool:
	_reset_slot_styles()
	if data == null or not (data is Dictionary):
		return false
	if not data.has("from_idx") or not data.has("from_inv"):
		return false
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	# Can't drop on same slot
	if from_inv == _inventory and from_idx == idx:
		return false
	var src_slot: ItemSlot = from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
	if src_slot == null or src_slot.is_empty():
		return false
	var dst_slot: ItemSlot = _inventory.slots[idx]
	if dst_slot.is_empty():
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	if from_inv == _inventory:
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	if dst_slot.item.id == src_slot.item.id and dst_slot.item.stackable and dst_slot.count < dst_slot.item.max_stack:
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	return false

func _slot_drop_data(idx: int, _position: Vector2, data) -> void:
	_reset_slot_styles()
	if data == null or not (data is Dictionary):
		return
	if not data.has("from_idx") or not data.has("from_inv"):
		return
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	if from_inv == _inventory:
		# Same inventory: transfer if possible, else swap
		if _inventory.can_transfer(from_idx, idx):
			_inventory.transfer(from_idx, idx)
		else:
			_inventory.swap(from_idx, idx)
	else:
		# Cross-inventory (e.g. chest -> player)
		var src_slot: ItemSlot = from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
		if src_slot == null or src_slot.is_empty():
			return
		var item: ItemDef = src_slot.item
		var count: int = src_slot.count
		var remaining: int = _inventory.add_item(item, count)
		if remaining < count:
			from_inv.remove_item(from_idx, count - remaining)



func set_inventory(inv: Inventory) -> void:
	_inventory = inv

func set_player(p: PlayerCharacter) -> void:
	_player_ref = p

func open() -> void:
	if _opening:
		return
	_opening = true
	_play_appear()

func close() -> void:
	if not _opening:
		return
	_opening = false
	_play_disappear()

func _play_appear() -> void:
	visible = true
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.20)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.20)

func _play_disappear() -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.12)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func():
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0
	)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") and _lib_search_box and _lib_search_box.has_focus():
			_lib_search_box.release_focus()

func _process(delta: float) -> void:
	if _inventory == null: return
	for i in range(_inventory.slots.size()):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			var col = Color(0.20,0.15,0.30,0.4) if i != _selected_slot else Color(0.30,0.20,0.40,0.5)
			_slot_faces[i].color = col; _slot_count_labels[i].text = ""
			_slot_icons[i].texture = null; _slot_icons[i].visible = false
		else:
			var tex := ItemDatabase.load_icon_2d(slot.item.id)
			if tex:
				_slot_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
				_slot_icons[i].texture = tex
				_slot_icons[i].visible = true
			else:
				_slot_faces[i].color = slot.item.icon_color
				_slot_icons[i].texture = null
				_slot_icons[i].visible = false
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""

	if _player_ref:
		_hp_label.text  = "\u2665  %d / %d"   % [_player_ref.hp, _player_ref.max_hp]
		_atk_label.text = "\u2694  %d"        % _player_ref.get_total_atk()
		_def_label.text = "\u2741  %d"        % _player_ref.get_total_def()
		_weight_label.text = "\u2696  %.0f / %.0f" % [_player_ref.get_total_weight(), _player_ref.max_weight]
		_crit_rate_label.text = "\u2620  %.0f%%" % (_player_ref.crit_rate * 100.0)
		_crit_dmg_label.text = "\u2694\u2726  %.0f%%" % (_player_ref.crit_dmg * 100.0)
		var eff_speed: float = _player_ref.move_speed * _player_ref.get_speed_multiplier()
		_speed_label.text = "\u26A1  %.1f m/s" % eff_speed
		_update_equipment_display(_player_ref)

	_Detail.update_detail_panel(self)

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
