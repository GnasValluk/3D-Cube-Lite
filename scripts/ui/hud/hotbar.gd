class_name Hotbar
extends Control

var _inventory: Inventory = null
var _selected: int = 0
var _slots: Array[Panel] = []
var _slot_faces: Array[ColorRect] = []
var _slot_labels: Array[Label] = []
var _slot_count_labels: Array[Label] = []
var _tooltip: Label = null
var _tooltip_bg: ColorRect = null

var _slot_style: StyleBoxFlat
var _slot_hl_style: StyleBoxFlat
var _slot_sel_style: StyleBoxFlat

func _ready() -> void:
	var ss: float = 44.0
	var gap: float = 4.0
	var tw: float = ss * 9 + gap * 8

	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -tw * 0.5
	offset_top = -(ss + 22)
	offset_right = tw * 0.5
	offset_bottom = -14

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

	_slot_hl_style = _slot_style.duplicate()
	_slot_hl_style.bg_color = Color(0.08, 0.08, 0.14, 0.70)

	_slot_sel_style = _slot_style.duplicate()
	_slot_sel_style.bg_color = Color(0.15, 0.18, 0.30, 0.75)
	_slot_sel_style.border_color = Color(0.40, 0.55, 0.90, 0.45)

	for i in range(9):
		var panel := Panel.new()
		panel.size = Vector2(ss, ss)
		panel.position = Vector2(i * (ss + gap), 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui_input.bind(i))
		panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_slot_mouse_exited)
		panel.add_theme_stylebox_override("panel", _slot_style)
		add_child(panel)

		var face := ColorRect.new()
		face.position = Vector2(2, 2)
		face.size = Vector2(ss - 4, ss - 4)
		face.color = Color(0.15, 0.15, 0.22, 0.4)
		panel.add_child(face)
		_slot_faces.append(face)

		var lbl := Label.new()
		lbl.position = Vector2(2, 2)
		lbl.size = Vector2(ss - 4, ss - 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		panel.add_child(lbl)
		_slot_labels.append(lbl)

		var cnt := Label.new()
		cnt.position = Vector2(2, ss - 16)
		cnt.size = Vector2(ss - 4, 14)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 10)
		cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
		panel.add_child(cnt)
		_slot_count_labels.append(cnt)

		var key_lbl := Label.new()
		key_lbl.position = Vector2(2, 0)
		key_lbl.size = Vector2(14, 14)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		key_lbl.text = str(i + 1)
		panel.add_child(key_lbl)

		_slots.append(panel)

	_tooltip_bg = ColorRect.new()
	_tooltip_bg.color = Color(0.06, 0.06, 0.12, 0.92)
	_tooltip_bg.position = Vector2(0, -36)
	_tooltip_bg.size = Vector2(120, 28)
	_tooltip_bg.visible = false
	add_child(_tooltip_bg)

	_tooltip = Label.new()
	_tooltip.position = Vector2(4, -34)
	_tooltip.size = Vector2(116, 24)
	_tooltip.add_theme_font_size_override("font_size", 11)
	_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
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
			_handle_left_click(idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_use_item(idx)

func _on_slot_mouse_entered(idx: int) -> void:
	if _inventory == null:
		return
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		_tooltip.visible = false
		_tooltip_bg.visible = false
		return
	_tooltip.text = slot.item.name
	_tooltip_bg.size.x = max(120, _tooltip.get_minimum_size().x + 8)
	_tooltip_bg.visible = true
	_tooltip.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false
	_tooltip_bg.visible = false

func _handle_left_click(idx: int) -> void:
	var player: PlayerCharacter = _find_player()
	if player == null:
		return
	if not player._inventory_open:
		return
	var held: Dictionary = player._held_item
	if held.is_empty():
		if _inventory.slots[idx].is_empty():
			return
		player._held_item = {"from_idx": idx}
	else:
		var from_idx: int = held.from_idx
		if from_idx == idx:
			player._held_item = {}
			return
		if _inventory.can_transfer(from_idx, idx):
			_inventory.transfer(from_idx, idx)
		else:
			_inventory.swap(from_idx, idx)
		player._held_item = {}

func _use_item(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		return
	var player: PlayerCharacter = _find_player()
	if player == null:
		return
	player.use_item_from_inventory(idx)

func _find_player() -> PlayerCharacter:
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

func _update_highlight() -> void:
	for i in range(_slots.size()):
		var s: Panel = _slots[i]
		if i == _selected:
			s.add_theme_stylebox_override("panel", _slot_sel_style)
		else:
			s.add_theme_stylebox_override("panel", _slot_style)

func _process(_delta: float) -> void:
	if _inventory == null:
		return
	for i in range(9):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			_slot_faces[i].color = Color(0.15, 0.15, 0.22, 0.4)
			_slot_labels[i].text = ""
			_slot_count_labels[i].text = ""
		else:
			_slot_faces[i].color = slot.item.icon_color
			_slot_labels[i].text = slot.item.icon_char
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""
