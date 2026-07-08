## ui/explore_map.gd – Bản đồ toàn màn hình (JourneyMap-style)
extends Control
class_name ExploreMap

const CELL_PX_BASE: float = 4.0
const PLAYER_RADIUS: float = 4.0
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 8.0
const CHUNK_SIZE: int = 32
const REDRAW_DELAY: float = 0.1

var _sys: ExploreSystem
var _explored_cache: Dictionary = {}
var _explored_keys: Array = []
var _player_wx: float = 0.0
var _player_wz: float = 0.0
var _vp: Vector2 = Vector2.ZERO

var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO
var _touch_drag_idx: int = -1

var _waypoints: Array[Dictionary] = []
var _mouse_wx: float = 0.0
var _mouse_wz: float = 0.0
var _show_coords: bool = false
var _show_grid: bool = false
var _dark_mode: bool = false

var _mgr: CharacterManager = null
var _redraw_pending: bool = false

var _node_coord: Label = null
var _node_help: Label = null
var _node_title: Label = null
var _node_death: Label = null
var _node_toolbar: Control = null
var _cache_font: Font = null
var _last_version: int = -1

var _map_texture: ImageTexture = null
var _map_image: Image = null
var _map_origin_x: float = 0.0
var _map_origin_z: float = 0.0
var _tex_scale: float = CELL_PX_BASE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	_node_title = Label.new()
	_node_title.text = tr("MAP_TITLE")
	_node_title.add_theme_font_size_override("font_size", 24)
	_node_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_node_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_title)

	_node_death = Label.new()
	_node_death.text = ""
	_node_death.add_theme_font_size_override("font_size", 12)
	_node_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_death)

	_node_help = Label.new()
	_node_help.text = ""
	_node_help.add_theme_font_size_override("font_size", 11)
	_node_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_help)

	_node_coord = Label.new()
	_node_coord.text = ""
	_node_coord.add_theme_font_size_override("font_size", 14)
	_node_coord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_coord)

	_cache_font = get_theme_default_font()
	_build_toolbar()

func _build_toolbar() -> void:
	_node_toolbar = Control.new()
	_node_toolbar.name = "Toolbar"
	_node_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_node_toolbar)
	var tools := [
		["✕", Color(0.80, 0.20, 0.20), "_on_close"],
		["+", Color(0.25, 0.55, 0.85), "_on_zoom_in"],
		["−", Color(0.25, 0.55, 0.85), "_on_zoom_out"],
		["⟲", Color(0.50, 0.50, 0.50), "_on_reset"],
		["Grid", Color(0.35, 0.45, 0.55), "_on_toggle_grid"],
		["☽", Color(0.40, 0.35, 0.55), "_on_toggle_dark"],
	]
	var idx: int = 0
	for t in tools:
		var btn := Button.new()
		btn.text = t[0]
		btn.name = "TB" + str(idx)
		btn.toggle_mode = (idx >= 4)
		btn.size = Vector2(40, 32)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(1,1,1,0.95))
		var sty := StyleBoxFlat.new()
		sty.bg_color = t[1]
		sty.corner_radius_top_left = 4; sty.corner_radius_top_right = 4
		sty.corner_radius_bottom_left = 4; sty.corner_radius_bottom_right = 4
		sty.border_width_left = 1; sty.border_width_right = 1
		sty.border_width_top = 1; sty.border_width_bottom = 1
		sty.border_color = Color(1,1,1,0.15)
		btn.add_theme_stylebox_override("normal", sty)
		var sty_p := sty.duplicate() as StyleBoxFlat
		sty_p.bg_color = Color(t[1].r * 1.4, t[1].g * 1.4, t[1].b * 1.4, t[1].a)
		btn.add_theme_stylebox_override("pressed", sty_p)
		btn.add_theme_stylebox_override("hover", sty)
		btn.pressed.connect(_on_toolbar_pressed.bind(idx, StringName(t[2])))
		_node_toolbar.add_child(btn)
		idx += 1

func _on_toolbar_pressed(_idx: int, method: StringName) -> void:
	call(method)

