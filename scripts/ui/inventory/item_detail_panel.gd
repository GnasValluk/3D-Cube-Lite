## Item Detail Panel
extends RefCounted

static func setup_detail_panel(owner) -> void:
	var ox: float = owner.LIB_W + owner.LIB_MARGIN
	var grid_y: float = owner.PAD + 40
	var dy: float = grid_y + 4 * (owner.SLOT_SIZE + owner.GAP) + 10
	var dw: float = owner.GRID_W
	var dx: float = ox + owner.PAD

	owner._detail_bg = ColorRect.new()
	owner._detail_bg.position = Vector2(dx, dy)
	owner._detail_bg.size = Vector2(dw, owner.DETAIL_H)
	owner._detail_bg.color = Color(0.10, 0.07, 0.18, 0.70)
	owner._detail_bg.visible = false
	owner._detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(owner._detail_bg)

	owner._detail_item_name = Label.new()
	owner._detail_item_name.position = Vector2(dx + 8, dy + 6)
	owner._detail_item_name.size = Vector2(dw - 16, 28)
	owner._detail_item_name.add_theme_font_size_override("font_size", 26)
	owner._detail_item_name.add_theme_color_override("font_color", owner.TEXT_BRIGHT)
	owner._detail_item_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	owner._detail_item_name.add_theme_constant_override("shadow_offset_x", 1)
	owner._detail_item_name.add_theme_constant_override("shadow_offset_y", 1)
	owner._detail_item_name.visible = false
	owner.add_child(owner._detail_item_name)

	owner._detail_desc = Label.new()
	owner._detail_desc.position = Vector2(dx + 8, dy + 38)
	owner._detail_desc.size = Vector2(dw - 16, 46)
	owner._detail_desc.add_theme_font_size_override("font_size", 18)
	owner._detail_desc.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.85))
	owner._detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner._detail_desc.visible = false
	owner.add_child(owner._detail_desc)

	owner._detail_stats = Label.new()
	owner._detail_stats.position = Vector2(dx + 8, dy + 80)
	owner._detail_stats.size = Vector2(dw - 16, 20)
	owner._detail_stats.add_theme_font_size_override("font_size", 18)
	owner._detail_stats.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.80))
	owner._detail_stats.visible = false
	owner.add_child(owner._detail_stats)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.10, 0.22, 0.85)
	btn_style.corner_radius_top_left = 6; btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6; btn_style.corner_radius_bottom_right = 6
	btn_style.border_width_left = 1; btn_style.border_width_right = 1
	btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.55, 0.57, 0.62, 0.45)

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.35, 0.22, 0.50, 0.95)
	btn_hover.border_color = Color(0.55, 0.57, 0.62, 0.75)

	var btn_y: float = dy + owner.DETAIL_H - 40

	owner._detail_use_btn = Button.new()
	owner._detail_use_btn.text = owner.tr("EQUIP_ITEM")
	owner._detail_use_btn.position = Vector2(dx + dw - 200, btn_y)
	owner._detail_use_btn.size = Vector2(90, 30)
	owner._detail_use_btn.add_theme_font_size_override("font_size", 18)
	owner._detail_use_btn.add_theme_color_override("font_color", owner.TEAL)
	owner._detail_use_btn.add_theme_stylebox_override("normal", btn_style)
	owner._detail_use_btn.add_theme_stylebox_override("hover", btn_hover)
	owner._detail_use_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	owner._detail_use_btn.pressed.connect(on_detail_equip.bind(owner))
	owner._detail_use_btn.visible = false
	owner.add_child(owner._detail_use_btn)

	owner._detail_drop_btn = Button.new()
	owner._detail_drop_btn.text = owner.tr("DROP_ITEM")
	owner._detail_drop_btn.position = Vector2(dx + dw - 105, btn_y)
	owner._detail_drop_btn.size = Vector2(95, 30)
	owner._detail_drop_btn.add_theme_font_size_override("font_size", 18)
	owner._detail_drop_btn.add_theme_color_override("font_color", Color(0.88, 0.35, 0.32, 0.90))
	owner._detail_drop_btn.add_theme_stylebox_override("normal", btn_style)
	owner._detail_drop_btn.add_theme_stylebox_override("hover", btn_hover)
	owner._detail_drop_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	owner._detail_drop_btn.pressed.connect(on_detail_drop.bind(owner))
	owner._detail_drop_btn.visible = false
	owner.add_child(owner._detail_drop_btn)

	owner._detail_vis_btn = Button.new()
	owner._detail_vis_btn.text = owner.tr("HIDE_MODEL")
	owner._detail_vis_btn.position = Vector2(dx + 8, btn_y)
	owner._detail_vis_btn.size = Vector2(90, 30)
	owner._detail_vis_btn.add_theme_font_size_override("font_size", 18)
	owner._detail_vis_btn.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 0.95))
	owner._detail_vis_btn.add_theme_stylebox_override("normal", btn_style)
	owner._detail_vis_btn.add_theme_stylebox_override("hover", btn_hover)
	owner._detail_vis_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	owner._detail_vis_btn.pressed.connect(on_detail_toggle_visual.bind(owner))
	owner._detail_vis_btn.visible = false
	owner.add_child(owner._detail_vis_btn)

