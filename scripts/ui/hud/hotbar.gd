class_name Hotbar
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

signal slot_changed(idx: int)

var _inventory: Inventory = null
var _player_ref: PlayerCharacter = null   # direct reference, không cần find
var _selected: int = 0
var _slots: Array[Panel] = []
var _slot_faces: Array[ColorRect] = []
var _slot_labels: Array[Label] = []
var _slot_icons: Array[TextureRect] = []
var _slot_count_labels: Array[Label] = []
var _tooltip: Label = null
var _tooltip_bg: ColorRect = null

var _slot_style: StyleBoxFlat
var _slot_hl_style: StyleBoxFlat
var _slot_sel_style: StyleBoxFlat
var _slot_hover_style: StyleBoxFlat
var _slot_drop_style: StyleBoxFlat

func _ready() -> void:
	var ss: float = 62.0
	var gap: float = 6.0
	var tw: float = ss * 9 + gap * 8

	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -tw * 0.5
	offset_top = -(ss + 22)
	offset_right = tw * 0.5
	offset_bottom = -20

	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.70)
	_slot_style.corner_radius_top_left = 4
	_slot_style.corner_radius_top_right = 4
	_slot_style.corner_radius_bottom_left = 4
	_slot_style.corner_radius_bottom_right = 4
	_slot_style.border_width_left = 1
	_slot_style.border_width_right = 1
	_slot_style.border_width_top = 1
	_slot_style.border_width_bottom = 1
	_slot_style.border_color = Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.10)

	_slot_hl_style = _slot_style.duplicate()
	_slot_hl_style.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.70)

	_slot_sel_style = _slot_style.duplicate()
	_slot_sel_style.bg_color = Color(0.22, 0.18, 0.35, 0.75)
	_slot_sel_style.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.45)

	_slot_hover_style = _slot_style.duplicate()
	_slot_hover_style.bg_color = Color(0.22, 0.18, 0.35, 0.80)
	_slot_hover_style.border_color = Color(0.55, 0.57, 0.62, 0.60)

	_slot_drop_style = _slot_style.duplicate()
	_slot_drop_style.bg_color = Color(0.18, 0.35, 0.22, 0.75)
	_slot_drop_style.border_color = Color(0.22, 0.62, 0.28, 0.60)

	var slot_scr := GDScript.new()
	slot_scr.source_code = """
extends Panel
var _hb_ui = null
var _hb_idx = -1
func _get_drag_data(at_position):
	return _hb_ui._slot_get_drag_data(_hb_idx, at_position) if _hb_ui else null
func _can_drop_data(position, data):
	return _hb_ui._slot_can_drop_data(_hb_idx, position, data) if _hb_ui else false
func _drop_data(position, data):
	if _hb_ui: _hb_ui._slot_drop_data(_hb_idx, position, data)
"""
	slot_scr.reload()

	for i in range(9):
		var panel := Panel.new()
		panel.size = Vector2(ss, ss)
		panel.position = Vector2(i * (ss + gap), 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui_input.bind(i))
		panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_slot_mouse_exited)
		panel.add_theme_stylebox_override("panel", _slot_style)
		panel.set_script(slot_scr)
		panel._hb_ui = self
		panel._hb_idx = i
		add_child(panel)

		var face := ColorRect.new()
		face.position = Vector2(3, 3)
		face.size = Vector2(ss - 4, ss - 4)
		face.color = Color(0.20, 0.15, 0.30, 0.4)
		panel.add_child(face)
		_slot_faces.append(face)

		var lbl := Label.new()
		lbl.position = Vector2(3, 3)
		lbl.size = Vector2(ss - 4, ss - 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", TEXT_BRIGHT)
		panel.add_child(lbl)
		_slot_labels.append(lbl)

		var icon_tex := TextureRect.new()
		icon_tex.position = Vector2(3, 3)
		icon_tex.size = Vector2(ss - 4, ss - 4)
		icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_tex.visible = false
		panel.add_child(icon_tex)
		_slot_icons.append(icon_tex)

		var cnt := Label.new()
		cnt.position = Vector2(3, ss - 24)
		cnt.size = Vector2(ss - 4, 20)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 16)
		cnt.add_theme_color_override("font_color", TEXT_DIM)
		panel.add_child(cnt)
		_slot_count_labels.append(cnt)

		var key_lbl := Label.new()
		key_lbl.position = Vector2(3, 0)
		key_lbl.size = Vector2(20, 20)
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		key_lbl.text = str(i + 1)
		panel.add_child(key_lbl)

		_slots.append(panel)

	_tooltip_bg = ColorRect.new()
	_tooltip_bg.color = Color(0.08, 0.05, 0.16, 0.92)
	_tooltip_bg.position = Vector2(0, -50)
	_tooltip_bg.size = Vector2(170, 40)
	_tooltip_bg.visible = false
	add_child(_tooltip_bg)

	_tooltip = Label.new()
	_tooltip.position = Vector2(6, -48)
	_tooltip.size = Vector2(162, 34)
	_tooltip.add_theme_font_size_override("font_size", 18)
	_tooltip.add_theme_color_override("font_color", TEXT_BRIGHT)
	_tooltip.visible = false
	add_child(_tooltip)

	_select(0)
	visible = false

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select(idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_slot_right_click(idx)

func _on_slot_right_click(idx: int) -> void:
	if _inventory == null:
		return
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty() or not slot.item.stackable:
		return
	if slot.count > 1:
		var half: int = slot.count / 2
		_inventory.split_stack(idx, half)

func _on_slot_mouse_entered(idx: int) -> void:
	if _inventory == null:
		return
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		_tooltip.visible = false
		_tooltip_bg.visible = false
		_slots[idx].add_theme_stylebox_override("panel", _slot_hover_style)
		return
	_tooltip.text = slot.item.name
	_tooltip_bg.size.x = max(170, _tooltip.get_minimum_size().x + 8)
	_tooltip_bg.visible = true
	_tooltip.visible = true
	_slots[idx].add_theme_stylebox_override("panel", _slot_hover_style)

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false
	_tooltip_bg.visible = false
	_update_highlight()

# ── Drag & Drop ────────────────────────────────────────────────────────────────
func _slot_get_drag_data(idx: int, _at_position: Vector2):
	if _inventory == null:
		return null
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		return null
	var data := { "from_idx": idx, "from_inv": _inventory, "item_id": slot.item.id, "count": slot.count }
	var preview := Panel.new()
	var ss: float = 62.0
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
	cnt.position = Vector2(3, ss - 24)
	cnt.size = Vector2(ss - 6, 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0, 0.90))
	cnt.text = str(slot.count) if slot.count > 1 else ""
	preview.add_child(cnt)
	set_drag_preview(preview)
	return data