func _on_close() -> void: close()
func _on_zoom_in() -> void: _zoom = clampf(_zoom * 1.5, MIN_ZOOM, MAX_ZOOM); queue_redraw()
func _on_zoom_out() -> void: _zoom = clampf(_zoom / 1.5, MIN_ZOOM, MAX_ZOOM); queue_redraw()
func _on_reset() -> void: _zoom = 1.0; _pan_offset = Vector2.ZERO; queue_redraw()
func _on_toggle_grid() -> void: _show_grid = not _show_grid; queue_redraw()
func _on_toggle_dark() -> void: _dark_mode = not _dark_mode; queue_redraw()

func _rebuild_texture() -> void:
	if _explored_cache.is_empty():
		return
	var min_cx: int = 999999; var max_cx: int = -999999
	var min_cz: int = 999999; var max_cz: int = -999999
	for key in _explored_keys:
		var cell: Vector2i = key
		if cell.x < min_cx: min_cx = cell.x
		if cell.x > max_cx: max_cx = cell.x
		if cell.y < min_cz: min_cz = cell.y
		if cell.y > max_cz: max_cz = cell.y
	var cs: float = ExploreSystem.CELL_SIZE
	var pw: int = 1
	var tw: float = (max_cx - min_cx + 1 + pw * 2) * cs
	var th: float = (max_cz - min_cz + 1 + pw * 2) * cs
	var cell_block: int = (cs * _tex_scale) as int
	var tex_w: int = maxi((tw * _tex_scale) as int, 1)
	var tex_h: int = maxi((th * _tex_scale) as int, 1)
	_map_origin_x = (min_cx - pw) * cs
	_map_origin_z = (min_cz - pw) * cs
	if _map_image == null or _map_image.get_size() != Vector2i(tex_w, tex_h):
		_map_image = Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
		if _map_texture:
			_map_texture = null
	_map_image.fill(Color(0, 0, 0, 0))
	for key in _explored_keys:
		var cell: Vector2i = key
		var px: int = ((cell.x * cs) - _map_origin_x) * _tex_scale as int
		var py: int = ((cell.y * cs) - _map_origin_z) * _tex_scale as int
		if px < 0 or py < 0 or px + cell_block > tex_w or py + cell_block > tex_h: continue
		var col: Color = _explored_cache[key] as Color
		col.r = min(col.r * 2.5, 1.0)
		col.g = min(col.g * 2.5, 1.0)
		col.b = min(col.b * 2.5, 1.0)
		_map_image.fill_rect(Rect2i(px, py, cell_block, cell_block), col)
	if _map_texture and _map_image.get_size() == Vector2i(_map_texture.get_size()):
		_map_texture.update(_map_image)
	else:
		_map_texture = ImageTexture.create_from_image(_map_image)

func open(sys: ExploreSystem) -> void:
	_sys = sys
	_last_version = _sys.get_explore_version()
	_explored_cache = _sys.get_explored().duplicate()
	_explored_keys = _explored_cache.keys()
	_mgr = _sys.get_node("../CharacterManager") as CharacterManager if _sys else null
	_zoom = 1.0; _pan_offset = Vector2.ZERO; _waypoints.clear()
	_redraw_pending = false; _rebuild_texture()
	visible = true; _layout(); queue_redraw()

func close() -> void:
	visible = false; _sys = null; _mgr = null; _redraw_pending = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_layout(); queue_redraw()

func _layout() -> void:
	_vp = size
	if _node_title:
		_node_title.position = Vector2(_vp.x * 0.5 - 55.0, 8)
		_node_title.size = Vector2(110, 32)
	if _node_toolbar:
		var bsz := 40.0; var pad := 8.0
		var total_w := 6 * bsz + 5 * pad
		_node_toolbar.position = Vector2((_vp.x - total_w) * 0.5, _vp.y - bsz - pad)
		_node_toolbar.size = Vector2(total_w, bsz + pad)
		for i in 6:
			var btn := _node_toolbar.get_node("TB" + str(i)) as Button
			if btn: btn.position = Vector2(i * (bsz + pad), pad)
	if _node_death: _node_death.position = Vector2(12, 42); _node_death.size = Vector2(200, 20)
	if _node_coord: _node_coord.position = Vector2(12, _vp.y - 60); _node_coord.size = Vector2(200, 22)
	if _node_help: _node_help.position = Vector2(12, _vp.y - 20); _node_help.size = Vector2(_vp.x - 24, 18)

