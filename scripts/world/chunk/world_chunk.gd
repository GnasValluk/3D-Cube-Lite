extends Node3D
class_name WorldChunk

const _Data  = preload("chunk_data.gd")
const _Noise = preload("chunk_noise.gd")
const _Road  = preload("chunk_road.gd")
const _River = preload("chunk_river.gd")
const _Detail = preload("chunk_detail.gd")
const _Grass = preload("chunk_grass.gd")
const _Aquatic = preload("chunk_aquatic.gd")
const _BlockData = preload("chunk_block_data.gd")
const _RoadLamp = preload("chunk_road_lamp.gd")
const _PalmProp = preload("res://scripts/world/props/palm_prop.gd")
const _OakProp = preload("res://scripts/world/props/oak_prop.gd")
const _OrangeTreeProp = preload("res://scripts/world/props/orange_tree_prop.gd")
const _DenseTreeProp = preload("res://scripts/world/props/dense_tree_prop.gd")
const _EggplantProp = preload("res://scripts/world/props/eggplant_prop.gd")
const _WatermelonVine = preload("res://scripts/world/props/watermelon_vine_prop.gd")
const _PumpkinVine = preload("res://scripts/world/props/pumpkin_vine_prop.gd")
const _Terrain = preload("chunk_terrain.gd")
const _Village = preload("village.gd")
const _WaterFlow = preload("water_flow.gd")
const _OreTex = preload("res://scripts/items/models/ore_texture.gd")

static func _is_water_bid(bid: int) -> bool:
	return bid == _Data.BlockID.WATER \
		or (bid >= _Data.BlockID.WATER_SOURCE and bid <= _Data.BlockID.WATER_LEVEL_1)

## ── BFS đa nguồn (4-láng giềng, Manhattan) — thay multi-pass distance map ─────
## Nguồn = ô có giá trị != CONST_INF (0 cho source, sẵn giá trị band đầu nếu cần).
## Lan chỉ vào ô có mask==1 (mask rỗng → mọi ô). Kết quả y hệt multi-pass cũ.
static func _bfs_manhattan(dmap: PackedInt32Array, total: int, mask: PackedByteArray = PackedByteArray()) -> void:
	var use_mask: bool = mask.size() > 0
	var frontier := PackedInt32Array()
	for i in range(dmap.size()):
		if dmap[i] != _Data.CONST_INF:
			frontier.append(i)
	var fhead := 0
	while fhead < frontier.size():
		var idx: int = frontier[fhead]
		fhead += 1
		var nd: int = dmap[idx] + 1
		var cx: int = idx / total
		var cz: int = idx % total
		if cx > 0:
			var ni: int = idx - total
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cx < total - 1:
			var ni: int = idx + total
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cz > 0:
			var ni: int = idx - 1
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)
		if cz < total - 1:
			var ni: int = idx + 1
			if dmap[ni] == _Data.CONST_INF and (not use_mask or mask[ni] == 1):
				dmap[ni] = nd
				frontier.append(ni)

## ── BFS đa nguồn (8-láng giềng, Chebyshev) — khoảng cách nước/đường/sa mạc ──
## Đầu vào: nguồn = 0, chưa biết = -1. Đầu ra: -1 được đổi thành CONST_INF để
## phép so sánh "khoảng cách <= r" không dính lỗi -1 <= r.
static func _bfs_chebyshev(dmap: PackedInt32Array, cols: int) -> void:
	var frontier := PackedInt32Array()
	for i in range(dmap.size()):
		if dmap[i] == 0:
			frontier.append(i)
	var fhead := 0
	while fhead < frontier.size():
		var idx: int = frontier[fhead]
		fhead += 1
		var nd: int = dmap[idx] + 1
		var cx: int = idx / cols
		var cz: int = idx % cols
		for dx in range(-1, 2):
			var nx: int = cx + dx
			if nx < 0 or nx >= cols:
				continue
			for dz in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nz: int = cz + dz
				if nz < 0 or nz >= cols:
					continue
				var ni: int = nx * cols + nz
				if dmap[ni] == -1:
					dmap[ni] = nd
					frontier.append(ni)
	for i in range(dmap.size()):
		if dmap[i] == -1:
			dmap[i] = _Data.CONST_INF

static func _water_level_of(bid: int) -> int:
	if bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER:
		return 8
	if bid >= _Data.BlockID.WATER_LEVEL_7 and bid <= _Data.BlockID.WATER_LEVEL_1:
		return 8 - (bid - _Data.BlockID.WATER_LEVEL_7)
	return 0

# ── Ocean mask tại 1 world cell — nguồn duy nhất cho đất vs biển ────────────
# Warp bờ biển + bias vùng spawn (gốc tọa độ luôn là đất). Hud teleport,
# explore map, fish_spawner và test dùng chung hàm này để không lệch nhau.
const SPAWN_BIAS_AMP: float = 2.2
const SPAWN_BIAS_SIG2: float = 500000.0
const SPAWN_BIAS_CUT: float = 2000000.0

static func _ocean_mask_at(nd: Dictionary, wx: float, wz: float) -> bool:
	var ow: FastNoiseLite = nd["ocean_warp"]
	var warp_x: float = ow.get_noise_2d(wx * 0.5, wz * 0.5) * 200.0
	var warp_z: float = ow.get_noise_2d(wx * 0.5 + 100.0, wz * 0.5 + 100.0) * 200.0
	var raw: float = (nd["ocean"] as FastNoiseLite).get_noise_2d(wx + warp_x, wz + warp_z)
	var d2: float = wx * wx + wz * wz
	if d2 < SPAWN_BIAS_CUT:
		raw -= SPAWN_BIAS_AMP * exp(-d2 / SPAWN_BIAS_SIG2)
	return (raw + 1.0) * 0.5 > _Data.OCEAN_THRESHOLD

