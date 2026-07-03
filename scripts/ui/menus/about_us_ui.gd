extends Control

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = 520.0
	var H: float = 380.0

	# Overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton:
			get_viewport().set_input_as_handled()
	)
	add_child(overlay)

	# Panel
	var panel := Panel.new()
	panel.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	panel.size = Vector2(W, H)
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.07, 0.08, 0.14, 0.97)
	bg_sty.corner_radius_top_left    = 14
	bg_sty.corner_radius_top_right   = 14
	bg_sty.corner_radius_bottom_left = 14
	bg_sty.corner_radius_bottom_right = 14
	bg_sty.border_width_left   = 2
	bg_sty.border_width_right  = 2
	bg_sty.border_width_top    = 2
	bg_sty.border_width_bottom = 2
	bg_sty.border_color = Color(0.30, 0.55, 0.80, 0.50)
	panel.add_theme_stylebox_override("panel", bg_sty)
	add_child(panel)

	# Title
	var title := Label.new()
	title.text = "CUPY  Cozy Daily"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0.3, 0.6, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(0, 18)
	title.size = Vector2(W, 38)
	panel.add_child(title)

	var line := ColorRect.new()
	line.color = Color(0.30, 0.55, 0.80, 0.22)
	line.position = Vector2(28, 60)
	line.size = Vector2(W - 56, 1)
	panel.add_child(line)

	# Content
	var lines: Array[String] = [
		"A cozy life-sim built in Godot 4",
		"",
		"Game Design & Programming",
		"    Cube Studio",
		"",
		"Art & Sound",
		"    Cube Studio",
		"",
		"Engine   Godot 4.x",
		"",
		"Thank you for playing  ♥",
	]

	var y: float = 74.0
	for ln in lines:
		var lbl := Label.new()
		lbl.text = ln
		lbl.position = Vector2(36, y)
		lbl.size = Vector2(W - 72, 22)
		if ln.begins_with("    "):
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 0.90, 0.70))
		elif ln == "Thank you for playing  ♥":
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.50, 0.85))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(W - 72, 22)
		elif ln.is_empty():
			lbl.size.y = 10
		else:
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96, 0.90))
		panel.add_child(lbl)
		y += lbl.size.y + 2

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(W * 0.5 - 70, H - 46)
	close_btn.size = Vector2(140, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	var c_sty := StyleBoxFlat.new()
	c_sty.bg_color = Color(0.12, 0.14, 0.24, 0.80)
	c_sty.corner_radius_top_left    = 7
	c_sty.corner_radius_top_right   = 7
	c_sty.corner_radius_bottom_left = 7
	c_sty.corner_radius_bottom_right = 7
	c_sty.border_width_left   = 1
	c_sty.border_width_right  = 1
	c_sty.border_width_top    = 1
	c_sty.border_width_bottom = 1
	c_sty.border_color = Color(0.3, 0.4, 0.6, 0.40)
	close_btn.add_theme_stylebox_override("normal", c_sty)
	var c_h := c_sty.duplicate()
	c_h.bg_color = Color(0.18, 0.24, 0.42, 0.90)
	c_h.border_color = Color(0.40, 0.70, 1.0, 0.50)
	close_btn.add_theme_stylebox_override("hover", c_h)
	close_btn.pressed.connect(func(): visible = false)
	panel.add_child(close_btn)
