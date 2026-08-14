class_name CraftingUI
extends Control

## Bàn chế tạo kiểu lưới (Minecraft): trái = danh sách công thức,
## phải = lưới chế tạo 2x2 (cầm tay) hoặc 3x3 (bàn chế tạo) + ô kết quả.
## Khớp công thức theo hình dạng ô; click recipe để tự xếp nguyên liệu.

const _RecipeDB = preload("res://scripts/items/core/recipe_database.gd")

const S: float = 1.6

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
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

var _player_ref: PlayerCharacter = null
var _grid_size: int = 2
var _built_grid_size: int = -1
var _craft_inv: Inventory

var _grid_faces: Array[ColorRect] = []
var _grid_icons: Array[TextureRect] = []
var _grid_counts: Array[Label] = []
var _grid_panels: Array[Panel] = []
var _player_faces: Array[ColorRect] = []
var _player_icons: Array[TextureRect] = []
var _player_counts: Array[Label] = []
var _player_panels: Array[Panel] = []
var _hotbar_faces: Array[ColorRect] = []
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_counts: Array[Label] = []
var _hotbar_panels: Array[Panel] = []

var _output_face: ColorRect
var _output_icon: TextureRect
var _output_count: Label
var _output_panel: Panel

var _content_h: float = 0.0
var _slot_style: StyleBoxFlat
var _slot_hover_style: StyleBoxFlat
var _slot_drop_style: StyleBoxFlat
var _slot_script: GDScript
var _craft_btn: Button

var _recipes: Array = []
var _recipe_cards: Array[Panel] = []
var _recipe_list: VBoxContainer
var _selected_recipe: int = -1
var _recipe_card_style: StyleBoxFlat
var _recipe_sel_style: StyleBoxFlat
var _empty_label: Label
var _tween: Tween

func _init() -> void:
	_craft_inv = Inventory.new(0)

func _ready() -> void:
	_grid_size = 2
	_built_grid_size = 2
	_build_ui()
	visible = false

func _build_ui() -> void:
	for ch in get_children():
		ch.free()
	_grid_faces.clear()
	_grid_icons.clear()
	_grid_counts.clear()
	_grid_panels.clear()
	_player_faces.clear()
	_player_icons.clear()
	_player_counts.clear()
	_player_panels.clear()
	_hotbar_faces.clear()
	_hotbar_icons.clear()
	_hotbar_counts.clear()
	_hotbar_panels.clear()
	_recipe_cards.clear()
	_build_layout()
	_setup_styles()
	_setup_background()
	_setup_title()
	_setup_recipe_bar()
	_setup_craft_area()
	_setup_player_grid()

