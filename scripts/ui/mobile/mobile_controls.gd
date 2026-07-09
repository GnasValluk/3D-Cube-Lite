## MobileControls — Overlay điều khiển cho điện thoại
## Tự ẩn/hiện theo DeviceManager.is_mobile()
extends CanvasLayer

const _VJoy = preload("res://scripts/ui/mobile/virtual_joystick.gd")

signal jump_pressed
signal interact_pressed
signal sprint_changed(held: bool)
signal inventory_pressed
signal map_pressed
signal attack_pressed
signal camera_drag(delta: Vector2)
signal pinch_zoom(factor: float)

var joystick: Control = null   # VirtualJoystick instance

var jump_held:     bool = false
var sprint_held:   bool = false
var interact_held: bool = false
var attack_held:   bool = false

var _cam_touches: Dictionary = {}  # index -> Vector2 position
var _pinch_last_dist: float = 0.0
var _sprint_held_internal: bool = false

## Scale toàn bộ UI theo button_scale setting
var _scale: float = 1.0

func _ready() -> void:
	layer = 10
	_scale = ProjectSettings.get_setting("mobile/button_scale", 1.0)
	_build()
	_refresh_visibility()
	if DeviceManager:
		DeviceManager.device_changed.connect(_on_device_changed)

func _refresh_visibility() -> void:
	if not DeviceManager:
		visible = false
		return
	var touch_on: bool = ProjectSettings.get_setting("mobile/touch_controls_enabled", true)
	visible = DeviceManager.is_mobile() and touch_on

func _on_device_changed(_is_mob: bool) -> void:
	_refresh_visibility()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _scale

	# ── Joystick (góc trái dưới) ────────────────────────────────────────────
	joystick = _VJoy.new()
	joystick.base_radius  = 60.0 * s
	joystick.knob_radius  = 26.0 * s
	joystick.size = Vector2(joystick.base_radius * 2.2, joystick.base_radius * 2.2)
	joystick.position = Vector2(20.0 * s, vp.y - joystick.size.y - 20.0 * s)
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(joystick)

	# ── Camera drag area (giữa màn hình, vô hình) ───────────────────────────
	var cam_area := _make_cam_area(vp, s)
	add_child(cam_area)

	# ── Nút Jump (góc phải dưới) ─────────────────────────────────────────────
	var bsz := 62.0 * s
	var br  := 8.0 * s
	var bx  := vp.x - bsz - 20.0 * s
	var by  := vp.y - bsz - 20.0 * s

	var btn_jump := _make_btn("↑", bx, by, bsz, br, Color(0.35, 0.75, 0.35, 0.75))
	btn_jump.button_down.connect(func(): jump_held = true;  emit_signal("jump_pressed"))
	btn_jump.button_up.connect(func():   jump_held = false)
	add_child(btn_jump)

	# ── Nút Sprint (bên trái Jump) ──────────────────────────────────────────
	var btn_sprint := _make_btn("»", bx - bsz - 10.0 * s, by, bsz, br, Color(0.35, 0.55, 0.90, 0.70))
	btn_sprint.toggle_mode = true
	btn_sprint.toggled.connect(func(on: bool):
		sprint_held = on
		emit_signal("sprint_changed", on)
	)
	add_child(btn_sprint)

	# ── Nút Attack (phía trên Sprint) ───────────────────────────────────────
	var btn_atk := _make_btn("⚔", bx - bsz - 10.0 * s, by - bsz - 10.0 * s, bsz, br, Color(0.85, 0.30, 0.30, 0.75))
	btn_atk.button_down.connect(func(): attack_held = true;  emit_signal("attack_pressed"))
	btn_atk.button_up.connect(func():   attack_held = false)
	add_child(btn_atk)

	# ── Nút Interact (phía trên Jump) ───────────────────────────────────────
	var btn_int := _make_btn("F", bx, by - bsz - 10.0 * s, bsz, br, Color(0.90, 0.75, 0.20, 0.75))
	btn_int.button_down.connect(func(): interact_held = true;  emit_signal("interact_pressed"))
	btn_int.button_up.connect(func():   interact_held = false)
	add_child(btn_int)

	# ── Nút Inventory (góc trái trên) ───────────────────────────────────────
	var btn_inv := _make_btn("🎒", 20.0 * s, 80.0 * s, bsz * 0.85, br, Color(0.70, 0.60, 0.40, 0.70))
	btn_inv.pressed.connect(func(): emit_signal("inventory_pressed"))
	add_child(btn_inv)

	# ── Nút Map (kế Inventory) ──────────────────────────────────────────────
	var btn_map := _make_btn("🗺", 20.0 * s + bsz * 0.85 + 10.0 * s, 80.0 * s, bsz * 0.85, br, Color(0.30, 0.65, 0.45, 0.70))
	btn_map.pressed.connect(func(): emit_signal("map_pressed"))
	add_child(btn_map)

func _make_btn(label: String, x: float, y: float, sz: float, radius: float, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = Vector2(x, y)
	btn.size = Vector2(sz, sz)
	btn.add_theme_font_size_override("font_size", int(sz * 0.40))
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var sty := StyleBoxFlat.new()
	sty.bg_color = col
	sty.corner_radius_top_left    = int(radius)
	sty.corner_radius_top_right   = int(radius)
	sty.corner_radius_bottom_left = int(radius)
	sty.corner_radius_bottom_right = int(radius)
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.border_color = Color(1, 1, 1, 0.25)
	btn.add_theme_stylebox_override("normal", sty)

	var sty_p := sty.duplicate() as StyleBoxFlat
	sty_p.bg_color = Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, col.a)
	btn.add_theme_stylebox_override("pressed", sty_p)
	return btn

func _make_cam_area(vp: Vector2, s: float) -> Control:
	var area := Control.new()
	area.position = Vector2(vp.x * 0.35, 0)
	area.size = Vector2(vp.x * 0.65, vp.y * 0.70)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_on_cam_input)
	return area

func _on_cam_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_cam_touches[e.index] = e.position
			if _cam_touches.size() == 2:
				var pts := _cam_touches.values()
				_pinch_last_dist = pts[0].distance_to(pts[1])
		else:
			_cam_touches.erase(e.index)
			if _cam_touches.size() < 2:
				_pinch_last_dist = 0.0

	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		var prev_pos: Vector2 = _cam_touches.get(e.index, e.position)
		_cam_touches[e.index] = e.position

		if _cam_touches.size() == 2 and _pinch_last_dist > 0.0:
			var pts := _cam_touches.values()
			var dist: float = pts[0].distance_to(pts[1])
			var factor: float = dist / _pinch_last_dist
			if abs(factor - 1.0) > 0.01:
				emit_signal("pinch_zoom", factor)
			_pinch_last_dist = dist
		elif _cam_touches.size() == 1:
			var sensitivity: float = ProjectSettings.get_setting("mobile/joystick_sensitivity", 1.0)
			var delta_pos: Vector2 = e.position - prev_pos
			if delta_pos.length_squared() > 0.01:
				emit_signal("camera_drag", delta_pos * sensitivity)
