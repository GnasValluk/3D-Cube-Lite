class_name FurnaceUI
extends Control

const _CookingStove = preload("res://scripts/items/entities/cooking_stove.gd")

## Lò nung kiểu mới: trái = danh sách công thức (nung), phải = vùng lò.
## Vùng lò: 3 ô nguyên liệu (nung) ở trên — icon lửa 2D (sáng + nhấp nháy khi
## đốt) — bên dưới 2 ô nhiên liệu + thanh process nhiên liệu (mỗi chất đốt có
## lượng nhiên liệu riêng, đốt hết theo thời gian). 3 ô thành phẩm ở dưới.

const S: float = 1.6

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

const SLOT_SIZE: float = 56.0
const GAP: float = 5.0
const COLS: int = 9
const PAD: float = 20.0
const GRID_W: float = COLS * (SLOT_SIZE + GAP) - GAP
const LIST_W: float = 244.0
const REC_X: float = PAD
const RIGHT_X: float = PAD + LIST_W + GAP * 2
const PANEL_W: float = RIGHT_X + GRID_W + PAD

const FUEL_SLOT_0: int = 3
const FUEL_SLOT_1: int = 4
const OUT_SLOT_0: int = 5

var _furnace = null
var _player_ref: PlayerCharacter = null
var _furnace_inv: Inventory

var _furnace_mode: String = "smelt"
var _title_label: Label

var _input_faces: Array[ColorRect] = []
var _input_icons: Array[TextureRect] = []
var _input_counts: Array[Label] = []
var _input_panels: Array[Panel] = []
var _fuel_faces: Array[ColorRect] = []
var _fuel_icons: Array[TextureRect] = []
var _fuel_counts: Array[Label] = []
var _fuel_panels: Array[Panel] = []
var _output_faces: Array[ColorRect] = []
var _output_icons: Array[TextureRect] = []
var _output_counts: Array[Label] = []
var _output_panels: Array[Panel] = []
var _player_faces: Array[ColorRect] = []
var _player_icons: Array[TextureRect] = []
var _player_counts: Array[Label] = []
var _player_panels: Array[Panel] = []
var _hotbar_faces: Array[ColorRect] = []
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_counts: Array[Label] = []
var _hotbar_panels: Array[Panel] = []

var _content_h: float = 0.0
var _slot_style: StyleBoxFlat
var _slot_hover_style: StyleBoxFlat
var _slot_drop_style: StyleBoxFlat
var _slot_script: GDScript

var _recipes: Array = []
var _recipe_cards: Array[Panel] = []
var _recipe_list: VBoxContainer
var _selected_recipe: int = -1
var _recipe_card_style: StyleBoxFlat
var _recipe_sel_style: StyleBoxFlat
var _empty_label: Label

var _smelting_items: Dictionary = {}
var _fuels: Dictionary = {}
var _smelt_active: bool = false
var _smelt_time: float = 5.0
var _smelt_progress: Array[float] = [0.0, 0.0, 0.0]
var _fuel_energy: float = 0.0
var _fuel_piece_value: float = 80.0
var _fire_time: float = 0.0
var _fire_cold: bool = true
var _tween: Tween

var _fire_glow: Panel
var _fire_label: Label
var _fuel_bar: ColorRect
var _fuel_fill: ColorRect
var _fuel_bar_label: Label

func _init() -> void:
	_furnace_inv = Inventory.new(8)

func _ready() -> void:
	_content_h = _build_layout()
	size = Vector2(PANEL_W, _content_h)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_styles()
	_init_smelting_items()
	_setup_background()
	_setup_title()
	_setup_recipe_bar()
	_setup_furnace_slots()
	_setup_fire_area()
	_setup_player_grid()
	visible = false

func _build_layout() -> float:
	var furnace_area_h: float = PAD + 22 + 3 * SLOT_SIZE + 3 * 60 + 8
	var inv_label_y: float = furnace_area_h + 10
	var inv_start: float = inv_label_y + 24
	var grid_bottom: float = inv_start + 3 * (SLOT_SIZE + GAP)
	var hotbar_bottom: float = grid_bottom + GAP + SLOT_SIZE
	return hotbar_bottom + PAD

