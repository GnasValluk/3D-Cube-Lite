extends Node3D
class_name OpenWorldManager

const CHUNK_SIZE: int = 32
const VIEW_RADIUS: int = 3
const PRELOAD_RADIUS: int = 3
const MAX_LOADING_PER_FRAME: int = 1

const _Dim = preload("res://scripts/world/dimension_defs.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

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

## ── Fade dưới lòng đất (x-ray) ─────────────────────────────────────────────
var _fade_active: bool = false

## ── Occlude fade — làm mờ block che khuất player từ camera iso ──────────────
var _occlude_chunks: Array[WorldChunk] = []  # chunk đang được làm mờ
var _occlude_timer: float = 0.0              # throttle ray-AABB mỗi 0.1s
const _OCCLUDE_INTERVAL: float = 0.10        # giây giữa các lần tính chunk

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

## ── X-ray khi xuống hang: kiểm tra player có "mái che" (solid phía trên) không
## Ngưỡng: tìm block solid trong 2..12 lớp trên đầu. Có → đang dưới lòng đất →
## bật fade cho mọi terrain chunk quanh (theo khoảng cách ngang trong shader).
func _update_underground_fade(ppos: Vector3) -> void:
	var chunk := get_chunk_at(ppos.x, ppos.z)
	var underground := false
	if chunk != null and chunk.block_data != null:
		var blk := chunk.world_to_local_block(ppos.x, ppos.y, ppos.z)
		for ly in range(blk.y + 2, blk.y + 12):
			var bid: int = chunk.block_data.get_block(blk.x, ly, blk.z)
			if bid != 0 and _Data.is_solid(bid):
				underground = true
				break
	if underground != _fade_active:
		_fade_active = underground
		for key in _chunks:
			_chunks[key].set_terrain_fade(underground)
		for key in _loading.keys():
			_loading[key].set_terrain_fade(underground)
	if _fade_active:
		# Ống mờ nhỏ quanh player: bán kính 2.5m, chỉ cắt lớp đất ngay trên đầu
		WorldChunk.set_fade_uniforms(dimension_id, ppos, 2.5,
			ppos.y - 0.5, ppos.y + 2.0)

## ── Occlude fade: làm mờ terrain block che khuất player từ camera iso ────────
## Shader dùng half-space test: chỉ mờ fragment nằm về phía camera so với
## player. Mọi chunk đều dùng chung 1 material (shared shader), chỉ cần
## bật/tắt khi player di chuyển đủ xa hoặc camera thay đổi góc.
func _update_occlusion_fade(ppos: Vector3, delta: float) -> void:
	_occlude_timer -= delta

	# Lấy camera để tính cam_dir và dist
	var cam: Camera3D = null
	var vp := get_viewport()
	if vp != null:
		cam = vp.get_camera_3d()

	# Tính cam_dir + dist mỗi frame (dùng chung cho cả uniform update lẫn raycast)
	var cam_dir := Vector3(0.577, 0.577, 0.577)
	var cam_dist: float = 52.0
	if cam != null:
		var v: Vector3 = cam.global_position - ppos
		cam_dist = v.length()
		if cam_dist > 0.01:
			cam_dir = v / cam_dist

	# Luôn push uniform mỗi frame để shader bám player mượt
	if not _occlude_chunks.is_empty():
		WorldChunk.set_occlude_uniforms(dimension_id, ppos, cam_dir,
			cam_dist, 8.0, 0.52)

	if _occlude_timer > 0.0:
		return
	_occlude_timer = _OCCLUDE_INTERVAL

	if cam == null:
		return

	# Tìm chunk nào bị ray camera→player đi qua — dùng ray-AABB slab test.
	# Shader tự lọc fragment nào thực sự nằm trong hình trụ cam→player.
	var cam_pos: Vector3 = cam.global_position
	# dir = hướng từ cam đến player
	var dir: Vector3 = -cam_dir  # cam_dir là player→cam, đảo lại

	var new_occluded: Array[WorldChunk] = []
	for key in _chunks:
		var chunk: WorldChunk = _chunks[key] as WorldChunk
		if chunk == null or not is_instance_valid(chunk) or not chunk._built:
			continue

		# AABB chunk (origin = góc TL)
		var o: Vector3 = chunk.global_position
		var aabb_min := Vector3(o.x, o.y - 1.0, o.z)
		var aabb_max := Vector3(o.x + CHUNK_SIZE, o.y + 40.0, o.z + CHUNK_SIZE)

		# Ray-AABB slab test (ray từ cam đến player)
		var t_min: float = 0.001
		var t_max: float = cam_dist
		var hit: bool = true
		for axis in [0, 1, 2]:
			if absf(dir[axis]) < 1e-6:
				if cam_pos[axis] < aabb_min[axis] or cam_pos[axis] > aabb_max[axis]:
					hit = false; break
				continue
			var inv_d: float = 1.0 / dir[axis]
			var t1: float = (aabb_min[axis] - cam_pos[axis]) * inv_d
			var t2: float = (aabb_max[axis] - cam_pos[axis]) * inv_d
			if t1 > t2:
				var tmp: float = t1; t1 = t2; t2 = tmp
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				hit = false; break

		if not hit:
			continue
		new_occluded.append(chunk)

	# Tắt occlude cho chunk không còn trên đường cam→player
	for old_chunk in _occlude_chunks:
		if is_instance_valid(old_chunk) and not new_occluded.has(old_chunk):
			old_chunk.set_terrain_occlude(false)

	# Bật occlude cho chunk mới trên đường
	for new_chunk in new_occluded:
		if not _occlude_chunks.has(new_chunk):
			new_chunk.set_terrain_occlude(true)

	_occlude_chunks = new_occluded

	# Push uniform ngay sau khi cập nhật danh sách (chunk mới cần uniform đúng ngay)
	if not _occlude_chunks.is_empty():
		WorldChunk.set_occlude_uniforms(dimension_id, ppos, cam_dir,
			cam_dist, 8.0, 0.52)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_find_player()
		return

	var ppos := _player.global_position
	var cx: int = int(floor(ppos.x / CHUNK_SIZE))
	var cz: int = int(floor(ppos.z / CHUNK_SIZE))
	var cur := Vector2i(cx, cz)

	_update_underground_fade(ppos)
	_update_occlusion_fade(ppos, _delta)

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
				var leaving: WorldChunk = _chunks[key] as WorldChunk
				if leaving != null and is_instance_valid(leaving):
					_occlude_chunks.erase(leaving)
				_chunks[key].queue_free()
				_chunks.erase(key)
		for key in _loading.keys():
			if not key in keep:
				var leaving: WorldChunk = _loading[key] as WorldChunk
				if leaving != null and is_instance_valid(leaving):
					_occlude_chunks.erase(leaving)
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