static func update_detail_panel(owner) -> void:
	if owner._selected_equip >= 0 and owner._player_ref != null:
		var eq_item: ItemDef = owner._player_ref.get_equipped_by_slot(owner._selected_equip)
		if eq_item != null:
			owner._detail_item_name.text = eq_item.name
			owner._detail_desc.text = eq_item.desc if eq_item.desc.length() > 0 else "(" + eq_item.get_type_name() + ")"
			var eq_stats: String = ""
			if eq_item.atk_bonus > 0:  eq_stats += owner.tr("STAT_ATK_BONUS") % eq_item.atk_bonus + "  "
			if eq_item.def_bonus > 0:  eq_stats += owner.tr("STAT_DEF_BONUS") % eq_item.def_bonus + "  "
			if eq_item.heal_amount > 0: eq_stats += owner.tr("STAT_HEAL") % eq_item.heal_amount
			owner._detail_stats.text = eq_stats
			owner._detail_use_btn.text = owner.tr("UNEQUIP_ITEM")
			owner._detail_use_btn.visible = true
			owner._detail_drop_btn.visible = true
			owner._detail_vis_btn.text = owner.tr("HIDE_MODEL") if owner._player_ref.get_armor_visible(owner._selected_equip) else owner.tr("SHOW_MODEL")
			owner._detail_vis_btn.visible = true
			owner._detail_item_name.visible = true
			owner._detail_desc.visible = true
			owner._detail_stats.visible = true
			owner._detail_bg.visible = true
			return
		owner._selected_equip = -1
	var has_selection: bool = false
	if owner._inventory != null and owner._selected_slot >= 0 and owner._selected_slot < owner._inventory.slots.size():
		var slot: ItemSlot = owner._inventory.slots[owner._selected_slot]
		if not slot.is_empty():
			has_selection = true
			var item: ItemDef = slot.item
			owner._detail_item_name.text = item.name
			owner._detail_desc.text = item.desc if item.desc.length() > 0 else "(" + item.get_type_name() + ")"
			var stats_text: String = ""
			if item.atk_bonus > 0:  stats_text += owner.tr("STAT_ATK_BONUS") % item.atk_bonus + "  "
			if item.def_bonus > 0:  stats_text += owner.tr("STAT_DEF_BONUS") % item.def_bonus + "  "
			if item.heal_amount > 0: stats_text += owner.tr("STAT_HEAL") % item.heal_amount
			owner._detail_stats.text = stats_text
			var can_equip: bool = item.type == ItemDef.Type.ARMOR
			owner._detail_use_btn.text = owner.tr("EQUIP_ITEM")
			owner._detail_use_btn.visible = can_equip
			owner._detail_vis_btn.visible = false
			owner._detail_item_name.visible = true
			owner._detail_desc.visible = true
			owner._detail_stats.visible = true
			owner._detail_drop_btn.visible = true
			owner._detail_bg.visible = true

	if not has_selection:
		owner._detail_bg.visible = false
		owner._detail_item_name.visible = false
		owner._detail_desc.visible = false
		owner._detail_stats.visible = false
		owner._detail_use_btn.visible = false
		owner._detail_drop_btn.visible = false
		owner._detail_vis_btn.visible = false

static func on_detail_equip(owner) -> void:
	if owner._selected_equip >= 0:
		owner._unequip_to_inventory(owner._selected_equip)
		return
	if owner._player_ref == null or owner._inventory == null: return
	var idx: int = owner._selected_slot
	if idx < 0 or idx >= owner._inventory.slots.size(): return
	var slot: ItemSlot = owner._inventory.slots[idx]
	if slot.is_empty(): return
	owner._player_ref.use_item_from_inventory(idx)
	if slot.is_empty():
		owner._selected_slot = -1
		owner._reset_slot_styles()

static func on_detail_drop(owner) -> void:
	if owner._selected_equip >= 0:
		owner._drop_equipped(owner._selected_equip)
		return
	if owner._player_ref == null or owner._inventory == null: return
	var idx: int = owner._selected_slot
	if idx < 0 or idx >= owner._inventory.slots.size(): return
	var slot: ItemSlot = owner._inventory.slots[idx]
	if slot.is_empty(): return
	owner._player_ref.drop_item(idx)
	owner._selected_slot = -1
	owner._reset_slot_styles()

static func on_detail_toggle_visual(owner) -> void:
	if owner._selected_equip < 0 or owner._player_ref == null:
		return
	var vis: bool = owner._player_ref.get_armor_visible(owner._selected_equip)
	owner._player_ref.set_armor_visible(owner._selected_equip, not vis)
	owner._detail_vis_btn.text = owner.tr("HIDE_MODEL") if owner._player_ref.get_armor_visible(owner._selected_equip) else owner.tr("SHOW_MODEL")

static func show_tooltip(owner, item: ItemDef) -> void:
	if owner._tooltip == null:
		return
	var tt: String = item.name
	if item.desc.length() > 0: tt += "\n" + item.desc
	if item.atk_bonus > 0: tt += "\n" + owner.tr("STAT_ATK_BONUS") % item.atk_bonus
	if item.def_bonus > 0: tt += "\n" + owner.tr("STAT_DEF_BONUS") % item.def_bonus
	if item.heal_amount > 0: tt += "\n" + owner.tr("STAT_HEAL") % item.heal_amount
	var tn: String = item.get_type_name()
	if tn.length() > 0: tt += "\n[" + tn + "]"
	if item.type == ItemDef.Type.ARMOR: tt += "\n[" + item.get_armor_slot_name() + "]"
	owner._tooltip.text = tt
	owner._tooltip_bg.size = owner._tooltip.size + Vector2(8, 8)
	owner._tooltip_bg.visible = true
	owner._tooltip.visible = true

static func hide_tooltip(owner) -> void:
	if owner._tooltip == null:
		return
	owner._tooltip.visible = false
	owner._tooltip_bg.visible = false
