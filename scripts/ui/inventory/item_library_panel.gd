## Item Library Panel
extends RefCounted

static func search_matches(item: ItemDef, q: String) -> bool:
	return item.id.contains(q) or item.name.to_lower().contains(q) or item.desc.to_lower().contains(q)

static func _sort_items(owner) -> void:
	var mode: int = owner._lib_sort_mode
	owner._lib_items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if mode == owner.SortMode.NAME_ASC:
			return a.name.to_lower() < b.name.to_lower()
		elif mode == owner.SortMode.NAME_DESC:
			return a.name.to_lower() > b.name.to_lower()
		elif mode == owner.SortMode.TYPE:
			if a.type != b.type:
				return a.type < b.type
			return a.name.to_lower() < b.name.to_lower()
		elif mode == owner.SortMode.ATK:
			var aa: int = a.atk_bonus; var ba: int = b.atk_bonus
			if aa != ba: return aa > ba
			return a.name.to_lower() < b.name.to_lower()
		elif mode == owner.SortMode.DEF:
			var ad: int = a.def_bonus; var bd: int = b.def_bonus
			if ad != bd: return ad > bd
			return a.name.to_lower() < b.name.to_lower()
		elif mode == owner.SortMode.HEAL:
			var ah: int = a.heal_amount; var bh: int = b.heal_amount
			if ah != bh: return ah > bh
			return a.name.to_lower() < b.name.to_lower()
		return a.name.to_lower() < b.name.to_lower()
	)

static func apply_filter(owner) -> void:
	owner._lib_items.clear()
	var q: String = owner._lib_search_box.text.strip_edges().to_lower() if owner._lib_search_box else ""
	for id in owner._item_db:
		var item: ItemDef = owner._item_db[id]
		if not q.is_empty() and not search_matches(item, q):
			continue
		owner._lib_items.append(item)
	_sort_items(owner)
	owner._lib_scroll_offset = 0
	refresh_display(owner)

static func refresh_display(owner) -> void:
	if owner._lib_panels.is_empty():
		return
	var total_slots: int = owner._lib_panels.size()
	var visible_count: int = total_slots
	var start: int = owner._lib_scroll_offset * owner.LIB_COLS

	for i in range(visible_count):
		var item_idx: int = start + i
		var panel: Panel = owner._lib_panels[i]
		var face: ColorRect = owner._lib_faces[i]
		var lbl: Label = owner._lib_name_labels[i]
		if item_idx < owner._lib_items.size():
			var item: ItemDef = owner._lib_items[item_idx]
			var icon_tex: TextureRect = owner._lib_icon_textures[i]
			var tex := ItemDatabase.load_icon_2d(item.id)
			if tex:
				face.color = Color(0.20, 0.15, 0.30, 0.4)
				icon_tex.texture = tex
				icon_tex.visible = true
			else:
				face.color = item.icon_color
				icon_tex.texture = null
				icon_tex.visible = false
			lbl.text = item.name
			panel.visible = true
			panel.set_meta("item_idx", item_idx)
		else:
			face.color = Color(0.14, 0.10, 0.22, 0.3)
			owner._lib_icon_textures[i].texture = null
			owner._lib_icon_textures[i].visible = false
			lbl.text = ""
			panel.visible = true
			panel.set_meta("item_idx", -1)

	var max_row: int = ceili(float(owner._lib_items.size()) / float(owner.LIB_COLS))
	var can_up: bool = owner._lib_scroll_offset > 0
	var can_down: bool = (owner._lib_scroll_offset + owner._lib_visible_rows) < max_row
	if owner._lib_scroll_up:
		owner._lib_scroll_up.modulate.a = 1.0 if can_up else 0.3
		owner._lib_scroll_up.disabled = not can_up
	if owner._lib_scroll_down:
		owner._lib_scroll_down.modulate.a = 1.0 if can_down else 0.3
		owner._lib_scroll_down.disabled = not can_down

