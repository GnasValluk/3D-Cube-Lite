extends Node3D
class_name OpenWorldManager

const CHUNK_SIZE: int = 32
const VIEW_RADIUS: int = 2
const PRELOAD_RADIUS: int = 2
const MAX_LOADING_PER_FRAME: int = 1

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
	# Xóa noise cache để buộc rebuild với frequency mới nhất từ chunk_data.gd
	WorldChunk.clear_noise_cache()
	WorldChunk._noise_for_dim(dimension_id)
	WorldChunk._noise_for_dim(_Dim.DimensionID.TWILIGHT)
	WorldChunk._noise_for_dim(_Dim.DimensionID.REAL_WORLD)

	# Generate center chunk immediately so ground collision exists
	# before any physics frame runs (player spawns at (0,3,0) → chunk (0,0))
	var cx := 0
	var cz := 0
	_last_chunk = Vector2i(cx, cz)
	_start_loading(Vector2i(cx, cz), true)

	for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
		for dz in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if key != Vector2i(cx, cz) and not _loading.has(key) and not _chunks.has(key):
				_pending.append(key)
	_pending.sort_custom(_sort_chunks)

	var to_submit: int = mini(MAX_LOADING_PER_FRAME, _pending.size())
	for _i in range(to_submit):
		var key: Vector2i = _pending.pop_front()
		if not _chunks.has(key) and not _loading.has(key):
			_start_loading(key, false)

	_initial_generated = true

func _find_player() -> void:
	var mgr := get_node("../CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()
	else:
		_player = get_node_or_null("Player")

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_find_player()
		return

	var ppos := _player.global_position

	# Promote completed async chunks — tối đa 1 chunk/frame để tránh spike
	var promoted: int = 0
	for ck in _loading.keys():
		if promoted >= 1:
			break
		var chunk: WorldChunk = _loading[ck] as WorldChunk
		if chunk._built:
			_loading.erase(ck)
			_chunks[ck] = chunk
			if SaveManager:
				SaveManager.apply_block_modifications_for_chunk(chunk, ck.x, ck.y)
			promoted += 1

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

		for key in _chunks.keys():
			if not key in keep:
				_chunks[key].queue_free()
				_chunks.erase(key)
		for key in _loading.keys():
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
		if SaveManager:
			SaveManager.apply_block_modifications_for_chunk(chunk, key.x, key.y)

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

## ── Block API (Minecraft-style) ───────────────────────────────────────────────
func get_chunk_at(wx: float, wz: float) -> WorldChunk:
	var half: float = CHUNK_SIZE * 0.5
	var cx: int = int(floor((wx + half) / CHUNK_SIZE))
	var cz: int = int(floor((wz + half) / CHUNK_SIZE))
	var key := Vector2i(cx, cz)
	return _chunks.get(key, null) as WorldChunk

## Phá block tại vị trí world. Trả về block_id đã phá (0 = không có gì).
func break_block(wx: float, wy: float, wz: float) -> int:
	var chunk := get_chunk_at(wx, wz)
	if chunk == null: return 0
	return chunk.break_block_at(wx, wy, wz)

## Đặt block tại vị trí world. Trả về true nếu thành công.
func place_block(wx: float, wy: float, wz: float, block_id: int) -> bool:
	var chunk := get_chunk_at(wx, wz)
	if chunk == null: return false
	return chunk.place_block_at(wx, wy, wz, block_id)

## Lấy block ID tại vị trí world.
func get_block(wx: float, wy: float, wz: float) -> int:
	var chunk := get_chunk_at(wx, wz)
	if chunk == null: return 0
	if chunk.block_data == null: return 0
	var blk := chunk.world_to_local_block(wx, wy, wz)
	return chunk.block_data.get_block(blk.x, blk.y, blk.z)
