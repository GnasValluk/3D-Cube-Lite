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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(MAP_SIZE, MAP_SIZE)
	_cache_font = get_theme_default_font()

func _refresh_cache() -> void:
	_explored_cache = _sys.get_explored().duplicate()
	_explored_keys = _explored_cache.keys()
	queue_redraw()

func setup(sys: ExploreSystem) -> void:
	_sys = sys
	_mgr = _sys.get_node("../CharacterManager") as CharacterManager if _sys else null
	_last_version = _sys.get_explore_version()
	_refresh_cache()

func _process(delta: float) -> void:
	if _sys == null: return
	var v := _sys.get_explore_version()
	if v != _last_version:
		_last_version = v
		_refresh_cache()
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
	var cs := ExploreSystem.CELL_SIZE
	var blk := cs * CELL_PX as int
	var off_x := off.x - _player_wx * CELL_PX
	var off_z := off.y - _player_wz * CELL_PX
	for key in _explored_keys:
		var c: Vector2i = key
		var px := c.x * blk + int(off_x)
		var py := c.y * blk + int(off_z)
		if px + blk < 0 or px > MAP_SIZE or py + blk < 0 or py > MAP_SIZE: continue
		var col: Color = _explored_cache[key] as Color
		var mc: float = max(col.r, max(col.g, col.b))
		var boost: float = 1.0 + (1.0 - mc) * 1.8 if mc > 0.01 else 2.5
		col.r = min(col.r * boost, 1.0)
		col.g = min(col.g * boost, 1.0)
		col.b = min(col.b * boost, 1.0)
		draw_rect(Rect2(px, py, blk, blk), col)
	draw_circle(off, PLAYER_RADIUS, Color(1.0, 1.0, 1.0, 0.95))
	draw_line(off, off + Vector2(0, -PLAYER_RADIUS - 4), Color(1.0, 1.0, 1.0, 0.70), 1.5)
	draw_string(_cache_font, Vector2(MAP_SIZE * 0.5 - 3, 14), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.7, 0.7, 0.7, 0.50))