static func setup_library_panel(owner) -> void:
	var lib_bg_style: StyleBoxFlat = owner._glass_style.duplicate() as StyleBoxFlat
	lib_bg_style.bg_color = Color(0.10, 0.07, 0.18, 0.92)

	var lib_bg := Panel.new()
	lib_bg.position = Vector2(0, 0)
	lib_bg.size = Vector2(owner.LIB_W, owner.CONTENT_H)
	lib_bg.add_theme_stylebox_override("panel", lib_bg_style)
	lib_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.add_child(lib_bg)

	# ── Title ──
	owner._lib_title_label = Label.new()
	owner._lib_title_label.text = owner.tr("ITEM_LIBRARY_TITLE")
	owner._lib_title_label.position = Vector2(owner.LIB_PAD, owner.LIB_PAD - 2)
	owner._lib_title_label.size = Vector2(owner.LIB_W - owner.LIB_PAD * 2, 22)
	owner._lib_title_label.add_theme_font_size_override("font_size", 22)
	owner._lib_title_label.add_theme_color_override("font_color", owner.TEXT_MAIN)
	owner._lib_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	owner._lib_title_label.add_theme_constant_override("shadow_offset_x", 1)
	owner._lib_title_label.add_theme_constant_override("shadow_offset_y", 1)
	owner.add_child(owner._lib_title_label)

	# ── Search bar (top) ──
	var search_y: float = owner.LIB_PAD + 28
	owner._lib_search_box = LineEdit.new()
	owner._lib_search_box.position = Vector2(owner.LIB_PAD + 2, search_y)
	owner._lib_search_box.size = Vector2(owner.LIB_W - owner.LIB_PAD * 2 - 4, owner.LIB_SEARCH_H)
	owner._lib_search_box.placeholder_text = "🔍 " + owner.tr("LIB_SEARCH_HINT")
	owner._lib_search_box.add_theme_font_size_override("font_size", 18)
	owner._lib_search_box.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.90))
	owner._lib_search_box.add_theme_color_override("placeholder_color", Color(0.35, 0.32, 0.50, 0.70))
	owner._lib_search_box.caret_blink = true
	owner._lib_search_box.focus_mode = Control.FOCUS_CLICK
	owner._lib_search_box.text_submitted.connect(func(_t): owner._lib_search_box.release_focus())
	owner._lib_search_box.gui_input.connect(func(ev):
		if ev is InputEventKey and ev.pressed and ev.is_action_pressed("ui_cancel"):
			owner._lib_search_box.release_focus()
			owner.accept_event()
	)
	var search_bg := StyleBoxFlat.new()
	search_bg.bg_color = Color(0.06, 0.04, 0.12, 0.90)
	search_bg.corner_radius_top_left = 8; search_bg.corner_radius_top_right = 8
	search_bg.corner_radius_bottom_left = 8; search_bg.corner_radius_bottom_right = 8
	search_bg.border_width_left = 1; search_bg.border_width_right = 1
	search_bg.border_width_top = 1; search_bg.border_width_bottom = 1
	search_bg.border_color = Color(0.35, 0.28, 0.50, 0.25)
	owner._lib_search_box.add_theme_stylebox_override("normal", search_bg)
	var search_focus_bg := search_bg.duplicate() as StyleBoxFlat
	search_focus_bg.border_color = Color(0.22, 0.62, 0.28, 0.50)
	owner._lib_search_box.add_theme_stylebox_override("focus", search_focus_bg)
	owner._lib_search_box.text_changed.connect(on_lib_search_changed.bind(owner))
	owner.add_child(owner._lib_search_box)

	# ── Sort bar ──
	var sort_y: float = search_y + owner.LIB_SEARCH_H + 4
	var sort_labels: Array[Dictionary] = [
		{ "label": "Tên ↑",  "mode": owner.SortMode.NAME_ASC },
		{ "label": "Tên ↓",  "mode": owner.SortMode.NAME_DESC },
		{ "label": "Loại",   "mode": owner.SortMode.TYPE },
		{ "label": "ATK",    "mode": owner.SortMode.ATK },
		{ "label": "DEF",    "mode": owner.SortMode.DEF },
		{ "label": "Heal",   "mode": owner.SortMode.HEAL },
	]
	var sort_btn_w: float = (owner.LIB_W - owner.LIB_PAD * 2 - 4) / sort_labels.size()
	for i in range(sort_labels.size()):
		var sl := sort_labels[i]
		var btn := Button.new()
		btn.text = sl["label"]
		btn.position = Vector2(owner.LIB_PAD + 2 + i * sort_btn_w, sort_y)
		btn.size = Vector2(sort_btn_w - 2, 26)
		btn.add_theme_font_size_override("font_size", 13)
		var mode: int = sl["mode"]
		var sbg := StyleBoxFlat.new()
		sbg.bg_color = Color(0.06, 0.04, 0.12, 0.85)
		sbg.corner_radius_top_left = 4; sbg.corner_radius_top_right = 4
		sbg.corner_radius_bottom_left = 4; sbg.corner_radius_bottom_right = 4
		sbg.border_width_left = 1; sbg.border_width_right = 1
		sbg.border_width_top = 1; sbg.border_width_bottom = 1
		sbg.border_color = Color(0.40, 0.32, 0.55, 0.20)
		btn.add_theme_stylebox_override("normal", sbg)
		var sbg_h := sbg.duplicate() as StyleBoxFlat
		sbg_h.bg_color = Color(0.22, 0.18, 0.35, 0.85)
		sbg_h.border_color = Color(0.22, 0.62, 0.28, 0.50)
		btn.add_theme_stylebox_override("hover", sbg_h)
		btn.add_theme_stylebox_override("pressed", sbg_h)
		btn.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
		btn.pressed.connect(on_lib_sort.bind(owner, mode))
		owner.add_child(btn)
		owner._lib_sort_buttons.append(btn)

	# ── Item grid ──
	var grid_y: float = sort_y + 30
	var remaining_h: float = owner.CONTENT_H - grid_y - owner.LIB_PAD - 38
	if remaining_h < 60: remaining_h = 60
	owner._lib_visible_rows = max(1, int((remaining_h) / (owner.LIB_SLOT + owner.LIB_GAP)))
	var total_lib_slots: int = owner._lib_visible_rows * owner.LIB_COLS

	for i in range(total_lib_slots):
		var row: int = i / owner.LIB_COLS
		var col: int = i % owner.LIB_COLS
		var px: float = owner.LIB_PAD + col * (owner.LIB_SLOT + owner.LIB_GAP)
		var py: float = grid_y + row * (owner.LIB_SLOT + owner.LIB_GAP)

		var panel := Panel.new()
		panel.position = Vector2(px, py)
		panel.size = Vector2(owner.LIB_SLOT, owner.LIB_SLOT)
		panel.clip_contents = true
		panel.add_theme_stylebox_override("panel", owner._lib_slot_style)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.set_meta("item_idx", -1)
		panel.gui_input.connect(on_lib_slot_input.bind(owner, i))
		panel.mouse_entered.connect(on_lib_slot_entered.bind(owner, i))
		panel.mouse_exited.connect(on_lib_slot_exited.bind(owner))
		owner.add_child(panel)
		owner._lib_panels.append(panel)

		# Chia slot thành vùng icon (trên) và label (dưới)
		var LABEL_H: float = 18.0
		var ICON_H: float = owner.LIB_SLOT - LABEL_H - 4  # 4 = top padding + gap

		var face := ColorRect.new()
		face.position = Vector2(2, 2)
		face.size = Vector2(owner.LIB_SLOT - 4, ICON_H)
		face.color = Color(0.14, 0.10, 0.22, 0.3)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(face)
		owner._lib_faces.append(face)

		var lib_icon := TextureRect.new()
		lib_icon.position = Vector2(2, 2)
		lib_icon.size = Vector2(owner.LIB_SLOT - 4, ICON_H)
		lib_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lib_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lib_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lib_icon.visible = false
		panel.add_child(lib_icon)
		owner._lib_icon_textures.append(lib_icon)

		var lbl := Label.new()
		lbl.position = Vector2(1, owner.LIB_SLOT - LABEL_H)
		lbl.size = Vector2(owner.LIB_SLOT - 2, LABEL_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
		lbl.clip_contents = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
		owner._lib_name_labels.append(lbl)

	# ── Scroll buttons ──
	var scroll_y: float = grid_y + owner._lib_visible_rows * (owner.LIB_SLOT + owner.LIB_GAP) + 4
	owner._lib_scroll_up = make_scroll_btn("▲", Vector2(owner.LIB_PAD, scroll_y))
	owner._lib_scroll_up.pressed.connect(on_lib_scroll.bind(owner, -1))
	owner.add_child(owner._lib_scroll_up)

	owner._lib_scroll_down = make_scroll_btn("▼", Vector2(owner.LIB_PAD + 56, scroll_y))
	owner._lib_scroll_down.pressed.connect(on_lib_scroll.bind(owner, 1))
	owner.add_child(owner._lib_scroll_down)

	refresh_display(owner)

static func make_scroll_btn(txt: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.position = pos
	btn.size = Vector2(50, 28)
	btn.add_theme_font_size_override("font_size", 20)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.10, 0.22, 0.75)
	bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.40, 0.32, 0.55, 0.25)
	btn.add_theme_stylebox_override("normal", bg)
	var bg_h := bg.duplicate() as StyleBoxFlat
	bg_h.bg_color = Color(0.30, 0.20, 0.40, 0.85)
	bg_h.border_color = Color(0.22, 0.62, 0.28, 0.50)
	btn.add_theme_stylebox_override("hover", bg_h)
	btn.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95, 0.80))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return btn