func _setup_styles() -> void:
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = BG_PANEL
	_slot_style.corner_radius_top_left = 6
	_slot_style.corner_radius_top_right = 6
	_slot_style.corner_radius_bottom_left = 6
	_slot_style.corner_radius_bottom_right = 6
	_slot_style.border_width_left = 2
	_slot_style.border_width_right = 2
	_slot_style.border_width_top = 2
	_slot_style.border_width_bottom = 2
	_slot_style.border_color = Color(0.12, 0.08, 0.20, 0.35)

	_slot_hover_style = _slot_style.duplicate()
	_slot_hover_style.bg_color = Color(0.22, 0.18, 0.35, 0.80)
	_slot_hover_style.border_color = Color(0.55, 0.57, 0.62, 0.60)

	_slot_drop_style = _slot_style.duplicate()
	_slot_drop_style.bg_color = Color(0.18, 0.35, 0.22, 0.75)
	_slot_drop_style.border_color = Color(0.22, 0.62, 0.28, 0.60)

	_recipe_card_style = StyleBoxFlat.new()
	_recipe_card_style.bg_color = BG_CARD
	_recipe_card_style.corner_radius_top_left = 8
	_recipe_card_style.corner_radius_top_right = 8
	_recipe_card_style.corner_radius_bottom_left = 8
	_recipe_card_style.corner_radius_bottom_right = 8
	_recipe_card_style.border_width_left = 1
	_recipe_card_style.border_width_right = 1
	_recipe_card_style.border_width_top = 1
	_recipe_card_style.border_width_bottom = 1
	_recipe_card_style.border_color = Color(0.55, 0.57, 0.62, 0.15)

	_recipe_sel_style = _recipe_card_style.duplicate()
	_recipe_sel_style.bg_color = Color(0.18, 0.30, 0.22, 0.95)
	_recipe_sel_style.border_color = Color(0.22, 0.72, 0.38, 0.75)
	_recipe_sel_style.border_width_left = 2
	_recipe_sel_style.border_width_right = 2
	_recipe_sel_style.border_width_top = 2
	_recipe_sel_style.border_width_bottom = 2

	_slot_script = GDScript.new()
	_slot_script.source_code = """
extends Panel
var _chest_ui = null
var _chest_type = ""
var _chest_idx = -1
var _just_dragged = false
func _get_drag_data(at_position):
	_just_dragged = true
	return _chest_ui._slot_get_drag_data(_chest_type, _chest_idx, at_position) if _chest_ui else null
func _can_drop_data(position, data):
	return _chest_ui._slot_can_drop_data(_chest_type, _chest_idx, position, data) if _chest_ui else false
func _drop_data(position, data):
	if _chest_ui: _chest_ui._slot_drop_data(_chest_type, _chest_idx, position, data)
"""
	_slot_script.reload()

func _init_smelting_items() -> void:
	# Toàn bộ công thức nung đã bị xoá. `_smelting_items` để trống — thêm lại sau.
	_smelting_items = {}
	# Chất đốt: mỗi loại có lượng nhiên liệu riêng (giây đốt cho 1 đơn vị).
	_fuels = {
		"coal": 80.0,
		"charcoal": 40.0,
		"palm_wood": 10.0,
		"block_oak_wood": 10.0,
	}

## Áp thư viện công thức theo chế độ của entity (lò nung / bếp nấu) rồi
## build lại danh sách thẻ công thức bên trái. `_smelting_items` là nguồn
## duy nhất cho `_update_smelting` nên chế độ cooking chỉ cần đổi nguồn này.
func _apply_mode(mode: String) -> void:
	_furnace_mode = mode
	_smelting_items = {}
	if mode == "cooking":
		_smelting_items = _CookingStove.COOKING_ITEMS
	_recipes.clear()
	for ore in _smelting_items:
		_recipes.append({ "input": ore, "output": _smelting_items[ore] })
	if _title_label:
		_title_label.text = tr("COOKING_LABEL") if mode == "cooking" else tr("FURNACE_LABEL")
	_rebuild_recipe_cards()

func _setup_background() -> void:
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
	bg.size = Vector2(PANEL_W, _content_h)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	_title_label = Label.new()
	_title_label.text = tr("FURNACE_LABEL")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", int(S * 15))
	_title_label.add_theme_color_override("font_color", TEXT_BRIGHT)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.position = Vector2(RIGHT_X + PAD, PAD - 4)
	_title_label.size = Vector2(GRID_W, 30)
	add_child(_title_label)

	var rec_lbl := Label.new()
	rec_lbl.text = tr("FURNACE_RECIPES")
	rec_lbl.add_theme_font_size_override("font_size", int(S * 13))
	rec_lbl.add_theme_color_override("font_color", TEXT_BRIGHT)
	rec_lbl.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	rec_lbl.add_theme_constant_override("shadow_offset_x", 1)
	rec_lbl.add_theme_constant_override("shadow_offset_y", 1)
	rec_lbl.position = Vector2(REC_X, PAD - 4)
	rec_lbl.size = Vector2(LIST_W, 30)
	add_child(rec_lbl)