## ── _gen_water_top_layer: layer cao nhất nước generation có thể tồn tại ─────
static func _gen_water_top_layer() -> int:
	return floori((_Data.WATER_Y - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN

var _cx: int = 0
var _cz: int = 0
var _was_setup: bool = false
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Data._Dim.DimensionID.TWILIGHT
var _built: bool = false
var _water_tick_timer: float = 0.0
var _has_water: bool = false
var _max_water_ly: int = -1
var _has_ores: bool = false
var _has_soil: bool = false
var _top_ly_cache := PackedInt32Array()

## Block data — cho phép set_block / get_block sau này (build/mine)
var block_data: _BlockData = null

## References to per-type meshes (preserved across rebuilds)
var _terrain_mesh_instance: MeshInstance3D = null
var _water_mesh_instance: MeshInstance3D = null
var _aquatic_mesh_instance: MeshInstance3D = null
var _textured_block_mesh_instances: Dictionary[int, MeshInstance3D] = {}
var _shaped_block_instances: Array[MeshInstance3D] = []
var _mesh_container: Node3D = null
var _lotus_lights: Array[OmniLight3D] = []
var _prop_queue: Array = []

## Bật/tắt spawn prop plant (headless benchmark tắt để đo sạch phần chunk;
## game thật luôn true).
static var props_enabled: bool = true

## Ngân sách spawn prop dùng chung toàn game/frame — khi có nhiều chunk cùng
## stream, từng chunk KHÔNG còn tự do 2 prop/frame (tổng có thể bùng hàng chục
## cây/khối nặng trong cùng 1 frame → spike). Thay vào đó dùng qui ước chi phí:
## cỏ/meadow rẻ, cây/khối nặng đắt; mỗi frame chia sẻ tổng ngân sách, hết thì
## dồn frame sau. Prop rẻ (weed/seagrass/taro) ưu tiên trước, cây nặng để sau.
static var _prop_budget_remaining: int = 0
static var _prop_budget_max: int = 8
static var _prop_budget_frame: int = -1
## Reset ngân sách 1 lần mỗi frame (idempotent dù nhiều chunk cùng _process).
static func _prop_reset_budget() -> void:
	var f := Engine.get_process_frames()
	if f == _prop_budget_frame:
		return
	_prop_budget_frame = f
	_prop_budget_remaining = _prop_budget_max

## Chi phí spawn (đơn vị ngân sách) theo loại prop — đắt nhất là cây voxel.
static func _prop_cost(ptype: String) -> int:
	match ptype:
		"oak": return 6
		"dense_tree": return 4
		"palm": return 3
		"orange_tree": return 3
		"pumpkin", "watermelon", "eggplant": return 1
		_: return 1

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}
static var _pending_mutex := Mutex.new()

## ── Task tracking: chờ mọi worker task xong trước khi process thoát ─────────
## Worker chạy lúc teardown (chunk build, water, collision, decorative, prewarm)
## đọc dữ liệu đang bị destroy → crash 0xC0000005 (từng tái hiện tất định ở
## test_till/test_ore_tex/test_promote). Test gọi wait_for_tasks_async() trước
## khi quit — engine bản này không có SceneTree.about_to_quit nên không thể
## hook tập trung.
static var _task_ids: Array[int] = []
static var _task_mutex := Mutex.new()

static func _track_task(tid: int) -> void:
	_task_mutex.lock()
	_task_ids.append(tid)
	_task_mutex.unlock()

static func _pending_task_count() -> int:
	_task_mutex.lock()
	var ids := _task_ids.duplicate()
	_task_mutex.unlock()
	var count := 0
	for tid in ids:
		if not WorkerThreadPool.is_task_completed(tid):
			count += 1
	return count

## Đợi mọi task hoàn thành (kể cả task sinh deferred sau 1-2 frame).
static func wait_for_tasks_async(tree: SceneTree, max_wait_ms: int = 15000) -> void:
	var stable_frames := 0
	var waited := 0
	while stable_frames < 3:
		if _pending_task_count() == 0:
			stable_frames += 1
		else:
			stable_frames = 0
		if waited >= max_wait_ms:
			push_warning("WorldChunk.wait_for_tasks_async: timeout %dms" % max_wait_ms)
			return
		await tree.process_frame
		waited += 16
var _pending_data: Dictionary = {}
static var _river_noise: FastNoiseLite = null
static var _river_bed_noise: FastNoiseLite = null

static func _ensure_river_noise() -> void:
	if _river_noise == null:
		_river_noise = FastNoiseLite.new()
		_river_noise.seed = SeedSnapshot.ensure() + 9999
		_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_river_noise.frequency = 0.06
	if _river_bed_noise == null:
		_river_bed_noise = FastNoiseLite.new()
		_river_bed_noise.seed = SeedSnapshot.ensure() + 10101
		_river_bed_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_river_bed_noise.frequency = 0.04

static func _noise_for_dim(dim_id: int) -> Dictionary:
	return _Noise._noise_for_dim(dim_id)

static func clear_noise_cache() -> void:
	_Noise.clear_cache()
	_mesh_cache.clear()
	_mat_cache.clear()
	_river_noise = null
	_river_bed_noise = null

## ── Pre-warm mạng đường + sông trên worker thread ────────────────────────────
## Network gen tốn ~5-6s một lần (cached static). Chạy trên worker trong lúc
## loading screen để world scene không bị đứng hình khi build chunk đầu.
static var _networks_ready: bool = false
static var _networks_seed: int = -1
static var _prewarm_running: bool = false

static func _reset_networks() -> void:
	_networks_ready = false
	_Road._road_curves.clear()
	_Road._road_curve_bboxes.clear()
	_Road._road_spatial.clear()
	_Road._road_ready = false
	_Road._int_cache.clear()
	_River._river_curves.clear()
	_River._river_spatial.clear()
	_River._river_ready = false
	_River._int_cache.clear()
	_River._noise_river = null

static func _prewarm_networks() -> void:
	var seed_v: int = SeedSnapshot.ensure()
	if _networks_ready and _networks_seed == seed_v:
		_prewarm_running = false
		return
	_reset_networks()
	_networks_seed = seed_v
	_Road._ensure_roads()
	_River._ensure_rivers()
	_networks_ready = true
	_prewarm_running = false

static func prewarm_async() -> void:
	var seed_v: int = WorldSeed.seed_value
	SeedSnapshot.set_seed(seed_v)
	if _networks_ready and _networks_seed == seed_v:
		return
	if _prewarm_running:
		return
	# Chặn ngay trên main thread — tránh loading screen start world với dữ liệu cũ
	_networks_ready = false
	_prewarm_running = true
	_track_task(WorkerThreadPool.add_task(_prewarm_networks))

static func _is_on_road(wx: float, wz: float) -> bool:
	return _Road.is_on_road(wx, wz)

static func _is_on_river(wx: float, wz: float) -> bool:
	return _River.is_on_river(wx, wz)

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

# ── Registry chunk (tra cứu O(1)) ─────────────────────────────────────────────
# Thay cho việc đệ quy quét toàn bộ scene tree từng lần (gây lag 400ms khi
# máy kéo/thuyền đổi chunk). Đăng ký khi setup, gỡ khi PREDELETE.
static var _chunk_registry: Dictionary = {}

static func get_chunk(cx: int, cz: int, dim: int) -> Node:
	return _chunk_registry.get(_cache_key(cx, cz, dim))

static func _register_chunk(cx: int, cz: int, dim: int, node: Node) -> void:
	_chunk_registry[_cache_key(cx, cz, dim)] = node

static func _unregister_chunk(cx: int, cz: int, dim: int) -> void:
	_chunk_registry.erase(_cache_key(cx, cz, dim))

func setup(cx: int, cz: int, size: int,
		dimension_id: int = _Data._Dim.DimensionID.TWILIGHT, sync: bool = false) -> void:
	# Đồng bộ SeedSnapshot với WorldSeed hiện tại (main thread) — test/flow có
	# thể set WorldSeed.seed_value trực tiếp; worker chỉ đọc snapshot.
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_was_setup = true
	_cols = int(_size / _Data.VOXEL)
	_tiles_per_chunk = int(_cols / _Data.TILE_W)
	_init_materials()
	_water_tick_timer = randf_range(0.0, 0.5)
	WorldChunk._register_chunk(cx, cz, dimension_id, self)

	var ck: String = _cache_key(cx, cz, dimension_id)
	if _mesh_cache.has(ck):
		apply_chunk(_mesh_cache[ck])
		return

	if sync:
		apply_chunk(compute_chunk(cx, cz, size, dimension_id, true))
		call_deferred("_schedule_decorative_rebuild")
		return

	_pending_mutex.lock()
	_pending_chunks[ck] = self
	_pending_mutex.unlock()
	_track_task(WorkerThreadPool.add_task(
		_thread_build.bind(ck, cx, cz, size, dimension_id), true, "chunk"))

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	_pending_mutex.lock()
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	_pending_mutex.unlock()
	if chunk != null and is_instance_valid(chunk) and chunk.is_inside_tree():
		# Không apply_chunk trực tiếp — chỉ lưu data, manager promote 1 chunk/frame
		# để tránh nhiều worker hoàn thành cùng lúc → node-creation spike trên main
		chunk.call_deferred("_store_pending_data", data)

func _store_pending_data(data: Dictionary) -> void:
	_pending_data = data

## ── compute_chunk: tạo block data + build mesh ───────────────────────────────
static func compute_chunk(cx: int, cz: int, size: int, dim_id: int, fast_mode: bool = false) -> Dictionary:
	var cols: int = int(size / _Data.VOXEL)
	var world_ox: float = cx * size
	var world_oz: float = cz * size
	var half: float = size * 0.5
	var h_vox: float = _Data.VOXEL * 0.5

	# ── 1. Biome sampling (với padding để stitch biên) ─────────────────────────
	var total: int = cols + 2 * _Data.PAD
	var bio: Array[Array] = []
	bio.resize(total)
	for vx in range(total):
		var row: Array = []; row.resize(total); bio[vx] = row
		for vz in range(total):
			var wx: float = world_ox - half + (float(vx - _Data.PAD) + 0.5) * _Data.VOXEL
			var wz: float = world_oz - half + (float(vz - _Data.PAD) + 0.5) * _Data.VOXEL
			row[vz] = _Noise._biome_at(wx, wz, dim_id)

	# ── 2. BFS distance map từ DARK_GRASS → tính gradient xuống nước ──────────
	# Đa nguồn: ô DARK_GRASS=0, ô GRASS/DESERT kề DARK_GRASS=1 → BFS 4-láng giềng.
	var dst := PackedInt32Array()
	dst.resize(total * total)
	for i in range(total * total):
		dst[i] = 0 if bio[i / total][i % total] == _Data.TileType.DARK_GRASS else _Data.CONST_INF
	for vx in range(total):
		for vz in range(total):
			if bio[vx][vz] != _Data.TileType.GRASS and bio[vx][vz] != _Data.TileType.DESERT: continue
			if (vx > 0 and bio[vx-1][vz] == _Data.TileType.DARK_GRASS) \
			or (vx < total-1 and bio[vx+1][vz] == _Data.TileType.DARK_GRASS) \
			or (vz > 0 and bio[vx][vz-1] == _Data.TileType.DARK_GRASS) \
			or (vz < total-1 and bio[vx][vz+1] == _Data.TileType.DARK_GRASS):
				dst[vx * total + vz] = 1
	_bfs_manhattan(dst, total)


	# ── 3. biome_grid + height_grid: biển trước → lục địa → hồ ──────────────
	var biome_grid: Array[Array] = []
	biome_grid.resize(cols)
	var height_grid: Array[Array] = []
	height_grid.resize(cols)

	var beach_mask: PackedByteArray
	beach_mask.resize(cols * cols)
	beach_mask.fill(0)

	var reef_mask: PackedFloat32Array
	reef_mask.resize(cols * cols)
	reef_mask.fill(0.0)

	for ivx in range(cols):
		biome_grid[ivx] = []; biome_grid[ivx].resize(cols)
		height_grid[ivx] = []; height_grid[ivx].resize(cols)

	# dmask: ô thuộc vùng sa mạc (base_bio DESERT) — cấm môn ngọt ở sa mạc
	# theo đúng vùng, không lệ thuộc cửa sổ lân cận cục bộ (chính xác qua biên chunk).
	var dmask: PackedByteArray = PackedByteArray()
	dmask.resize(total * total)
	dmask.fill(0)

	var nd: Dictionary = {}
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		nd = _Noise._noise_for_dim(dim_id)
		var n_lake: FastNoiseLite      = nd["lake"]
		var n_lake_type: FastNoiseLite = nd["lake_type"]
		var n_biome: FastNoiseLite     = nd["biome"]

		# ── Ocean mask (BFS padded) — stride 2, ~75% fewer noise calls ─────────
		const OCEAN_PAD: int = 26
		var oct_total: int = cols + 2 * OCEAN_PAD
		var oct: Array[Array] = []
		oct.resize(oct_total)
		for pvx in range(oct_total):
			oct[pvx] = []; oct[pvx].resize(oct_total)
		for pvx in range(0, oct_total, 2):
			for pvz in range(0, oct_total, 2):
				var wx: float = world_ox - half + (float(pvx - OCEAN_PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - OCEAN_PAD) + 0.5) * _Data.VOXEL
				oct[pvx][pvz] = _ocean_mask_at(nd, wx, wz)
		# Fill odd indices by copying nearest computed neighbor
		for pvx in range(0, oct_total, 2):
			for pvz in range(0, oct_total, 2):
				var val: bool = oct[pvx][pvz]
				if pvx + 1 < oct_total: oct[pvx + 1][pvz] = val
				if pvz + 1 < oct_total: oct[pvx][pvz + 1] = val
				if pvx + 1 < oct_total and pvz + 1 < oct_total:
					oct[pvx + 1][pvz + 1] = val

		var oct_small: Array[Array] = []
		oct_small.resize(total)
		for pvx in range(total):
			oct_small[pvx] = []; oct_small[pvx].resize(total)
			for pvz in range(total):
				oct_small[pvx][pvz] = oct[pvx + OCEAN_PAD - _Data.PAD][pvz + OCEAN_PAD - _Data.PAD]

		const OCEAN_BUFFER: int = 45
		var odst := PackedInt32Array()
		odst.resize(total * total)
		for i in range(total * total):
			odst[i] = 0 if oct_small[i / total][i % total] else _Data.CONST_INF
		_bfs_manhattan(odst, total)

		var shore_dst := PackedInt32Array()
		shore_dst.resize(total * total)
		var oct_mask := PackedByteArray()
		oct_mask.resize(total * total)
		for pvx in range(total):
			for pvz in range(total):
				var is_oc: bool = oct_small[pvx][pvz]
				oct_mask[pvx * total + pvz] = 1 if is_oc else 0
				if is_oc:
					var adj_land: bool = false
					if pvx > 0 and not oct_small[pvx-1][pvz]: adj_land = true
					elif pvx < total-1 and not oct_small[pvx+1][pvz]: adj_land = true
					elif pvz > 0 and not oct_small[pvx][pvz-1]: adj_land = true
					elif pvz < total-1 and not oct_small[pvx][pvz+1]: adj_land = true
					shore_dst[pvx * total + pvz] = 1 if adj_land else _Data.CONST_INF
				else:
					shore_dst[pvx * total + pvz] = _Data.CONST_INF
		_bfs_manhattan(shore_dst, total, oct_mask)

		# ── Single pass: biển → bãi biển → lục địa (có hồ) ────────────────
		const MAX_OCEAN_DEPTH_DIST: int = 30
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var base_bio: int = bio[pvx][pvz]
				var od: int = odst[pvx * total + pvz]

				if od == 0:
					biome_grid[ivx][ivz] = _Data.TileType.OCEAN_DEEP
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var sd: int = shore_dst[pvx * total + pvz]
					if sd == _Data.CONST_INF: sd = MAX_OCEAN_DEPTH_DIST
					var raw_depth_t: float = clamp(float(sd - 1) / float(MAX_OCEAN_DEPTH_DIST - 1), 0.0, 1.0)

					# 3 chế độ địa hình: thềm → sườn → đồng bằng sâu
					var shelf_var: float = nd["sea_large"].get_noise_2d(wx * 0.5, wz * 0.5) * 0.08
					var shelf_end: float = 0.12 + shelf_var
					var slope_end: float = 0.32 + shelf_var * 0.5

					var base_h: float
					if raw_depth_t < shelf_end:
						var st: float = raw_depth_t / shelf_end
						base_h = lerp(-0.3, -1.5, st)
					elif raw_depth_t < slope_end:
						var st: float = (raw_depth_t - shelf_end) / max(slope_end - shelf_end, 0.01)
						st = st * st  # dốc tăng dần
						base_h = lerp(-1.5, -5.0, st)
					else:
						var st: float = (raw_depth_t - slope_end) / max(1.0 - slope_end, 0.01)
						base_h = lerp(-5.0, -8.5, st)

					# Cấu trúc lớn: sống núi, bồn trũng (amplitude tăng theo depth)
					var large_n: float = nd["sea_large"].get_noise_2d(wx, wz)
					base_h += large_n * (0.15 + raw_depth_t * 1.2)

					# Núi ngầm (Seamount) — núi lửa ngầm cao vút, xuất hiện khắp nơi
					var mt_n: float = nd["sea_mountain"].get_noise_2d(wx * 0.5, wz * 0.5)
					var mt_h: float = max(0.0, mt_n) * 8.0
					base_h += mt_h

					# Hẻm núi (canyon) — rãnh cắt vào thềm/sườn lục địa
					var c1: float = nd["sea_rough"].get_noise_2d(wx * 3.0, wz * 0.35)
					if c1 > 0.40:
						var c_h: float = (c1 - 0.40) / 0.60
						var c2: float = nd["sea_rough"].get_noise_2d(wx * 0.35, wz * 3.0)
						if c2 > 0.40:
							c_h = max(c_h, (c2 - 0.40) / 0.60)
						base_h -= c_h * c_h * (0.4 + raw_depth_t * 0.8)

					# Nhấp nhô tầm trung: mạnh ở vùng thềm/sườn, nhẹ ở đồng bằng
					var rough_n: float = nd["sea_rough"].get_noise_2d(wx, wz)
					var rough_scale: float = 1.0 - raw_depth_t * 0.6  # gần bờ gồ ghề hơn
					base_h += rough_n * 0.25 * rough_scale

					# Khe rãnh hẹp (trench) — vực sâu hiếm gặp
					var trench_n: float = nd["sea_rough"].get_noise_2d(wx * 4.0, wz * 0.5)
					var trench_t: float = clamp((abs(trench_n) - 0.55) / 0.25, 0.0, 1.0)
					var trench_mask: float = trench_t * trench_t * (3.0 - 2.0 * trench_t)
					base_h -= trench_mask * (0.3 + raw_depth_t * 1.0)

					# Bãi đá ngầm (Reef) — đá nhô cao rải rác khắp đáy biển
					var rf_n: float = (nd["reef"].get_noise_2d(wx, wz) + 1.0) * 0.5
					if rf_n > 0.40:
						var rf_h: float = (rf_n - 0.40) / 0.60
						rf_h = rf_h * 4.0
						base_h += rf_h
						reef_mask[ivx * cols + ivz] = rf_h * 0.3

					# Chặn không trồi lên quá mặt nước
					height_grid[ivx][ivz] = min(base_h, _Data.WATER_Y - 0.1)
				elif od <= _Data.BEACH_WIDTH:
					var beach_t: float = float(od - 1) / float(maxi(_Data.BEACH_WIDTH - 1, 1))
					biome_grid[ivx][ivz] = _Data.TileType.SAND_WHITE
					var wx2: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz2: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var warp_n: float = (nd["warp"].get_noise_2d(wx2 * 3.0, wz2 * 3.0) + 1.0) * 0.5
					var noise_offset: float = (warp_n - 0.5) * 0.3
					height_grid[ivx][ivz] = clamp(
						lerp(_Data.WATER_Y, _Data.VOXEL - 0.15, beach_t) + noise_offset,
						_Data.WATER_Y - 0.1, _Data.VOXEL - 0.08)
					beach_mask[ivx * cols + ivz] = 1
				else:
					# ── LỤC ĐỊA ──
					if base_bio == _Data.TileType.DARK_GRASS:
						var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
						var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
						var is_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						# Hồ đồng cỏ nội địa: DARK_GRASS không có hồ → lục địa sâu toàn
						# đất khô. Dùng chung n_lake, ngưỡng cao hơn GRASS (0.74) để
# mật độ vừa phải; đáy sâu theo lake_val (bờ nông, giữa sâu).
						var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						if not is_ocean and lake_val > 0.68 and (od == _Data.CONST_INF or od > 40):
							var lake_type_val: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
							if lake_type_val > 0.50:
								biome_grid[ivx][ivz] = _Data.TileType.SILT
							else:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
							height_grid[ivx][ivz] = _Data.WATER_Y - (1.0 + (lake_val - 0.68) * 8.0)
						else:
							biome_grid[ivx][ivz] = _Data.TileType.DARK_GRASS
							height_grid[ivx][ivz] = _Data.VOXEL
							var dn: float = (n_biome.get_noise_2d((wx+500.0)*0.7, (wz+500.0)*0.7) + 1.0) * 0.5
							if dn > 0.70:
								biome_grid[ivx][ivz] = _Data.TileType.DIRT
							elif dn > 0.66:
								# Bãi cỏ non — cơ chế y hệt bãi đất (cùng noise, cell-level),
								# dải ngưỡng ngay dưới bãi đất → mật độ ~ngang bãi đất (~6%),
								# các bãi cỏ non nằm sát/vây quanh bãi đất.
								biome_grid[ivx][ivz] = _Data.TileType.YOUNG_GRASS
					else:
						var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
						var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
						var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						var d: int = dst[pvx * total + pvz]

						var is_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						var lake_t: float = 0.60 if base_bio == _Data.TileType.DESERT else 0.70
						if not is_ocean and lake_val > lake_t and (od == _Data.CONST_INF or od > 40):
							var lake_type_val: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
							if lake_type_val > 0.50:
								biome_grid[ivx][ivz] = _Data.TileType.SILT if d <= _Data.PAD else _Data.TileType.MUDDY_SAND
							else:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND if d <= _Data.PAD else _Data.TileType.SAND
							if base_bio == _Data.TileType.DESERT:
								height_grid[ivx][ivz] = _Data.WATER_Y
							else:
								height_grid[ivx][ivz] = _Data.WATER_Y if d <= 1 else _Data.WATER_Y - min(d, _Data.PAD) * _BlockData.SLAB_HEIGHT
						elif base_bio == _Data.TileType.DESERT:
							biome_grid[ivx][ivz] = _Data.TileType.DESERT
							height_grid[ivx][ivz] = _Data.VOXEL
						else:
							biome_grid[ivx][ivz] = _Data.TileType.SAND
							if d <= 1:
								height_grid[ivx][ivz] = _Data.WATER_Y
							else:
								if d == _Data.CONST_INF: d = _Data.PAD
								height_grid[ivx][ivz] = _Data.WATER_Y - min(d, _Data.PAD) * _BlockData.SLAB_HEIGHT

		# ── 3a2. Hồ DARK_GRASS: đáy thoải theo khoảng cách từ bờ (BFS padded,
		# hàn liền qua biên chunk; ring 0 = WATER_Y như hồ cát dựa trên dst) ──
		var lake_mask: PackedByteArray = PackedByteArray()
		lake_mask.resize(total * total)
		lake_mask.fill(0)
		for pvx in range(total):
			for pvz in range(total):
				if bio[pvx][pvz] == _Data.TileType.DESERT:
					dmask[pvx * total + pvz] = 1
				if bio[pvx][pvz] != _Data.TileType.DARK_GRASS: continue
				if oct[pvx + OCEAN_PAD - _Data.PAD][pvz + OCEAN_PAD - _Data.PAD]: continue
				var wx: float = world_ox - half + (float(pvx - _Data.PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - _Data.PAD) + 0.5) * _Data.VOXEL
				var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
				var odv: int = odst[pvx * total + pvz]
				if lv > 0.68 and (odv == _Data.CONST_INF or odv > 40):
					lake_mask[pvx * total + pvz] = 1
		var ldist: PackedInt32Array = PackedInt32Array()
		ldist.resize(total * total)
		ldist.fill(-1)
		var frontier: Array[Vector2i] = []
		for pvx in range(total):
			for pvz in range(total):
				if lake_mask[pvx * total + pvz] == 0: continue
				var touching_land := false
				for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = pvx + d4.x
					var nz: int = pvz + d4.y
					if nx < 0 or nx >= total or nz < 0 or nz >= total: continue
					if lake_mask[nx * total + nz] == 0:
						touching_land = true
						break
				if touching_land:
					ldist[pvx * total + pvz] = 0
					frontier.append(Vector2i(pvx, pvz))
		var fhead := 0
		while fhead < frontier.size():
			var c: Vector2i = frontier[fhead]
			fhead += 1
			var cd: int = ldist[c.x * total + c.y] + 1
			for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = c.x + d4.x
				var nz: int = c.y + d4.y
				if nx < 0 or nx >= total or nz < 0 or nz >= total: continue
				if lake_mask[nx * total + nz] == 0: continue
				if ldist[nx * total + nz] != -1: continue
				ldist[nx * total + nz] = cd
				frontier.append(Vector2i(nx, nz))
		for ivx in range(cols):
			for ivz in range(cols):
				var pvx: int = ivx + _Data.PAD
				var pvz: int = ivz + _Data.PAD
				if lake_mask[pvx * total + pvz] == 0: continue
				var sd: float = minf(float(ldist[pvx * total + pvz]), float(_Data.PAD)) * _BlockData.SLAB_HEIGHT
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				var lv: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
				height_grid[ivx][ivz] = _Data.WATER_Y - minf(1.0 + (lv - 0.68) * 8.0, sd)

	else:
		# ── Non-REAL_WORLD: giữ logic cũ ────────────────────────────────────
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				biome_grid[ivx][ivz] = bio[pvx][pvz]
				if bio[pvx][pvz] == _Data.TileType.DARK_GRASS:
					height_grid[ivx][ivz] = _Data.VOXEL
				else:
					var d: int = dst[pvx * total + pvz]
					if d == _Data.CONST_INF: d = _Data.PAD
					height_grid[ivx][ivz] = _Data.WATER_Y - min(d, _Data.PAD) * _Data.VOXEL


	# ── 3b. River override ────────────────────────────────────────────────────
	var river_flag: PackedByteArray = PackedByteArray()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		_ensure_river_noise()
		river_flag.resize(cols * cols)
		var orig_heights: Array[Array] = []
		orig_heights.resize(cols)
		for ivx in range(cols):
			orig_heights[ivx] = []; orig_heights[ivx].resize(cols)
			for ivz in range(cols):
				orig_heights[ivx][ivz] = height_grid[ivx][ivz]
		for ivx in range(cols):
			for ivz in range(cols):
				var bg: int = biome_grid[ivx][ivz]
				if bg == _Data.TileType.OCEAN_DEEP:
					continue
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				var factor: float = _River.river_distance_factor(wx, wz)
				if factor >= 0.0:
					var orig_h: float = height_grid[ivx][ivz]
					var bottom_var: float = _river_noise.get_noise_2d(wx * 0.5, wz * 0.5) * 1.5 * _BlockData.SLAB_HEIGHT
					var deep_h: float = _Data.WATER_Y - 6.0 * _BlockData.SLAB_HEIGHT + bottom_var
					var t: float = clamp(factor, 0.0, 1.0)
					t = t * t * (3.0 - 2.0 * t)
					if orig_h <= _Data.WATER_Y:
						height_grid[ivx][ivz] = lerp(deep_h, orig_h, t)
					else:
						height_grid[ivx][ivz] = lerp(deep_h, max(orig_h, _Data.WATER_Y - 0.1), t)
					if t < 0.4:
						var bed_n: float = (_river_bed_noise.get_noise_2d(wx * 1.5, wz * 1.5) + 1.0) * 0.5
						if bed_n < 0.25:
							biome_grid[ivx][ivz] = _Data.TileType.SAND
						elif bed_n < 0.55:
							biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
						else:
							biome_grid[ivx][ivz] = _Data.TileType.SILT
					else:
						biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND
					river_flag[ivx * cols + ivz] = 1
		# Flatten river banks at lake boundary
		var dirs4: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for ivx in range(cols):
			for ivz in range(cols):
				if river_flag[ivx * cols + ivz] == 0:
					continue
				if height_grid[ivx][ivz] <= _Data.WATER_Y:
					continue
				var adjacent_to_lake: bool = false
				for d in dirs4:
					var nx: int = ivx + d.x
					var nz: int = ivz + d.y
					if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
						continue
					if orig_heights[nx][nz] <= _Data.WATER_Y and height_grid[nx][nz] <= _Data.WATER_Y:
						adjacent_to_lake = true
						break
				if adjacent_to_lake:
					height_grid[ivx][ivz] = _Data.WATER_Y - 0.1
					biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND


	var road_grid: PackedByteArray
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		road_grid.resize(cols * cols)
		for ivx in range(cols):
			for ivz in range(cols):
				var bg: int = biome_grid[ivx][ivz]
				if bg == _Data.TileType.OCEAN_DEEP:
					road_grid[ivx * cols + ivz] = 0
					continue
				if river_flag[ivx * cols + ivz] == 1:
					road_grid[ivx * cols + ivz] = 0
				else:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					road_grid[ivx * cols + ivz] = 1 if _Road.is_on_road(wx, wz) else 0

	# ── 4b. BFS bán kính Chebyshev: nước / đường / đất sa mạc ────────────────
	# Thay các cửa sổ quét 7×7 lặp lại cho cỏ, cây, môn ngọt bằng tra O(1).
	var wdist := PackedInt32Array()
	var rdist := PackedInt32Array()
	var dland := PackedInt32Array()
	wdist.resize(cols * cols); wdist.fill(-1)
	rdist.resize(cols * cols); rdist.fill(-1)
	dland.resize(cols * cols); dland.fill(-1)
	for vx in range(cols):
		for vz in range(cols):
			var i2: int = vx * cols + vz
			if height_grid[vx][vz] <= _Data.WATER_Y:
				wdist[i2] = 0
			if road_grid.size() > 0 and road_grid[i2] != 0:
				rdist[i2] = 0
			if biome_grid[vx][vz] == _Data.TileType.DESERT and height_grid[vx][vz] > _Data.WATER_Y:
				dland[i2] = 0
	_bfs_chebyshev(wdist, cols)
	_bfs_chebyshev(rdist, cols)
	_bfs_chebyshev(dland, cols)


	# ── 5. Tạo ChunkBlockData từ biome + height ────────────────────────────────
	var bd := _BlockData.new()
	bd.init(cols, cols)
	_Terrain.fill_blocks(bd, biome_grid, height_grid, road_grid, cols, dim_id, cx, cz, size, nd, reef_mask)

	# ── 5b. Đồi quặng trên bề mặt — chỉ khu vực xa spawn (deterministic) ─────
	var ore_hill_info: Dictionary = { "cx": -1, "cz": -1 }
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		ore_hill_info = _Terrain.spawn_ore_hills(bd, biome_grid, height_grid, road_grid, cols, cx, cz, size)

	# ── 6. Build terrain mesh từ block data (greedy mesher) ───────────────────
	# top_ly_hint tính từ height grid — tránh scan lại 69 layer/column trong build
	var top_ly_hint := PackedInt32Array()
	top_ly_hint.resize(cols * cols)
	for vx in range(cols):
		for vz in range(cols):
			top_ly_hint[vx * cols + vz] = clampi(
				floori((height_grid[vx][vz] - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN,
				0, _BlockData.CHUNK_H - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, bd, cols, dim_id, top_ly_hint)


	# ── 6b. Detail mesh — đường mòn, sỏi cát, hoạ tiết đất ──────────────────
	var grass_xforms: Array = []
	var grass_colors: Array = []
	for vx in range(cols):
		for vz in range(cols):
			var b: int  = biome_grid[vx][vz]
			var h: float = height_grid[vx][vz]
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var pz: float = -half + (float(vz) + 0.5) * _Data.VOXEL
			var pos := Vector3(px, h, pz)
			var is_road: bool = road_grid.size() > 0 and road_grid[vx * cols + vz] != 0

			if is_road and b != _Data.TileType.SAND and b != _Data.TileType.SAND_WHITE and b != _Data.TileType.SILT and b != _Data.TileType.MUDDY_SAND:
				_Detail.add_trail_detail(st, cx, cz, size, vx, vz, pos, 0.0)

			if b == _Data.TileType.SAND and h >= _Data.VOXEL * 0.9:
				_Detail.add_sand_gravel(st, cx, cz, size, vx, vz, pos, 0.0)

			if b == _Data.TileType.DIRT or b == _Data.TileType.YOUNG_GRASS:
				_Detail.add_dirt_mounds(st, cx, cz, size, vx, vz, pos, 0.0)

			if not fast_mode and (b == _Data.TileType.GRASS or b == _Data.TileType.DARK_GRASS) and not is_road and h >= _Data.VOXEL * 0.9:
				_Grass.add_voxel_grass(vx, vz, pos, grass_xforms, grass_colors, cols, wdist)

	# ── 6d. Quán rượu — bên mép đường tại ngã 3 / ngã tư (không trên đường) ──
	var village_data: Dictionary = { "has": false, "xforms": [], "colors": [], "info": {} }
	if not fast_mode and dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		village_data = _Village.compute_village(cx, cz, size, dim_id,
			biome_grid, height_grid, road_grid, river_flag, cols)
	var mesh := st.commit()
	if mesh == null:
		return { "mesh": null, "water_mesh": null, "biome_grid": biome_grid,
				"cols": cols, "block_data_bytes": bd.to_bytes() }

	# ── 7. Water mesh — from block data ──────────────────────────────────
	var has_water: bool = false
	for vx in range(cols):
		for vz in range(cols):
			if height_grid[vx][vz] <= _Data.WATER_Y:
				has_water = true
				break
		if has_water: break
	var mesh_water: ArrayMesh = null
	if has_water:
		mesh_water = _build_water_mesh(bd, cols, dim_id, h_vox, half, {}, _gen_water_top_layer())

	# ── 8. Aquatic mesh — hồ (SAND/SILT) + rong, cỏ biển ở biển nông ──────────
	var mesh_aquatic = null
	var lotus_lights: Array[Vector3] = []
	var plant_props: Array[Dictionary] = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var st_aq := SurfaceTool.new()
		st_aq.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vx in range(cols):
			for vz in range(cols):
				var b: int = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				# Hồ: SAND/SAND_WHITE/SILT/MUDDY_SAND; biển nông: OCEAN_DEEP
				if b != _Data.TileType.SAND and b != _Data.TileType.SAND_WHITE \
						and b != _Data.TileType.SILT and b != _Data.TileType.MUDDY_SAND \
						and b != _Data.TileType.OCEAN_DEEP: continue
				if h > _Data.WATER_Y: continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				var is_river: bool = river_flag[vx * cols + vz] == 1
				# Cấm môn ngọt ở sa mạc: ô thuộc vùng DESERT (mask theo base_bio,
				# chính xác qua biên chunk) HOẶC có đất sa mạc trong 3 ô (hồ cát
				# giáp ranh sa mạc cũng bị cấm).
				var is_desert_water: bool = dmask[(vx + _Data.PAD) * total + (vz + _Data.PAD)] == 1
				if not is_desert_water and (b == _Data.TileType.SAND or b == _Data.TileType.MUDDY_SAND):
					if dland[vx * cols + vz] <= 3:
						is_desert_water = true
				# Cỏ biển multimesh (thay cỏ biển prop cũ) — đáy biển nông OCEAN_DEEP
				if b == _Data.TileType.OCEAN_DEEP:
					var sea_wx: float = world_ox - half + (float(vx) + 0.5) * _Data.VOXEL
					var sea_wz: float = world_oz - half + (float(vz) + 0.5) * _Data.VOXEL
					_Grass.add_voxel_seagrass(vx, vz, pos2, grass_xforms, grass_colors,
						cols, _Data.WATER_Y - h, sea_wx, sea_wz)
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox,
					b == _Data.TileType.SILT, b, lotus_lights, plant_props, is_river, is_desert_water)
		mesh_aquatic = st_aq.commit()

	# ── 8b. Palm trees — on GRASS/DARK_GRASS land, ≥2 cells from water ─────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				if biome_grid[vx][vz] != _Data.TileType.GRASS and biome_grid[vx][vz] != _Data.TileType.DARK_GRASS \
						and biome_grid[vx][vz] != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				var wd: int = wdist[vx * cols + vz]
				if wd >= 2 and wd <= 3 and randf() < 0.004:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					# Cấm mọc trên đường đi
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					# Sink slightly into terrain, but never below water surface
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "palm", "pos": Vector3(px, y, pz), "variant": "river"})

	# ── 8c. Cây sồi cổ thụ — đồng cỏ tối (plains) & bờ sông (river), xa nước ≥2 ──
	for vx in range(cols):
		for vz in range(cols):
			var oak_bio: int = biome_grid[vx][vz]
			if oak_bio != _Data.TileType.DARK_GRASS and oak_bio != _Data.TileType.GRASS \
					and oak_bio != _Data.TileType.YOUNG_GRASS:
				continue
			var h: float = height_grid[vx][vz]
			if h <= _Data.WATER_Y:
				continue
			if wdist[vx * cols + vz] <= 2:
				continue
			var chance: float = 0.0035 if oak_bio == _Data.TileType.DARK_GRASS else 0.0012
			if randf() < chance:
				var px := -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
				# Cấm mọc trên đường đi
				if _is_on_road(world_ox + px, world_oz + pz):
					continue
				var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
				var variant := "plains" if oak_bio == _Data.TileType.DARK_GRASS else "river"
				plant_props.append({"type": "oak", "pos": Vector3(px, y, pz), "variant": variant})

	# ── 8e. Cây cà tím dại — SÁT ĐƯỜNG ĐI (cách đường ≤2 ô), KHÔNG mọc trên đường ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var eg_bio: int = biome_grid[vx][vz]
				if eg_bio != _Data.TileType.DARK_GRASS and eg_bio != _Data.TileType.GRASS \
						and eg_bio != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if road_grid[vx * cols + vz] != 0:
					continue
				if rdist[vx * cols + vz] > 2:
					continue
				var chance: float = 0.0024 if eg_bio == _Data.TileType.DARK_GRASS else 0.0009
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "eggplant", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8f. Cây dưa hấu dại — GẦN nguồn nước (nước cách ≤2 ô), đồng cỏ ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var wm_bio: int = biome_grid[vx][vz]
				if wm_bio != _Data.TileType.DARK_GRASS and wm_bio != _Data.TileType.GRASS \
						and wm_bio != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] > 2:
					continue
				var chance: float = 0.0016 if wm_bio == _Data.TileType.DARK_GRASS else 0.0006
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "watermelon", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8g. Dây bí đỏ dại — XA nguồn nước (nước cách ≥3 ô), đồng cỏ ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var pk_bio: int = biome_grid[vx][vz]
				if pk_bio != _Data.TileType.DARK_GRASS and pk_bio != _Data.TileType.GRASS \
						and pk_bio != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 3:
					continue
				var chance: float = 0.0016 if pk_bio == _Data.TileType.DARK_GRASS else 0.0006
				if randf() < chance:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "pumpkin", "pos": Vector3(px, y, pz), "variant": "wild"})

	# ── 8h. Cây cam — bờ nước (xa nước 2-3 ô) & trung tâm đồng cỏ tối ────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var or_bio: int = biome_grid[vx][vz]
				if or_bio != _Data.TileType.DARK_GRASS and or_bio != _Data.TileType.GRASS \
						and or_bio != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				# Bờ nước: nước cách 2-3 ô nhưng không liền kề
				var wd2: int = wdist[vx * cols + vz]
				var near_close: bool = wd2 <= 1
				var near_far: bool = wd2 >= 2 and wd2 <= 3
				var spawned := false
				if near_far and not near_close and randf() < 0.0025:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "orange_tree", "pos": Vector3(px, y, pz), "variant": "river"})
					spawned = true
				# Trung tâm đồng cỏ tối: xa nước ≥2
				if not spawned and or_bio == _Data.TileType.DARK_GRASS and not near_close and randf() < 0.0016:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "orange_tree", "pos": Vector3(px, y, pz), "variant": "plains"})

	# ── 8i. Cây rừng rậm — tán um tùm, xa nước ≥2 trên đồng cỏ ──────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var dt_bio: int = biome_grid[vx][vz]
				if dt_bio != _Data.TileType.DARK_GRASS and dt_bio != _Data.TileType.GRASS \
						and dt_bio != _Data.TileType.YOUNG_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				if wdist[vx * cols + vz] <= 2:
					continue
				if randf() < 0.0012:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					if _is_on_road(world_ox + px, world_oz + pz):
						continue
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "dense_tree", "pos": Vector3(px, y, pz), "variant": "plains"})

	# ── 9. Lamp positions ──────────────────────────────────────────────────────
	var lamp_positions: Array = []
	if not fast_mode and dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		lamp_positions = _RoadLamp.compute_positions(cx, cz, size, biome_grid, height_grid, cols)


	# ── 10. Textured block (ore) overlays — bounded scan dưới bề mặt ─────────
	# Ore không được generation sinh ra (feature chưa kích hoạt) → bỏ hẳn scan
	var ore_meshes: Dictionary[int, ArrayMesh] = {}
	if not fast_mode and _ORES_GENERATION_ENABLED:
		var max_top_ly: int = 0
		for vx in range(cols):
			for vz in range(cols):
				max_top_ly = maxi(max_top_ly, top_ly_hint[vx * cols + vz])
		ore_meshes = _build_textured_block_meshes(bd, cols, max_top_ly)

	# ── 10b. Shaped blocks (đá ¼/⅛/phiến) — BỎ SCAN ở generation ────────────
	# Terrain generation KHÔNG BAO GIỜ ghi shaped block (chỉ check). Shaped block
	# chỉ tồn tại qua đặt tay/save-restore → cả hai đều rebuild qua rebuild_mesh
	# → _build_shaped_block_nodes (scan tại đó). Scan 70K ô ~34ms ngay tại đây là
	# phí hoàn toàn, nhất là chunk trung tâm sync chạy ngay trên main thread.
	var shaped_data := _empty_shaped_data()


	return {
		"mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic,
		"grass_blade_data": { "xforms": grass_xforms, "colors": grass_colors },
		"village_data": village_data,
		"ore_hill": ore_hill_info,
		"lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols,
		"river_flag": river_flag,
		"block_data_bytes": bd.to_bytes(), "lamp_positions": lamp_positions,
		"textured_block_meshes": ore_meshes,
		"plant_props": plant_props, "has_water": has_water,
		"has_ores": not ore_meshes.is_empty(),
		"top_ly_hint": top_ly_hint,
		"shaped_mesh": shaped_data["shaped_mesh"],
		"shaped_pos": shaped_data["shaped_pos"],
		"shaped_size": shaped_data["shaped_size"],
	}



