class_name InventoryUI
extends Control

const SLOT_SIZE: float = 50.0
const GAP: float = 5.0
const COLS: int = 9
const PAD: float = 18.0

const GRID_W: float = COLS * (SLOT_SIZE + GAP) - GAP
const STAT_W: float = 190.0
const CONTENT_W: float = PAD + GRID_W + 12 + STAT_W + PAD
const EQUIP_H: float = 154.0
const CONTENT_H: float = PAD + 40 + 140 + 10 + EQUIP_H + PAD

var _inventory: Inventory = null
var _player_ref: PlayerCharacter = null
var _slots: Array[Panel] = []
var _slot_faces: Array[ColorRect] = []
var _slot_count_labels: Array[Label] = []
var _selected_slot: int = -1
var _tooltip: Label
var _tooltip_bg: ColorRect
var _hp_label: Label
var _mp_label: Label
var _atk_label: Label
var _def_label: Label
var _count_label: Label
var _equip_faces: Array[ColorRect] = []
var _equip_labels: Array[Label] = []
var _equip_names: Array[String] = ["Head", "Body", "Legs", "Feet"]

var _glass_style: StyleBoxFlat
var _slot_style: StyleBoxFlat
var _slot_hl_style: StyleBoxFlat

func _ready() -> void:
	size = Vector2(CONTENT_W, CONTENT_H)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glass_style = StyleBoxFlat.new()
	_glass_style.bg_color = Color(0.10, 0.10, 0.16, 0.70)
	_glass_style.corner_radius_top_left = 10
	_glass_style.corner_radius_top_right = 10
	_glass_style.corner_radius_bottom_left = 10
	_glass_style.corner_radius_bottom_right = 10
	_glass_style.border_width_left = 1
	_glass_style.border_width_right = 1
	_glass_style.border_width_top = 1
	_glass_style.border_width_bottom = 1
	_glass_style.border_color = Color(1, 1, 1, 0.12)

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
	_slot_hl_style.bg_color = Color(0.20, 0.22, 0.34, 0.75)
	_slot_hl_style.border_color = Color(0.40, 0.55, 0.90, 0.40)

	_setup_background()
	_setup_title()
	_setup_grid()
	_setup_status_panel()
	_setup_equipment_panel()
	_setup_tooltip()
	visible = false

func _setup_background() -> void:
	var bg := Panel.new()
	bg.size = Vector2(CONTENT_W, CONTENT_H)
	bg.add_theme_stylebox_override("panel", _glass_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

func _setup_title() -> void:
	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.position = Vector2(PAD, PAD - 2)
	title.size = Vector2(200, 28)
	add_child(title)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_count_label.position = Vector2(PAD + 220, PAD + 1)
	_count_label.size = Vector2(180, 16)
	add_child(_count_label)

func _setup_grid() -> void:
	var grid_y: float = PAD + 40
	var rows: int = 4

	for row in range(rows):
		for col in range(COLS):
			var i: int = row * COLS + col
			var px: float = PAD + col * (SLOT_SIZE + GAP)
			var py: float = grid_y + row * (SLOT_SIZE + GAP)

			var panel := Panel.new()
			panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			panel.position = Vector2(px, py)
			panel.add_theme_stylebox_override("panel", _slot_style)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.gui_input.connect(_on_slot_gui_input.bind(i))
			panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
			panel.mouse_exited.connect(_on_slot_mouse_exited)
			add_child(panel)

			var face := ColorRect.new()
			face.position = Vector2(2, 2)
			face.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
			face.color = Color(0.15, 0.15, 0.22, 0.4)
			panel.add_child(face)
			_slot_faces.append(face)

			var cnt := Label.new()
			cnt.position = Vector2(2, SLOT_SIZE - 18)
			cnt.size = Vector2(SLOT_SIZE - 4, 14)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.add_theme_font_size_override("font_size", 11)
			cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
			panel.add_child(cnt)
			_slot_count_labels.append(cnt)

			_slots.append(panel)

func _setup_status_panel() -> void:
	var sx: float = PAD + GRID_W + 12
	var sy: float = PAD + 40

	var stat := Panel.new()
	stat.position = Vector2(sx, sy)
	stat.size = Vector2(STAT_W, 140)
	var st_style := _glass_style.duplicate()
	st_style.bg_color = Color(0.08, 0.08, 0.14, 0.45)
	st_style.corner_radius_top_left = 8
	st_style.corner_radius_top_right = 8
	st_style.corner_radius_bottom_left = 8
	st_style.corner_radius_bottom_right = 8
	stat.add_theme_stylebox_override("panel", st_style)
	add_child(stat)

	var stat_title := Label.new()
	stat_title.text = "Stats"
	stat_title.position = Vector2(sx + 12, sy + 8)
	stat_title.add_theme_font_size_override("font_size", 15)
	stat_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	add_child(stat_title)

	_hp_label = Label.new()
	_hp_label.position = Vector2(sx + 12, sy + 34)
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.30))
	add_child(_hp_label)

	_mp_label = Label.new()
	_mp_label.position = Vector2(sx + 12, sy + 54)
	_mp_label.add_theme_font_size_override("font_size", 13)
	_mp_label.add_theme_color_override("font_color", Color(0.30, 0.55, 0.95))
	add_child(_mp_label)

	_atk_label = Label.new()
	_atk_label.position = Vector2(sx + 12, sy + 74)
	_atk_label.add_theme_font_size_override("font_size", 13)
	_atk_label.add_theme_color_override("font_color", Color(0.85, 0.60, 0.25))
	add_child(_atk_label)

	_def_label = Label.new()
	_def_label.position = Vector2(sx + 12, sy + 94)
	_def_label.add_theme_font_size_override("font_size", 13)
	_def_label.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55))
	add_child(_def_label)

	var dh := Label.new()
	dh.text = "Q = Drop  |  Right-click = Use"
	dh.position = Vector2(sx + 12, sy + 120)
	dh.add_theme_font_size_override("font_size", 10)
	dh.add_theme_color_override("font_color", Color(1, 1, 1, 0.30))
	add_child(dh)

