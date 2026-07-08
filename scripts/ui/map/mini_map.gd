## ui/mini_map.gd – Mini-map góc màn hình
extends Control
class_name MiniMap

const MAP_SIZE: float = 150.0
const CELL_PX: float = 3.0
const PLAYER_RADIUS: float = 3.0
const REDRAW_COOLDOWN: float = 0.15

var _sys: ExploreSystem
var _explored_cache: Dictionary = {}
var _explored_keys: Array = []
var _player_wx: float = 0.0
var _player_wz: float = 0.0
var _redraw_timer: float = 0.0
var _mgr: CharacterManager = null
var _cache_font: Font = null
var _last_version: int = -1

var _tex: ImageTexture = null
var _img: Image = null
var _origin_x: float = 0.0
var _origin_z: float = 0.0
var _tex_scale: float = CELL_PX

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(MAP_SIZE, MAP_SIZE)
	_cache_font = get_theme_default_font()

func setup(sys: ExploreSystem) -> void:
	_sys = sys
	_mgr = _sys.get_node("../CharacterManager") as CharacterManager if _sys else null
	_last_version = _sys.get_explore_version()
	_explored_cache = _sys.get_explored().duplicate()
	_explored_keys = _explored_cache.keys()
	_rebuild_tex()

func _rebuild_tex() -> void:
	if _explored_cache.is_empty():
		return
	var min_x := 999999; var max_x := -999999
	var min_z := 999999; var max_z := -999999
	for key in _explored_keys:
		var c: Vector2i = key
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
		if c.y < min_z: min_z = c.y
		if c.y > max_z: max_z = c.y
	var cs := ExploreSystem.CELL_SIZE
	var pad := 1
	var w_u := (max_x - min_x + 1 + pad * 2) * cs
	var h_u := (max_z - min_z + 1 + pad * 2) * cs
	var blk := cs * _tex_scale as int
	var tw := w_u * _tex_scale as int
	var th := h_u * _tex_scale as int
	tw = maxi(tw, 1); th = maxi(th, 1)
	_origin_x = (min_x - pad) * cs
	_origin_z = (min_z - pad) * cs
	if _img == null or _img.get_size() != Vector2i(tw, th):
		_img = Image.create(tw, th, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	for key in _explored_keys:
		var c: Vector2i = key
		var px := (c.x * cs - _origin_x) * _tex_scale as int
		var py := (c.y * cs - _origin_z) * _tex_scale as int
		if px < 0 or py < 0 or px + blk > tw or py + blk > th: continue
		var col: Color = _explored_cache[key] as Color
		col.r = min(col.r * 2.5, 1.0)
		col.g = min(col.g * 2.5, 1.0)
		col.b = min(col.b * 2.5, 1.0)
		_img.fill_rect(Rect2i(px, py, blk, blk), col)
	if _tex and _img.get_size() == Vector2i(_tex.get_size()):
		_tex.update(_img)
	else:
		_tex = ImageTexture.create_from_image(_img)

func _process(delta: float) -> void:
	if _sys == null: return
	var v := _sys.get_explore_version()
	if v != _last_version:
		_last_version = v
		_explored_cache = _sys.get_explored().duplicate()
		_explored_keys = _explored_cache.keys()
		_rebuild_tex()
	_redraw_timer -= delta
	if _redraw_timer > 0: return
	if _mgr == null: return
	var ch := _mgr.get_current_character()
	if ch:
		var pw := ch.global_position.x
		var pz := ch.global_position.z
		if abs(pw - _player_wx) > 0.5 or abs(pz - _player_wz) > 0.5:
			_player_wx = pw
			_player_wz = pz
			_redraw_timer = REDRAW_COOLDOWN
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.70))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.50, 0.70, 0.60), false, 2.0)

	var off := size * 0.5
	if _tex:
		var w_min_x := (0.0 - off.x) / _tex_scale + _player_wx
		var w_max_x := (MAP_SIZE - off.x) / _tex_scale + _player_wx
		var w_min_z := (0.0 - off.y) / _tex_scale + _player_wz
		var w_max_z := (MAP_SIZE - off.y) / _tex_scale + _player_wz
		var rx := (w_min_x - _origin_x) * _tex_scale
		var ry := (w_min_z - _origin_z) * _tex_scale
		var rw := (w_max_x - w_min_x) * _tex_scale
		var rh := (w_max_z - w_min_z) * _tex_scale
		draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, size), Rect2(rx, ry, rw, rh))
	draw_circle(off, PLAYER_RADIUS, Color(1.0, 1.0, 1.0, 0.95))
	draw_line(off, off + Vector2(0, -PLAYER_RADIUS - 4), Color(1.0, 1.0, 1.0, 0.70), 1.5)
	draw_string(_cache_font, Vector2(MAP_SIZE * 0.5 - 3, 14), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.7, 0.7, 0.7, 0.50))
