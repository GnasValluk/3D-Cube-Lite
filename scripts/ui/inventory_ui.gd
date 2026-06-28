class_name InventoryUI
extends Control

const SLOT_SIZE: float = 44.0
const GAP: float = 4.0
const COLS: int = 9

var _inventory: Inventory = null
var _player_ref: PlayerCharacter = null
var _slots: Array[Panel] = []
var _slot_icons: Array[ColorRect] = []
var _slot_count_labels: Array[Label] = []
var _slot_bg_styles: Array[StyleBoxFlat] = []
var _selected_slot: int = -1
var _tooltip: Label
var _hp_label: Label
var _mp_label: Label
var _atk_label: Label
var _def_label: Label
var _count_label: Label
var _equip_weapon_icon: ColorRect
var _equip_armor_icon: ColorRect
var _equip_weapon_label: Label
var _equip_armor_label: Label

func _ready() -> void:
	_setup_background()
	_setup_title()
	_setup_grid()
	_setup_status_panel()
	_setup_equipment_panel()
	_setup_tooltip()
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
	title.text = "TÚI ĐỒ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	title.position = Vector2(30, 20)
	title.size = Vector2(200, 30)
	add_child(title)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_label.add_theme_font_size_override("font_size", 11)
	_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	_count_label.position = Vector2(30, 44)
	_count_label.size = Vector2(200, 16)
	add_child(_count_label)

func _setup_grid() -> void:
	var grid_w: float = COLS * (SLOT_SIZE + GAP) - GAP
	var start_x: float = 30.0
	var storage_rows: int = 4
	var start_y: float = 70.0

	for row in range(storage_rows):
		for col in range(COLS):
			var i: int = row * COLS + col
			var px: float = start_x + col * (SLOT_SIZE + GAP)
			var py: float = start_y + row * (SLOT_SIZE + GAP)

			var panel := Panel.new()
			panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			panel.position = Vector2(px, py)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.gui_input.connect(_on_slot_gui_input.bind(i))
			panel.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
			panel.mouse_exited.connect(_on_slot_mouse_exited)
			add_child(panel)

			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
			bg.border_width_left = 1
			bg.border_width_right = 1
			bg.border_width_top = 1
			bg.border_width_bottom = 1
			bg.border_color = Color(0.2, 0.2, 0.3, 0.4)
			panel.add_theme_stylebox_override("panel", bg)
			_slot_bg_styles.append(bg)

			var icon := ColorRect.new()
			icon.position = Vector2(3, 3)
			icon.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
			icon.color = Color(0.15, 0.15, 0.20, 0.3)
			panel.add_child(icon)
			_slot_icons.append(icon)

			var cnt := Label.new()
			cnt.position = Vector2(2, SLOT_SIZE - 18)
			cnt.size = Vector2(SLOT_SIZE - 4, 14)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.add_theme_font_size_override("font_size", 10)
			cnt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			panel.add_child(cnt)
			_slot_count_labels.append(cnt)

			_slots.append(panel)

func _setup_status_panel() -> void:
	var sx: float = 30.0 + COLS * (SLOT_SIZE + GAP) + 20.0
	var sy: float = 70.0

	var stat_bg := ColorRect.new()
	stat_bg.color = Color(0.06, 0.06, 0.10, 0.85)
	stat_bg.position = Vector2(sx, sy)
	stat_bg.size = Vector2(170, 140)
	add_child(stat_bg)

	var stat_title := Label.new()
	stat_title.text = "THÔNG TIN"
	stat_title.position = Vector2(sx + 8, sy + 8)
	stat_title.add_theme_font_size_override("font_size", 12)
	stat_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
	add_child(stat_title)

	_hp_label = Label.new()
	_hp_label.position = Vector2(sx + 8, sy + 30)
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 0.8))
	add_child(_hp_label)

	_mp_label = Label.new()
	_mp_label.position = Vector2(sx + 8, sy + 48)
	_mp_label.add_theme_font_size_override("font_size", 11)
	_mp_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 0.8))
	add_child(_mp_label)

	_atk_label = Label.new()
	_atk_label.position = Vector2(sx + 8, sy + 66)
	_atk_label.add_theme_font_size_override("font_size", 11)
	_atk_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 0.8))
	add_child(_atk_label)

	_def_label = Label.new()
	_def_label.position = Vector2(sx + 8, sy + 84)
	_def_label.add_theme_font_size_override("font_size", 11)
	_def_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 0.8))
	add_child(_def_label)

	var drop_hint := Label.new()
	drop_hint.text = "Q = Vứt bỏ  |  Chuột Phải = Dùng"
	drop_hint.position = Vector2(sx + 8, sy + 115)
	drop_hint.add_theme_font_size_override("font_size", 9)
	drop_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
	add_child(drop_hint)

