extends Control

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Xoá nội dung cũ rồi build lại (danh sách save có thể thay đổi)
	for ch in get_children():
		ch.queue_free()
	await get_tree().process_frame
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 420.0

	var saves: Array = WorldSeed.get_saves()
	var row_h: float = 52.0
	var row_gap: float = 6.0
	var header_h: float = 58.0
	var footer_h: float = 52.0
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
	sty.bg_color = Color(0.07, 0.08, 0.14, 0.97)
	sty.corner_radius_top_left    = 12
	sty.corner_radius_top_right   = 12
	sty.corner_radius_bottom_left = 12
	sty.corner_radius_bottom_right = 12
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.border_color = Color(0.30, 0.50, 0.75, 0.45)
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	# Header
	var title := Label.new()
	title.text = tr("PREVIOUS_JOURNEYS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.80, 0.92, 1.0, 0.95))
	title.position = Vector2(0, 14)
	title.size = Vector2(W, 32)
	panel.add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(0.30, 0.50, 0.75, 0.18)
	divider.position = Vector2(20, 50)
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
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
		empty_lbl.custom_minimum_size = Vector2(W - 48, 56)
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
	close_btn.position = Vector2(W * 0.5 - 75, H - 40)
	close_btn.size = Vector2(150, 30)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	var c_sty := StyleBoxFlat.new()
	c_sty.bg_color = Color(0.12, 0.14, 0.24, 0.80)
	c_sty.corner_radius_top_left    = 7
	c_sty.corner_radius_top_right   = 7
	c_sty.corner_radius_bottom_left = 7
	c_sty.corner_radius_bottom_right = 7
	c_sty.border_width_left   = 1; c_sty.border_width_right  = 1
	c_sty.border_width_top    = 1; c_sty.border_width_bottom = 1
	c_sty.border_color = Color(0.3, 0.4, 0.6, 0.35)
	close_btn.add_theme_stylebox_override("normal", c_sty)
	var c_h := c_sty.duplicate()
	c_h.bg_color = Color(0.18, 0.24, 0.42, 0.90)
	c_h.border_color = Color(0.4, 0.7, 1.0, 0.50)
	close_btn.add_theme_stylebox_override("hover", c_h)
	close_btn.pressed.connect(func(): visible = false)
	panel.add_child(close_btn)

func _make_save_row(s: Dictionary, idx: int, row_w: float) -> Control:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(row_w, 52)

	var row_sty := StyleBoxFlat.new()
	row_sty.bg_color = Color(1, 1, 1, 0.04)
	row_sty.corner_radius_top_left    = 7
	row_sty.corner_radius_top_right   = 7
	row_sty.corner_radius_bottom_left = 7
	row_sty.corner_radius_bottom_right = 7
	row_sty.border_width_left   = 1; row_sty.border_width_right  = 1
	row_sty.border_width_top    = 1; row_sty.border_width_bottom = 1
	row_sty.border_color = Color(1, 1, 1, 0.07)
	row.add_theme_stylebox_override("panel", row_sty)

	# Save name
	var name_lbl := Label.new()
	name_lbl.text = s.get("name", "Unknown")
	name_lbl.position = Vector2(12, 8)
	name_lbl.size = Vector2(row_w - 100, 24)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 0.90))
	row.add_child(name_lbl)

	# Seed info
	var seed_lbl := Label.new()
	seed_lbl.text = tr("SEED") % s.get("seed", 0)
	seed_lbl.position = Vector2(12, 30)
	seed_lbl.size = Vector2(row_w - 100, 16)
	seed_lbl.add_theme_font_size_override("font_size", 11)
	seed_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	row.add_child(seed_lbl)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "▶"
	play_btn.position = Vector2(row_w - 88, 10)
	play_btn.size = Vector2(42, 32)
	play_btn.add_theme_font_size_override("font_size", 16)
	play_btn.add_theme_color_override("font_color", Color(0.40, 0.90, 0.55, 0.90))
	play_btn.add_theme_color_override("font_hover_color", Color(0.40, 0.90, 0.55, 1.0))
	var pb_sty := StyleBoxFlat.new()
	pb_sty.bg_color = Color(0, 0, 0, 0)
	play_btn.add_theme_stylebox_override("normal", pb_sty)
	var pb_h := pb_sty.duplicate()
	pb_h.bg_color = Color(0.20, 0.50, 0.25, 0.20)
	play_btn.add_theme_stylebox_override("hover", pb_h)
	play_btn.pressed.connect(_on_load.bind(idx))
	row.add_child(play_btn)

	# Delete button
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.position = Vector2(row_w - 42, 10)
	del_btn.size = Vector2(32, 32)
	del_btn.add_theme_font_size_override("font_size", 18)
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
	confirm.dialog_text = tr("DELETE_JOURNEY") % save_name
	confirm.ok_button_text = tr("DELETE")
	confirm.add_cancel_button(tr("CANCEL"))
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(_do_delete.bind(idx))

func _do_delete(idx: int) -> void:
	WorldSeed.delete_save(idx)
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