## ── _get_textured_block_material: delegate OreTextures (mỗi ore 1 hoa văn) ──
static func _get_textured_block_material(block_id: int) -> Material:
	if block_id == _Data.BlockID.TILLED_SOIL:
		return _OreTex.get_soil_material(false)
	return _OreTex.get_material(block_id)

## ── _build_xform_multimesh: BoxMesh đơn vị + vertex color (cỏ, rêu, làng, ...) ──
## `unshaded=true` cho chi tiết nhỏ (cỏ/rêu); làng/cầu dùng shaded như cây dừa
## (metallic 0, roughness cao, có ánh sáng).
## Đổ transforms + colors vào MultiMesh bằng set_buffer (1 lệnh) — nhanh hơn
## loop set_instance_transform/color ~3x cho hàng nghìn instance (grass/village).
static func _multimesh_buffer(mm: MultiMesh, xforms: Array, colors: Array) -> void:
	var n: int = xforms.size()
	if n == 0:
		return
	var buf := PackedFloat32Array()
	buf.resize(n * 16)
	var k: int = 0
	for i in range(n):
		var t: Transform3D = xforms[i] as Transform3D
		buf[k]     = t.basis.x.x; buf[k + 1]  = t.basis.y.x; buf[k + 2]  = t.basis.z.x; buf[k + 3]  = t.origin.x
		buf[k + 4] = t.basis.x.y; buf[k + 5]  = t.basis.y.y; buf[k + 6]  = t.basis.z.y; buf[k + 7]  = t.origin.y
		buf[k + 8] = t.basis.x.z; buf[k + 9]  = t.basis.y.z; buf[k + 10] = t.basis.z.z; buf[k + 11] = t.origin.z
		var c: Color = colors[i] as Color
		buf[k + 12] = c.r; buf[k + 13] = c.g; buf[k + 14] = c.b; buf[k + 15] = c.a
		k += 16
	mm.set_buffer(buf)

