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
	_build()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var W: float = min(vp.x * 0.6, 720.0)
	var H: float = vp.y * 0.5

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
	bg_sty.bg_color = Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.97)
	bg_sty.corner_radius_top_left    = 18
	bg_sty.corner_radius_top_right   = 18
	bg_sty.corner_radius_bottom_left = 18
	bg_sty.corner_radius_bottom_right = 18
	bg_sty.border_width_left   = 2
	bg_sty.border_width_right  = 2
	bg_sty.border_width_top    = 2
	bg_sty.border_width_bottom = 2
	bg_sty.border_color = Color(0.45, 0.30, 0.70, 0.50)
	panel.add_theme_stylebox_override("panel", bg_sty)
	add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(2, 2)
	accent.size = Vector2(W - 4, 3)
	accent.color = PURPLE
	panel.add_child(accent)

	# Title
	var title := Label.new()
	title.text = "Tila'Adventure"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", PURPLE)
	title.add_theme_color_override("font_shadow_color", Color(0.30, 0.15, 0.50, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(0, 24)
	title.size = Vector2(W, 52)
	panel.add_child(title)

	var line := ColorRect.new()
	line.color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.22)
	line.position = Vector2(28, 80)
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

	var y: float = 100.0
	for ln in lines:
		var lbl := Label.new()
		lbl.text = ln
		lbl.position = Vector2(36, y)
		lbl.size = Vector2(W - 72, 28)
		if ln.begins_with("    "):
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.70))
		elif ln == "Thank you for playing  ♥":
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.50, 0.85))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(W - 72, 28)
		elif ln.is_empty():
			lbl.size.y = 14
		else:
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, 0.90))
		panel.add_child(lbl)
		y += lbl.size.y + 4

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(W * 0.5 - 100, H - 56)
	close_btn.size = Vector2(200, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(TEXT_BRIGHT.r, TEXT_BRIGHT.g, TEXT_BRIGHT.b, 0.80))
	var c_sty := StyleBoxFlat.new()
	c_sty.bg_color = Color(BG_CARD.r, BG_CARD.g, BG_CARD.b, 0.80)
	c_sty.corner_radius_top_left    = 10
	c_sty.corner_radius_top_right   = 10
	c_sty.corner_radius_bottom_left = 10
	c_sty.corner_radius_bottom_right = 10
	c_sty.border_width_left   = 1
	c_sty.border_width_right  = 1
	c_sty.border_width_top    = 1
	c_sty.border_width_bottom = 1
	c_sty.border_color = Color(0.45, 0.30, 0.70, 0.40)
	close_btn.add_theme_stylebox_override("normal", c_sty)
	var c_h := c_sty.duplicate()
	c_h.bg_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.30)
	c_h.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.50)
	close_btn.add_theme_stylebox_override("hover", c_h)
	close_btn.pressed.connect(func(): visible = false)
	panel.add_child(close_btn)
