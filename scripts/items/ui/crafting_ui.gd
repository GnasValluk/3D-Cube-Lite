class_name CraftingUI
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

var _grid_inventory: Inventory
var _player_ref: PlayerCharacter = null

var _grid_faces: Array[ColorRect] = []
var _grid_icons: Array[TextureRect] = []
var _grid_counts: Array[Label] = []
var _grid_panels: Array[Panel] = []

var _result_faces: Array[ColorRect] = []
var _result_icons: Array[TextureRect] = []
var _result_counts: Array[Label] = []
var _result_panels: Array[Panel] = []

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
var _tween: Tween

func _ready() -> void:
	_grid_inventory = Inventory.new(9)
	_content_h = _build_layout()
	size = Vector2(GRID_W + PAD * 2, _content_h)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	position += Vector2(160, 0)
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
	_slot_style.border_color = Color(0.85, 0.80, 0.95, 0.10)

	_slot_hover_style = _slot_style.duplicate()
	_slot_hover_style.bg_color = Color(0.22, 0.18, 0.35, 0.80)
	_slot_hover_style.border_color = Color(0.55, 0.57, 0.62, 0.60)

	_slot_drop_style = _slot_style.duplicate()
	_slot_drop_style.bg_color = Color(0.18, 0.35, 0.22, 0.75)
	_slot_drop_style.border_color = Color(0.22, 0.62, 0.28, 0.60)

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

	_setup_background()
	_setup_title()
	_setup_crafting_grid()
	_setup_result_slot()
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
	bg.size = Vector2(GRID_W + PAD * 2, _content_h)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	var title := Label.new()
	title.text = tr("CRAFTING_LABEL")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(S * 15))
	title.add_theme_color_override("font_color", TEXT_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(PAD, PAD - 4)
	title.size = Vector2(GRID_W, 30)
	add_child(title)

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
	face.position = Vector2(3, 3)
	face.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	face.color = Color(0.20, 0.15, 0.30, 0.4)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(face)
	faces.append(face)

	var slot_icon := TextureRect.new()
	slot_icon.position = Vector2(3, 3)
	slot_icon.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	slot_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_icon.visible = false
	panel.add_child(slot_icon)
	icons.append(slot_icon)

	var cnt := Label.new()
	cnt.position = Vector2(3, SLOT_SIZE - 22)
	cnt.size = Vector2(SLOT_SIZE - 6, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", int(S * 10))
	cnt.add_theme_color_override("font_color", TEXT_DIM)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cnt)
	counts.append(cnt)

	panels.append(panel)
	return panel

func _setup_crafting_grid() -> void:
	var grid_cols: int = 3
	var grid_sy: float = PAD + 22
	var grid_sx: float = PAD

	var lbl := Label.new()
	lbl.text = tr("CRAFTING_GRID")
	lbl.position = Vector2(grid_sx, grid_sy - 24)
	lbl.add_theme_font_size_override("font_size", int(S * 12))
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	add_child(lbl)

	for row in range(3):
		for col in range(grid_cols):
			var px: float = grid_sx + col * (SLOT_SIZE + GAP)
			var pyf: float = grid_sy + row * (SLOT_SIZE + GAP)
			var i: int = row * grid_cols + col
			var panel := _make_slot(px, pyf, _grid_faces, _grid_icons, _grid_counts, _grid_panels, "grid", i)
			panel.gui_input.connect(_on_slot_gui_input.bind("grid", i))

func _setup_result_slot() -> void:
	var grid_sx: float = PAD
	var grid_sy: float = PAD + 22
	var rsx: float = grid_sx + 3 * (SLOT_SIZE + GAP) - (SLOT_SIZE + GAP) + (SLOT_SIZE + GAP + 10)
	var rsy: float = grid_sy + 1 * (SLOT_SIZE + GAP) - 2

	var arrow := Label.new()
	arrow.text = "▼"
	arrow.position = Vector2(rsx - 32, rsy + 10)
	arrow.add_theme_font_size_override("font_size", int(S * 14))
	arrow.add_theme_color_override("font_color", TEXT_MUTED)
	add_child(arrow)

	var panel := _make_slot(rsx, rsy, _result_faces, _result_icons, _result_counts, _result_panels, "result", 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_player_grid() -> void:
	var sx: float = PAD
	var chest_rows: int = 3
	var py: float = PAD + 22 + chest_rows * (SLOT_SIZE + GAP) + 10

	var lbl := Label.new()
	lbl.text = "Inventory"
	lbl.position = Vector2(sx, py - 24)
	lbl.add_theme_font_size_override("font_size", int(S * 12))
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	add_child(lbl)

	for row in range(3):
		for col in range(COLS):
			var i: int = 9 + row * COLS + col
			var px: float = sx + col * (SLOT_SIZE + GAP)
			var py2: float = py + row * (SLOT_SIZE + GAP)
			var panel := _make_slot(px, py2, _player_faces, _player_icons, _player_counts, _player_panels, "player", i)
			panel.gui_input.connect(_on_slot_gui_input.bind("player", i))

	var hot_y: float = py + 3 * (SLOT_SIZE + GAP) + 6
	for col in range(COLS):
		var i: int = col
		var px: float = sx + col * (SLOT_SIZE + GAP)
		var panel := _make_slot(px, hot_y, _hotbar_faces, _hotbar_icons, _hotbar_counts, _hotbar_panels, "hotbar", i)
		panel.gui_input.connect(_on_slot_gui_input.bind("hotbar", i))

func _get_panel(_type: String, idx: int) -> Panel:
	match _type:
		"grid": return _grid_panels[idx] if idx >= 0 and idx < _grid_panels.size() else null
		"result": return _result_panels[idx] if idx >= 0 and idx < _result_panels.size() else null
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
	match _type:
		"grid":
			_transfer_from_grid(idx, slot.count)
		"player", "hotbar":
			_transfer_to_grid(idx, slot.count)

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
	match _type:
		"grid":
			_transfer_from_grid(idx, half)
		"player", "hotbar":
			_transfer_to_grid(idx, half)

func _get_inv(_type: String) -> Inventory:
	match _type:
		"grid": return _grid_inventory
		"result": return null
		"player", "hotbar": return _player_ref.inventory if _player_ref else null
	return null

func _transfer_from_grid(idx: int, count: int) -> void:
	var gi = _grid_inventory
	var pi = _player_ref.inventory
	if gi == null or pi == null:
		return
	var slot: ItemSlot = gi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	var remaining: int = pi.add_item(slot.item, count)
	if remaining < count:
		gi.remove_item(idx, count - remaining)

func _transfer_to_grid(idx: int, count: int) -> void:
	var gi = _grid_inventory
	var pi = _player_ref.inventory
	if gi == null or pi == null:
		return
	var slot: ItemSlot = pi.slots[idx]
	if slot.is_empty() or count < 1:
		return
	var remaining: int = gi.add_item(slot.item, count)
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
	if _type == "result":
		return null
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
	face.position = Vector2(3, 3)
	face.size = Vector2(ss - 6, ss - 6)
	face.color = slot.item.icon_color
	preview.add_child(face)
	var cnt := Label.new()
	cnt.position = Vector2(3, ss - 22)
	cnt.size = Vector2(ss - 6, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", int(S * 10))
	cnt.add_theme_color_override("font_color", TEXT_BRIGHT)
	cnt.text = str(slot.count) if slot.count > 1 else ""
	preview.add_child(cnt)
	set_drag_preview(preview)
	return data

func _slot_can_drop_data(_type: String, idx: int, _position: Vector2, data) -> bool:
	if _type == "result":
		return false
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
	if _type == "result":
		return
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
	var panels: Array = []
	match _type:
		"grid": panels = _grid_panels
		"player": panels = _player_panels
		"hotbar": panels = _hotbar_panels
	if idx >= 0 and idx < panels.size():
		panels[idx].add_theme_stylebox_override("panel", _slot_drop_style if on else _slot_style)

func _clear_drop_highlights() -> void:
	for p in _grid_panels:
		p.add_theme_stylebox_override("panel", _slot_style)
	for p in _player_panels:
		p.add_theme_stylebox_override("panel", _slot_style)
	for p in _hotbar_panels:
		p.add_theme_stylebox_override("panel", _slot_style)

func open(player: PlayerCharacter) -> void:
	_player_ref = player
	_play_appear()

func close() -> void:
	if _player_ref:
		var pi = _player_ref.inventory
		if pi:
			for i in range(_grid_inventory.slots.size()):
				var slot = _grid_inventory.slots[i]
				if not slot.is_empty():
					var remaining: int = pi.add_item(slot.item, slot.count)
					var moved: int = slot.count - remaining
					if moved > 0:
						_grid_inventory.remove_item(i, moved)
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
	if _player_ref == null:
		return
	var pi = _player_ref.inventory
	if pi == null:
		return

	for i in range(min(_grid_inventory.slots.size(), _grid_faces.size())):
		var slot: ItemSlot = _grid_inventory.slots[i]
		if slot.is_empty():
			_grid_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
			_grid_icons[i].texture = null; _grid_icons[i].visible = false
			_grid_counts[i].text = ""
		else:
			var tex := ItemDatabase.load_icon_2d(slot.item.id)
			_grid_faces[i].color = Color(0.20, 0.15, 0.30, 0.4) if tex != null else slot.item.icon_color
			_grid_icons[i].texture = tex; _grid_icons[i].visible = tex != null
			_grid_counts[i].text = str(slot.count) if slot.count > 1 else ""

	if _result_faces.size() > 0:
		_result_faces[0].color = Color(0.20, 0.15, 0.30, 0.2)
		_result_icons[0].texture = null; _result_icons[0].visible = false
		_result_counts[0].text = ""

	for i in range(27):
		var pidx: int = 9 + i
		if pidx < pi.slots.size() and i < _player_faces.size():
			var slot: ItemSlot = pi.slots[pidx]
			if slot.is_empty():
				_player_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
				_player_icons[i].texture = null; _player_icons[i].visible = false
				_player_counts[i].text = ""
			else:
				var tex := ItemDatabase.load_icon_2d(slot.item.id)
				_player_faces[i].color = Color(0.20, 0.15, 0.30, 0.4) if tex != null else slot.item.icon_color
				_player_icons[i].texture = tex; _player_icons[i].visible = tex != null
				_player_counts[i].text = str(slot.count) if slot.count > 1 else ""

	for i in range(9):
		if i < pi.slots.size() and i < _hotbar_faces.size():
			var slot: ItemSlot = pi.slots[i]
			if slot.is_empty():
				_hotbar_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
				_hotbar_icons[i].texture = null; _hotbar_icons[i].visible = false
				_hotbar_counts[i].text = ""
			else:
				var tex := ItemDatabase.load_icon_2d(slot.item.id)
				_hotbar_faces[i].color = Color(0.20, 0.15, 0.30, 0.4) if tex != null else slot.item.icon_color
				_hotbar_icons[i].texture = tex; _hotbar_icons[i].visible = tex != null
				_hotbar_counts[i].text = str(slot.count) if slot.count > 1 else ""