func _make_slot(px: float, py: float, faces: Array, icons: Array, counts: Array, panels: Array, slot_type: String, slot_idx: int) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(px, py)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _slot_style)
	panel.set_script(_slot_script)
	panel._chest_ui = self
	panel._chest_type = slot_type
	panel._chest_idx = slot_idx
	panel.mouse_entered.connect(_on_slot_entered.bind(panels, slot_type, slot_idx))
	panel.mouse_exited.connect(_on_slot_exited.bind(panels))
	add_child(panel)

	var face := ColorRect.new()
	face.position = Vector2(2, 2)
	face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	face.color = Color(0.20, 0.15, 0.30, 0.4)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(face)
	faces.append(face)

	var slot_icon := TextureRect.new()
	slot_icon.position = Vector2(2, 2)
	slot_icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	slot_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_icon.visible = false
	panel.add_child(slot_icon)
	icons.append(slot_icon)

	var cnt := Label.new()
	cnt.position = Vector2(2, SLOT_SIZE - 24)
	cnt.size = Vector2(SLOT_SIZE - 4, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 18)
	cnt.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.70))
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cnt)
	counts.append(cnt)

	panels.append(panel)
	return panel

func _recipe_card(input_id: String, output_id: String) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(LIST_W - 14, 76)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _recipe_card_style)
	var idx: int = _recipe_cards.size()
	card.gui_input.connect(_on_recipe_input.bind(idx))
	_recipe_list.add_child(card)
	_recipe_cards.append(card)

	ItemDatabase.ensure_db()
	var rin := ItemDatabase.load_icon_2d(input_id)
	var rout := ItemDatabase.load_icon_2d(output_id)
	var in_def: ItemDef = ItemDatabase.items_db.get(input_id) as ItemDef
	var out_def: ItemDef = ItemDatabase.items_db.get(output_id) as ItemDef
	var out_name: String = out_def.name if out_def != null else output_id

	var in_slot := Panel.new()
	in_slot.position = Vector2(8, 14)
	in_slot.size = Vector2(48, 48)
	in_slot.clip_contents = true
	in_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	in_slot.add_theme_stylebox_override("panel", _slot_style)
	card.add_child(in_slot)
	if rin:
		var t := TextureRect.new()
		t.position = Vector2(2, 2)
		t.size = Vector2(44, 44)
		t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture = rin
		in_slot.add_child(t)

	var arr := Label.new()
	arr.text = "→"
	arr.position = Vector2(64, 26)
	arr.add_theme_font_size_override("font_size", int(S * 14))
	arr.add_theme_color_override("font_color", TEXT_MUTED)
	card.add_child(arr)

	var out_slot := Panel.new()
	out_slot.position = Vector2(90, 14)
	out_slot.size = Vector2(48, 48)
	out_slot.clip_contents = true
	out_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_slot.add_theme_stylebox_override("panel", _slot_style)
	card.add_child(out_slot)
	if rout:
		var t2 := TextureRect.new()
		t2.position = Vector2(2, 2)
		t2.size = Vector2(44, 44)
		t2.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t2.texture = rout
		out_slot.add_child(t2)

	var nm := Label.new()
	nm.text = out_name
	nm.position = Vector2(146, 27)
	nm.size = Vector2(LIST_W - 158, 24)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_font_size_override("font_size", int(S * 10))
	nm.add_theme_color_override("font_color", TEXT_BRIGHT)
	card.add_child(nm)

func _on_recipe_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and idx >= 0 and idx < _recipes.size():
		_select_recipe(idx)
		_try_fill_input(idx)

func _select_recipe(idx: int) -> void:
	_selected_recipe = idx
	for i in range(_recipe_cards.size()):
		_recipe_cards[i].add_theme_stylebox_override("panel", _recipe_sel_style if i == idx else _recipe_card_style)