static func _build_xform_multimesh(xforms: Array, colors: Array,
		shadow_on: bool = false, unshaded: bool = true) -> MultiMeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.metallic = 0.0
		mat.roughness = 0.85
	cube.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = xforms.size()
	_multimesh_buffer(mm, xforms, colors)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_on \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## ── _build_textured_block_mesh: mesh có UV cho block có texture ─────────────
static func _build_textured_block_mesh(bd: _BlockData, cols: int, target_block_id: int, top_ly: PackedInt32Array) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const _SIDE_MUL: float = 0.50
	const _BOT_MUL: float = 0.35

	for x in range(cols):
		for z in range(cols):
			var ly: int = top_ly[x * cols + z]
			if ly < 0: continue
			var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL
			var cy_top: float = float(ly + Y_MIN) * SLAB + SLAB
			var cy_bot: float = float(ly + Y_MIN) * SLAB

			st.set_color(Color.WHITE)
			_Terrain._add_quad_uv(st, Vector3(cx_f, cy_top + 0.01, cz_f),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0))

			if ly > 0:
				var below: int = bd.get_block(x, ly - 1, z)
				if below == B.AIR or below == B.WATER:
					st.set_color(Color(_BOT_MUL, _BOT_MUL, _BOT_MUL))
					_Terrain._add_quad_uv(st, Vector3(cx_f, cy_bot, cz_f),
						Vector3(-hw, 0, 0), Vector3(0, 0, hw), Vector3(0, -1, 0))

			var checks: Array = [
				[z > 0, x, z - 1, Vector3(0, 0, -1), Vector3(0, 0, -hw)],
				[z < cols - 1, x, z + 1, Vector3(0, 0, 1), Vector3(0, 0, hw)],
				[x > 0, x - 1, z, Vector3(-1, 0, 0), Vector3(-hw, 0, 0)],
				[x < cols - 1, x + 1, z, Vector3(1, 0, 0), Vector3(hw, 0, 0)],
			]
			for c in checks:
				if not c[0]: continue
				var nx: int = c[1]; var nz: int = c[2]
				var nly: int = top_ly[nx * cols + nz]
				if nly >= ly: continue
				var nrm: Vector3 = c[3]; var off: Vector3 = c[4]
				var n_top: float = float(nly + Y_MIN) * SLAB + SLAB if nly >= 0 else float(Y_MIN) * SLAB
				var side_h: float = cy_top - max(cy_bot, n_top)
				if side_h <= 0: continue
				var cy_mid: float = cy_top - side_h * 0.5
				var side_u: Vector3 = Vector3(hw, 0, 0) if abs(off.x) < 0.01 else Vector3(0, 0, hw)
				st.set_color(Color(_SIDE_MUL, _SIDE_MUL, _SIDE_MUL))
				_Terrain._add_quad_uv(st, Vector3(cx_f + off.x + nrm.x * 0.01, cy_mid, cz_f + off.z + nrm.z * 0.01),
					side_u, Vector3(0, side_h * 0.5, 0), nrm)

	return st.commit()