func _setup_equipment_panel() -> void:
	var sx: float = 30.0 + COLS * (SLOT_SIZE + GAP) + 20.0
	var sy: float = 70.0 + 140 + 16

	var eq_bg := ColorRect.new()
	eq_bg.color = Color(0.06, 0.06, 0.10, 0.85)
	eq_bg.position = Vector2(sx, sy)
	eq_bg.size = Vector2(170, 110)
	add_child(eq_bg)

	var eq_title := Label.new()
	eq_title.text = "TRANG BỊ"
	eq_title.position = Vector2(sx + 8, sy + 8)
	eq_title.add_theme_font_size_override("font_size", 12)
	eq_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
	add_child(eq_title)

	var esize: float = 50.0
	var egap: float = 8.0
	var estart_x: float = sx + 8.0
	var estart_y: float = sy + 30.0

	var weapon_panel := Panel.new()
	weapon_panel.position = Vector2(estart_x, estart_y)
	weapon_panel.size = Vector2(esize, esize)
	var wbg := StyleBoxFlat.new()
	wbg.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	wbg.border_width_left = 1; wbg.border_width_right = 1
	wbg.border_width_top = 1; wbg.border_width_bottom = 1
	wbg.border_color = Color(0.3, 0.3, 0.5, 0.5)
	weapon_panel.add_theme_stylebox_override("panel", wbg)
	add_child(weapon_panel)
	var wlbl := Label.new()
	wlbl.text = "VK"
	wlbl.position = Vector2(estart_x, estart_y + esize + 1)
	wlbl.size = Vector2(esize, 14)
	wlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wlbl.add_theme_font_size_override("font_size", 8)
	wlbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.5))
	add_child(wlbl)
	_equip_weapon_icon = ColorRect.new()
	_equip_weapon_icon.position = Vector2(4, 4)
	_equip_weapon_icon.size = Vector2(esize - 8, esize - 8)
	_equip_weapon_icon.color = Color(0.15, 0.15, 0.20, 0.5)
	weapon_panel.add_child(_equip_weapon_icon)
	_equip_weapon_label = Label.new()
	_equip_weapon_label.position = Vector2(estart_x + esize + egap, estart_y + 4)
	_equip_weapon_label.size = Vector2(100, 20)
	_equip_weapon_label.add_theme_font_size_override("font_size", 10)
	_equip_weapon_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 0.8))
	add_child(_equip_weapon_label)

	var armor_panel := Panel.new()
	armor_panel.position = Vector2(estart_x, estart_y + esize + 16)
	armor_panel.size = Vector2(esize, esize)
	var abg := StyleBoxFlat.new()
	abg.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	abg.border_width_left = 1; abg.border_width_right = 1
	abg.border_width_top = 1; abg.border_width_bottom = 1
	abg.border_color = Color(0.3, 0.3, 0.5, 0.5)
	armor_panel.add_theme_stylebox_override("panel", abg)
	add_child(armor_panel)
	var albl := Label.new()
	albl.text = "AP"
	albl.position = Vector2(estart_x, estart_y + esize + 17 + esize)
	albl.size = Vector2(esize, 14)
	albl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	albl.add_theme_font_size_override("font_size", 8)
	albl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.5))
	add_child(albl)
	_equip_armor_icon = ColorRect.new()
	_equip_armor_icon.position = Vector2(4, 4)
	_equip_armor_icon.size = Vector2(esize - 8, esize - 8)
	_equip_armor_icon.color = Color(0.15, 0.15, 0.20, 0.5)
	armor_panel.add_child(_equip_armor_icon)
	_equip_armor_label = Label.new()
	_equip_armor_label.position = Vector2(estart_x + esize + egap, estart_y + esize + 16 + 4)
	_equip_armor_label.size = Vector2(100, 20)
	_equip_armor_label.add_theme_font_size_override("font_size", 10)
	_equip_armor_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 0.8))
	add_child(_equip_armor_label)

