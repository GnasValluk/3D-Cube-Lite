## ui/mini_map.gd – Mini-map góc màn hình
extends Control
class_name MiniMap

const MAP_SIZE: float = 150.0
const CELL_PX: float = 3.0
const PLAYER_RADIUS: float = 3.0

var _sys: ExploreSystem
var _explored_cache: Dictionary = {}
var _player_wx: float = 0.0
var _player_wz: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(MAP_SIZE, MAP_SIZE)

func setup(sys: ExploreSystem) -> void:
	_sys = sys
	_explored_cache = _sys.get_explored().duplicate()

func _process(delta: float) -> void:
	if _sys == null:
		return
	if _sys.is_dirty():
		_explored_cache = _sys.get_explored().duplicate()
		queue_redraw()

	var mgr := _sys.get_node("../CharacterManager") as CharacterManager
	if mgr:
		var ch := mgr.get_current_character()
		if ch:
			var pw := ch.global_position.x
			var pz := ch.global_position.z
			if abs(pw - _player_wx) > 0.01 or abs(pz - _player_wz) > 0.01:
				_player_wx = pw
				_player_wz = pz
				queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.70))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.50, 0.70, 0.60), false, 2.0)

	var offset := size * 0.5

	var cell_w: float = ExploreSystem.CELL_SIZE * CELL_PX
	for cell_key in _explored_cache.keys():
		var cell: Vector2i = cell_key
		var wx: float = (cell.x + 0.5) * ExploreSystem.CELL_SIZE
		var wz: float = (cell.y + 0.5) * ExploreSystem.CELL_SIZE
		var sx: float = offset.x + (wx - _player_wx) * CELL_PX - cell_w * 0.5
		var sy: float = offset.y + (wz - _player_wz) * CELL_PX - cell_w * 0.5
		if sx + cell_w < 0 or sx > MAP_SIZE or sy + cell_w < 0 or sy > MAP_SIZE:
			continue
		var col: Color = _explored_cache[cell_key] as Color
		col.r = min(col.r * 2.5, 1.0)
		col.g = min(col.g * 2.5, 1.0)
		col.b = min(col.b * 2.5, 1.0)
		draw_rect(Rect2(sx, sy, cell_w, cell_w), col)

	draw_circle(offset, PLAYER_RADIUS, Color(1.0, 1.0, 1.0, 0.95))