func _build_layout() -> void:
	var grid_w: float = _grid_size * (SLOT_SIZE + GAP) - GAP
	var craft_top: float = PAD + 22
	var craft_h: float = maxf(grid_w, SLOT_SIZE) + 16 + SLOT_SIZE + 12 + 46
	var inv_label: float = craft_top + craft_h + 12
	var inv_start: float = inv_label + 24
	var grid_bottom: float = inv_start + 3 * (SLOT_SIZE + GAP)
	var hotbar_bottom: float = grid_bottom + GAP + SLOT_SIZE
	_content_h = hotbar_bottom + PAD
	size = Vector2(PANEL_W, _content_h)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	position += Vector2(0, -10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	title.text = tr("CRAFT_HAND") if _grid_size == 2 else tr("CRAFTING_LABEL")
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

func _setup_craft_area() -> void:
	var grid_w: float = _grid_size * (SLOT_SIZE + GAP) - GAP
	var base_x: float = RIGHT_X + (GRID_W - grid_w) * 0.5
	var craft_top: float = PAD + 22

	# Ô kết quả bên phải lưới
	var out_x: float = base_x + grid_w + 14
	var out_y: float = craft_top + maxf(grid_w, SLOT_SIZE) * 0.5 - SLOT_SIZE * 0.5
	_output_panel = Panel.new()
	_output_panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_output_panel.position = Vector2(out_x, out_y)
	_output_panel.clip_contents = true
	_output_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_output_panel.add_theme_stylebox_override("panel", _slot_drop_style)
	_output_panel.gui_input.connect(_on_output_input)
	add_child(_output_panel)

	_output_face = ColorRect.new()
	_output_face.position = Vector2(2, 2)
	_output_face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	_output_face.color = Color(0.20, 0.15, 0.30, 0.4)
	_output_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output_panel.add_child(_output_face)

	_output_icon = TextureRect.new()
	_output_icon.position = Vector2(2, 2)
	_output_icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	_output_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_output_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output_panel.add_child(_output_icon)

	_output_count = Label.new()
	_output_count.position = Vector2(2, SLOT_SIZE - 24)
	_output_count.size = Vector2(SLOT_SIZE - 4, 18)
	_output_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_output_count.add_theme_font_size_override("font_size", 18)
	_output_count.add_theme_color_override("font_color", TEXT_BRIGHT)
	_output_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output_panel.add_child(_output_count)

	# Mũi tên giữa lưới và ô kết quả
	var arrow := Label.new()
	arrow.text = "→"
	arrow.position = Vector2(out_x - 30, out_y + SLOT_SIZE * 0.5 - 16)
	arrow.size = Vector2(26, 32)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", int(S * 18))
	arrow.add_theme_color_override("font_color", TEXT_DIM)
	add_child(arrow)

	# Nút chế tạo dưới lưới
	_craft_btn = Button.new()
	_craft_btn.text = tr("CRAFT_BUTTON")
	_craft_btn.position = Vector2(base_x + grid_w * 0.5 - 80, craft_top + maxf(grid_w, SLOT_SIZE) + 12)
	_craft_btn.size = Vector2(160, 46)
	_craft_btn.add_theme_font_size_override("font_size", int(S * 13))
	_craft_btn.add_theme_color_override("font_color", TEXT_BRIGHT)
	var craft_style := StyleBoxFlat.new()
	craft_style.bg_color = Color(0.18, 0.55, 0.30)
	craft_style.corner_radius_top_left = 8
	craft_style.corner_radius_top_right = 8
	craft_style.corner_radius_bottom_left = 8
	craft_style.corner_radius_bottom_right = 8
	craft_style.border_width_left = 2
	craft_style.border_width_right = 2
	craft_style.border_width_top = 2
	craft_style.border_width_bottom = 2
	craft_style.border_color = Color(0.30, 0.80, 0.45, 0.6)
	_craft_btn.add_theme_stylebox_override("normal", craft_style)
	_craft_btn.add_theme_stylebox_override("hover", craft_style)
	_craft_btn.add_theme_stylebox_override("pressed", craft_style)
	var craft_dis_style := craft_style.duplicate()
	craft_dis_style.bg_color = Color(0.12, 0.13, 0.16)
	craft_dis_style.border_color = Color(0.30, 0.30, 0.32, 0.4)
	_craft_btn.add_theme_stylebox_override("disabled", craft_dis_style)
	_craft_btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	_craft_btn.pressed.connect(_craft)
	add_child(_craft_btn)

	# Lưới chế tạo
	_craft_inv = Inventory.new(_grid_size * _grid_size)
	var grid_top: float = craft_top + maxf(grid_w, SLOT_SIZE) * 0.5 - grid_w * 0.5
	for r in range(_grid_size):
		for c in range(_grid_size):
			var i: int = r * _grid_size + c
			var px: float = base_x + c * (SLOT_SIZE + GAP)
			var py: float = grid_top + r * (SLOT_SIZE + GAP)
			var panel := _make_slot(px, py, _grid_faces, _grid_icons, _grid_counts, _grid_panels, "grid", i)
			panel.gui_input.connect(_on_slot_gui_input.bind("grid", i))

func _on_output_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_craft()

func _setup_player_grid() -> void:
	var sx: float = RIGHT_X + PAD
	var grid_w: float = _grid_size * (SLOT_SIZE + GAP) - GAP
	var craft_top: float = PAD + 22
	var craft_h: float = maxf(grid_w, SLOT_SIZE) + 16 + SLOT_SIZE + 12 + 46
	var inv_label_y: float = craft_top + craft_h + 12
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
		"grid": return _grid_panels[idx] if idx >= 0 and idx < _grid_panels.size() else null
		"player": return _player_panels[idx] if idx >= 0 and idx < _player_panels.size() else null
		"hotbar": return _hotbar_panels[idx] if idx >= 0 and idx < _hotbar_panels.size() else null
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
	if _type == "grid":
		_transfer_from_grid(idx, 1)
	else:
		_transfer_to_grid(idx, _type, 1)

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
	if _type == "grid":
		_transfer_from_grid(idx, half)
	else:
		_transfer_to_grid(idx, _type, half)

func _get_inv(_type: String) -> Inventory:
	match _type:
		"grid": return _craft_inv
		"player", "hotbar": return _player_ref.inventory if _player_ref else null
	return null

func _transfer_from_grid(idx: int, count: int) -> void:
	var gi = _craft_inv
	var pi = _player_ref.inventory
	if gi == null or pi == null:
		return
	var slot: ItemSlot = gi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	var remaining: int = pi.add_item(slot.item, count)
	if remaining < count:
		gi.remove_item(idx, count - remaining)

func _transfer_to_grid(idx: int, _type: String, count: int) -> void:
	var gi = _craft_inv
	var pi = _player_ref.inventory
	if gi == null or pi == null:
		return
	var slot: ItemSlot = pi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	# Lưới chế tạo kiểu Minecraft: mỗi lần chuyển đặt 1 đơn vị vào ô trống đầu
	# tiên (không gộp chồng) để giữ đúng hình dạng công thức.
	var placed: int = 0
	for g in range(gi.slots.size()):
		if placed >= count:
			break
		var gs: ItemSlot = gi.slots[g]
		if gs.is_empty():
			gs.item = slot.item
			gs.count = 1
			placed += 1
	pi.remove_item(idx, placed)

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
	for p in _grid_panels + _player_panels + _hotbar_panels:
		p.add_theme_stylebox_override("panel", _slot_style)

func _recipe_card(r: Dictionary) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(LIST_W - 14, 76)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _recipe_card_style)
	var idx: int = _recipe_cards.size()
	card.gui_input.connect(_on_recipe_input.bind(idx))
	_recipe_list.add_child(card)
	_recipe_cards.append(card)

	ItemDatabase.ensure_db()
	var rid: String = r.get("result", "")
	var out_def: ItemDef = ItemDatabase.items_db.get(rid) as ItemDef
	var out_name: String = out_def.name if out_def != null else rid

	var out_slot := Panel.new()
	out_slot.position = Vector2(8, 14)
	out_slot.size = Vector2(48, 48)
	out_slot.clip_contents = true
	out_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_slot.add_theme_stylebox_override("panel", _slot_style)
	card.add_child(out_slot)
	var rout := ItemDatabase.load_icon_2d(rid)
	if rout:
		var t := TextureRect.new()
		t.position = Vector2(2, 2)
		t.size = Vector2(44, 44)
		t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture = rout
		out_slot.add_child(t)

	var nm := Label.new()
	nm.text = out_name
	nm.position = Vector2(64, 10)
	nm.size = Vector2(LIST_W - 76, 22)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_font_size_override("font_size", int(S * 11))
	nm.add_theme_color_override("font_color", TEXT_BRIGHT)
	card.add_child(nm)

	var cnt := Label.new()
	cnt.text = "x%d" % r.get("count", 1)
	cnt.position = Vector2(LIST_W - 74, 12)
	cnt.size = Vector2(52, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", int(S * 9))
	cnt.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
	card.add_child(cnt)

	# Dòng nguyên liệu: icon + số lượng
	var ing: Dictionary = r.get("ingredients", {})
	var x: float = 64.0
	var y: float = 38.0
	var first := true
	for ing_id in ing:
		if not first:
			var plus := Label.new()
			plus.text = "+"
			plus.position = Vector2(x, y - 1)
			plus.add_theme_font_size_override("font_size", int(S * 9))
			plus.add_theme_color_override("font_color", TEXT_MUTED)
			card.add_child(plus)
			x += 14.0
		first = false
		_add_small_icon(card, x, y, 18, ing_id)
		var need := Label.new()
		need.text = "x%d" % int(ing[ing_id])
		need.position = Vector2(x + 20, y + 1)
		need.add_theme_font_size_override("font_size", int(S * 8))
		need.add_theme_color_override("font_color", TEXT_DIM)
		card.add_child(need)
		x += 20.0 + 16.0 * int(ing[ing_id]) + 26.0
		if x > LIST_W - 30:
			break

func _add_small_icon(parent: Control, px: float, py: float, sz: float, item_id: String) -> void:
	ItemDatabase.ensure_db()
	var tex := ItemDatabase.load_icon_2d(item_id)
	var slot := Panel.new()
	slot.position = Vector2(px, py)
	slot.size = Vector2(sz, sz)
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _slot_style)
	parent.add_child(slot)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.position = Vector2(1, 1)
		t.size = Vector2(sz - 2, sz - 2)
		t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(t)

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

	_empty_label = Label.new()
	_empty_label.text = tr("NO_RECIPES")
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", int(S * 11))
	_empty_label.add_theme_color_override("font_color", TEXT_MUTED)
	_recipe_list.add_child(_empty_label)

	for r in _recipes:
		_recipe_card(r)

