extends Control
class_name AxisGizmo

signal view_rotated(delta_yaw: float, delta_pitch: float)
signal view_snapped(yaw: float, pitch: float)

var camera: Camera3D = null

var _font: Font = null
var _font_size: int = 14
var _gizmo_center: Vector2
var _gizmo_radius: float = 55.0
var _axis_len: float = 48.0
var _dragging: bool = false
var _hovered_axis: int = -1

var _axes := [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
var _cols := [Color(1, 0.25, 0.25), Color(0.25, 1, 0.25), Color(0.25, 0.50, 1)]
var _labels := ["X", "Y", "Z"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = ThemeDB.fallback_font
	_font_size = ThemeDB.fallback_font_size

func _draw() -> void:
	if camera == null:
		return
	_gizmo_center = Vector2(size.x - 70, 70)
	draw_circle(_gizmo_center, _gizmo_radius, Color(0.08, 0.08, 0.14, 0.75))
	draw_arc(_gizmo_center, _gizmo_radius, 0, TAU, 36, Color(0.3, 0.3, 0.4, 0.6), 1.5)
	var inv := camera.global_transform.basis.inverse()
	for i in 3:
		var d: Vector3 = inv * _axes[i]
		var v := Vector2(d.x, -d.y)
		if v.length() < 0.001:
			continue
		v = v.normalized() * _axis_len
		var e := _gizmo_center + v
		var c: Color = _cols[i].lightened(0.3 if _hovered_axis == i else 0.0)
		draw_line(_gizmo_center, e, c, 3.0)
		draw_circle(e, 6, c)
		if _hovered_axis == i:
			draw_circle(e, 8, c * Color(1, 1, 1, 0.3))
		if _font:
			draw_string(_font, e + Vector2(8, -8), _labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, c)

func _gui_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var pos := mm.position
		var dist := pos.distance_to(_gizmo_center)
		if dist <= _gizmo_radius:
			_hovered_axis = _hit_axis(pos)
			queue_redraw()
		elif _hovered_axis >= 0:
			_hovered_axis = -1
			queue_redraw()
		if _dragging:
			view_rotated.emit(-mm.relative.x * 0.3, -mm.relative.y * 0.3)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var pos := mb.position
				if pos.distance_to(_gizmo_center) <= _gizmo_radius:
					var hit := _hit_axis(pos)
					if hit >= 0:
						_snap_to_axis(hit)
						get_viewport().set_input_as_handled()
						return
					_dragging = true
					get_viewport().set_input_as_handled()
			else:
				if _dragging:
					_dragging = false
					get_viewport().set_input_as_handled()

func _hit_axis(pos: Vector2) -> int:
	var inv := camera.global_transform.basis.inverse()
	for i in 3:
		var d: Vector3 = inv * _axes[i]
		var v := Vector2(d.x, -d.y)
		if v.length() < 0.001:
			continue
		v = v.normalized() * _axis_len
		if pos.distance_to(_gizmo_center + v) <= 10.0:
			return i
	return -1

func _snap_to_axis(idx: int) -> void:
	var a: Vector3 = _axes[idx]
	var yaw := rad_to_deg(atan2(a.x, -a.z))
	var pitch := -rad_to_deg(asin(a.y))
	view_snapped.emit(yaw, pitch)
