extends Node3D
class_name OpenWorldManager

const CHUNK_SIZE: int = 32
const VIEW_RADIUS: int = 3
const PRELOAD_RADIUS: int = 3
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
var _loading_ready: bool = false
var _total_initial: int = 0
var _loaded_initial: int = 0

signal initial_chunks_ready

func _ready() -> void:
	dimension_name = tr(_Dim.DIM_NAME_KEY.get(dimension_id, ""))

	WorldChunk.clear_noise_cache()
	WorldChunk._noise_for_dim(dimension_id)
	WorldChunk._noise_for_dim(_Dim.DimensionID.TWILIGHT)
	WorldChunk._noise_for_dim(_Dim.DimensionID.REAL_WORLD)

	# Generate center chunk synchronously để có ground ngay frame đầu.
	# Khi load lại hành trình: center = chunk chứa điểm đứng đã lưu, spawn
	# thẳng tại đó (không sinh vùng (0,0) rồi teleport → gây lag double-gen).
	var cx := 0
	var cz := 0
	if WorldSeed.is_loading and WorldSeed.has_saved_player_pos:
		cx = int(floor(WorldSeed.saved_player_pos.x / CHUNK_SIZE))
		cz = int(floor(WorldSeed.saved_player_pos.z / CHUNK_SIZE))
	_last_chunk = Vector2i(cx, cz)
	# Count all chunks first before any loading
	_total_initial = 1  # center chunk
	for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
		for dz in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if key != Vector2i(cx, cz):
				_total_initial += 1

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
	_check_initial_ready()

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
	var cx: int = int(floor(ppos.x / CHUNK_SIZE))
	var cz: int = int(floor(ppos.z / CHUNK_SIZE))
	var cur := Vector2i(cx, cz)

	# Promote completed async chunks — theo NGÂN SÁCH THỜI GIAN/frame thay vì
	# cố định 1 chunk/frame. Chunk nào tính xong trên worker (cheap sau khi đưa
	# shaped-block scan sang worker) được apply nhiều chunk trong cùng frame nếu
	# còn dư budget → thế giới hiện nhanh hơn; khi gặp chunk nặng (nhiều cỏ/
	# nước) tự giới hạn lại, không gây spike vượt 1 frame.
	const PROMOTION_BUDGET_US: int = 15000
	var budget_t0 := Time.get_ticks_usec()
	var candidates: Array = []
	for ck in _loading.keys():
		var chunk: WorldChunk = _loading[ck] as WorldChunk
		if chunk != null and (chunk._built or not chunk._pending_data.is_empty()):
			candidates.append(ck)
	if candidates.size() > 1:
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := (a - cur).length_squared()
			var db := (b - cur).length_squared()
			return da < db)
	for ck in candidates:
		if Time.get_ticks_usec() - budget_t0 >= PROMOTION_BUDGET_US:
			break
		var chunk: WorldChunk = _loading[ck] as WorldChunk
		if chunk == null or not (chunk._built or not chunk._pending_data.is_empty()):
			continue
		if not chunk._pending_data.is_empty():
			chunk.apply_chunk(chunk._pending_data)
			chunk._pending_data = {}
		_loading.erase(ck)
		_chunks[ck] = chunk
		if SaveManager:
			SaveManager.apply_block_modifications_for_chunk(chunk, ck.x, ck.y)
		chunk.refresh_boundary_water()
		_check_initial_ready()

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
		chunk.refresh_boundary_water()

func _check_initial_ready() -> void:
	if _loading_ready or _total_initial == 0: return
	_loaded_initial = 0
	for key in _chunks:
		if _chunks[key]._built:
			_loaded_initial += 1
	for key in _loading:
		if _loading[key]._built:
			_loaded_initial += 1
	if _loaded_initial >= _total_initial:
		_loading_ready = true
		initial_chunks_ready.emit()

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

## Cuốc đất tại vị trí world. Trả về block cũ đã cuốc (0 = không cuốc được).
func till_block(wx: float, wy: float, wz: float) -> int:
	var chunk := get_chunk_at(wx, wz)
	if chunk == null: return 0
	return chunk.till_block_at(wx, wy, wz)

## Lấy block ID tại vị trí world.
func get_block(wx: float, wy: float, wz: float) -> int:
	var chunk := get_chunk_at(wx, wz)
	if chunk == null: return 0
	if chunk.block_data == null: return 0
	var blk := chunk.world_to_local_block(wx, wy, wz)
	return chunk.block_data.get_block(blk.x, blk.y, blk.z)