const _TEXTURED_BLOCK_IDS: Array[int] = [
	_Data.BlockID.COPPER_ORE,
	_Data.BlockID.BAUXITE_ORE,
	_Data.BlockID.SILVER_ORE,
	_Data.BlockID.IRON_ORE,
	_Data.BlockID.GOLD_ORE,
	_Data.BlockID.TITAN_ORE,
	_Data.BlockID.PLATINUM_ORE,
	_Data.BlockID.COAL_ORE,
	_Data.BlockID.OAK_WOOD,
]

## Ore hiện được sinh qua đồi quặng (spawn_ore_hills) ở khu xa spawn
const _ORES_GENERATION_ENABLED: bool = true

static func _build_textured_block_meshes(bd: _BlockData, cols: int, max_ly: int = -1) -> Dictionary[int, ArrayMesh]:
	const CHUNK_H := _BlockData.CHUNK_H
	if max_ly < 0:
		max_ly = CHUNK_H - 1
	max_ly = clampi(max_ly, 0, CHUNK_H - 1)
	# 1 pass từ trên xuống: top_ly cho từng loại ore theo từng cột.
	# max_ly là đỉnh terrain cao nhất → ore luôn dưới max_ly → kết quả y hệt scan
	# đủ CHUNK_H trước đây (ore chỉ tồn tại dưới bề mặt terrain).
	var top_maps: Dictionary = {}
	for bid in _TEXTURED_BLOCK_IDS:
		var arr := PackedInt32Array()
		arr.resize(cols * cols)
		arr.fill(-1)
		top_maps[bid] = arr
	var n_types: int = _TEXTURED_BLOCK_IDS.size()
	for x in range(cols):
		for z in range(cols):
			var found_in_col := 0
			for ly in range(max_ly, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if not top_maps.has(blk):
					continue
				var arr: PackedInt32Array = top_maps[blk]
				if arr[x * cols + z] == -1:
					arr[x * cols + z] = ly
					found_in_col += 1
					if found_in_col >= n_types:
						break
	var result: Dictionary[int, ArrayMesh] = {}
	for bid in _TEXTURED_BLOCK_IDS:
		var arr: PackedInt32Array = top_maps[bid]
		var any_hit := false
		for i in range(arr.size()):
			if arr[i] >= 0:
				any_hit = true
				break
		if not any_hit:
			continue
		var m := _build_textured_block_mesh(bd, cols, bid, arr)
		if m and m.get_surface_count() > 0:
			result[bid] = m
	return result

## ── Đất tơi xốp: overlay mesh — ẩm/khô qua vertex color tint ────────────────
## Ẩm khi có nước trong bán kính SOIL_RADIUS (tính từ block nước thực tế, đi
## qua biên chunk bằng nb_data) — deterministic, không lưu state riêng.
const _SOIL_DRY_TINT := Color(1.0, 0.96, 0.90)
const _SOIL_WET_TINT := Color(0.55, 0.60, 0.72)

static func _soil_cell_is_water(bd: _BlockData, nb_data: Dictionary, cols: int,
		wx: int, wly: int, wz: int) -> bool:
	if wx >= 0 and wx < cols and wz >= 0 and wz < cols:
		return _is_water_bid(bd.get_block(wx, wly, wz))
	var dir: String
	var tx: int = wx
	var tz: int = wz
	if wx < 0:
		dir = "w"; tx += cols
	elif wx >= cols:
		dir = "e"; tx -= cols
	elif wz < 0:
		dir = "n"; tz += cols
	else:
		dir = "s"; tz -= cols
	if not nb_data.has(dir):
		return false
	var info: Dictionary = nb_data[dir]
	var nb_bd: _BlockData = info["bd"]
	var nb_cols: int = info["cols"]
	if tx < 0 or tx >= nb_cols or tz < 0 or tz >= nb_cols:
		return false
	return _is_water_bid(nb_bd.get_block(tx, wly, tz))

static func _soil_is_wet_at(bd: _BlockData, nb_data: Dictionary, cols: int,
		x: int, ly: int, z: int) -> bool:
	const CHUNK_H := _BlockData.CHUNK_H
	var r: int = _Data.SOIL_RADIUS
	var max_ly: int = mini(ly + r, CHUNK_H - 1)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for wly in range(ly, max_ly + 1):
				if _soil_cell_is_water(bd, nb_data, cols, x + dx, wly, z + dz):
					return true
	return false

static func _build_soil_mesh(bd: _BlockData, cols: int, nb_data: Dictionary = {}) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	const _SIDE_MUL: float = 0.50
	const _BOT_MUL: float = 0.35
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	var top_ly := PackedInt32Array()
	top_ly.resize(cols * cols)
	top_ly.fill(-1)
	for x in range(cols):
		for z in range(cols):
			for ly in range(CHUNK_H - 1, -1, -1):
				if bd.get_block(x, ly, z) == B.TILLED_SOIL:
					top_ly[x * cols + z] = ly
					break

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(cols):
		for z in range(cols):
			var ly: int = top_ly[x * cols + z]
			if ly < 0: continue
			var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL
			var cy_top: float = float(ly + Y_MIN) * SLAB + SLAB
			var cy_bot: float = float(ly + Y_MIN) * SLAB

			var wet: bool = _soil_is_wet_at(bd, nb_data, cols, x, ly, z)
			var tint: Color = _SOIL_WET_TINT if wet else _SOIL_DRY_TINT

			st.set_color(tint)
			_Terrain._add_quad_uv(st, Vector3(cx_f, cy_top + 0.01, cz_f),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0))

			if ly > 0:
				var below: int = bd.get_block(x, ly - 1, z)
				if below == B.AIR or _is_water_bid(below):
					st.set_color(tint * _BOT_MUL)
					_Terrain._add_quad_uv(st, Vector3(cx_f, cy_bot, cz_f),
						Vector3(-hw, 0, 0), Vector3(0, 0, hw), Vector3(0, -1, 0))

			var checks: Array = [
				[z > 0, x, z - 1, Vector3(0, 0, -1), Vector3(0, 0, -hw)],
				[z < cols - 1, x, z + 1, Vector3(0, 0, 1), Vector3(0, 0, hw)],
				[x > 0, x - 1, z, Vector3(-1, 0, 0), Vector3(-hw, 0, 0)],
				[x < cols - 1, x + 1, z, Vector3(1, 0, 0), Vector3(hw, 0, 0)],
			]
			for c in checks:
				if not c[0]: continue
				var nx: int = c[1]; var nz: int = c[2]
				var nly: int = top_ly[nx * cols + nz]
				if nly >= ly: continue
				var nrm: Vector3 = c[3]; var off: Vector3 = c[4]
				var n_top: float = float(nly + Y_MIN) * SLAB + SLAB if nly >= 0 else float(Y_MIN) * SLAB
				var side_h: float = cy_top - max(cy_bot, n_top)
				if side_h <= 0: continue
				var cy_mid: float = cy_top - side_h * 0.5
				var side_u: Vector3 = Vector3(hw, 0, 0) if abs(off.x) < 0.01 else Vector3(0, 0, hw)
				st.set_color(tint * _SIDE_MUL)
				_Terrain._add_quad_uv(st, Vector3(cx_f + off.x + nrm.x * 0.01, cy_mid, cz_f + off.z + nrm.z * 0.01),
					side_u, Vector3(0, side_h * 0.5, 0), nrm)

	return st.commit()

## ── _build_water_mesh: render exposed faces only (skip bottom, correct size) ─
static func _build_water_mesh(bd: _BlockData, cols: int, dim_id: int,
		h_vox: float, half: float, nb_data: Dictionary = {}, max_ly: int = -1) -> ArrayMesh:
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	var VOXEL := _Data.VOXEL
	# Nước chỉ tồn tại ở layers 0..max_ly — giới hạn scan (tránh 69 layer rỗng)
	if max_ly < 0:
		max_ly = _gen_water_top_layer()
	max_ly = clampi(max_ly, 0, CHUNK_H - 1)

# ── Column-top map: per cột, tầng cao nhất có nước (tops[t]) + level của đỉnh
	# (levs[t]). 1 pass raw (bỏ bounds-check get_block), z innermost theo layout
	# x*CHUNK_H*cols + y*cols + z. Vòng y tăng → tops bị ghi đè lên tầng cao nhất.
	var nc := cols * cols
	var tops := PackedInt32Array()
	tops.resize(nc)
	tops.fill(-1)
	var levs := PackedByteArray()
	levs.resize(nc)
	var stride_x := CHUNK_H * cols
	var raw := bd._data
	for y in range(max_ly + 1):
		var yoff := y * cols
		for x in range(cols):
			var bbase := x * stride_x + yoff
			for z in range(cols):
				var bid: int = raw[bbase + z]
				if _is_water_bid(bid):
					var ti := z * cols + x
					tops[ti] = y
					levs[ti] = _water_level_of(bid)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const EPS := 0.02  # tránh z-fight với vách terrain coplanar
	var hh := h_vox
	var hv := SLAB * 0.5
	for x in range(cols):
		var px := -half + (float(x) + 0.5) * VOXEL
		for z in range(cols):
			var ti := z * cols + x
			var tl: int = tops[ti]
			if tl < 0:
				continue
			var pz := -half + (float(z) + 0.5) * VOXEL
			var col := Color(float(levs[ti]) / 8.0, 0.0, 0.0)
			var top_y := (float(tl + Y_MIN) + 0.5) * SLAB

			# Top face (+y) — luôn có vì tl là đỉnh cao nhất
			_add_quad(st, Vector3(px, top_y + hv, pz), Vector3(hh, 0, 0), Vector3(0, 0, hh), Vector3(0, 1, 0), col)

			# Side faces: band [nb_top+1 .. tl] nếu neighbor thấp hơn (hoặc 0 nước).
			# NOTE: tops là z-major (ti = z*cols+x) → x-neighbor lệch ±1, z lệch ±cols.
			var nxm: int = tops[ti - 1] if x > 0 else _nb_water_top(bd, nb_data, cols, x, max_ly, z, -1, 0)
			var nxp: int = tops[ti + 1] if x + 1 < cols else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 1, 0)
			var nzm: int = tops[ti - cols] if z > 0 else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 0, -1)
			var nzp: int = tops[ti + cols] if z + 1 < cols else _nb_water_top(bd, nb_data, cols, x, max_ly, z, 0, 1)

			if nxp < tl:
				var ya := (float(maxi(nxp, -1) + 1 + Y_MIN) + 0.5) * SLAB
				_add_quad(st, Vector3(px + hh + EPS, (ya + top_y) * 0.5, pz), Vector3(0, (top_y - ya) * 0.5, 0), Vector3(0, 0, hh), Vector3(1, 0, 0), col)
			if nxm < tl:
				var ya := (float(maxi(nxm, -1) + 1 + Y_MIN) + 0.5) * SLAB
				_add_quad(st, Vector3(px - hh - EPS, (ya + top_y) * 0.5, pz), Vector3(0, (top_y - ya) * 0.5, 0), Vector3(0, 0, hh), Vector3(-1, 0, 0), col)
			if nzp < tl:
				var ya := (float(maxi(nzp, -1) + 1 + Y_MIN) + 0.5) * SLAB
				_add_quad(st, Vector3(px, (ya + top_y) * 0.5, pz + hh + EPS), Vector3(hh, 0, 0), Vector3(0, (top_y - ya) * 0.5, 0), Vector3(0, 0, 1), col)
			if nzm < tl:
				var ya := (float(maxi(nzm, -1) + 1 + Y_MIN) + 0.5) * SLAB
				_add_quad(st, Vector3(px, (ya + top_y) * 0.5, pz - hh - EPS), Vector3(hh, 0, 0), Vector3(0, (top_y - ya) * 0.5, 0), Vector3(0, 0, -1), col)
	return st.commit()

