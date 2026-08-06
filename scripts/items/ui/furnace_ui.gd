class_name FurnaceUI
extends Control

const S: float = 1.6
const SS: float = 1.4

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

var _furnace = null
var _player_ref: PlayerCharacter = null
var _furnace_inv: Inventory

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

var _smelting_items: Dictionary = {}
var _fuels: Dictionary = {}
var _smelt_active: bool = false
var _tween: Tween
var _smelt_progress: float = 0.0
var _smelt_time: float = 5.0
var _progress_bar: ColorRect
var _progress_fill: ColorRect

func _init() -> void:
	_furnace_inv = Inventory.new(3)

func _ready() -> void:
	_content_h = _build_layout()
	size = Vector2(PANEL_W, _content_h)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	_init_smelting_items()
	_setup_background()
	_setup_title()
	_setup_recipe_bar()
	_setup_furnace_slots()
	_setup_player_grid()
	visible = false

func _build_layout() -> float:
	var furnace_bottom: float = PAD + 22 + 64 + SLOT_SIZE
	var inv_label: float = furnace_bottom + 12
	var inv_start: float = inv_label + 24
	var grid_bottom: float = inv_start + 3 * (SLOT_SIZE + GAP)
	var hotbar_bottom: float = grid_bottom + GAP + SLOT_SIZE
	return hotbar_bottom + PAD