func _on_recipe_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and idx >= 0 and idx < _recipes.size():
		_select_recipe(idx)
		_try_fill_from_recipe(idx)

func _select_recipe(idx: int) -> void:
	_selected_recipe = idx
	for i in range(_recipe_cards.size()):
		_recipe_cards[i].add_theme_stylebox_override("panel", _recipe_sel_style if i == idx else _recipe_card_style)

func _try_fill_from_recipe(idx: int) -> void:
	if _player_ref == null:
		return
	var r: Dictionary = _recipes[idx] if idx >= 0 and idx < _recipes.size() else {}
	if r.is_empty():
		return
	var pi = _player_ref.inventory
	if pi == null:
		return
	# Trả đồ đang nằm trong lưới về túi trước
	for i in range(_craft_inv.slots.size()):
		var slot: ItemSlot = _craft_inv.slots[i]
		if not slot.is_empty():
			pi.add_item(slot.item, slot.count)
	_craft_inv = Inventory.new(_grid_size * _grid_size)
	var pattern: Array = r.get("pattern", [])
	var ing: Dictionary = r.get("ingredients", {})
	# Kiểm tra đủ nguyên liệu
	for ing_id in ing:
		if pi.get_item_count(ing_id) < int(ing[ing_id]):
			return
	# Đặt pattern vào lưới (dịch về góc trái-trên)
	for row in range(pattern.size()):
		var prow: Array = pattern[row]
		for col in range(prow.size()):
			var cell: String = prow[col]
			if cell == "":
				continue
			var def: ItemDef = ItemDatabase.items_db.get(cell) as ItemDef
			if def == null:
				return
			var slot_idx: int = row * _grid_size + col
			if slot_idx >= _craft_inv.slots.size():
				return
			pi.remove_item_by_id(cell, 1)
			_craft_inv.slots[slot_idx].item = def
			_craft_inv.slots[slot_idx].count = 1

