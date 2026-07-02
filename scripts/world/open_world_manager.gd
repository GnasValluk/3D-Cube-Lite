extends Node3D
class_name OpenWorldManager

const CHUNK_SIZE: int = 32
const VIEW_RADIUS: int = 2
const PRELOAD_RADIUS: int = 4
const MAX_LOADING_PER_FRAME: int = 8

const _Dim = preload("res://scripts/world/dimension_defs.gd")

@export var dimension_id: int = _Dim.DimensionID.TWILIGHT

var dimension_name: String = ""

var _chunks: Dictionary = {}
var _loading: Dictionary = {}
var _player: Node3D = null
var _last_chunk: Vector2i = Vector2i(99999, 99999)
var _last_pos: Vector3 = Vector3(99999, 99999, 99999)
var _pending: Array[Vector2i] = []

var _initial_generated: bool = false

func _ready() -> void:
	dimension_name = tr(_Dim.DIM_NAME_KEY.get(dimension_id, ""))
	WorldChunk._noise_for_dim(dimension_id)
	WorldChunk._noise_for_dim(_Dim.DimensionID.TWILIGHT)
	WorldChunk._noise_for_dim(_Dim.DimensionID.REAL_WORLD)

func _find_player() -> void:
	var mgr := get_node("../CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()
	else:
		_player = get_node_or_null("Player")

func _generate_all_initial() -> void:
	if not _player:
		return
	var cx: int = int(floor(_player.global_position.x / CHUNK_SIZE))
	var cz: int = int(floor(_player.global_position.z / CHUNK_SIZE))
	_last_chunk = Vector2i(cx, cz)

	# Center chunk sync — player needs ground collision immediately
	_start_loading(Vector2i(cx, cz), true)

	for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
		for dz in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if key != Vector2i(cx, cz) and not _loading.has(key) and not _chunks.has(key):
				_pending.append(key)
	_pending.sort_custom(_sort_chunks)

	# Submit first batch immediately so nearby chunks appear next frame
	var to_submit: int = mini(MAX_LOADING_PER_FRAME, _pending.size())
	for _i in range(to_submit):
		var key: Vector2i = _pending.pop_front()
		if not _chunks.has(key) and not _loading.has(key):
			_start_loading(key, false)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_find_player()
		return

	var ppos := _player.global_position

	# Promote completed async chunks
	for ck in _loading.keys().duplicate():
		var chunk: WorldChunk = _loading[ck] as WorldChunk
		if chunk._built:
			_loading.erase(ck)
			_chunks[ck] = chunk

	if not _initial_generated:
		_initial_generated = true
		_generate_all_initial()
		_last_pos = ppos
		return

	var cx: int = int(floor(ppos.x / CHUNK_SIZE))
	var cz: int = int(floor(ppos.z / CHUNK_SIZE))
	var cur := Vector2i(cx, cz)

	var dist_moved := ppos.distance_squared_to(_last_pos)
	if dist_moved < 0.25 and _pending.is_empty() and cur == _last_chunk:
		return

	_last_pos = ppos

	if cur != _last_chunk:
		_last_chunk = cur
		var keep: Array[Vector2i] = []
		for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			for dz in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
				keep.append(Vector2i(cx + dx, cz + dz))

		for key in _chunks.keys().duplicate():
			if not key in keep:
				_chunks[key].queue_free()
				_chunks.erase(key)
		for key in _loading.keys().duplicate():
			if not key in keep:
				var ck_pending: String = "%d,%d,%d" % [key.x, key.y, dimension_id]
				WorldChunk._pending_chunks.erase(ck_pending)
				_loading[key].queue_free()
				_loading.erase(key)

		_pending = []
		for key in keep:
			if not _chunks.has(key) and not _loading.has(key):
				_pending.append(key)
		_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := (a - cur).length_squared()
			var db := (b - cur).length_squared()
			return da < db)

	var to_submit: int = mini(MAX_LOADING_PER_FRAME, _pending.size())
	for _i in range(to_submit):
		var key: Vector2i = _pending.pop_front()
		if not _chunks.has(key) and not _loading.has(key):
			_start_loading(key, false)

func _start_loading(key: Vector2i, sync: bool) -> void:
	var chunk := WorldChunk.new()
	chunk.position = Vector3(key.x * CHUNK_SIZE, 0.0, key.y * CHUNK_SIZE)
	chunk.setup(key.x, key.y, CHUNK_SIZE, dimension_id, sync)
	add_child(chunk)
	_loading[key] = chunk
	if sync and chunk._built:
		_loading.erase(key)
		_chunks[key] = chunk

func _sort_chunks(a: Vector2i, b: Vector2i) -> bool:
	var da := (a - _last_chunk).length_squared()
	var db := (b - _last_chunk).length_squared()
	return da < db

func _spawn_return_portal() -> void:
	var portal := PortalGate.new()
	portal.name = "PortalGate"
	if dimension_id == _Dim.DimensionID.TWILIGHT:
		portal.dest_dimension = _Dim.DimensionID.REAL_WORLD
	else:
		portal.dest_dimension = _Dim.DimensionID.TWILIGHT
	add_child(portal)
	portal.position = Vector3(0, 0.25, 0)

func is_in_water(wx: float, wz: float, wy: float) -> bool:
	var half: float = CHUNK_SIZE * 0.5
	var cx: int = int(floor((wx + half) / CHUNK_SIZE))
	var cz: int = int(floor((wz + half) / CHUNK_SIZE))
	var key := Vector2i(cx, cz)
	if not _chunks.has(key):
		return false
	return _chunks[key].is_water_at(wx, wz, wy)
