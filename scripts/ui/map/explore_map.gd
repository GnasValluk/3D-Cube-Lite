## ui/explore_map.gd – Bản đồ khám phá toàn màn hình
extends Control
class_name ExploreMap

const CELL_PX: float = 4.0
const PLAYER_RADIUS: float = 4.0

var _sys: ExploreSystem
var _explored_cache: Dictionary = {}
var _player_wx: float = 0.0
var _player_wz: float = 0.0
var _vp: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var title := Label.new()
	title.text = tr("MAP_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.name = "MapTitle"

func open(sys: ExploreSystem) -> void:
	_sys = sys
	_explored_cache = _sys.get_explored().duplicate()
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	_sys = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if visible:
			queue_redraw()

func _process(delta: float) -> void:
	if not visible or _sys == null:
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
	_vp = get_viewport().get_visible_rect().size

	draw_rect(Rect2(Vector2.ZERO, _vp), Color(0.0, 0.0, 0.0, 0.80))

	var title_lbl := get_node("MapTitle") as Label
	if title_lbl:
		title_lbl.position = Vector2(_vp.x * 0.5 - 55.0, 8.0)
		title_lbl.size = Vector2(110, 32)

	var offset := _vp * 0.5
	var cell_w: float = ExploreSystem.CELL_SIZE * CELL_PX

	for cell_key in _explored_cache.keys():
		var cell: Vector2i = cell_key
		var wx: float = (cell.x + 0.5) * ExploreSystem.CELL_SIZE
		var wz: float = (cell.y + 0.5) * ExploreSystem.CELL_SIZE
		var sx: float = offset.x + (wx - _player_wx) * CELL_PX - cell_w * 0.5
		var sy: float = offset.y + (wz - _player_wz) * CELL_PX - cell_w * 0.5
		if sx + cell_w < 0 or sx > _vp.x or sy + cell_w < 0 or sy > _vp.y:
			continue
		var col: Color = _explored_cache[cell_key] as Color
		col.r = min(col.r * 2.5, 1.0)
		col.g = min(col.g * 2.5, 1.0)
		col.b = min(col.b * 2.5, 1.0)
		draw_rect(Rect2(sx, sy, cell_w, cell_w), col)

	draw_circle(offset, PLAYER_RADIUS, Color(1.0, 1.0, 1.0, 0.95))