func _try_fill_input(idx: int) -> void:
	if _player_ref == null or idx < 0 or idx >= _recipes.size():
		return
	var pi = _player_ref.inventory
	var fi = _furnace_inv
	if pi == null or fi == null:
		return
	var input: String = _recipes[idx].get("input", "")
	# Tìm ô nguyên liệu trống hoặc cùng loại để nạp
	var slot_idx := -1
	for i in range(3):
		var s: ItemSlot = fi.slots[i]
		if s.is_empty():
			slot_idx = i
			break
		if s.item.id == input and s.count < s.item.max_stack:
			slot_idx = i
			break
	if slot_idx < 0:
		return
	var def: ItemDef = ItemDatabase.items_db.get(input) as ItemDef
	if def == null:
		return
	for s in range(pi.slots.size()):
		var slot: ItemSlot = pi.slots[s]
		if slot.is_empty() or slot.item.id != input:
			continue
		pi.remove_item(s, 1)
		fi.add_item(def, 1)
		return

func _setup_recipe_bar() -> void:
	var rec_panel := Panel.new()
	rec_panel.position = Vector2(REC_X, 50)
	rec_panel.size = Vector2(LIST_W, _content_h - 50 - PAD)
	var rec_style := StyleBoxFlat.new()
	rec_style.bg_color = BG_CARD
	rec_style.corner_radius_top_left = 10
	rec_style.corner_radius_top_right = 10
	rec_style.corner_radius_bottom_left = 10
	rec_style.corner_radius_bottom_right = 10
	rec_style.border_width_left = 1
	rec_style.border_width_right = 1
	rec_style.border_width_top = 1
	rec_style.border_width_bottom = 1
	rec_style.border_color = Color(0.55, 0.57, 0.62, 0.15)
	rec_panel.add_theme_stylebox_override("panel", rec_style)
	rec_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rec_panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 8)
	scroll.size = Vector2(LIST_W - 12, _content_h - 50 - PAD - 16)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rec_panel.add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_recipe_list)

	_rebuild_recipe_cards()

## Build (lại) toàn bộ thẻ công thức từ `_recipes` — dùng chung cho cả
## chế độ nung lẫn nấu ăn (đổi mode sẽ gọi lại hàm này).
func _rebuild_recipe_cards() -> void:
	for card in _recipe_cards:
		card.queue_free()
	_recipe_cards.clear()
	if _empty_label:
		_empty_label.queue_free()
	_empty_label = Label.new()
	_empty_label.text = tr("NO_RECIPES")
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", int(S * 11))
	_empty_label.add_theme_color_override("font_color", TEXT_MUTED)
	_recipe_list.add_child(_empty_label)
	if _recipes.is_empty():
		_selected_recipe = -1
		return
	_empty_label.visible = false
	for r in _recipes:
		_recipe_card(r.get("input", ""), r.get("output", ""))
	_selected_recipe = -1
	_select_recipe(0)

func _label(pos: Vector2, text: String, color: Color, isize: int = 12) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", int(S * isize))
	lbl.add_theme_color_override("font_color", color)
	add_child(lbl)

func _setup_furnace_slots() -> void:
	var sx: float = RIGHT_X + (GRID_W - 3 * (SLOT_SIZE + GAP) + GAP) * 0.5
	var sy: float = PAD + 22
	var in_y := sy
	var fuel_y := sy + SLOT_SIZE + 52
	var out_y := fuel_y + SLOT_SIZE + 40

	_label(Vector2(sx, in_y - 22), tr("FURNACE_INPUT"), TEXT_DIM, 10)
	for i in range(3):
		var px: float = sx + i * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, in_y, _input_faces, _input_icons, _input_counts, _input_panels, "furnace", i)
		panel.gui_input.connect(_on_slot_gui_input.bind("furnace", i))

	_label(Vector2(sx, fuel_y - 22), tr("FURNACE_FUEL"), TEXT_DIM, 10)
	for i in range(2):
		var px: float = sx + i * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, fuel_y, _fuel_faces, _fuel_icons, _fuel_counts, _fuel_panels, "furnace", FUEL_SLOT_0 + i)
		panel.gui_input.connect(_on_slot_gui_input.bind("furnace", FUEL_SLOT_0 + i))

	_label(Vector2(sx, out_y - 22), tr("FURNACE_OUTPUT"), TEXT_DIM, 10)
	for i in range(3):
		var px: float = sx + i * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, out_y, _output_faces, _output_icons, _output_counts, _output_panels, "furnace", OUT_SLOT_0 + i)
		panel.gui_input.connect(_on_slot_gui_input.bind("furnace", OUT_SLOT_0 + i))

	var fuel_x: float = sx + 2 * (SLOT_SIZE + GAP) + 14
	_fuel_bar = ColorRect.new()
	_fuel_bar.position = Vector2(fuel_x, fuel_y + 4)
	_fuel_bar.size = Vector2(150, 22)
	_fuel_bar.color = Color(0.15, 0.10, 0.22, 0.6)
	add_child(_fuel_bar)
	_fuel_fill = ColorRect.new()
	_fuel_fill.position = Vector2(fuel_x + 2, fuel_y + 6)
	_fuel_fill.size = Vector2(0, 18)
	_fuel_fill.color = Color(0.95, 0.50, 0.10)
	add_child(_fuel_fill)
	_fuel_bar_label = Label.new()
	_fuel_bar_label.position = Vector2(fuel_x, fuel_y + 30)
	_fuel_bar_label.size = Vector2(150, 18)
	_fuel_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fuel_bar_label.add_theme_font_size_override("font_size", int(S * 9))
	_fuel_bar_label.add_theme_color_override("font_color", TEXT_DIM)
	add_child(_fuel_bar_label)

