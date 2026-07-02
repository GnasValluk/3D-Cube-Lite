class_name ChestUI
extends Control

const SLOT_SIZE: float = 40.0
const GAP: float = 3.0
const COLS: int = 9
const PAD: float = 14.0
const GRID_W: float = COLS * (SLOT_SIZE + GAP) - GAP

var _chest = null
var _player_ref: PlayerCharacter = null
var _chest_faces: Array[ColorRect] = []
var _chest_counts: Array[Label] = []
var _player_faces: Array[ColorRect] = []
var _player_counts: Array[Label] = []
var _hotbar_faces: Array[ColorRect] = []
var _hotbar_counts: Array[Label] = []

var _content_h: float = 0.0
var _slot_style: StyleBoxFlat

func _ready() -> void:
	_content_h = _build_layout()
	size = Vector2(GRID_W + PAD * 2, _content_h)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.08, 0.08, 0.14, 0.70)
	_slot_style.corner_radius_top_left = 4
	_slot_style.corner_radius_top_right = 4
	_slot_style.corner_radius_bottom_left = 4
	_slot_style.corner_radius_bottom_right = 4
	_slot_style.border_width_left = 1
	_slot_style.border_width_right = 1
	_slot_style.border_width_top = 1
	_slot_style.border_width_bottom = 1
	_slot_style.border_color = Color(1, 1, 1, 0.10)

	_setup_background()
	_setup_title()
	_setup_chest_grid()
	_setup_player_grid()
	visible = false

func _build_layout() -> float:
	var top: float = PAD + 24
	top += 3 * (SLOT_SIZE + GAP) + 8
	top += 3 * (SLOT_SIZE + GAP) + 6
	top += 1 * (SLOT_SIZE + GAP)
	return top + PAD

func _setup_background() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.14, 0.70)
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(1, 1, 1, 0.12)

	var bg := Panel.new()
	bg.size = Vector2(GRID_W + PAD * 2, _content_h)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	var title := Label.new()
	title.text = "Chest  -  Press F to close"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(PAD, PAD - 2)
	title.size = Vector2(GRID_W, 22)
	add_child(title)

func _make_slot(px: float, py: float, faces: Array, counts: Array) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(px, py)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _slot_style)
	add_child(panel)

	var face := ColorRect.new()
	face.position = Vector2(2, 2)
	face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	face.color = Color(0.15, 0.15, 0.22, 0.4)
	panel.add_child(face)
	faces.append(face)

	var cnt := Label.new()
	cnt.position = Vector2(2, SLOT_SIZE - 16)
	cnt.size = Vector2(SLOT_SIZE - 4, 14)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 10)
	cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
	panel.add_child(cnt)
	counts.append(cnt)

	return panel

func _setup_chest_grid() -> void:
	var sx: float = PAD
	var sy: float = PAD + 22
	var rows: int = 3

	var lbl := Label.new()
	lbl.text = "Chest"
	lbl.position = Vector2(sx, sy - 18)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.60))
	add_child(lbl)

	for row in range(rows):
		for col in range(COLS):
			var px: float = sx + col * (SLOT_SIZE + GAP)
			var pyf: float = sy + row * (SLOT_SIZE + GAP)
			var i: int = row * COLS + col
			var panel := _make_slot(px, pyf, _chest_faces, _chest_counts)
			panel.gui_input.connect(_on_slot_gui_input.bind("chest", i))

func _setup_player_grid() -> void:
	var sx: float = PAD
	var chest_rows: int = 3
	var py: float = PAD + 22 + chest_rows * (SLOT_SIZE + GAP) + 10

	var lbl := Label.new()
	lbl.text = "Inventory"
	lbl.position = Vector2(sx, py - 18)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.60))
	add_child(lbl)

	for row in range(3):
		for col in range(COLS):
			var i: int = 9 + row * COLS + col
			var px: float = sx + col * (SLOT_SIZE + GAP)
			var py2: float = py + row * (SLOT_SIZE + GAP)
			var panel := _make_slot(px, py2, _player_faces, _player_counts)
			panel.gui_input.connect(_on_slot_gui_input.bind("player", i))

	var hot_y: float = py + 3 * (SLOT_SIZE + GAP) + 6
	for col in range(COLS):
		var i: int = col
		var px: float = sx + col * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, hot_y, _hotbar_faces, _hotbar_counts)
		panel.gui_input.connect(_on_slot_gui_input.bind("hotbar", i))

func _on_slot_gui_input(event: InputEvent, _type: String, idx: int) -> void:
	if not visible or _chest == null or _player_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _type == "chest":
			_transfer_from_chest(idx)
		else:
			_transfer_to_chest(idx, _type)

func _transfer_from_chest(idx: int) -> void:
	var ci = _chest.inventory
	var pi = _player_ref.inventory
	if ci == null or pi == null:
		return
	var slot: ItemSlot = ci.slots[idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item
	var count: int = slot.count
	var remaining: int = pi.add_item(item, count)
	if remaining < count:
		ci.remove_item(idx, count - remaining)

func _transfer_to_chest(idx: int, _type: String) -> void:
	var ci = _chest.inventory
	var pi = _player_ref.inventory
	if ci == null or pi == null:
		return
	var slot: ItemSlot = pi.slots[idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item
	var count: int = slot.count
	var remaining: int = ci.add_item(item, count)
	if remaining < count:
		pi.remove_item(idx, count - remaining)

func open(chest, player: PlayerCharacter) -> void:
	_chest = chest
	_player_ref = player
	visible = true

func close() -> void:
	_chest = null
	_player_ref = null
	visible = false

func _process(_delta: float) -> void:
	if _chest == null or _player_ref == null:
		return
	var ci = _chest.inventory
	var pi = _player_ref.inventory
	if ci == null or pi == null:
		return

	for i in range(min(ci.slots.size(), _chest_faces.size())):
		var slot: ItemSlot = ci.slots[i]
		var col: Color = Color(0.15, 0.15, 0.22, 0.4) if slot.is_empty() else slot.item.icon_color
		_chest_faces[i].color = col
		_chest_counts[i].text = "" if slot.is_empty() else (str(slot.count) if slot.count > 1 else "")

	for i in range(27):
		var pidx: int = 9 + i
		if pidx < pi.slots.size() and i < _player_faces.size():
			var slot: ItemSlot = pi.slots[pidx]
			var col: Color = Color(0.15, 0.15, 0.22, 0.4) if slot.is_empty() else slot.item.icon_color
			_player_faces[i].color = col
			_player_counts[i].text = "" if slot.is_empty() else (str(slot.count) if slot.count > 1 else "")

	for i in range(9):
		if i < pi.slots.size() and i < _hotbar_faces.size():
			var slot: ItemSlot = pi.slots[i]
			var col: Color = Color(0.15, 0.15, 0.22, 0.4) if slot.is_empty() else slot.item.icon_color
			_hotbar_faces[i].color = col
			_hotbar_counts[i].text = "" if slot.is_empty() else (str(slot.count) if slot.count > 1 else "")