func _slot_can_drop_data(idx: int, _position: Vector2, data) -> bool:
	_update_highlight()
	if _inventory == null or data == null or not (data is Dictionary):
		return false
	if not data.has("from_idx") or not data.has("from_inv"):
		return false
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	if from_inv == _inventory and from_idx == idx:
		return false
	var src := from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
	if src == null or src.is_empty():
		return false
	var dst := _inventory.slots[idx]
	if dst.is_empty():
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	if from_inv == _inventory:
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	if dst.item.id == src.item.id and dst.item.stackable and dst.count < dst.item.max_stack:
		_slots[idx].add_theme_stylebox_override("panel", _slot_drop_style)
		return true
	return false

func _slot_drop_data(idx: int, _position: Vector2, data) -> void:
	_update_highlight()
	if _inventory == null or data == null or not (data is Dictionary):
		return
	if not data.has("from_idx") or not data.has("from_inv"):
		return
	var from_inv: Inventory = data["from_inv"]
	var from_idx: int = data["from_idx"]
	if from_inv == _inventory:
		if _inventory.can_transfer(from_idx, idx):
			_inventory.transfer(from_idx, idx)
		else:
			_inventory.swap(from_idx, idx)
	else:
		var src := from_inv.slots[from_idx] if from_idx >= 0 and from_idx < from_inv.slots.size() else null
		if src == null or src.is_empty():
			return
		var remaining: int = _inventory.add_item(src.item, src.count)
		if remaining < src.count:
			from_inv.remove_item(from_idx, src.count - remaining)

func _auto_equip_selected() -> void:
	var player: PlayerCharacter = _player_ref
	print("[Hotbar] _auto_equip slot=%d player=%s" % [_selected, str(player != null)])
	if player == null or _inventory == null:
		return
	var slot: ItemSlot = _inventory.slots[_selected]
	if slot.is_empty():
		player.equip_weapon_direct(null)
		return
	var item: ItemDef = slot.item
	print("[Hotbar] equipping item: ", item.id, " type=", item.type)
	player.equip_weapon_direct(item)

func _find_player() -> PlayerCharacter:
	if _player_ref != null:
		return _player_ref
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.current_scene
	if root == null:
		return null
	for child in root.find_children("", "PlayerCharacter", true, false):
		return child as PlayerCharacter
	return null

func set_inventory(inv: Inventory) -> void:
	_inventory = inv
	if inv != null:
		_auto_equip_selected()

func set_player(player: PlayerCharacter) -> void:
	_player_ref = player
	print("[Hotbar] set_player called: ", player != null)

func select_slot(idx: int) -> void:
	if idx >= 0 and idx < 9:
		_select(idx)

func get_selected() -> int:
	return _selected

func get_selected_item() -> ItemDef:
	if _inventory == null:
		return null
	var slot: ItemSlot = _inventory.slots[_selected]
	if slot.is_empty():
		return null
	return slot.item

func _select(idx: int) -> void:
	if _selected == idx:
		return
	_selected = idx
	_update_highlight()
	# Auto-equip: khi chọn slot có weapon/tool → tự cầm; slot trống/khác → bỏ
	_auto_equip_selected()
	slot_changed.emit(idx)

func _update_highlight() -> void:
	for i in range(_slots.size()):
		if i == _selected:
			_slots[i].add_theme_stylebox_override("panel", _slot_sel_style)
		else:
			_slots[i].add_theme_stylebox_override("panel", _slot_style)

func _process(_delta: float) -> void:
	if _inventory == null:
		return
	for i in range(9):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			_slot_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
			_slot_labels[i].text = ""
			_slot_count_labels[i].text = ""
			_slot_icons[i].texture = null
			_slot_icons[i].visible = false
		else:
			var tex := ItemDatabase.load_icon_2d(slot.item.id)
			if tex:
				_slot_faces[i].color = Color(0.20, 0.15, 0.30, 0.4)
				_slot_icons[i].texture = tex
				_slot_icons[i].visible = true
				_slot_labels[i].text = ""
			else:
				_slot_faces[i].color = slot.item.icon_color
				_slot_icons[i].texture = null
				_slot_icons[i].visible = false
				_slot_labels[i].text = slot.item.icon_char
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""

	var player := _player_ref
	if player == null:
		return
	var cur := player.equipped_weapon
	var sel_slot := _inventory.slots[_selected]
	var target := sel_slot.item if not sel_slot.is_empty() else null
	if cur != target:
		_auto_equip_selected()