func _setup_fire_area() -> void:
	var sx: float = RIGHT_X + (GRID_W - 3 * (SLOT_SIZE + GAP) + GAP) * 0.5
	var sy: float = PAD + 22
	var fire_y: float = sy + SLOT_SIZE + 4
	var fire_x: float = sx + (3 * (SLOT_SIZE + GAP) - GAP) * 0.5 - 26

	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0.55, 0.20, 0.05, 0.25)
	glow_style.corner_radius_top_left = 6
	glow_style.corner_radius_top_right = 6
	glow_style.corner_radius_bottom_left = 6
	glow_style.corner_radius_bottom_right = 6
	_fire_glow = Panel.new()
	_fire_glow.position = Vector2(fire_x - 6, fire_y - 4)
	_fire_glow.size = Vector2(64, 52)
	_fire_glow.add_theme_stylebox_override("panel", glow_style)
	_fire_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fire_glow)

	_fire_label = Label.new()
	_fire_label.text = "🔥"
	_fire_label.position = Vector2(fire_x, fire_y)
	_fire_label.size = Vector2(52, 44)
	_fire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fire_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fire_label.add_theme_font_size_override("font_size", int(S * 24))
	_fire_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fire_label)
	_set_fire_cold()

func _set_fire_cold() -> void:
	_fire_cold = true
	_fire_label.modulate = Color(0.5, 0.45, 0.4, 0.45)
	_fire_glow.modulate.a = 0.35

func _set_fire_lit() -> void:
	_fire_cold = false
	_fire_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_fire_glow.modulate.a = 0.9

func _setup_player_grid() -> void:
	var sx: float = RIGHT_X + PAD
	var inv_label_y: float = _build_layout() - PAD - SLOT_SIZE - GAP - 3 * (SLOT_SIZE + GAP) - 24 - 24 - 6
	var sy: float = inv_label_y + 24

	var lbl := Label.new()
	lbl.text = tr("INVENTORY_TITLE")
	lbl.position = Vector2(sx, inv_label_y)
	lbl.add_theme_font_size_override("font_size", int(S * 12))
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	add_child(lbl)

	for row in range(3):
		for col in range(COLS):
			var i: int = 9 + row * COLS + col
			var px: float = sx + col * (SLOT_SIZE + GAP)
			var py2: float = sy + row * (SLOT_SIZE + GAP)
			var panel := _make_slot(px, py2, _player_faces, _player_icons, _player_counts, _player_panels, "player", i)
			panel.gui_input.connect(_on_slot_gui_input.bind("player", i))

	var hot_y: float = sy + 3 * (SLOT_SIZE + GAP) + GAP
	for col in range(COLS):
		var i: int = col
		var px: float = sx + col * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, hot_y, _hotbar_faces, _hotbar_icons, _hotbar_counts, _hotbar_panels, "hotbar", i)
		panel.gui_input.connect(_on_slot_gui_input.bind("hotbar", i))

func _get_panel(_type: String, idx: int) -> Panel:
	match _type:
		"player": return _player_panels[idx] if idx >= 0 and idx < _player_panels.size() else null
		"hotbar": return _hotbar_panels[idx] if idx >= 0 and idx < _hotbar_panels.size() else null
		"furnace":
			if idx >= 0 and idx < 3 and idx < _input_panels.size():
				return _input_panels[idx]
			if idx >= FUEL_SLOT_0 and idx <= FUEL_SLOT_1 and idx - FUEL_SLOT_0 < _fuel_panels.size():
				return _fuel_panels[idx - FUEL_SLOT_0]
			if idx >= OUT_SLOT_0 and idx - OUT_SLOT_0 < _output_panels.size():
				return _output_panels[idx - OUT_SLOT_0]
	return null