func _process(delta: float) -> void:
	if not visible or _sys == null: return
	var v := _sys.get_explore_version()
	if v != _last_version:
		_last_version = v
		_explored_cache = _sys.get_explored().duplicate()
		_explored_keys = _explored_cache.keys()
		_rebuild_texture()
	if not _redraw_pending: return
	_redraw_pending = false
	if _mgr == null: return
	var ch := _mgr.get_current_character()
	if ch:
		_player_wx = ch.global_position.x
		_player_wz = ch.global_position.z
		queue_redraw()

func _draw_throttle() -> void: _redraw_pending = true

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_G:
			_on_toggle_grid()
			if _node_toolbar:
				var btn := _node_toolbar.get_node("TB4") as Button
				if btn: btn.button_pressed = _show_grid
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.2, MIN_ZOOM, MAX_ZOOM); queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.2, MIN_ZOOM, MAX_ZOOM); queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed: _dragging = true; _drag_start = mb.position; _drag_offset = _pan_offset
			elif _dragging and _drag_start.distance_to(mb.position) < 5.0: _add_waypoint_at(mb.position); _dragging = false
			else: _dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed: _remove_waypoint_at(mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed: _zoom = 1.0; _pan_offset = Vector2.ZERO; queue_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging: _pan_offset = _drag_offset + mm.position - _drag_start; _draw_throttle()
		_mouse_wx = _screen_to_world(mm.position).x; _mouse_wz = _screen_to_world(mm.position).y; _show_coords = true
		if _node_coord: _node_coord.text = "X: %.0f  Z: %.0f" % [_mouse_wx, _mouse_wz]
	elif event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed: _dragging = true; _drag_start = e.position; _drag_offset = _pan_offset; _touch_drag_idx = e.index
		elif _dragging and _touch_drag_idx == e.index:
			if _drag_start.distance_to(e.position) < 10.0: _add_waypoint_at(e.position)
			_dragging = false; _touch_drag_idx = -1
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _dragging and e.index == _touch_drag_idx: _pan_offset = _drag_offset + e.position - _drag_start; _draw_throttle()

func _screen_to_world(screen: Vector2) -> Vector2:
	var off := (_vp - _pan_offset) * 0.5
	var inv := 1.0 / (_zoom * CELL_PX_BASE)
	return Vector2((screen.x - off.x) * inv + _player_wx, (screen.y - off.y) * inv + _player_wz)

func _world_to_screen(wx: float, wz: float) -> Vector2:
	var off := (_vp - _pan_offset) * 0.5
	var s := _zoom * CELL_PX_BASE
	return Vector2(off.x + (wx - _player_wx) * s, off.y + (wz - _player_wz) * s)

func _add_waypoint_at(screen: Vector2) -> void:
	var w := _screen_to_world(screen)
	_waypoints.append({ "wx": w.x, "wz": w.y })
	queue_redraw()

func _remove_waypoint_at(screen: Vector2) -> void:
	var best := -1; var best_dist := 20.0
	for i in _waypoints.size():
		var ws := _world_to_screen(_waypoints[i].wx, _waypoints[i].wz)
		var d := ws.distance_to(screen)
		if d < best_dist: best_dist = d; best = i
	if best >= 0: _waypoints.remove_at(best); queue_redraw()

func _draw() -> void:
	_vp = size
	var bg := Color(0.0, 0.0, 0.0, 0.85)
	if _dark_mode: bg = Color(0.02, 0.02, 0.06, 0.90)
	draw_rect(Rect2(Vector2.ZERO, _vp), bg)

	if _map_texture:
		var cp := _zoom * _tex_scale
		var o := (_vp - _pan_offset) * 0.5
		var w_min_x := (0.0 - o.x) / cp + _player_wx
		var w_max_x := (_vp.x - o.x) / cp + _player_wx
		var w_min_z := (0.0 - o.y) / cp + _player_wz
		var w_max_z := (_vp.y - o.y) / cp + _player_wz
		var rx := (w_min_x - _map_origin_x) * _tex_scale
		var ry := (w_min_z - _map_origin_z) * _tex_scale
		var rw := (w_max_x - w_min_x) * _tex_scale
		var rh := (w_max_z - w_min_z) * _tex_scale
		if _dark_mode:
			draw_texture_rect_region(_map_texture, Rect2(Vector2.ZERO, _vp), Rect2(rx, ry, rw, rh), Color(0.35, 0.35, 0.55, 1.0))
		else:
			draw_texture_rect_region(_map_texture, Rect2(Vector2.ZERO, _vp), Rect2(rx, ry, rw, rh))

	var po := _vp * 0.5 - _pan_offset * 0.5
	draw_circle(po, PLAYER_RADIUS, Color(1.0, 1.0, 1.0, 0.95))
	draw_line(po, po + Vector2(0, -PLAYER_RADIUS - 6), Color(1.0, 1.0, 1.0, 0.80), 2.0)

	for wp in _waypoints:
		var ws := _world_to_screen(wp.wx, wp.wz)
		draw_circle(ws, 6.0, Color(1.0, 0.84, 0.0))
		draw_circle(ws, 4.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(ws, 2.0, Color(1.0, 0.84, 0.0))
		var d := Vector2(wp.wx - _player_wx, wp.wz - _player_wz).length()
		draw_string(_cache_font, ws + Vector2(10, -4), "WP (%.0fm)" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,1,0.85))

	if _show_grid:
		var cs: float = ExploreSystem.CELL_SIZE
		var px_per: float = _zoom * _tex_scale / cs
		var step: float = CHUNK_SIZE
		while step * px_per < 40.0: step *= 2
		var po2: Vector2 = (_vp - _pan_offset) * 0.5
		var gx0: float = floor((_player_wx - _vp.x * 0.5 / px_per) / step) * step
		var gx_e: float = _player_wx + _vp.x * 0.5 / px_per
		var gz0: float = floor((_player_wz - _vp.y * 0.5 / px_per) / step) * step
		var gz_e: float = _player_wz + _vp.y * 0.5 / px_per
		var cp2: float = _zoom * _tex_scale
		var gx: float = gx0
		while gx < gx_e:
			var sx2: float = po2.x + (gx - _player_wx) * cp2
			draw_line(Vector2(sx2, 0), Vector2(sx2, _vp.y), Color(1,1,1,0.10), 1.0)
			gx += step
		var gz: float = gz0
		while gz < gz_e:
			var sy2: float = po2.y + (gz - _player_wz) * cp2
			draw_line(Vector2(0, sy2), Vector2(_vp.x, sy2), Color(1,1,1,0.10), 1.0)
			gx = gx0
			while gx < gx_e:
				if int(floor(gx / step)) % 2 == 0 and int(floor(gz / step)) % 2 == 0:
					draw_rect(Rect2(po2.x + (gx - _player_wx) * cp2, sy2, step * px_per, step * px_per), Color(1,1,1,0.06))
				gx += step
			gz += step

	if _node_coord and _show_coords:
		_node_coord.text = "X: %.0f  Z: %.0f" % [_mouse_wx, _mouse_wz]

	draw_circle(Vector2(_vp.x - 40, 40), 14, Color(0,0,0,0.5))
	draw_circle(Vector2(_vp.x - 40, 40), 14, Color(1,1,1,0.3), false, 1.0)
	draw_line(Vector2(_vp.x - 40, 40) + Vector2(0, -10), Vector2(_vp.x - 40, 40) + Vector2(0, 10), Color(0.8,0.2,0.2,0.7), 1.5)
	draw_line(Vector2(_vp.x - 40, 40) + Vector2(-10, 0), Vector2(_vp.x - 40, 40) + Vector2(10, 0), Color(0.7,0.7,0.7,0.5), 1.0)

	if _node_help: _node_help.text = "Drag: Pan  |  Left-click: Waypoint  |  Right-click: Remove  |  Wheel: Zoom  |  G: Grid"
