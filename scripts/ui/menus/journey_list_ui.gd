extends Control

const BG_DEEP := Color(0.06, 0.04, 0.12)
const BG_PANEL := Color(0.10, 0.07, 0.18)
const BG_CARD := Color(0.14, 0.10, 0.22)
const PURPLE := Color(0.55, 0.35, 0.90)
const TEAL := Color(0.15, 0.72, 0.68)
const PINK := Color(0.82, 0.28, 0.52)
const ORANGE := Color(0.92, 0.52, 0.12)
const CYAN := Color(0.15, 0.62, 0.92)
const TEXT_BRIGHT := Color(0.95, 0.92, 1.0)
const TEXT_MAIN := Color(0.82, 0.78, 0.95)
const TEXT_DIM := Color(0.55, 0.50, 0.72)
const TEXT_MUTED := Color(0.35, 0.32, 0.50)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for ch in get_children():
		ch.queue_free()
	await get_tree().process_frame
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = min(vp.x * 0.55, 600.0)

	var saves: Array = WorldSeed.get_saves()
	var row_h: float = 72.0
	var row_gap: float = 10.0
	var header_h: float = 74.0
	var footer_h: float = 64.0
	var min_h: float = header_h + footer_h + 60.0
	var content_h: float = maxf(saves.size() * (row_h + row_gap), 60.0)
	var H: float = clampf(header_h + content_h + footer_h, min_h, vp.y * 0.85)

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			get_viewport().set_input_as_handled()
	)
	add_child(overlay)

	# Panel
	var panel := Panel.new()
	panel.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	panel.size = Vector2(W, H)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.97)
	sty.corner_radius_top_left    = 16
	sty.corner_radius_top_right   = 16
	sty.corner_radius_bottom_left = 16
	sty.corner_radius_bottom_right = 16
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.border_color = Color(0.45, 0.30, 0.70, 0.45)
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(2, 2)
	accent.size = Vector2(W - 4, 3)
	accent.color = PURPLE
	panel.add_child(accent)

	# Header
	var title := Label.new()
	title.text = tr("PREVIOUS_JOURNEYS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.95))
	title.position = Vector2(0, 18)
	title.size = Vector2(W, 44)
	panel.add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.18)
	divider.position = Vector2(20, 64)
	divider.size = Vector2(W - 40, 1)
	panel.add_child(divider)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, header_h)
	scroll.size = Vector2(W - 24, H - header_h - footer_h)
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if saves.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = tr("NO_SAVES")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 20)
		empty_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		empty_lbl.custom_minimum_size = Vector2(W - 48, 72)
		list.add_child(empty_lbl)
	else:
		for i in range(saves.size()):
			var s: Dictionary = saves[i]
			list.add_child(_make_save_row(s, i, W - 48))
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, row_gap)
			list.add_child(gap)

	# Close button
	var close_btn := Button.new()
	close_btn.text = tr("CLOSE")
	close_btn.position = Vector2(W * 0.5 - 100, H - 52)
	close_btn.size = Vector2(200, 42)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.80))
	var c_sty := StyleBoxFlat.new()
	c_sty.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.80)
	c_sty.corner_radius_top_left    = 10
	c_sty.corner_radius_top_right   = 10
	c_sty.corner_radius_bottom_left = 10
	c_sty.corner_radius_bottom_right = 10
	c_sty.border_width_left   = 1; c_sty.border_width_right  = 1
	c_sty.border_width_top    = 1; c_sty.border_width_bottom = 1
	c_sty.border_color = Color(0.45, 0.30, 0.70, 0.35)
	close_btn.add_theme_stylebox_override("normal", c_sty)
	var c_h := c_sty.duplicate()
	c_h.bg_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.30)
	c_h.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.50)
	close_btn.add_theme_stylebox_override("hover", c_h)
	close_btn.pressed.connect(func(): visible = false)
	panel.add_child(close_btn)

func _make_save_row(s: Dictionary, idx: int, row_w: float) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(row_w, 72)

	var row_sty := StyleBoxFlat.new()
	row_sty.bg_color = Color(0.40, 0.30, 0.55, 0.08)
	row_sty.corner_radius_top_left    = 10
	row_sty.corner_radius_top_right   = 10
	row_sty.corner_radius_bottom_left = 10
	row_sty.corner_radius_bottom_right = 10
	row_sty.border_width_left   = 1; row_sty.border_width_right  = 1
	row_sty.border_width_top    = 1; row_sty.border_width_bottom = 1
	row_sty.border_color = Color(0.35, 0.28, 0.50, 0.12)
	row.add_theme_stylebox_override("panel", row_sty)

	# Save name
	var name_lbl := Label.new()
	name_lbl.text = s.get("name", "Unknown")
	name_lbl.position = Vector2(16, 10)
	name_lbl.size = Vector2(row_w - 140, 34)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.90))
	row.add_child(name_lbl)

	# Seed info
	var seed_lbl := Label.new()
	var save_name: String = s.get("name", "Unknown")
	var has_data: bool = SaveManager and SaveManager.save_exists(save_name)
	seed_lbl.text = tr("SEED").replace("%d", str(s.get("seed", 0))) + ("  ●" if has_data else "  ○")
	seed_lbl.position = Vector2(16, 44)
	seed_lbl.size = Vector2(row_w - 140, 20)
	seed_lbl.add_theme_font_size_override("font_size", 16)
	seed_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	row.add_child(seed_lbl)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "▶"
	play_btn.position = Vector2(row_w - 120, 14)
	play_btn.size = Vector2(56, 44)
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.add_theme_color_override("font_color", Color(TEAL.r, TEAL.g, TEAL.b, 0.90))
	play_btn.add_theme_color_override("font_hover_color", Color(TEAL.r, TEAL.g, TEAL.b, 1.0))
	var pb_sty := StyleBoxFlat.new()
	pb_sty.bg_color = Color(0, 0, 0, 0)
	play_btn.add_theme_stylebox_override("normal", pb_sty)
	var pb_h := pb_sty.duplicate()
	pb_h.bg_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.20)
	play_btn.add_theme_stylebox_override("hover", pb_h)
	play_btn.pressed.connect(_on_load.bind(idx))
	row.add_child(play_btn)

	# Delete button
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.position = Vector2(row_w - 58, 14)
	del_btn.size = Vector2(44, 44)
	del_btn.add_theme_font_size_override("font_size", 26)
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 0.60))
	del_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35, 1.0))
	var db_sty := StyleBoxFlat.new()
	db_sty.bg_color = Color(0, 0, 0, 0)
	del_btn.add_theme_stylebox_override("normal", db_sty)
	var db_h := db_sty.duplicate()
	db_h.bg_color = Color(0.50, 0.10, 0.10, 0.20)
	del_btn.add_theme_stylebox_override("hover", db_h)
	del_btn.pressed.connect(_on_delete.bind(idx, s.get("name", "Unknown")))
	row.add_child(del_btn)

	return row

func _on_load(idx: int) -> void:
	if WorldSeed.load_journey(idx):
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _on_delete(idx: int, save_name: String) -> void:
	var confirm := AcceptDialog.new()
	confirm.dialog_text = tr("DELETE_JOURNEY").replace("%s", save_name)
	confirm.ok_button_text = tr("DELETE")
	confirm.add_cancel_button(tr("CANCEL"))
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(_do_delete.bind(idx))

func _do_delete(idx: int) -> void:
	WorldSeed.delete_save(idx)
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