func _matched() -> Dictionary:
	return _RecipeDB.match_shape(_craft_inv, _grid_size)

func _craft() -> void:
	if _player_ref == null:
		return
	var matched := _matched()
	if matched.is_empty():
		return
	var pi = _player_ref.inventory
	if pi == null:
		return
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(matched.get("result", "")) as ItemDef
	if def == null:
		return
	var count: int = matched.get("count", 1)
	# Kiểm tra chỗ trống
	if pi.is_full() and not (def.stackable and pi.get_item_count(def.id) > 0):
		return
	# Tiêu hao từng ô trong lưới 1 đơn vị
	for i in range(_craft_inv.slots.size()):
		if not _craft_inv.slots[i].is_empty():
			_craft_inv.remove_item(i, 1)
	pi.add_item(def, count)
	if _player_ref.has_method("_scroll_inventory_message"):
		_player_ref._scroll_inventory_message("+%d %s" % [count, def.name])

func open(player: PlayerCharacter, grid_size: int = 2, station_id: String = "") -> void:
	_player_ref = player
	_RecipeDB.ensure()
	_recipes = _RecipeDB.recipes.duplicate()
	if station_id != "":
		var filtered: Array[Dictionary] = []
		for r in _recipes:
			var req: String = r.get("station", "")
			if req == "" or req == station_id:
				filtered.append(r)
		_recipes = filtered
	_selected_recipe = -1
	var new_size: int = grid_size if grid_size == 3 else 2
	# Nếu lưới đang chứa đồ và sắp đổi kích thước: trả đồ về túi trước khi build lại
	if _craft_inv != null and _craft_inv.slots.size() != new_size * new_size and _player_ref:
		for i in range(_craft_inv.slots.size()):
			var slot: ItemSlot = _craft_inv.slots[i]
			if not slot.is_empty():
				_player_ref.inventory.add_item(slot.item, slot.count)
	_craft_inv = Inventory.new(new_size * new_size)
	_grid_size = new_size
	if _built_grid_size != new_size:
		_build_ui()
		_built_grid_size = new_size
	_rebuild_recipe_list()
	_play_appear()