## ── _nb_water_top: top layer nước của ô (x+dx, z+dz), băng qua biên chunk ────
## Trả -1 nếu không nước. Quét xuống từ y_max (chỉ gọi cho cột biên → rẻ).
static func _nb_water_top(bd: _BlockData, nb_data: Dictionary, cols: int,
		x: int, y_max: int, z: int, dx: int, dz: int) -> int:
	var nx: int = x + dx
	var nz: int = z + dz
	if nx >= 0 and nx < cols and nz >= 0 and nz < cols:
		for y in range(y_max, -1, -1):
			if _is_water_bid(bd.get_block(nx, y, nz)):
				return y
		return -1
	var dir: String
	if nx < 0: dir = "w"
	elif nx >= cols: dir = "e"
	elif nz < 0: dir = "n"
	else: dir = "s"
	if not nb_data.has(dir):
		return -1
	var info: Dictionary = nb_data[dir]
	var nb_bd: _BlockData = info["bd"]
	var nb_cols: int = info["cols"]
	var tx: int = nx if dir == "w" or dir == "e" else x
	var tz: int = nz if dir == "n" or dir == "s" else z
	if nx < 0: tx = nb_cols - 1
	elif nx >= cols: tx = 0
	if nz < 0: tz = nb_cols - 1
	elif nz >= cols: tz = 0
	if tx < 0 or tx >= nb_cols or tz < 0 or tz >= nb_cols:
		return -1
	for y in range(y_max, -1, -1):
		if _is_water_bid(nb_bd.get_block(tx, y, tz)):
			return y
	return -1

## ── rebuild_water_mesh: chỉ rebuild water mesh ───────────────────────────────
func rebuild_water_mesh() -> void:
	if block_data == null: return
	var h_vox := _Data.VOXEL * 0.5
	var half := _size * 0.5
	var nb_data := _get_neighbor_water_data()
	var mesh := _build_water_mesh(block_data, _cols, _dimension_id, h_vox, half, nb_data, _max_water_ly)
	_has_water = mesh != null
	if not _has_water:
		_max_water_ly = -1
	if _water_mesh_instance != null and is_instance_valid(_water_mesh_instance):
		_water_mesh_instance.mesh = mesh
	else:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		if _mesh_container != null:
			_mesh_container.add_child(mi_w)
		else:
			add_child(mi_w)
		_water_mesh_instance = mi_w
	# Nước đổi → độ ẩm đất tơi xốp đổi theo
	rebuild_soil_mesh()

## ── refresh_boundary_water: rebuild water mesh của chunk + 4 lân cận ────────
func refresh_boundary_water() -> void:
	# Thu thập jobs (chunk này + lân cận có nước) trên main thread — chỉ vài
	# lookup dictionary, rẻ. MESH BUILD CHẠY TRÊN MAIN (rate-limited trong
	# WaterRebuildQueue._process): build ArrayMesh trên worker thread gây hư
	# hỏng RenderingServer → crash 0xC0000005 khi process thoát (headless).
	var parent := get_parent()
	var chunks: Dictionary
	if parent != null and "_chunks" in parent:
		chunks = parent._chunks
	else:
		return
	var jobs: Array = []
	var seen: Dictionary = {}
	_collect_water_job(chunks, self, jobs, seen)
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var key := Vector2i(_cx + off.x, _cz + off.y)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				_collect_water_job(chunks, nb, jobs, seen)
	if jobs.is_empty():
		return
	if is_instance_valid(WaterRebuildQueue):
		WaterRebuildQueue.push_jobs(jobs)

## Gom 1 job rebuild water mesh của chunk `c` (nếu có nước) + refs lân cận.
## Chạy trên main thread — chỉ đọc refs, không lock.
static func _collect_water_job(chunks: Dictionary, c: WorldChunk, jobs: Array, seen: Dictionary) -> void:
	var id := c.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	if not c._has_water or c.block_data == null:
		return
	var nb: Dictionary = {}
	for d in [["w", c._cx - 1, c._cz], ["e", c._cx + 1, c._cz], ["n", c._cx, c._cz - 1], ["s", c._cx, c._cz + 1]]:
		var key := Vector2i(d[1], d[2])
		if chunks.has(key):
			var nb_chunk := chunks[key] as WorldChunk
			if nb_chunk and nb_chunk.block_data:
				nb[d[0]] = {"bd": nb_chunk.block_data, "cols": nb_chunk._cols}
	jobs.append({
		"inst_id": id,
		"bd": c.block_data,
		"cols": c._cols,
		"dim_id": c._dimension_id,
		"max_ly": c._max_water_ly,
		"h_vox": _Data.VOXEL * 0.5,
		"half": c._size * 0.5,
		"nb": nb,
	})

## Build 1 water mesh từ job data.
static func _build_water_mesh_job(job: Dictionary) -> ArrayMesh:
	return _build_water_mesh(job["bd"], job["cols"], job["dim_id"],
		job["h_vox"], job["half"], job["nb"], job["max_ly"])

## Main thread — gán mesh rebuild sẵn lên MeshInstance3D (mesh build trên MAIN
## bởi WaterRebuildQueue — build ArrayMesh trên worker gây hư hỏng RenderingServer).
func _apply_water_mesh(mesh: ArrayMesh) -> void:
	if not is_inside_tree() or block_data == null:
		return
	_has_water = mesh != null and mesh.get_surface_count() > 0
	if not _has_water:
		_max_water_ly = -1
	if _water_mesh_instance != null and is_instance_valid(_water_mesh_instance):
		_water_mesh_instance.mesh = mesh
	else:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		if _mesh_container != null:
			_mesh_container.add_child(mi_w)
		else:
			add_child(mi_w)
		_water_mesh_instance = mi_w
	rebuild_soil_mesh()