static func on_lib_sort(owner, mode: int) -> void:
	owner._lib_sort_mode = mode
	_sort_items(owner)
	owner._lib_scroll_offset = 0
	refresh_display(owner)

static func on_lib_scroll(owner, dir: int) -> void:
	var max_row: int = ceili(float(owner._lib_items.size()) / float(owner.LIB_COLS))
	owner._lib_scroll_offset = clampi(owner._lib_scroll_offset + dir, 0, max(0, max_row - owner._lib_visible_rows))
	refresh_display(owner)

static func on_lib_search_changed(text: String, owner) -> void:
	apply_filter(owner)

static func on_lib_slot_input(event: InputEvent, owner, slot_i: int) -> void:
	if not owner.visible or owner._inventory == null or owner._player_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Panel = owner._lib_panels[slot_i]
		var item_idx: int = panel.get_meta("item_idx", -1)
		if item_idx < 0 or item_idx >= owner._lib_items.size():
			return
		var item: ItemDef = owner._lib_items[item_idx]
		var remaining: int = owner._inventory.add_item(item, 1)
		if remaining == 0:
			panel.add_theme_stylebox_override("panel", owner._lib_slot_hover_style)
			var tween: Tween = owner.create_tween()
			tween.tween_interval(0.15)
			tween.tween_callback(func(): panel.add_theme_stylebox_override("panel", owner._lib_slot_style))
		owner.accept_event()