func _init_smelting_items() -> void:
	_smelting_items = {
		"copper_ore": "copper_ingot",
		"bauxite_ore": "aluminium_ingot",
		"silver_ore": "silver_ingot",
		"iron_ore": "iron_ingot",
		"gold_ore": "gold_ingot",
		"titan_ore": "titan_ingot",
		"platinum_ore": "platinum_ingot",
		"coal_ore": "coal",
	}
	# Chất đốt: than, than củi, gỗ dừa. 1 đơn vị = 1 mẻ nung.
	_fuels = {
		"coal": true,
		"charcoal": true,
		"palm_wood": true,
		"block_oak_wood": true,
	}
	for ore in _smelting_items:
		_recipes.append({ "input": ore, "output": _smelting_items[ore] })

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
	var title := Label.new()
	title.text = tr("FURNACE_LABEL")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(S * 15))
	title.add_theme_color_override("font_color", TEXT_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(RIGHT_X + PAD, PAD - 4)
	title.size = Vector2(GRID_W, 30)
	add_child(title)

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
	if _player_ref == null:
		return
	var pi = _player_ref.inventory
	var fi = _furnace_inv
	if pi == null or fi == null:
		return
	var input: String = _recipes[idx].input
	var inslot: ItemSlot = fi.slots[0]
	if not inslot.is_empty() and inslot.item.id != input:
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

	for r in _recipes:
		_recipe_card(r.input, r.output)

func _label(pos: Vector2, text: String, color: Color, isize: int = 12) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", int(S * isize))
	lbl.add_theme_color_override("font_color", color)
	add_child(lbl)

func _setup_furnace_slots() -> void:
	var base_x: float = RIGHT_X + GRID_W * 0.5 - 120
	var sy: float = PAD + 22
	var in_y := sy
	var fuel_y := sy + 64
	var out_y := sy

	# Input slot (idx 0)
	_label(Vector2(base_x, in_y - 24), tr("FURNACE_INPUT"), TEXT_DIM)
	var inp := _make_slot(base_x, in_y, _input_faces, _input_icons, _input_counts, _input_panels, "furnace", 0)
	inp.gui_input.connect(_on_slot_gui_input.bind("furnace", 0))

	# Fuel slot (idx 1)
	_label(Vector2(base_x + SLOT_SIZE + GAP, fuel_y - 24), tr("FURNACE_FUEL"), TEXT_DIM)
	var fuel := _make_slot(base_x + SLOT_SIZE + GAP, fuel_y, _fuel_faces, _fuel_icons, _fuel_counts, _fuel_panels, "furnace", 1)
	fuel.gui_input.connect(_on_slot_gui_input.bind("furnace", 1))

	# Arrow + progress between input and output
	var arrow_x: float = base_x + 2 * (SLOT_SIZE + GAP) + 4
	var arrow_y: float = sy + SLOT_SIZE * 0.5 - 6

	_progress_bar = ColorRect.new()
	_progress_bar.position = Vector2(arrow_x - 4, arrow_y - 4)
	_progress_bar.size = Vector2(40, 28)
	_progress_bar.color = Color(0.15, 0.10, 0.22, 0.6)
	add_child(_progress_bar)

	_progress_fill = ColorRect.new()
	_progress_fill.position = Vector2(arrow_x, arrow_y)
	_progress_fill.size = Vector2(0, 20)
	_progress_fill.color = ORANGE
	add_child(_progress_fill)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.position = Vector2(arrow_x + 12, arrow_y - 8)
	arrow.add_theme_font_size_override("font_size", int(S * 16))
	arrow.add_theme_color_override("font_color", TEXT_DIM)
	add_child(arrow)

	# Output label + slot (idx 2)
	var out_lbl := Label.new()
	out_lbl.text = tr("FURNACE_OUTPUT")
	out_lbl.position = Vector2(arrow_x + 66, sy - 26)
	out_lbl.add_theme_font_size_override("font_size", int(S * 12))
	out_lbl.add_theme_color_override("font_color", TEXT_DIM)
	add_child(out_lbl)
	var outp := _make_slot(arrow_x + 70, out_y, _output_faces, _output_icons, _output_counts, _output_panels, "furnace", 2)
	outp.gui_input.connect(_on_slot_gui_input.bind("furnace", 2))

func _setup_player_grid() -> void:
	var sx: float = RIGHT_X + PAD
	var inv_label_y: float = PAD + 22 + 64 + SLOT_SIZE + 12
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
			match idx:
				0: return _input_panels[0] if not _input_panels.is_empty() else null
				1: return _fuel_panels[0] if not _fuel_panels.is_empty() else null
				_: return _output_panels[0] if not _output_panels.is_empty() else null
	return null

func _on_slot_gui_input(event: InputEvent, _type: String, idx: int) -> void:
	if not visible or _furnace == null or _player_ref == null:
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
	_furnace_inv = Inventory.new(3)

func _process(_delta: float) -> void:
	if not visible or _player_ref == null:
		return
	var fi = _furnace_inv
	var pi = _player_ref.inventory
	if fi == null or pi == null:
		return

	var i0: ItemSlot = fi.slots[0]
	var i1: ItemSlot = fi.slots[1]
	var i2: ItemSlot = fi.slots[2]
	if _input_faces.size() > 0:
		_refresh_slot(i0, _input_faces[0], _input_icons[0], _input_counts[0])
	if _fuel_faces.size() > 0:
		_refresh_slot(i1, _fuel_faces[0], _fuel_icons[0], _fuel_counts[0])
	if _output_faces.size() > 0:
		_refresh_slot(i2, _output_faces[0], _output_icons[0], _output_counts[0])

	for i in range(27):
		var pidx: int = 9 + i
		if pidx < pi.slots.size() and i < _player_faces.size():
			_refresh_slot(pi.slots[pidx], _player_faces[i], _player_icons[i], _player_counts[i])
	for i in range(9):
		if i < pi.slots.size() and i < _hotbar_faces.size():
			_refresh_slot(pi.slots[i], _hotbar_faces[i], _hotbar_icons[i], _hotbar_counts[i])

	_update_smelting(_delta)

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

func _update_smelting(delta: float) -> void:
	var input_slot: ItemSlot = _furnace_inv.slots[0]
	var fuel_slot: ItemSlot = _furnace_inv.slots[1]
	var output_slot: ItemSlot = _furnace_inv.slots[2]

	if input_slot.is_empty() or input_slot.item.id not in _smelting_items:
		_smelt_active = false
		_smelt_progress = 0.0
		_progress_fill.size.x = 0
		return

	var output_id: String = _smelting_items[input_slot.item.id]
	if not output_slot.is_empty() and output_slot.item.id != output_id:
		_smelt_active = false
		_smelt_progress = 0.0
		_progress_fill.size.x = 0
		return
	if not output_slot.is_empty() and output_slot.count >= output_slot.item.max_stack:
		_smelt_active = false
		_smelt_progress = 0.0
		_progress_fill.size.x = 0
		return

	if fuel_slot.is_empty() or fuel_slot.item.id not in _fuels:
		_smelt_active = false
		_smelt_progress = 0.0
		_progress_fill.size.x = 0
		return

	if not _smelt_active:
		_smelt_active = true
		_smelt_progress = 0.0

	_smelt_progress += delta / _smelt_time
	_progress_fill.size.x = clampf(_smelt_progress * 32, 0, 32)

	if _smelt_progress >= 1.0:
		_complete_smelt(output_id)

func _complete_smelt(output_id: String) -> void:
	var input_slot: ItemSlot = _furnace_inv.slots[0]
	var output_slot: ItemSlot = _furnace_inv.slots[2]

	if not _furnace_inv.remove_item(0, 1):
		_smelt_active = false
		return
	# Tiêu hao 1 chất đốt / mẻ nung
	_furnace_inv.remove_item(1, 1)

	var out_def: ItemDef = ItemDatabase.items_db.get(output_id) as ItemDef
	if out_def == null:
		_smelt_active = false
		return

	if output_slot.is_empty():
		_furnace_inv.slots[2].item = out_def
		_furnace_inv.slots[2].count = 1
	else:
		output_slot.count += 1

	_smelt_progress = 0.0

	if input_slot.is_empty() or input_slot.item.id not in _smelting_items:
		_smelt_active = false