## ── Materials ─────────────────────────────────────────────────────────────────
func _make_water_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		# Vertex color: R = water_level/8 (density 0..1), G/B unused
		s.code = """
shader_type spatial;
render_mode blend_mix;
uniform vec4 shallow_color : source_color = vec4(0.15, 0.70, 0.60, 0.65);
uniform vec4 deep_color    : source_color = vec4(0.02, 0.18, 0.45, 0.85);
uniform float wave_speed = 1.0;
uniform float wave_height = 0.0;
uniform float wave_freq = 8.0;
uniform bool low_quality = false;

void vertex() {
	if (wave_height > 0.001) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
		float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
		float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
		VERTEX.y += w1 + w2 + w3;
	}
}

void fragment() {
	float density = COLOR.r;
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, density);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wuv = world_pos.xz * 3.0;
	float caustic;
	if (low_quality) {
		caustic = max(0.0, sin(wuv.x * 3.0 + TIME * 1.2) * 0.06 + 0.06);
	} else {
		float c1 = sin(wuv.x * 4.0 + TIME * 1.2) * cos(wuv.y * 3.5 + TIME * 0.9);
		float c2 = sin(wuv.x * 6.0 - TIME * 1.5) * cos(wuv.y * 5.0 + TIME * 1.1);
		caustic = max(0.0, c1 * c2 * 0.12);
	}
	vec3 refl = vec3(0.55, 0.72, 0.90) * 0.06;
	vec3 final_col = water_col + refl + caustic;
	ALBEDO = final_col;
	ALPHA = mix(deep_color.a, shallow_color.a, density);
	ROUGHNESS = mix(0.05, 0.25, density);
	METALLIC = mix(0.05, 0.0, density);
	SPECULAR = 0.3;
}
"""
	else:
		s.code = """
shader_type spatial;
render_mode blend_mix, unshaded;
uniform vec4 water_color : source_color = vec4(0.10, 0.55, 0.45, 0.70);
uniform vec4 emit_color  : source_color = vec4(0.08, 0.45, 0.35, 1.0);
uniform float wave_speed = 1.0;
uniform float wave_height = 0.0;
uniform float wave_freq = 6.0;

void vertex() {
	if (wave_height > 0.001) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
		float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
		float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
		VERTEX.y += w1 + w2 + w3;
	}
}

void fragment() {
	float density = COLOR.r;
	vec4 base = mix(vec4(water_color.rgb * 0.5, water_color.a + 0.1), water_color, density);
	ALBEDO = base.rgb; ALPHA = base.a;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	EMISSION = emit_color.rgb * (1.5 + sin(TIME * 0.5 + wp.x * 2.0 + wp.z * 3.0) * 0.5);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	var is_mob: bool = DeviceManager != null and DeviceManager.is_mobile()
	m.set_shader_parameter("low_quality", is_mob)
	return m

static var _mat_cache: Dictionary = {}

func _init_materials() -> void:
	if _mat_cache.has(_dimension_id): return
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		var m_t := StandardMaterial3D.new()
		m_t.vertex_color_use_as_albedo = true
		m_t.roughness = 0.9; m_t.metallic_specular = 0.0
		_mat_cache[_dimension_id] = { "terrain": m_t, "water": _make_water_shader(_dimension_id) }
		return
	var m_t := StandardMaterial3D.new()
	m_t.vertex_color_use_as_albedo = true
	m_t.roughness = 1.0; m_t.metallic_specular = 0.0
	_mat_cache[_dimension_id] = { "terrain": m_t, "water": _make_water_shader(_dimension_id) }

## ── apply_chunk: nhận data từ thread, tạo nodes ──────────────────────────────
func apply_chunk(data: Dictionary) -> void:
	if _built:
		return
	_mesh_cache[_cache_key(_cx, _cz, _dimension_id)] = data
	_biome_grid = data["biome_grid"]
	_has_water = data.get("has_water", false)
	_max_water_ly = _gen_water_top_layer() if _has_water else -1
	_has_ores = data.get("has_ores", false)
	_top_ly_cache = data.get("top_ly_hint", PackedInt32Array())

	# Khôi phục block_data
	var bdbytes: PackedByteArray = data.get("block_data_bytes", PackedByteArray())
	if not bdbytes.is_empty():
		block_data = _BlockData.new()
		block_data.from_bytes(bdbytes, _cols, _cols)

	var mesh: ArrayMesh = data["mesh"]
	if mesh == null:
		_built = true; return

	# ── Gom tất cả nodes vào 1 container, add_child 1 lần duy nhất ──────────
	# Mỗi add_child khi đã trong scene tree tốn kém vì trigger notification.
	# Tạo container ngoài tree → add hết children vào → add_child(container) 1 lần.
	var container := Node3D.new()

	# Xoá container cũ nếu có (phòng trường hợp apply_chunk gọi 2 lần)
	if _mesh_container != null:
		_mesh_container.queue_free()
		_mesh_container = null
	_terrain_mesh_instance = null
	_water_mesh_instance = null
	_aquatic_mesh_instance = null
	_textured_block_mesh_instances.clear()
	for light in _lotus_lights:
		LotusLightManager.unregister(light)
	_lotus_lights.clear()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	container.add_child(mi)
	_terrain_mesh_instance = mi

	var water_mesh = data.get("water_mesh")
	if water_mesh:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = water_mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		container.add_child(mi_w)
		_water_mesh_instance = mi_w

	var aquatic_mesh = data.get("aquatic_mesh")
	if aquatic_mesh:
		var mi_aq := MeshInstance3D.new()
		mi_aq.mesh = aquatic_mesh
		if not _mat_cache[_dimension_id].has("aquatic"):
			_mat_cache[_dimension_id]["aquatic"] = make_aquatic_mat()
		mi_aq.material_override = _mat_cache[_dimension_id]["aquatic"]
		mi_aq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi_aq)
		_aquatic_mesh_instance = mi_aq

	var textured_block_meshes: Dictionary = data.get("textured_block_meshes", {})
	for bid in textured_block_meshes:
		var ore_mesh: ArrayMesh = textured_block_meshes[bid] as ArrayMesh
		if ore_mesh:
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			container.add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	# Block hình dạng riêng (đá ¼, đá ⅛, đá phiến) — dữ liệu worker tính sẵn
	_apply_shaped_block_data(data)

	var gbd: Dictionary = data.get("grass_blade_data", {})
	var gxforms: Array = gbd.get("xforms", [])
	var gcolors: Array = gbd.get("colors", [])
	if gxforms.size() > 0:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cube.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cube
		mm.instance_count = gxforms.size()
		_multimesh_buffer(mm, gxforms, gcolors)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

	# Quán rượu — MultiMesh có bóng đổ
	var vbd: Dictionary = data.get("village_data", {})
	var vxforms: Array = vbd.get("xforms", [])
	var vcolors: Array = vbd.get("colors", [])
	if vxforms.size() > 0:
		var mmi_v := _build_xform_multimesh(vxforms, vcolors, true, false)
		container.add_child(mmi_v)

	var lotus_positions: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	for lpos in lotus_positions:
		var is_weed_light: bool = lpos.x > 400.0
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		if is_weed_light:
			light.light_color      = Color(1.0, 0.82, 0.08)  # vàng quả
			light.light_energy     = 0.6
			light.omni_range       = 8.0
		else:
			light.light_color      = Color(0.45, 0.85, 1.0)  # xanh sen
			light.light_energy     = 0.30
			light.omni_range       = 12.0
		light.omni_attenuation = 2.5
		light.shadow_enabled   = false
		light.light_specular   = 0.0
		light.position         = real_pos + Vector3(0, 0.15, 0)
		container.add_child(light)
		_lotus_lights.append(light)

	# 1 add_child duy nhất vào scene tree → 1 notification thay vì N
	add_child(container)
	_mesh_container = container

	# Đăng ký lotus lights sau khi đã vào tree
	for light in _lotus_lights:
		LotusLightManager.register(light)

	# Collision: queue (chunk, mesh) — shape ĐƯỢC TẠO TRÊN MAIN THREAD trong
	# CollisionQueue._process (rate-limited).
	# KHÔNG tạo shape trên worker: create_trimesh_shape → physics server
	# (Jolt) — không thread-safe ở bản này — hư hỏng → crash 0xC0000005 lúc
	# process thoát (đã tái hiện tất định bằng test_probe_tex).
	if is_instance_valid(CollisionQueue):
		CollisionQueue.push_mesh(self, mesh)


	# Spawn đèn đường — dùng positions đã tính sẵn trên worker thread
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		var lamp_positions: Array = data.get("lamp_positions", [])
		if not lamp_positions.is_empty():
			_RoadLamp.spawn_from_data(self, lamp_positions)

	# Spawn plant props (taro, seaweed, seagrass) — global budget shared toàn
	# game để tránh nhiều chunk cùng bắn prop nặng trong 1 frame. Sắp prop rẻ
	# (weed/seagrass) lên trước để cây nặng spawn sau khi budget còn.
	_prop_queue = data.get("plant_props", []).duplicate()
	_prop_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _prop_cost(a.get("type", "weed")) < _prop_cost(b.get("type", "weed")))
	if not _prop_queue.is_empty():
		set_process(true)

	_built = true

## Process prop queue — global budget để tránh spike khi nhiều chunk cùng stream.
## Budget chia sẻ toàn game; prop rẻ (weed/seagrass) ưu tiên spawn trước.
func _process(delta: float) -> void:
	if not props_enabled:
		_prop_queue.clear()
		set_process(false)
		return
	_prop_reset_budget()
	if _prop_budget_remaining <= 0:
		return
	var count: int = mini(3, _prop_queue.size())
	for _i in range(count):
		if _prop_queue.is_empty():
			break
		if _prop_budget_remaining <= 0:
			break
		var pd: Dictionary = _prop_queue.pop_front()
		var ptype: String = pd.get("type", "weed")
		_prop_budget_remaining -= _prop_cost(ptype)
		if ptype == "palm":
			var prop := _PalmProp.new(150, DestroyableProp.WeaponReq.AXE, "palm_wood")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "river"))
			add_child(prop)
		elif ptype == "oak":
			var prop := _OakProp.new(250, DestroyableProp.WeaponReq.AXE, "block_oak_wood")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			add_child(prop)
		elif ptype == "orange_tree":
			var prop := _OrangeTreeProp.new(150, DestroyableProp.WeaponReq.AXE, "orange")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			add_child(prop)
		elif ptype == "dense_tree":
			var prop := _DenseTreeProp.new(200, DestroyableProp.WeaponReq.AXE, "block_hard_wood")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "plains"))
			add_child(prop)
		elif ptype == "eggplant":
			var prop := _EggplantProp.new(40, DestroyableProp.WeaponReq.SWORD, "eggplant_fruit")
			prop.position = pd["pos"]
			prop.setup()
			add_child(prop)
		elif ptype == "watermelon":
			var prop := _WatermelonVine.new(40, DestroyableProp.WeaponReq.SWORD, "watermelon")
			prop.position = pd["pos"]
			prop.setup()
			add_child(prop)
		elif ptype == "pumpkin":
			var prop := _PumpkinVine.new(40, DestroyableProp.WeaponReq.SWORD, "pumpkin")
			prop.position = pd["pos"]
			prop.setup()
			add_child(prop)
		else:
			var drop_id: String = "tropical_seaweed" if ptype == "weed" \
				else ("taro" if ptype == "taro" else "seagrass")
			var prop := PlantProp.new(50, DestroyableProp.WeaponReq.SWORD, drop_id)
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0),
				pd.get("has_silt", false), pd.get("water_gap", 1.0),
				pd.get("meadow", false))
			add_child(prop)
	if _prop_queue.is_empty():
		set_process(false)

	# Water flow tick (disabled — water is static blocks now)
	#_water_tick_timer -= delta
	#if _water_tick_timer <= 0.0:
	#	_water_tick_timer = 0.5
	#	var nb_data := _get_neighbor_water_data()
	#	if _WaterFlow.tick_flow(self, nb_data):
	#		rebuild_water_mesh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Unregister lotus lights
		for light in _lotus_lights:
			if is_instance_valid(light):
				LotusLightManager.unregister(light)
		_lotus_lights.clear()
		# Xóa collision entries pending trong queue — tránh apply sau khi freed
		if CollisionQueue:
			CollisionQueue.remove_chunk(self)
		if WaterRebuildQueue:
			WaterRebuildQueue.clear_for_chunk(get_instance_id())
		# Evict mesh cache khi chunk bị free — chống phình bộ nhớ vô hạn khi
		# lướt thế giới (cache chỉ giữ dữ liệu chunk đang/đã load).
		if _was_setup:
			_mesh_cache.erase(_cache_key(_cx, _cz, _dimension_id))
			WorldChunk._unregister_chunk(_cx, _cz, _dimension_id)

func _apply_collision(shape: Shape3D) -> void:
	if not is_inside_tree(): return
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

## ── Decorative rebuild (async) for elements skipped in fast_mode ──────────
func _schedule_decorative_rebuild() -> void:
	if block_data == null or _biome_grid.is_empty():
		return
	var ck: String = _cache_key(_cx, _cz, _dimension_id)
	_pending_mutex.lock()
	_pending_chunks[ck] = self
	_pending_mutex.unlock()
	_track_task(WorkerThreadPool.add_task(
		_thread_rebuild_decorative.bind(ck, _cx, _cz, _size, _dimension_id),
		true, "decorative"))

static func _thread_rebuild_decorative(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	_pending_mutex.lock()
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	_pending_mutex.unlock()
	if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	chunk.call_deferred("apply_decorative", {
		"grass_blade_data": data.get("grass_blade_data", {}),
		"village_data": data.get("village_data", {}),
		"textured_block_meshes": data.get("textured_block_meshes", {}),
		"lamp_positions": data.get("lamp_positions", [])
	})

func apply_decorative(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var container := _mesh_container
	if container == null:
		container = Node3D.new()
		add_child(container)
		_mesh_container = container

	var gbd: Dictionary = data.get("grass_blade_data", {})
	var gxforms: Array = gbd.get("xforms", [])
	var gcolors: Array = gbd.get("colors", [])
	if gxforms.size() > 0:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cube.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cube
		mm.instance_count = gxforms.size()
		_multimesh_buffer(mm, gxforms, gcolors)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

	var vbd: Dictionary = data.get("village_data", {})
	var vxforms: Array = vbd.get("xforms", [])
	var vcolors: Array = vbd.get("colors", [])
	if vxforms.size() > 0:
		var mmi_v := _build_xform_multimesh(vxforms, vcolors, true, false)
		container.add_child(mmi_v)

	var ore_meshes: Dictionary = data.get("textured_block_meshes", {})
	for bid in ore_meshes:
		var ore_mesh := ore_meshes[bid] as ArrayMesh
		if ore_mesh and not _textured_block_mesh_instances.has(bid):
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			container.add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	var lamp_positions: Array = data.get("lamp_positions", [])
	if not lamp_positions.is_empty() and _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		_RoadLamp.spawn_from_data(self, lamp_positions)

## ── rebuild_mesh: gọi khi block thay đổi (mine/place) ────────────────────────
## Chỉ thay thế terrain mesh + collision, không đụng mesh khác (cỏ, nước, ...)
## `at` = local block vừa đổi — dùng để cập nhật _top_ly_cache O(1) thay vì scan lại
func rebuild_mesh(at := Vector3i(-1, -1, -1)) -> void:
	if block_data == null: return

	# Cập nhật cache top layer cho column bị thay đổi
	if at.x >= 0 and _top_ly_cache.size() == _cols * _cols \
			and at.x < _cols and at.z < _cols:
		_update_top_ly_cache(at)
	else:
		# Fallback (save reload, ...) — scan lại toàn bộ
		_top_ly_cache = _build_top_ly_cache()

	# Xóa collision cũ
	for ch in get_children():
		if ch is StaticBody3D:
			ch.queue_free()

	# Xóa terrain mesh cũ, giữ nguyên mesh khác (cỏ, nước, thuỷ sinh, ...)
	if _terrain_mesh_instance != null and is_instance_valid(_terrain_mesh_instance):
		_terrain_mesh_instance.queue_free()
		_terrain_mesh_instance = null

	# Xóa overlay mesh instances cũ (ore blocks) — nay đã bake vào terrain mesh
	for bid in _textured_block_mesh_instances:
		var old := _textured_block_mesh_instances[bid]
		if is_instance_valid(old):
			old.queue_free()
	_textured_block_mesh_instances.clear()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, block_data, _cols, _dimension_id, _top_ly_cache)
	var mesh := st.commit()
	if mesh == null: return

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	if _mesh_container != null:
		_mesh_container.add_child(mi)
	else:
		add_child(mi)
	_terrain_mesh_instance = mi

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)

	# Rebuild textured block (ore) overlay meshes — scan lại từ block_data
	# (không dùng cờ _has_ores: ore đặt tay vào chunk chưa từng có ore sẽ bị mất texture)
	var max_top_ly: int = -1
	if _top_ly_cache.size() == _cols * _cols:
		max_top_ly = 0
		for ly_v in _top_ly_cache:
			max_top_ly = maxi(max_top_ly, ly_v)
	var ore_meshes := _build_textured_block_meshes(block_data, _cols, max_top_ly)
	_has_ores = not ore_meshes.is_empty()
	for bid in ore_meshes:
		var ore_mesh: ArrayMesh = ore_meshes[bid]
		if ore_mesh:
			var mi_o := MeshInstance3D.new()
			mi_o.mesh = ore_mesh
			mi_o.material_override = _get_textured_block_material(bid)
			mi_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if _mesh_container != null:
				_mesh_container.add_child(mi_o)
			else:
				add_child(mi_o)
			_textured_block_mesh_instances[bid] = mi_o

	# Rebuild đất tơi xốp overlay (ẩm/khô theo nước lân cận)
	rebuild_soil_mesh()

	_build_shaped_block_nodes()

	block_data.dirty = false

## ── Block có hình dạng riêng (đá ¼, đá ⅛, đá phiến mỏng...) ─────────────────
## Scan block_data, vẽ hộp nhỏ theo kích thước shape + collision riêng (hộp).
## Shape block KHÔNG vào heightmap/terrain mesh — vẽ đè lên như overlay.
## Block hình dạng riêng (đá ¼, đá ⅛, đá phiến). Scan thẳng PackedByteArray
## (bỏ 70K lời gọi get_block + bounds-check), gộp MỌI collider vào 1 StaticBody3D
## và dùng chung 3 BoxShape3D — trước đây mỗi block tạo 1 body + 1 shape mới
## ngay trên main thread (chunk đã trong tree → đăng ký physics Jolt từng body).
var _shaped_collider: StaticBody3D = null

## ── Build shaped-block overlay mesh + danh sách hộp collider (CHẠY TRÊN WORKER) ──
## Scan toàn bộ block_data tốn ~30ms (đo test_stream_profile) — tách khỏi main
## thread để apply_chunk không gây giật khi load chunk. Main thread chỉ nhận
## mesh có sẵn + tạo StaticBody3D từ danh sách hộp (nhanh).
static func _empty_shaped_data() -> Dictionary:
	return { "shaped_mesh": null, "shaped_pos": PackedVector3Array(), "shaped_size": PackedVector3Array() }

static func _build_shaped_block_data(bd: _BlockData, cols: int, dim_id: int) -> Dictionary:
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW
	var half: float = float(cols) * _Data.VOXEL * 0.5
	var raw: PackedByteArray = bd._data
	var raw_h: int = bd._chunk_h
	var raw_w: int = bd.size_z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos_data := PackedVector3Array()
	var size_data := PackedVector3Array()
	for x in range(cols):
		var xbase: int = x * raw_h * raw_w
		var wx: float = -half + (float(x) + 0.5) * _Data.VOXEL
		for z in range(cols):
			var wz: float = -half + (float(z) + 0.5) * _Data.VOXEL
			for ly in range(raw_h):
				var blk: int = raw[xbase + ly * raw_w + z]
				var shape: Vector3 = _Data.block_shape(blk)
				if shape == Vector3.ZERO:
					continue
				var bottom: float = float(ly + _BlockData.Y_MIN) * _BlockData.SLAB_HEIGHT
				var pos := Vector3(wx, bottom + shape.y * 0.5, wz)
				_add_shaped_box(st, pos, shape, colors[blk])
				pos_data.append(pos)
				size_data.append(shape)
	var mesh: ArrayMesh = null
	if pos_data.size() > 0:
		mesh = st.commit()
	return { "shaped_mesh": mesh, "shaped_pos": pos_data, "shaped_size": size_data }

## ── Áp dụng shaped-block data đã tính sẵn trên worker (main thread) ──────────
## Chỉ tạo MeshInstance3D + 1 StaticBody3D gộp mọi hộp — KHÔNG scan block_data.
func _apply_shaped_block_data(data: Dictionary) -> void:
	for mi in _shaped_block_instances:
		if is_instance_valid(mi):
			mi.queue_free()
	_shaped_block_instances.clear()
	if _shaped_collider != null:
		if is_instance_valid(_shaped_collider):
			_shaped_collider.queue_free()
		_shaped_collider = null
	var smesh: ArrayMesh = data.get("shaped_mesh")
	if smesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = smesh
		mi.material_override = _mat_cache[_dimension_id]["terrain"]
		if _mesh_container != null:
			_mesh_container.add_child(mi)
		else:
			add_child(mi)
		_shaped_block_instances.append(mi)
	var pos: PackedVector3Array = data.get("shaped_pos", PackedVector3Array())
	if pos.size() == 0:
		return
	var size: PackedVector3Array = data.get("shaped_size", PackedVector3Array())
	var shape_cache: Dictionary = {}
	var body := StaticBody3D.new()
	for i in range(pos.size()):
		var skey: String = "%.2f|%.2f|%.2f" % [size[i].x, size[i].y, size[i].z]
		var bs: BoxShape3D = shape_cache.get(skey)
		if bs == null:
			bs = BoxShape3D.new()
			bs.size = size[i]
			shape_cache[skey] = bs
		var cs := CollisionShape3D.new()
		cs.shape = bs
		cs.position = pos[i]
		body.add_child(cs)
	body.name = "ShapedPhysics"
	add_child(body)
	_shaped_collider = body

## Bản dùng cho rebuild_mesh (khi player phá/đặt block) — hiếm, giữ scan trên
## main thread. Load chunk thường dùng _apply_shaped_block_data (worker tính sẵn).
func _build_shaped_block_nodes() -> void:
	if block_data == null:
		return
	_apply_shaped_block_data(_build_shaped_block_data(block_data, _cols, _dimension_id))

## Vẽ hộp 6 mặt bằng màu block (top sáng, side tối, đáy tối nhất).
static func _add_shaped_box(st: SurfaceTool, center: Vector3, size: Vector3, top_col: Color) -> void:
	var h: Vector3 = size * 0.5
	var side_col := _Data.block_side_color(top_col)
	var bot_col := Color(top_col.r * 0.35, top_col.g * 0.35, top_col.b * 0.35, top_col.a)
	_Terrain._add_quad(st, center + Vector3(0, h.y, 0),
		Vector3(h.x, 0, 0), Vector3(0, 0, h.z), Vector3(0, 1, 0), top_col)
	_Terrain._add_quad(st, center - Vector3(0, h.y, 0),
		Vector3(h.x, 0, 0), Vector3(0, 0, h.z), Vector3(0, -1, 0), bot_col)
	_Terrain._add_quad(st, center + Vector3(0, 0, h.z),
		Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, 1), side_col)
	_Terrain._add_quad(st, center - Vector3(0, 0, h.z),
		Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, -1), side_col)
	_Terrain._add_quad(st, center + Vector3(h.x, 0, 0),
		Vector3(0, 0, h.z), Vector3(0, h.y, 0), Vector3(1, 0, 0), side_col)
	_Terrain._add_quad(st, center - Vector3(h.x, 0, 0),
		Vector3(0, 0, h.z), Vector3(0, h.y, 0), Vector3(-1, 0, 0), side_col)

## ── Cập nhật _top_ly_cache cho 1 column sau khi block đổi ────────────────────
func _update_top_ly_cache(at: Vector3i) -> void:
	var idx := at.x * _cols + at.z
	var old_top: int = _top_ly_cache[idx]
	var blk := block_data.get_block(at.x, at.y, at.z)
	if blk != _Data.BlockID.AIR and not _is_water_bid(blk) \
			and not _Data.is_shaped_block(blk):
		# Block solid mới — nâng top nếu đặt cao hơn bề mặt hiện tại
		_top_ly_cache[idx] = maxi(old_top, at.y)
	elif at.y >= old_top:
		# Block trên đỉnh bị phá / thay bằng air/water — tìm top solid mới
		var ly := at.y - 1
		while ly >= 0:
			var b := block_data.get_block(at.x, ly, at.z)
			if b != _Data.BlockID.AIR and not _is_water_bid(b) \
					and not _Data.is_shaped_block(b):
				break
			ly -= 1
		_top_ly_cache[idx] = ly
	# else: phá block dưới đỉnh → top không đổi

## ── Build lại toàn bộ top_ly cache từ block_data (fallback hiếm gặp) ─────────
func _build_top_ly_cache() -> PackedInt32Array:
	var cache := PackedInt32Array()
	cache.resize(_cols * _cols)
	for x in range(_cols):
		for z in range(_cols):
			var top := -1
			for ly in range(_BlockData.CHUNK_H - 1, -1, -1):
				var blk := block_data.get_block(x, ly, z)
				if blk != _Data.BlockID.AIR and not _is_water_bid(blk) \
						and not _Data.is_shaped_block(blk):
					top = ly
					break
			cache[x * _cols + z] = top
	return cache

## ── Block API (dùng cho building / mining) ───────────────────────────────────
## Đổi tọa độ world → local block index, rồi set_block + rebuild
func world_to_local_block(wx: float, wy: float, wz: float) -> Vector3i:
	var half: float = _size * 0.5
	var lx: int = int(floor(wx - (global_position.x - half)))
	var lz: int = int(floor(wz - (global_position.z - half)))
	var ly: int = _BlockData.world_y_to_layer(wy)
	return Vector3i(lx, ly, lz)

## Phá block tại world position. Trả về block_id đã xoá (0 = không có gì).
## BEDROCK không thể phá vỡ. WATER có thể phá (múc).
func break_block_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return 0
	var blk := world_to_local_block(wx, wy, wz)
	var old_id: int = block_data.get_block(blk.x, blk.y, blk.z)
	if old_id == _Data.BlockID.AIR: return 0
	if old_id == _Data.BlockID.BEDROCK: return 0   # Bedrock không thể phá vỡ
	block_data.set_block(blk.x, blk.y, blk.z, _Data.BlockID.AIR)
	_water_tick_timer = 0.0
	if _is_water_bid(old_id):
		rebuild_water_mesh()
	else:
		rebuild_mesh(blk)
	# Kích hoạt water tick ở chunk lân cận nếu block ở biên
	_trigger_neighbor_water_tick(blk.x, blk.z)
	return old_id

## Đặt block tại world position.
func place_block_at(wx: float, wy: float, wz: float, block_id: int) -> bool:
	if block_data == null: return false
	var blk := world_to_local_block(wx, wy, wz)
	var cur: int = block_data.get_block(blk.x, blk.y, blk.z)
	if cur != _Data.BlockID.AIR and not _is_water_bid(cur): return false
	block_data.set_block(blk.x, blk.y, blk.z, block_id)
	_water_tick_timer = 0.0
	if _is_water_bid(block_id):
		_has_water = true
		_max_water_ly = maxi(_max_water_ly, blk.y)
		rebuild_water_mesh()
	elif _is_water_bid(cur):
		rebuild_water_mesh()
		rebuild_mesh(blk)
	else:
		if block_id == _Data.BlockID.TILLED_SOIL:
			_has_soil = true
		rebuild_mesh(blk)
	_trigger_neighbor_water_tick(blk.x, blk.z)
	return true

## ── Cuốc đất: GRASS/DARK_GRASS/DIRT/DARK_DIRT → TILLED_SOIL ─────────────────
## Trả về block cũ đã cuốc (0 = không cuốc được).
func till_block_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return 0
	var blk := world_to_local_block(wx, wy, wz)
	var old_id: int = block_data.get_block(blk.x, blk.y, blk.z)
	if not _Data.is_tillable(old_id): return 0
	block_data.set_block(blk.x, blk.y, blk.z, _Data.BlockID.TILLED_SOIL)
	_has_soil = true
	_water_tick_timer = 0.0
	rebuild_mesh(blk)
	return old_id

## ── rebuild_soil_mesh: rebuild overlay đất tơi xốp (khô/ẩm theo nước) ───────
func rebuild_soil_mesh() -> void:
	if block_data == null: return
	if not _has_soil:
		_has_soil = _scan_has_soil()
		if not _has_soil: return
	var nb_data := _get_neighbor_water_data()
	var mesh := _build_soil_mesh(block_data, _cols, nb_data)
	if mesh == null or mesh.get_surface_count() == 0:
		_has_soil = false
		_remove_soil_mesh_instance()
		return
	_has_soil = true
	var mi := _textured_block_mesh_instances.get(_Data.BlockID.TILLED_SOIL) as MeshInstance3D
	if mi == null or not is_instance_valid(mi):
		mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _get_textured_block_material(_Data.BlockID.TILLED_SOIL)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh_container != null:
			_mesh_container.add_child(mi)
		else:
			add_child(mi)
		_textured_block_mesh_instances[_Data.BlockID.TILLED_SOIL] = mi
	else:
		mi.mesh = mesh

func _remove_soil_mesh_instance() -> void:
	var mi := _textured_block_mesh_instances.get(_Data.BlockID.TILLED_SOIL) as MeshInstance3D
	if mi != null and is_instance_valid(mi):
		mi.queue_free()
	_textured_block_mesh_instances.erase(_Data.BlockID.TILLED_SOIL)

## Đất tơi xốp luôn nằm trên bề mặt → scan theo top_ly_cache (625 lookup, rẻ).
func _scan_has_soil() -> bool:
	var cols := _cols
	if _top_ly_cache.size() != cols * cols:
		return false
	for x in range(cols):
		for z in range(cols):
			var ly: int = _top_ly_cache[x * cols + z]
			if ly < 0: continue
			if block_data.get_block(x, ly, z) == _Data.BlockID.TILLED_SOIL:
				return true
	return false

## ── Aquatic shader ────────────────────────────────────────────────────────────
static func make_aquatic_mat() -> ShaderMaterial:
	return _build_aquatic_shader()

static func _build_aquatic_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed  : hint_range(0.1, 5.0) = 1.6;
uniform float sway_amount : hint_range(0.0, 0.5) = 0.035;
uniform float sway_freq   : hint_range(0.1, 8.0) = 2.8;
void vertex() {
	float is_flat = step(0.85, abs(NORMAL.y));
	float height_factor = max(0.0, VERTEX.y + 0.5) * 0.7;
	float phase_x = VERTEX.x * 3.7 + VERTEX.z * 1.3;
	float phase_z = VERTEX.z * 3.1 + VERTEX.x * 1.7;
	float w1  = sin(TIME * sway_speed + phase_x) * sway_amount * height_factor;
	float w1z = sin(TIME * sway_speed * 0.73 + phase_z + 1.1) * sway_amount * 0.6 * height_factor;
	float w2  = sin(TIME * sway_speed * 2.1 + phase_x * 0.5 + 0.4) * sway_amount * 0.3 * height_factor;
	float w2z = sin(TIME * sway_speed * 1.85 + phase_z * 0.6 + 2.2) * sway_amount * 0.25 * height_factor;
	float w3  = sin(TIME * sway_speed * 4.3 + phase_x * 1.2) * sway_amount * 0.12 * height_factor;
	VERTEX.x += w1 + w2 + w3;
	VERTEX.z += w1z + w2z;
}
void fragment() {
	vec4 col = COLOR * albedo_tint;
	if (col.a < 0.35) discard;
	ALBEDO = col.rgb; ALPHA = col.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = 1
	return m

## ── is_water_at: kiểm tra block data thực tế (tất cả loại nước) ──────────────
func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if block_data == null: return false
	var half: float = _size * 0.5
	var vx: int = int((wx - (global_position.x - half)) / _Data.VOXEL)
	var vz: int = int((wz - (global_position.z - half)) / _Data.VOXEL)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols: return false
	var layer: int = _BlockData.world_y_to_layer(wy)
	return _is_water_bid(block_data.get_block(vx, layer, vz))

## ── _get_neighbor_water_data: lấy block data của 4 chunk lân cận ─────────────
func _get_neighbor_water_data() -> Dictionary:
	var parent := get_parent()
	if parent == null: return {}
	var chunks: Dictionary
	if "_chunks" in parent:
		chunks = parent._chunks
	else:
		return {}
	var res: Dictionary = {}
	var w_key := Vector2i(_cx - 1, _cz)
	if chunks.has(w_key):
		var nb := chunks[w_key] as WorldChunk
		if nb and nb.block_data:
			res["w"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var e_key := Vector2i(_cx + 1, _cz)
	if chunks.has(e_key):
		var nb := chunks[e_key] as WorldChunk
		if nb and nb.block_data:
			res["e"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var n_key := Vector2i(_cx, _cz - 1)
	if chunks.has(n_key):
		var nb := chunks[n_key] as WorldChunk
		if nb and nb.block_data:
			res["n"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	var s_key := Vector2i(_cx, _cz + 1)
	if chunks.has(s_key):
		var nb := chunks[s_key] as WorldChunk
		if nb and nb.block_data:
			res["s"] = {"bd": nb.block_data, "chunk": nb, "cols": nb._cols}
	return res

## ── _trigger_neighbor_water_tick: nếu block ở biên, kích water tick ở lân cận ─
func _trigger_neighbor_water_tick(lx: int, lz: int) -> void:
	if lx > 0 and lx < _cols - 1 and lz > 0 and lz < _cols - 1:
		return  # không ở biên
	var parent := get_parent()
	if parent == null: return
	var chunks: Dictionary
	if "_chunks" in parent:
		chunks = parent._chunks
	else:
		return
	if lx == 0:
		var key := Vector2i(_cx - 1, _cz)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lx == _cols - 1:
		var key := Vector2i(_cx + 1, _cz)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lz == 0:
		var key := Vector2i(_cx, _cz - 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()
	if lz == _cols - 1:
		var key := Vector2i(_cx, _cz + 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb:
				if nb._has_water:
					nb._water_tick_timer = 0.0
					nb.rebuild_water_mesh()
				nb.rebuild_soil_mesh()

## ── _add_quad (shared helper, delegates to Terrain) ─────────────────────────
static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3, col: Color) -> void:
	_Terrain._add_quad(st, center, u, v, n, col)