static func on_lib_slot_entered(owner, slot_i: int) -> void:
	var panel: Panel = owner._lib_panels[slot_i]
	var item_idx: int = panel.get_meta("item_idx", -1)
	if item_idx < 0 or item_idx >= owner._lib_items.size():
		owner._tooltip.visible = false; owner._tooltip_bg.visible = false
		return
	panel.add_theme_stylebox_override("panel", owner._lib_slot_hover_style)
	var item: ItemDef = owner._lib_items[item_idx]
	var tt: String = item.name
	if item.desc.length() > 0: tt += "\n" + item.desc
	if item.atk_bonus > 0: tt += "\n" + owner.tr("STAT_ATK_BONUS") % item.atk_bonus
	if item.def_bonus > 0: tt += "\n" + owner.tr("STAT_DEF_BONUS") % item.def_bonus
	if item.heal_amount > 0: tt += "\n" + owner.tr("STAT_HEAL") % item.heal_amount
	tt += "\n[" + item.get_type_name() + "]"
	if item.type == ItemDef.Type.ARMOR: tt += " [" + item.get_armor_slot_name() + "]"
	tt += "\n" + owner.tr("TOOLTIP_CLICK_ADD")
	owner._tooltip.text = tt
	owner._tooltip_bg.size = owner._tooltip.size + Vector2(8, 8)
	owner._tooltip_bg.visible = true
	owner._tooltip.visible = true

static func on_lib_slot_exited(owner) -> void:
	for i in range(owner._lib_panels.size()):
		owner._lib_panels[i].add_theme_stylebox_override("panel", owner._lib_slot_style)
	owner._tooltip.visible = false
	owner._tooltip_bg.visible = false
