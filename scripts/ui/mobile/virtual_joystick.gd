## VirtualJoystick — Touch joystick cho điện thoại
## Sử dụng: _joystick.get_vector() → Vector2 (-1..1)
extends Control

signal moved(vec: Vector2)

@export var base_radius: float  = 60.0
@export var knob_radius: float  = 26.0
@export var dead_zone: float    = 0.08

var _touch_idx: int  = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO
var _value: Vector2 = Vector2.ZERO

## Đọc giá trị joystick hiện tại (-1..1 mỗi trục)
func get_vector() -> Vector2:
	return _value

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2.2, base_radius * 2.2)
	_origin = size * 0.5
	_knob_pos = _origin

func _draw() -> void:
	# Vòng ngoài
	draw_circle(_origin, base_radius, Color(1, 1, 1, 0.12))
	draw_arc(_origin, base_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	# Núm joystick
	var knob_col := Color(1, 1, 1, 0.55) if _touch_idx >= 0 else Color(1, 1, 1, 0.30)
	draw_circle(_knob_pos, knob_radius, knob_col)
	draw_arc(_knob_pos, knob_radius, 0, TAU, 32, Color(1, 1, 1, 0.70), 1.5)
	# Chữ thập hướng
	var cross_col := Color(1, 1, 1, 0.20)
	var cr: float = base_radius * 0.55
	draw_line(_origin + Vector2(-cr, 0), _origin + Vector2(cr, 0), cross_col, 1.0)
	draw_line(_origin + Vector2(0, -cr), _origin + Vector2(0, cr), cross_col, 1.0)

func _gui_input(event: InputEvent) -> void:
	# ── Touch events (điện thoại) ─────────────────────────────────────────────
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _touch_idx < 0:
			_touch_idx = e.index
			_origin = e.position
			_knob_pos = _origin
			_value = Vector2.ZERO
			queue_redraw()
		elif not e.pressed and e.index == _touch_idx:
			_touch_idx = -1
			_knob_pos = _origin
			_value = Vector2.ZERO
			emit_signal("moved", _value)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _touch_idx:
			var delta := e.position - _origin
			if delta.length() > base_radius:
				delta = delta.normalized() * base_radius
			_knob_pos = _origin + delta
			_value = delta / base_radius
			if _value.length() < dead_zone:
				_value = Vector2.ZERO
			emit_signal("moved", _value)
			queue_redraw()

	# ── Mouse events (PC để test) ─────────────────────────────────────────────
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and _touch_idx < 0:
				_touch_idx = 0
				_origin = e.position
				_knob_pos = _origin
				_value = Vector2.ZERO
				queue_redraw()
			elif not e.pressed and _touch_idx == 0:
				_touch_idx = -1
				_knob_pos = _origin
				_value = Vector2.ZERO
				emit_signal("moved", _value)
				queue_redraw()
	elif event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		if _touch_idx == 0:
			var delta := e.position - _origin
			if delta.length() > base_radius:
				delta = delta.normalized() * base_radius
			_knob_pos = _origin + delta
			_value = delta / base_radius
			if _value.length() < dead_zone:
				_value = Vector2.ZERO
			emit_signal("moved", _value)
			queue_redraw()