func _rebuild_recipe_list() -> void:
	for ch in _recipe_list.get_children():
		if ch == _empty_label:
			continue
		ch.queue_free()
	_recipe_cards.clear()
	_empty_label.visible = _recipes.is_empty()
	if _empty_label.visible:
		return
	for r in _recipes:
		_recipe_card(r)

func close() -> void:
	# Trả đồ còn trong lưới về túi người chơi
	if _player_ref and _player_ref.inventory:
		for i in range(_craft_inv.slots.size()):
			var slot: ItemSlot = _craft_inv.slots[i]
			if not slot.is_empty():
				_player_ref.inventory.add_item(slot.item, slot.count)
	_craft_inv = Inventory.new(_grid_size * _grid_size)
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

func _process(_delta: float) -> void:
	if not visible or _player_ref == null:
		return
	var pi = _player_ref.inventory
	if pi == null:
		return
	# Cập nhật lưới chế tạo
	for i in range(_craft_inv.slots.size()):
		if i < _grid_faces.size():
			_refresh_slot(_craft_inv.slots[i], _grid_faces[i], _grid_icons[i], _grid_counts[i])
	# Túi người chơi
	for i in range(27):
		var pidx: int = 9 + i
		if pidx < pi.slots.size() and i < _player_faces.size():
			_refresh_slot(pi.slots[pidx], _player_faces[i], _player_icons[i], _player_counts[i])
	for i in range(9):
		if i < pi.slots.size() and i < _hotbar_faces.size():
			_refresh_slot(pi.slots[i], _hotbar_faces[i], _hotbar_icons[i], _hotbar_counts[i])
	# Ô kết quả
	var matched := _matched()
	if matched.is_empty():
		_output_icon.texture = null
		_output_icon.visible = false
		_output_face.color = Color(0.20, 0.15, 0.30, 0.4)
		_output_count.text = ""
		_craft_btn.disabled = true
		return
	ItemDatabase.ensure_db()
	var rid: String = matched.get("result", "")
	var rdef: ItemDef = ItemDatabase.items_db.get(rid) as ItemDef
	var tex := ItemDatabase.load_icon_2d(rid)
	_output_icon.texture = tex
	_output_icon.visible = tex != null
	_output_face.color = Color(0.05, 0.04, 0.10, 0.55) if tex != null else (rdef.icon_color if rdef != null else Color(0.20, 0.15, 0.30, 0.5))
	var count: int = matched.get("count", 1)
	_output_count.text = "x%d" % count if count > 1 else ""
	_craft_btn.disabled = _craft_inv.is_empty()

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