func _setup_equipment_panel() -> void:
	var sx: float = PAD + GRID_W + 12
	var sy: float = PAD + 40 + 140 + 10

	var eq := Panel.new()
	eq.position = Vector2(sx, sy)
	eq.size = Vector2(STAT_W, EQUIP_H)
	var eq_style := _glass_style.duplicate()
	eq_style.bg_color = Color(0.08, 0.08, 0.14, 0.45)
	eq_style.corner_radius_top_left = 8
	eq_style.corner_radius_top_right = 8
	eq_style.corner_radius_bottom_left = 8
	eq_style.corner_radius_bottom_right = 8
	eq.add_theme_stylebox_override("panel", eq_style)
	add_child(eq)

	var eq_title := Label.new()
	eq_title.text = "Equipment"
	eq_title.position = Vector2(sx + 12, sy + 8)
	eq_title.add_theme_font_size_override("font_size", 15)
	eq_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	add_child(eq_title)

	var esize: float = 48.0
	var gap: float = 6.0
	var cols: int = 2
	var gx: float = sx + 14.0
	var gy: float = sy + 34.0

	var equip_colors: Array[Color] = [
		Color(0.40, 0.70, 0.95),
		Color(0.55, 0.80, 0.55),
		Color(0.75, 0.60, 0.85),
		Color(0.90, 0.70, 0.40)
	]
	var lx: float = gx + 2 * (esize + gap) + 8

	for i in range(4):
		var row: int = i / cols
		var col: int = i % cols
		var px: float = gx + col * (esize + gap)
		var py: float = gy + row * (esize + 18)

		var panel := Panel.new()
		panel.position = Vector2(px, py)
		panel.size = Vector2(esize, esize)
		panel.add_theme_stylebox_override("panel", _slot_style)
		add_child(panel)

		var face := ColorRect.new()
		face.position = Vector2(2, 2)
		face.size = Vector2(esize - 4, esize - 4)
		face.color = Color(0.15, 0.15, 0.22, 0.4)
		panel.add_child(face)
		_equip_faces.append(face)

		var name_lbl := Label.new()
		name_lbl.text = _equip_names[i]
		name_lbl.position = Vector2(px, py + esize + 1)
		name_lbl.size = Vector2(esize, 14)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		add_child(name_lbl)

		var item_label := Label.new()
		item_label.position = Vector2(lx, py + 4)
		item_label.size = Vector2(STAT_W - (lx - sx), 18)
		item_label.add_theme_font_size_override("font_size", 11)
		item_label.add_theme_color_override("font_color", equip_colors[i])
		add_child(item_label)
		_equip_labels.append(item_label)

func _setup_tooltip() -> void:
	_tooltip_bg = ColorRect.new()
	_tooltip_bg.color = Color(0.06, 0.06, 0.10, 0.90)
	_tooltip_bg.visible = false
	_tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_bg)

	_tooltip = Label.new()
	_tooltip.position = Vector2.ZERO
	_tooltip.size = Vector2(280, 80)
	_tooltip.add_theme_font_size_override("font_size", 13)
	_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not visible or _inventory == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(idx)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(idx)
			accept_event()

