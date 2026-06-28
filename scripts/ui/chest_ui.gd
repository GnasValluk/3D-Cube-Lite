class_name ChestUI
extends Control

const SLOT_SIZE: float = 40.0
const GAP: float = 3.0
const COLS: int = 9

var _chest = null
var _player_ref: PlayerCharacter = null

var _chest_slots: Array[Panel] = []
var _chest_icons: Array[ColorRect] = []
var _chest_counts: Array[Label] = []

var _player_slots: Array[Panel] = []
var _player_icons: Array[ColorRect] = []
var _player_counts: Array[Label] = []

var _player_hotbar_slots: Array[Panel] = []
var _player_hotbar_icons: Array[ColorRect] = []
var _player_hotbar_counts: Array[Label] = []

func _ready() -> void:
	_setup_background()
	_setup_title()
	_setup_chest_grid()
	_setup_player_grid()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_title() -> void:
	var title := Label.new()
	title.text = "RƯƠNG — Nhấn F để đóng"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	title.position = Vector2(0, 16)
	title.size = Vector2(700, 24)
	add_child(title)

func _setup_chest_grid() -> void:
	var grid_w: float = COLS * (SLOT_SIZE + GAP) - GAP
	var start_x: float = (700 - grid_w) * 0.5
	var start_y: float = 50.0
	var rows: int = 3

	var chest_label := Label.new()
	chest_label.text = "Rương"
	chest_label.position = Vector2(start_x, start_y - 18)
	chest_label.add_theme_font_size_override("font_size", 11)
	chest_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6, 0.6))
	add_child(chest_label)

	for row in range(rows):
		for col in range(COLS):
			var i: int = row * COLS + col
			var px: float = start_x + col * (SLOT_SIZE + GAP)
			var py: float = start_y + row * (SLOT_SIZE + GAP)

			var panel := _make_slot(px, py, "chest", i)
			_chest_slots.append(panel)

	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.3)
	sep.position = Vector2(start_x, start_y + rows * (SLOT_SIZE + GAP) + 4)
	sep.size = Vector2(grid_w, 1)
	add_child(sep)

func _setup_player_grid() -> void:
	var grid_w: float = COLS * (SLOT_SIZE + GAP) - GAP
	var start_x: float = (700 - grid_w) * 0.5
	var chest_rows: int = 3
	var player_start_y: float = 50.0 + chest_rows * (SLOT_SIZE + GAP) + 12

	var inv_label := Label.new()
	inv_label.text = "Túi đồ"
	inv_label.position = Vector2(start_x, player_start_y - 18)
	inv_label.add_theme_font_size_override("font_size", 11)
	inv_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.6))
	add_child(inv_label)

	for row in range(3):
		for col in range(COLS):
			var i: int = 9 + row * COLS + col
			var px: float = start_x + col * (SLOT_SIZE + GAP)
			var py: float = player_start_y + row * (SLOT_SIZE + GAP)

			var panel := _make_slot(px, py, "player", i)
			_player_slots.append(panel)

	var hot_start_y: float = player_start_y + 3 * (SLOT_SIZE + GAP) + 6
	var sep2 := ColorRect.new()
	sep2.color = Color(0.2, 0.2, 0.3, 0.3)
	sep2.position = Vector2(start_x, hot_start_y - 4)
	sep2.size = Vector2(grid_w, 1)
	add_child(sep2)

	for col in range(COLS):
		var i: int = col
		var px: float = start_x + col * (SLOT_SIZE + GAP)
		var py: float = hot_start_y

		var panel := _make_slot(px, py, "hotbar", i)
		_player_hotbar_slots.append(panel)

func _make_slot(px: float, py: float, _type: String, _idx: int) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(px, py)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_gui_input.bind(_type, _idx))
	add_child(panel)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.2, 0.2, 0.3, 0.4)
	panel.add_theme_stylebox_override("panel", bg)

	var icon := ColorRect.new()
	icon.position = Vector2(2, 2)
	icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	icon.color = Color(0.15, 0.15, 0.20, 0.3)
	panel.add_child(icon)

	var cnt := Label.new()
	cnt.position = Vector2(2, SLOT_SIZE - 16)
	cnt.size = Vector2(SLOT_SIZE - 4, 14)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 10)
	cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	panel.add_child(cnt)

	if _type == "chest":
		_chest_icons.append(icon)
		_chest_counts.append(cnt)
	elif _type == "player":
		_player_icons.append(icon)
		_player_counts.append(cnt)
	else:
		_player_hotbar_icons.append(icon)
		_player_hotbar_counts.append(cnt)

	return panel

func _on_slot_gui_input(event: InputEvent, _type: String, idx: int) -> void:
	if not visible or _chest == null or _player_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _type == "chest":
			_transfer_from_chest(idx)
		else:
			_transfer_to_chest(idx)

func _transfer_from_chest(idx: int) -> void:
	if _chest.inventory == null or _player_ref.inventory == null:
		return
	var slot: ItemSlot = _chest.inventory.slots[idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item
	var count: int = slot.count

	var remaining: int = _player_ref.inventory.add_item(item, count)
	if remaining < count:
		_chest.inventory.remove_item(idx, count - remaining)

func _transfer_to_chest(idx: int) -> void:
	if _chest.inventory == null or _player_ref.inventory == null:
		return
	var slot: ItemSlot = _player_ref.inventory.slots[idx]
	if slot.is_empty():
		return
	var item: ItemDef = slot.item
	var count: int = slot.count

	var remaining: int = _chest.inventory.add_item(item, count)
	if remaining < count:
		_player_ref.inventory.remove_item(idx, count - remaining)

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

	var chest_inv: Inventory = _chest.inventory
	var player_inv: Inventory = _player_ref.inventory
	if chest_inv == null or player_inv == null:
		return

	for i in range(chest_inv.slots.size()):
		var slot: ItemSlot = chest_inv.slots[i]
		if i < _chest_icons.size():
			if slot.is_empty():
				_chest_icons[i].color = Color(0.15, 0.15, 0.20, 0.3)
				_chest_counts[i].text = ""
			else:
				_chest_icons[i].color = slot.item.icon_color
				_chest_counts[i].text = str(slot.count) if slot.count > 1 else ""

	for i in range(27):
		var pidx: int = 9 + i
		if pidx < player_inv.slots.size() and i < _player_icons.size():
			var slot: ItemSlot = player_inv.slots[pidx]
			if slot.is_empty():
				_player_icons[i].color = Color(0.15, 0.15, 0.20, 0.3)
				_player_counts[i].text = ""
			else:
				_player_icons[i].color = slot.item.icon_color
				_player_counts[i].text = str(slot.count) if slot.count > 1 else ""

	for i in range(9):
		if i < player_inv.slots.size() and i < _player_hotbar_icons.size():
			var slot: ItemSlot = player_inv.slots[i]
			if slot.is_empty():
				_player_hotbar_icons[i].color = Color(0.15, 0.15, 0.20, 0.3)
				_player_hotbar_counts[i].text = ""
			else:
				_player_hotbar_icons[i].color = slot.item.icon_color
				_player_hotbar_counts[i].text = str(slot.count) if slot.count > 1 else ""