func _setup_tooltip() -> void:
	_tooltip = Label.new()
	_tooltip.position = Vector2.ZERO
	_tooltip.size = Vector2(240, 60)
	_tooltip.add_theme_font_size_override("font_size", 12)
	_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
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
		return
	var tooltip_text: String = slot.item.name
	if slot.item.desc.length() > 0:
		tooltip_text += "\n" + slot.item.desc
	if slot.item.atk_bonus > 0:
		tooltip_text += "\nTấn công: +" + str(slot.item.atk_bonus)
	if slot.item.def_bonus > 0:
		tooltip_text += "\nPhòng thủ: +" + str(slot.item.def_bonus)
	if slot.item.heal_amount > 0:
		tooltip_text += "\nHồi máu: " + str(slot.item.heal_amount)
	var type_name: String = slot.item.get_type_name()
	if type_name.length() > 0:
		tooltip_text += "\n[" + type_name + "]"
	_tooltip.text = tooltip_text
	_tooltip.visible = true

func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false

func _highlight_slot(idx: int) -> void:
	for i in range(_slot_bg_styles.size()):
		var bg: StyleBoxFlat = _slot_bg_styles[i]
		if i == idx:
			bg.border_color = Color(1, 1, 1, 0.8)
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.bg_color = Color(0.15, 0.15, 0.25, 0.9)
		else:
			bg.border_color = Color(0.2, 0.2, 0.3, 0.4)
			bg.border_width_left = 1
			bg.border_width_right = 1
			bg.border_width_top = 1
			bg.border_width_bottom = 1
			bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)

func _clear_selection() -> void:
	for i in range(_slot_bg_styles.size()):
		var bg: StyleBoxFlat = _slot_bg_styles[i]
		bg.border_color = Color(0.2, 0.2, 0.3, 0.4)
		bg.border_width_left = 1
		bg.border_width_right = 1
		bg.border_width_top = 1
		bg.border_width_bottom = 1
		bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)

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
			_slot_icons[i].color = Color(0.15, 0.15, 0.20, 0.3)
			_slot_count_labels[i].text = ""
		else:
			_slot_icons[i].color = slot.item.icon_color
			_slot_count_labels[i].text = str(slot.count) if slot.count > 1 else ""

	if _player_ref:
		_hp_label.text = "HP: %d / %d" % [_player_ref.hp, _player_ref.max_hp]
		_mp_label.text = "MANA: %d / %d" % [_player_ref.mana, _player_ref.max_mana]
		_atk_label.text = "ATK: %d" % _player_ref.get_total_atk()
		_def_label.text = "DEF: %d" % _player_ref.get_total_def()
		_update_equipment_display(_player_ref)

	var filled: int = _inventory.count_filled_slots()
	_count_label.text = "Đã dùng: %d / %d" % [filled, _inventory.slots.size()]

	if _tooltip.visible:
		var mp: Vector2 = get_global_mouse_position()
		_tooltip.position = mp + Vector2(16, 16)

func _update_equipment_display(player: PlayerCharacter) -> void:
	if player.equipped_weapon != null:
		_equip_weapon_icon.color = player.equipped_weapon.icon_color
		_equip_weapon_label.text = player.equipped_weapon.name
	else:
		_equip_weapon_icon.color = Color(0.15, 0.15, 0.20, 0.3)
		_equip_weapon_label.text = ""

	if player.equipped_armor != null:
		_equip_armor_icon.color = player.equipped_armor.icon_color
		_equip_armor_label.text = player.equipped_armor.name
	else:
		_equip_armor_icon.color = Color(0.15, 0.15, 0.20, 0.3)
		_equip_armor_label.text = ""