func _on_slot_gui_input(event: InputEvent, _type: String, idx: int) -> void:
	if not visible or _player_ref == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var p := _get_panel(_type, idx)
				if p: p._just_dragged = false
			else:
				var p := _get_panel(_type, idx)
				if p and not p._just_dragged:
					_on_slot_left_click(_type, idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_slot_right_click(_type, idx)

func _on_slot_left_click(_type: String, idx: int) -> void:
	var inv: Inventory = _get_inv(_type)
	if inv == null:
		return
	var slot: ItemSlot = inv.slots[idx]
	if slot.is_empty():
		return
	if _type == "furnace":
		_transfer_from_furnace(idx, slot.count)
	else:
		_transfer_to_furnace(idx, _type, slot.count)

func _on_slot_right_click(_type: String, idx: int) -> void:
	var inv: Inventory = _get_inv(_type)
	if inv == null:
		return
	var slot: ItemSlot = inv.slots[idx]
	if slot.is_empty():
		return
	var half: int = slot.count / 2
	if half < 1:
		return
	if _type == "furnace":
		_transfer_from_furnace(idx, half)
	else:
		_transfer_to_furnace(idx, _type, half)

func _get_inv(_type: String) -> Inventory:
	match _type:
		"furnace": return _furnace_inv
		"player", "hotbar": return _player_ref.inventory if _player_ref else null
	return null

func _transfer_from_furnace(idx: int, count: int) -> void:
	var fi = _furnace_inv
	var pi = _player_ref.inventory
	if fi == null or pi == null:
		return
	var slot: ItemSlot = fi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	var remaining: int = pi.add_item(slot.item, count)
	if remaining < count:
		fi.remove_item(idx, count - remaining)

func _transfer_to_furnace(idx: int, _type: String, count: int) -> void:
	var fi = _furnace_inv
	var pi = _player_ref.inventory
	if fi == null or pi == null:
		return
	var slot: ItemSlot = pi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	var remaining: int = fi.add_item(slot.item, count)
	if remaining < count:
		pi.remove_item(idx, count - remaining)

func _on_slot_entered(panels: Array, _type: String, idx: int) -> void:
	for p in panels:
		p.add_theme_stylebox_override("panel", _slot_style)
	if idx >= 0 and idx < panels.size():
		panels[idx].add_theme_stylebox_override("panel", _slot_hover_style)

func _on_slot_exited(panels: Array) -> void:
	for p in panels:
		p.add_theme_stylebox_override("panel", _slot_style)

func _slot_get_drag_data(_type: String, idx: int, _at_position: Vector2):
	var inv: Inventory = _get_inv(_type)
	if inv == null:
		return null
	var slot: ItemSlot = inv.slots[idx]
	if slot.is_empty():
		return null
	var data := { "from_type": _type, "from_idx": idx, "from_inv": inv, "item_id": slot.item.id, "count": slot.count }
	var preview := Panel.new()
	var ss: float = SLOT_SIZE
	preview.size = Vector2(ss, ss)
	var ps := _slot_style.duplicate()
	ps.bg_color = Color(0.14, 0.10, 0.22, 0.90)
	ps.border_color = Color(0.22, 0.62, 0.28, 0.70)
	preview.add_theme_stylebox_override("panel", ps)
	var face := ColorRect.new()
	face.position = Vector2(2, 2)
	face.size = Vector2(ss - 4, ss - 4)
	face.color = slot.item.icon_color
	preview.add_child(face)
	var cnt := Label.new()
	cnt.position = Vector2(2, ss - 24)
	cnt.size = Vector2(ss - 4, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", int(S * 10))
	cnt.add_theme_color_override("font_color", TEXT_BRIGHT)
	cnt.text = str(slot.count) if slot.count > 1 else ""
	preview.add_child(cnt)
	set_drag_preview(preview)
	return data

func _slot_can_drop_data(_type: String, idx: int, _position: Vector2, data) -> bool:
	if data == null or not (data is Dictionary):
		return false
	if not data.has("from_inv") or not data.has("from_idx"):
		return false
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	var src := from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
	if src == null or src.is_empty():
		return false
	var dst_inv: Inventory = _get_inv(_type)
	if dst_inv == null:
		return false
	var dst := dst_inv.slots[idx]
	if dst.is_empty():
		_highlight_drop(_type, idx, true)
		return true
	if dst.item.id == src.item.id and dst.item.stackable and dst.count < dst.item.max_stack:
		_highlight_drop(_type, idx, true)
		return true
	return false

func _slot_drop_data(_type: String, idx: int, _position: Vector2, data) -> void:
	_clear_drop_highlights()
	if data == null or not (data is Dictionary):
		return
	if not data.has("from_inv") or not data.has("from_idx"):
		return
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	var src := from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
	if src == null or src.is_empty():
		return
	var dst_inv: Inventory = _get_inv(_type)
	if dst_inv == null:
		return
	var item: ItemDef = src.item
	var count: int = src.count
	if dst_inv == from_inv:
		if dst_inv.can_transfer(from_idx, idx):
			dst_inv.transfer(from_idx, idx)
		else:
			dst_inv.swap(from_idx, idx)
	else:
		var remaining: int = dst_inv.add_item(item, count)
		if remaining < count:
			from_inv.remove_item(from_idx, count - remaining)

func _highlight_drop(_type: String, idx: int, on: bool) -> void:
	var panel: Panel = _get_panel(_type, idx)
	if panel:
		panel.add_theme_stylebox_override("panel", _slot_drop_style if on else _slot_style)

func _clear_drop_highlights() -> void:
	for p in _input_panels + _fuel_panels + _output_panels + _player_panels + _hotbar_panels:
		p.add_theme_stylebox_override("panel", _slot_style)

func open(furnace, player: PlayerCharacter) -> void:
	_furnace = furnace
	_player_ref = player
	var mode: String = "smelt"
	if furnace != null and furnace.has_method("get_furnace_mode"):
		mode = furnace.get_furnace_mode()
	_apply_mode(mode)
	if _selected_recipe < 0 and not _recipes.is_empty():
		_select_recipe(0)
	_play_appear()

func close() -> void:
	_cleanup()
	_furnace = null
	_player_ref = null
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

func _cleanup() -> void:
	if _player_ref == null:
		return
	var pi = _player_ref.inventory
	if pi == null:
		return
	for i in range(_furnace_inv.slots.size()):
		var slot: ItemSlot = _furnace_inv.slots[i]
		if not slot.is_empty():
			pi.add_item(slot.item, slot.count)
	_furnace_inv = Inventory.new(8)

func _process(delta: float) -> void:
	_fire_time += delta
	_update_fire_animation()
	if not visible or _player_ref == null:
		return
	var fi = _furnace_inv
	var pi = _player_ref.inventory
	if fi == null or pi == null:
		return

	for i in range(3):
		if i < _input_faces.size():
			_refresh_slot(fi.slots[i], _input_faces[i], _input_icons[i], _input_counts[i])
	for i in range(2):
		if i < _fuel_faces.size():
			_refresh_slot(fi.slots[FUEL_SLOT_0 + i], _fuel_faces[i], _fuel_icons[i], _fuel_counts[i])
	for i in range(3):
		if i < _output_faces.size():
			_refresh_slot(fi.slots[OUT_SLOT_0 + i], _output_faces[i], _output_icons[i], _output_counts[i])

	for i in range(27):
		var pidx: int = 9 + i
		if pidx < pi.slots.size() and i < _player_faces.size():
			_refresh_slot(pi.slots[pidx], _player_faces[i], _player_icons[i], _player_counts[i])
	for i in range(9):
		if i < pi.slots.size() and i < _hotbar_faces.size():
			_refresh_slot(pi.slots[i], _hotbar_faces[i], _hotbar_icons[i], _hotbar_counts[i])

	_update_smelting(delta)
	_update_fuel_bar()

func _refresh_slot(slot: ItemSlot, face: ColorRect, icon: TextureRect, cnt: Label) -> void:
	if slot.is_empty():
		face.color = Color(0.20, 0.15, 0.30, 0.4)
		icon.texture = null
		icon.visible = false
		cnt.text = ""
		return
	var tex := ItemDatabase.load_icon_2d(slot.item.id)
	face.color = Color(0.20, 0.15, 0.30, 0.4) if tex != null else slot.item.icon_color
	icon.texture = tex
	icon.visible = tex != null
	cnt.text = str(slot.count) if slot.count > 1 else ""

func _update_fire_animation() -> void:
	if _fire_label == null:
		return
	if _fire_cold:
		var breath: float = 0.5 + 0.5 * sin(_fire_time * 1.6)
		_fire_label.modulate = Color(0.5, 0.45, 0.4, 0.35 + breath * 0.12)
		_fire_glow.modulate.a = 0.30 + breath * 0.06
		return
	var flicker: float = sin(_fire_time * 22.0) * 0.5 + sin(_fire_time * 7.3) * 0.5
	var a: float = 0.82 + flicker * 0.14
	var s: float = 1.0 + flicker * 0.10
	_fire_label.modulate = Color(1.0, 0.92, 0.78, a)
	_fire_label.scale = Vector2(s, s)
	_fire_label.pivot_offset = Vector2(26, 22)
	_fire_glow.modulate.a = 0.9 + flicker * 0.08

func _update_smelting(delta: float) -> void:
	# Có ít nhất 1 ô nguyên liệu nung được và thành phẩm không bị chặn?
	var any_work := false
	for i in range(3):
		var in_slot: ItemSlot = _furnace_inv.slots[i]
		if in_slot.is_empty() or in_slot.item.id not in _smelting_items:
			continue
		var output_id: String = _smelting_items[in_slot.item.id]
		var out_slot: ItemSlot = _furnace_inv.slots[OUT_SLOT_0 + i]
		if not out_slot.is_empty() and out_slot.item.id != output_id:
			continue
		if not out_slot.is_empty() and out_slot.count >= out_slot.item.max_stack:
			continue
		any_work = true

	if not any_work:
		_smelt_active = false
		for i in range(3):
			_smelt_progress[i] = 0.0
		_set_fire_cold()
		return

	# Có nhiên liệu để đốt? Nạp 1 đơn vị chất đốt khi hết nhiên liệu.
	if _fuel_energy <= 0.0:
		var fuelled := false
		for f in [FUEL_SLOT_0, FUEL_SLOT_1]:
			var fs: ItemSlot = _furnace_inv.slots[f]
			if not fs.is_empty() and _fuels.has(fs.item.id):
				_fuel_piece_value = _fuels[fs.item.id]
				_fuel_energy += _fuel_piece_value
				_furnace_inv.remove_item(f, 1)
				fuelled = true
				break
		if not fuelled:
			_smelt_active = false
			for i in range(3):
				_smelt_progress[i] = 0.0
			_set_fire_cold()
			return

	_smelt_active = true
	_set_fire_lit()

	# Tiêu hao nhiên liệu (tính theo giây refl của từng chất đốt)
	_fuel_energy = maxf(_fuel_energy - delta, 0.0)

	# Nung từng ô nguyên liệu (3 lò song song)
	for i in range(3):
		var in_slot: ItemSlot = _furnace_inv.slots[i]
		if in_slot.is_empty() or in_slot.item.id not in _smelting_items:
			continue
		var output_id: String = _smelting_items[in_slot.item.id]
		var out_slot: ItemSlot = _furnace_inv.slots[OUT_SLOT_0 + i]
		if not out_slot.is_empty() and out_slot.item.id != output_id:
			continue
		if not out_slot.is_empty() and out_slot.count >= out_slot.item.max_stack:
			continue
		_smelt_progress[i] += delta / _smelt_time
		if _smelt_progress[i] >= 1.0:
			_complete_smelt(i, output_id)
			_smelt_progress[i] = 0.0
		# Nếu hết nhiên liệu trong frame này → ngừng nung, lửa tắt
		if _fuel_energy <= 0.0:
			_smelt_active = false
			_set_fire_cold()
			for j in range(3):
				_smelt_progress[j] = 0.0
			return

func _complete_smelt(i: int, output_id: String) -> void:
	var fi = _furnace_inv
	if not fi.remove_item(i, 1):
		return
	var out_def: ItemDef = ItemDatabase.items_db.get(output_id) as ItemDef
	var out_slot: ItemSlot = fi.slots[OUT_SLOT_0 + i]
	if out_def == null:
		return
	if out_slot.is_empty():
		out_slot.item = out_def
		out_slot.count = 1
	else:
		out_slot.count += 1

func _update_fuel_bar() -> void:
	if _fuel_bar == null or _fuel_fill == null:
		return
	if not _smelt_active or _fuel_piece_value <= 0.0:
		_fuel_fill.size.x = 0.0
		_fuel_bar_label.text = tr("FURNACE_NO_FUEL")
		return
	var ratio: float = clampf(_fuel_energy / _fuel_piece_value, 0.0, 1.0)
	_fuel_fill.size.x = 146.0 * ratio
	_fuel_bar_label.text = "%d / %d s" % [int(_fuel_energy), int(_fuel_piece_value)]