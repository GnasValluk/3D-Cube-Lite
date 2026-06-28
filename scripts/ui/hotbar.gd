class_name Hotbar
extends Control

var _inventory: Inventory = null
var _selected: int = 0
var _slots: Array[Panel] = []
var _slot_icons: Array[ColorRect] = []
var _slot_labels: Array[Label] = []
var _slot_count_labels: Array[Label] = []
var _tooltip: Label = null

func _ready() -> void:
	var slot_size: float = 44.0
	var gap: float = 4.0
	var total_w: float = slot_size * 9 + gap * 8

	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -total_w * 0.5
	offset_top = -(slot_size + 24)
	offset_right = total_w * 0.5
	offset_bottom = -24

	for i in range(9):
		var panel := Panel.new()
		panel.size = Vector2(slot_size, slot_size)
		panel.position = Vector2(i * (slot_size + gap), 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui_input.bind(i))
		panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		panel.mouse_exited.connect(_on_slot_mouse_exited)
		add_child(panel)

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)
		bg.border_width_left = 2
		bg.border_width_right = 2
		bg.border_width_top = 2
		bg.border_width_bottom = 2
		bg.border_color = Color(0.35, 0.35, 0.45, 0.6)
		panel.add_theme_stylebox_override("panel", bg)
		panel.set_meta("bg", bg)

		var icon := ColorRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(slot_size - 8, slot_size - 8)
		icon.color = Color(0.15, 0.15, 0.20, 0.5)
		panel.add_child(icon)
		_slot_icons.append(icon)

		var lbl := Label.new()
		lbl.position = Vector2(2, 2)
		lbl.size = Vector2(slot_size - 4, slot_size - 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		panel.add_child(lbl)
		_slot_labels.append(lbl)

		var cnt := Label.new()
		cnt.position = Vector2(2, slot_size - 16)
		cnt.size = Vector2(slot_size - 4, 14)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 10)
		cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		panel.add_child(cnt)
		_slot_count_labels.append(cnt)

		var key_lbl := Label.new()
		key_lbl.position = Vector2(2, 0)
		key_lbl.size = Vector2(14, 14)
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.5))
		key_lbl.text = str(i + 1)
		panel.add_child(key_lbl)

		_slots.append(panel)

	_tooltip = Label.new()
	_tooltip.position = Vector2(0, -36)
	_tooltip.size = Vector2(200, 30)
	_tooltip.add_theme_font_size_override("font_size", 11)
	_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
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
		return
	_tooltip.text = slot.item.name
	_tooltip.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false

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
		var bg: StyleBoxFlat = _slots[i].get_meta("bg") as StyleBoxFlat
		if i == _selected:
			bg.border_color = Color(1, 1, 1, 0.95)
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.bg_color = Color(0.15, 0.15, 0.25, 0.9)
		else:
			bg.border_color = Color(0.35, 0.35, 0.45, 0.6)
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.bg_color = Color(0.06, 0.06, 0.10, 0.85)

func _process(_delta: float) -> void:
	if _inventory == null:
		return
	for i in range(9):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			_slot_icons[i].color = Color(0.15, 0.15, 0.20, 0.3)
			_slot_icons[i].visible = true
			_slot_labels[i].text = ""
			_slot_count_labels[i].text = ""
		else:
			_slot_icons[i].color = slot.item.icon_color
			_slot_icons[i].visible = true
			_slot_labels[i].text = slot.item.icon_char
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""