func _handle_left_click(idx: int) -> void:
	if _inventory.slots[idx].is_empty():
		_selected_slot = -1
		_clear_selection()
		return
	var player := _player_ref
	if player == null:
		return
	if not player._inventory_open:
		return
	var held: Dictionary = player._held_item
	if held.is_empty():
		player._held_item = {"from_idx": idx}
		_selected_slot = idx
		_highlight_slot(idx)
	else:
		var from_idx: int = held.from_idx
		if from_idx == idx:
			player._held_item = {}
			_selected_slot = -1
			_clear_selection()
			return
		if _inventory.can_transfer(from_idx, idx):
			_inventory.transfer(from_idx, idx)
		else:
			_inventory.swap(from_idx, idx)
		player._held_item = {}
		_selected_slot = -1
		_clear_selection()

func _handle_right_click(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		return
	var player := _player_ref
	if player == null:
		return
	_selected_slot = idx
	_highlight_slot(idx)
	player.use_item_from_inventory(idx)

func _on_slot_mouse_entered(idx: int) -> void:
	var slot: ItemSlot = _inventory.slots[idx]
	if slot.is_empty():
		_tooltip.visible = false
		_tooltip_bg.visible = false
		return
	var tt: String = slot.item.name
	if slot.item.desc.length() > 0:
		tt += "\n" + slot.item.desc
	if slot.item.atk_bonus > 0:
		tt += "\nATK: +" + str(slot.item.atk_bonus)
	if slot.item.def_bonus > 0:
		tt += "\nDEF: +" + str(slot.item.def_bonus)
	if slot.item.heal_amount > 0:
		tt += "\nHeal: " + str(slot.item.heal_amount)
	var tn: String = slot.item.get_type_name()
	if tn.length() > 0:
		tt += "\n[" + tn + "]"
	if slot.item.type == ItemDef.Type.ARMOR:
		tt += "\n[" + slot.item.get_armor_slot_name() + "]"
	_tooltip.text = tt
	_tooltip_bg.size = _tooltip.size + Vector2(8, 8)
	_tooltip_bg.visible = true
	_tooltip.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false
	_tooltip_bg.visible = false

func _highlight_slot(idx: int) -> void:
	for i in range(_slots.size()):
		if i == idx:
			_slots[i].add_theme_stylebox_override("panel", _slot_hl_style)
		else:
			_slots[i].add_theme_stylebox_override("panel", _slot_style)

func _clear_selection() -> void:
	for i in range(_slots.size()):
		_slots[i].add_theme_stylebox_override("panel", _slot_style)

func set_inventory(inv: Inventory) -> void:
	_inventory = inv

func set_player(p: PlayerCharacter) -> void:
	_player_ref = p

func _process(_delta: float) -> void:
	if _inventory == null:
		return
	for i in range(_inventory.slots.size()):
		var slot: ItemSlot = _inventory.slots[i]
		if slot.is_empty():
			var col = Color(0.15, 0.15, 0.22, 0.4) if i != _selected_slot else Color(0.25, 0.28, 0.40, 0.5)
			_slot_faces[i].color = col
			_slot_count_labels[i].text = ""
		else:
			_slot_faces[i].color = slot.item.icon_color
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""

	if _player_ref:
		_hp_label.text = "HP: %d / %d" % [_player_ref.hp, _player_ref.max_hp]
		_mp_label.text = "MANA: %d / %d" % [_player_ref.mana, _player_ref.max_mana]
		_atk_label.text = "ATK: %d" % _player_ref.get_total_atk()
		_def_label.text = "DEF: %d" % _player_ref.get_total_def()
		_update_equipment_display(_player_ref)

	var filled: int = _inventory.count_filled_slots()
	_count_label.text = "Used: %d / %d" % [filled, _inventory.slots.size()]

	if _tooltip.visible:
		var mp: Vector2 = get_global_mouse_position()
		_tooltip.position = mp + Vector2(16, 16)
		_tooltip_bg.position = mp + Vector2(14, 14)

func _update_equipment_display(player: PlayerCharacter) -> void:
	var equipped: Array = [
		player.equipped_head,
		player.equipped_body,
		player.equipped_legs,
		player.equipped_feet
	]
	for i in range(4):
		var item: ItemDef = equipped[i] as ItemDef
		if item != null:
			_equip_faces[i].color = item.icon_color
			_equip_labels[i].text = item.name
		else:
			_equip_faces[i].color = Color(0.15, 0.15, 0.22, 0.4)
			_equip_labels[i].text = ""
