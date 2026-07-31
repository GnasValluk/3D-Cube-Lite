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
const _Terrain = preload("chunk_terrain.gd")
const _WaterFlow = preload("water_flow.gd")

static func _is_water_bid(bid: int) -> bool:
	return bid == _Data.BlockID.WATER \
		or (bid >= _Data.BlockID.WATER_SOURCE and bid <= _Data.BlockID.WATER_LEVEL_1)

static func _water_level_of(bid: int) -> int:
	if bid == _Data.BlockID.WATER_SOURCE or bid == _Data.BlockID.WATER:
		return 8
	if bid >= _Data.BlockID.WATER_LEVEL_7 and bid <= _Data.BlockID.WATER_LEVEL_1:
		return 8 - (bid - _Data.BlockID.WATER_LEVEL_7)
	return 0

## ── _gen_water_top_layer: layer cao nhất nước generation có thể tồn tại ─────
static func _gen_water_top_layer() -> int:
	return floori((_Data.WATER_Y - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN

var _cx: int = 0
var _cz: int = 0
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
var _top_ly_cache := PackedInt32Array()

## Block data — cho phép set_block / get_block sau này (build/mine)
var block_data: _BlockData = null

## References to per-type meshes (preserved across rebuilds)
var _terrain_mesh_instance: MeshInstance3D = null
var _water_mesh_instance: MeshInstance3D = null
var _aquatic_mesh_instance: MeshInstance3D = null
var _sediment_mesh_instance: MeshInstance3D = null
var _textured_block_mesh_instances: Dictionary[int, MeshInstance3D] = {}
var _mesh_container: Node3D = null
var _lotus_lights: Array[OmniLight3D] = []
var _prop_queue: Array = []

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}
var _pending_data: Dictionary = {}
static var _river_noise: FastNoiseLite = null
static var _river_bed_noise: FastNoiseLite = null

static func _ensure_river_noise() -> void:
	if _river_noise == null:
		_river_noise = FastNoiseLite.new()
		_river_noise.seed = WorldSeed.seed_value + 9999
		_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_river_noise.frequency = 0.06
	if _river_bed_noise == null:
		_river_bed_noise = FastNoiseLite.new()
		_river_bed_noise.seed = WorldSeed.seed_value + 10101
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
	var seed_v: int = WorldSeed.seed_value
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
	if _networks_ready and _networks_seed == seed_v:
		return
	if _prewarm_running:
		return
	# Chặn ngay trên main thread — tránh loading screen start world với dữ liệu cũ
	_networks_ready = false
	_prewarm_running = true
	WorkerThreadPool.add_task(_prewarm_networks)

static func _is_on_road(wx: float, wz: float) -> bool:
	return _Road.is_on_road(wx, wz)

static func _is_on_river(wx: float, wz: float) -> bool:
	return _River.is_on_river(wx, wz)

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

func setup(cx: int, cz: int, size: int,
		dimension_id: int = _Data._Dim.DimensionID.TWILIGHT, sync: bool = false) -> void:
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_cols = int(_size / _Data.VOXEL)
	_tiles_per_chunk = int(_cols / _Data.TILE_W)
	_init_materials()
	_water_tick_timer = randf_range(0.0, 0.5)

	var ck: String = _cache_key(cx, cz, dimension_id)
	if _mesh_cache.has(ck):
		apply_chunk(_mesh_cache[ck])
		return

	if sync:
		apply_chunk(compute_chunk(cx, cz, size, dimension_id, true))
		call_deferred("_schedule_decorative_rebuild")
		return

	_pending_chunks[ck] = self
	WorkerThreadPool.add_task(
		_thread_build.bind(ck, cx, cz, size, dimension_id), true, "chunk")

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
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
	var dst: Array[Array] = []
	dst.resize(total)
	for vx in range(total):
		var row: Array = []; row.resize(total); dst[vx] = row
		for vz in range(total):
			row[vz] = 0 if bio[vx][vz] == _Data.TileType.DARK_GRASS else _Data.CONST_INF
	for vx in range(total):
		for vz in range(total):
			if bio[vx][vz] != _Data.TileType.GRASS and bio[vx][vz] != _Data.TileType.DESERT: continue
			if (vx > 0 and bio[vx-1][vz] == _Data.TileType.DARK_GRASS) \
			or (vx < total-1 and bio[vx+1][vz] == _Data.TileType.DARK_GRASS) \
			or (vz > 0 and bio[vx][vz-1] == _Data.TileType.DARK_GRASS) \
			or (vz < total-1 and bio[vx][vz+1] == _Data.TileType.DARK_GRASS):
				dst[vx][vz] = 1
	for d in range(2, _Data.PAD + 1):
		for vx in range(total):
			for vz in range(total):
				if dst[vx][vz] != _Data.CONST_INF: continue
				if (vx > 0 and dst[vx-1][vz] == d-1) \
				or (vx < total-1 and dst[vx+1][vz] == d-1) \
				or (vz > 0 and dst[vx][vz-1] == d-1) \
				or (vz < total-1 and dst[vx][vz+1] == d-1):
					dst[vx][vz] = d

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

	var nd: Dictionary = {}
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		nd = _Noise._noise_for_dim(dim_id)
		var n_lake: FastNoiseLite      = nd["lake"]
		var n_lake_type: FastNoiseLite = nd["lake_type"]
		var n_biome: FastNoiseLite     = nd["biome"]
		var n_ocean_pre: FastNoiseLite = nd["ocean"]

		# ── Ocean mask (BFS padded) — stride 2, ~75% fewer noise calls ─────────
		const OCEAN_PAD: int = 26
		var oct_total: int = cols + 2 * OCEAN_PAD
		var oct: Array[Array] = []
		oct.resize(oct_total)
		for pvx in range(oct_total):
			oct[pvx] = []; oct[pvx].resize(oct_total)
		var ow: FastNoiseLite = nd["ocean_warp"]
		for pvx in range(0, oct_total, 2):
			for pvz in range(0, oct_total, 2):
				var wx: float = world_ox - half + (float(pvx - OCEAN_PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - OCEAN_PAD) + 0.5) * _Data.VOXEL
				var warp_x: float = ow.get_noise_2d(wx * 0.5, wz * 0.5) * 200.0
				var warp_z: float = ow.get_noise_2d(wx * 0.5 + 100.0, wz * 0.5 + 100.0) * 200.0
				oct[pvx][pvz] = (n_ocean_pre.get_noise_2d(wx + warp_x, wz + warp_z) + 1.0) * 0.5 > _Data.OCEAN_THRESHOLD
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
		var odst: Array[Array] = []
		odst.resize(total)
		for pvx in range(total):
			odst[pvx] = []; odst[pvx].resize(total)
			for pvz in range(total):
				odst[pvx][pvz] = 0 if oct_small[pvx][pvz] else _Data.CONST_INF
		for d in range(1, OCEAN_BUFFER + _Data.BEACH_WIDTH + 2):
			for pvx in range(total):
				for pvz in range(total):
					if odst[pvx][pvz] != _Data.CONST_INF: continue
					if (pvx > 0 and odst[pvx-1][pvz] == d-1) \
					or (pvx < total-1 and odst[pvx+1][pvz] == d-1) \
					or (pvz > 0 and odst[pvx][pvz-1] == d-1) \
					or (pvz < total-1 and odst[pvx][pvz+1] == d-1):
						odst[pvx][pvz] = d

		var shore_dst: Array[Array] = []
		shore_dst.resize(total)
		for pvx in range(total):
			shore_dst[pvx] = []; shore_dst[pvx].resize(total)
			for pvz in range(total):
				var is_oc: bool = oct_small[pvx][pvz]
				if is_oc:
					var adj_land: bool = false
					if pvx > 0 and not oct_small[pvx-1][pvz]: adj_land = true
					elif pvx < total-1 and not oct_small[pvx+1][pvz]: adj_land = true
					elif pvz > 0 and not oct_small[pvx][pvz-1]: adj_land = true
					elif pvz < total-1 and not oct_small[pvx][pvz+1]: adj_land = true
					shore_dst[pvx][pvz] = 1 if adj_land else _Data.CONST_INF
				else:
					shore_dst[pvx][pvz] = _Data.CONST_INF
		const MAX_OCEAN_DEPTH_DIST: int = 30
		for d in range(2, MAX_OCEAN_DEPTH_DIST + 1):
			for pvx in range(total):
				for pvz in range(total):
					if not oct_small[pvx][pvz]: continue
					if shore_dst[pvx][pvz] != _Data.CONST_INF: continue
					if (pvx > 0 and shore_dst[pvx-1][pvz] == d-1) \
					or (pvx < total-1 and shore_dst[pvx+1][pvz] == d-1) \
					or (pvz > 0 and shore_dst[pvx][pvz-1] == d-1) \
					or (pvz < total-1 and shore_dst[pvx][pvz+1] == d-1):
						shore_dst[pvx][pvz] = d

		# ── Single pass: biển → bãi biển → lục địa (có hồ) ────────────────
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var base_bio: int = bio[pvx][pvz]
				var od: int = odst[pvx][pvz]

				if od == 0:
					biome_grid[ivx][ivz] = _Data.TileType.OCEAN_DEEP
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var sd: int = shore_dst[pvx][pvz]
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
						biome_grid[ivx][ivz] = _Data.TileType.DARK_GRASS
						height_grid[ivx][ivz] = _Data.VOXEL
						var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
						var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
						var dn: float = (n_biome.get_noise_2d((wx+500.0)*0.7, (wz+500.0)*0.7) + 1.0) * 0.5
						if dn > 0.70:
							biome_grid[ivx][ivz] = _Data.TileType.DIRT
					else:
						var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
						var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
						var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
						var d: int = dst[pvx][pvz]

						var is_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						var lake_t: float = 0.60 if base_bio == _Data.TileType.DESERT else 0.96
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
					var d: int = dst[pvx][pvz]
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

	# ── 4. Road grid ──────────────────────────────────────────────────────────
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

	# ── 5. Tạo ChunkBlockData từ biome + height ────────────────────────────────
	var bd := _BlockData.new()
	bd.init(cols, cols)
	_Terrain.fill_blocks(bd, biome_grid, height_grid, road_grid, cols, dim_id, cx, cz, size, nd, reef_mask)

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

			if b == _Data.TileType.DIRT:
				_Detail.add_dirt_mounds(st, cx, cz, size, vx, vz, pos, 0.0)

			if not fast_mode and (b == _Data.TileType.GRASS or b == _Data.TileType.DARK_GRASS) and not is_road and h >= _Data.VOXEL * 0.9:
				_Grass.add_voxel_grass(vx, vz, pos, grass_xforms, grass_colors, cols, height_grid)
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

	# ── 8. Aquatic mesh — chỉ hồ (SAND/SILT), biển không có rong/sen ───────────
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
				# Chỉ SAND/SILT dưới mặt nước — biển (OCEAN_DEEP) không có rong
				if b != _Data.TileType.SAND and b != _Data.TileType.SAND_WHITE and b != _Data.TileType.SILT and b != _Data.TileType.MUDDY_SAND: continue
				if h > _Data.WATER_Y: continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				var is_river: bool = river_flag[vx * cols + vz] == 1
				var is_desert_water := false
				if b == _Data.TileType.SAND or b == _Data.TileType.MUDDY_SAND:
					for dx in range(-3, 4):
						for dz in range(-3, 4):
							var nx := vx + dx; var nz := vz + dz
							if nx < 0 or nx >= cols or nz < 0 or nz >= cols: continue
							if height_grid[nx][nz] > _Data.WATER_Y and biome_grid[nx][nz] == _Data.TileType.DESERT:
								is_desert_water = true; break
						if is_desert_water: break
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox,
					b == _Data.TileType.SILT, b, lotus_lights, plant_props, is_river, is_desert_water)
		mesh_aquatic = st_aq.commit()

	# ── 8b. Palm trees — on GRASS/DARK_GRASS land, ≥2 cells from water ─────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				if biome_grid[vx][vz] != _Data.TileType.GRASS and biome_grid[vx][vz] != _Data.TileType.DARK_GRASS:
					continue
				var h: float = height_grid[vx][vz]
				if h <= _Data.WATER_Y:
					continue
				var near_close := false
				var near_far := false
				for dx in range(-3, 4):
					for dz in range(-3, 4):
						var nx := vx + dx; var nz := vz + dz
						if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
							continue
						if height_grid[nx][nz] <= _Data.WATER_Y:
							var dist: int = maxi(abs(dx), abs(dz))
							if dist <= 1:
								near_close = true
							elif dist <= 3:
								near_far = true
				if near_far and not near_close and randf() < 0.004:
					var px := -half + (float(vx) + 0.5) * _Data.VOXEL
					var pz := -half + (float(vz) + 0.5) * _Data.VOXEL
					# Sink slightly into terrain, but never below water surface
					var y := maxf(h - 0.0625, _Data.WATER_Y + 0.0625)
					plant_props.append({"type": "palm", "pos": Vector3(px, y, pz), "variant": "river"})

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

	return {
		"mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic,
		"grass_blade_data": { "xforms": grass_xforms, "colors": grass_colors },
		"lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols,
		"block_data_bytes": bd.to_bytes(), "lamp_positions": lamp_positions,
		"sediment_mesh": (null if fast_mode else 	_Terrain.build_sediment_mesh(bd, cols)),
		"textured_block_meshes": ore_meshes,
		"plant_props": plant_props, "has_water": has_water,
		"has_ores": not ore_meshes.is_empty(),
		"top_ly_hint": top_ly_hint
	}



## ── _get_textured_block_material: tạo 8x8 texture procedural theo block ────
static var _textured_block_mats: Dictionary[int, Material] = {}
static func _get_textured_block_material(block_id: int) -> Material:
	if _textured_block_mats.has(block_id):
		return _textured_block_mats[block_id]
	var base: Color
	var speck_dark: Color
	var speck_light: Color
	var is_ore: bool = false
	match block_id:
		_Data.BlockID.SEDIMENT:
			base = Color(0.50, 0.20, 0.10)
			speck_dark = Color(0.55, 0.18, 0.08)
			speck_light = Color(0.65, 0.30, 0.12)
		_Data.BlockID.COPPER_ORE:
			is_ore = true
			base = Color(0.38, 0.35, 0.32)
			speck_dark = Color(0.30, 0.28, 0.25)
			speck_light = Color(0.80, 0.55, 0.25)
		_Data.BlockID.BAUXITE_ORE:
			is_ore = true
			base = Color(0.38, 0.35, 0.32)
			speck_dark = Color(0.30, 0.28, 0.25)
			speck_light = Color(0.70, 0.70, 0.72)
		_Data.BlockID.SILVER_ORE:
			is_ore = true
			base = Color(0.38, 0.38, 0.40)
			speck_dark = Color(0.30, 0.30, 0.32)
			speck_light = Color(0.85, 0.85, 0.92)
		_Data.BlockID.IRON_ORE:
			is_ore = true
			base = Color(0.36, 0.33, 0.28)
			speck_dark = Color(0.28, 0.25, 0.20)
			speck_light = Color(0.55, 0.50, 0.45)
		_Data.BlockID.GOLD_ORE:
			is_ore = true
			base = Color(0.38, 0.35, 0.30)
			speck_dark = Color(0.30, 0.28, 0.22)
			speck_light = Color(0.95, 0.80, 0.30)
		_Data.BlockID.TITAN_ORE:
			is_ore = true
			base = Color(0.36, 0.34, 0.38)
			speck_dark = Color(0.28, 0.26, 0.30)
			speck_light = Color(0.65, 0.55, 0.80)
		_Data.BlockID.PLATINUM_ORE:
			is_ore = true
			base = Color(0.38, 0.36, 0.38)
			speck_dark = Color(0.30, 0.28, 0.30)
			speck_light = Color(0.80, 0.85, 0.95)
		_:
			base = Color(0.50, 0.50, 0.50)
			speck_dark = Color(0.30, 0.30, 0.30)
			speck_light = Color(0.70, 0.70, 0.70)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			var h: int = x * 374761393 + y * 668265263 + 12345
			h = (h ^ (h >> 13)) * 1274126177
			h = h ^ (h >> 16)
			var r := float(h & 0x7FFFFFFF) / 2147483648.0
			var c := Color(
				base.r + (r - 0.5) * 0.20,
				base.g + (r - 0.5) * 0.15,
				base.b + (r - 0.5) * 0.12
			)
			h = h * 16807 + 1
			var speck := float(h & 0x7FFFFFFF) / 2147483648.0
			if is_ore:
				if speck > 0.82:
					c = speck_dark
				elif speck < 0.15:
					c = speck_light
			else:
				if speck > 0.92:
					c = speck_dark
				elif speck < 0.06:
					c = speck_light
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if is_ore:
		mat.roughness = 0.65
		mat.metallic_specular = 0.15
		mat.emission_enabled = true
		mat.emission_texture = tex
		mat.emission_energy_multiplier = 0.25
	else:
		mat.roughness = 0.9
		mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	_textured_block_mats[block_id] = mat
	return mat


## ── _build_textured_block_mesh: mesh có UV cho block có texture ─────────────
static func _build_textured_block_mesh(bd: _BlockData, cols: int, target_block_id: int) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	var top_ly := PackedInt32Array()
	top_ly.resize(cols * cols)
	top_ly.fill(-1)
	for x in range(cols):
		for z in range(cols):
			for ly in range(CHUNK_H - 1, -1, -1):
				if bd.get_block(x, ly, z) == target_block_id:
					top_ly[x * cols + z] = ly
					break

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
]

## Ore chưa được sinh trong generation — đặt true khi bật feature để bỏ scan
const _ORES_GENERATION_ENABLED: bool = false

static func _build_textured_block_meshes(bd: _BlockData, cols: int, max_ly: int = -1) -> Dictionary[int, ArrayMesh]:
	const CHUNK_H := _BlockData.CHUNK_H
	# Pre-scan 1 pass: tìm ore type nào thực sự có block (chỉ scan dưới bề mặt)
	if max_ly < 0:
		max_ly = CHUNK_H - 1
	max_ly = clampi(max_ly, 0, CHUNK_H - 1)
	var found: Dictionary = {}
	for bid in _TEXTURED_BLOCK_IDS:
		found[bid] = false
	for x in range(cols):
		for z in range(cols):
			for ly in range(max_ly + 1):
				var blk := bd.get_block(x, ly, z)
				if found.has(blk) and not found[blk]:
					found[blk] = true
	# Build mesh chỉ cho type có block
	var result: Dictionary[int, ArrayMesh] = {}
	for bid in _TEXTURED_BLOCK_IDS:
		if not found[bid]:
			continue
		var m := _build_textured_block_mesh(bd, cols, bid)
		if m and m.get_surface_count() > 0:
			result[bid] = m
	return result

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

	# Water level grid (0 = không nước, 1..8 = mức nước) — 1 pass duy nhất.
	# Mọi check mặt dùng index grid thay vì get_block (bỏ hàm call + bounds check).
	var grid := PackedByteArray()
	var glen: int = cols * cols * (max_ly + 1)
	grid.resize(glen)
	for x in range(cols):
		for z in range(cols):
			for ly in range(max_ly + 1):
				var bid: int = bd.get_block(x, ly, z)
				if _is_water_bid(bid):
					grid[(ly * cols + z) * cols + x] = _water_level_of(bid)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const EPS := 0.02  # tránh z-fight với vách terrain coplanar
	for x in range(cols):
		for z in range(cols):
			var px := -half + (float(x) + 0.5) * VOXEL
			var pz := -half + (float(z) + 0.5) * VOXEL
			for ly in range(max_ly + 1):
				var level: int = grid[(ly * cols + z) * cols + x]
				if level == 0:
					continue
				var depth: float = float(level) / 8.0
				var col := Color(depth, 0.0, 0.0)
				var py := (float(ly + Y_MIN) + 0.5) * SLAB
				var hv := SLAB * 0.5
				var hh := h_vox  # VOXEL/2

				# Top face (+y)
				if ly >= max_ly or grid[((ly + 1) * cols + z) * cols + x] == 0:
					_add_quad(st, Vector3(px, py + hv, pz), Vector3(hh,0,0), Vector3(0,0,hh), Vector3(0,1,0), col)
				# Bottom face (-y) — skip, không cần thiết
				# Right face (+x)
				if x + 1 < cols:
					if grid[(ly * cols + z) * cols + (x + 1)] == 0:
						_add_quad(st, Vector3(px + hh + EPS, py, pz), Vector3(0,hv,0), Vector3(0,0,hh), Vector3(1,0,0), col)
				elif not _nb_is_water(bd, nb_data, cols, x, ly, z, 1, 0):
					_add_quad(st, Vector3(px + hh + EPS, py, pz), Vector3(0,hv,0), Vector3(0,0,hh), Vector3(1,0,0), col)
				# Left face (-x)
				if x > 0:
					if grid[(ly * cols + z) * cols + (x - 1)] == 0:
						_add_quad(st, Vector3(px - hh - EPS, py, pz), Vector3(0,hv,0), Vector3(0,0,hh), Vector3(-1,0,0), col)
				elif not _nb_is_water(bd, nb_data, cols, x, ly, z, -1, 0):
					_add_quad(st, Vector3(px - hh - EPS, py, pz), Vector3(0,hv,0), Vector3(0,0,hh), Vector3(-1,0,0), col)
				# Front face (+z)
				if z + 1 < cols:
					if grid[(ly * cols + (z + 1)) * cols + x] == 0:
						_add_quad(st, Vector3(px, py, pz + hh + EPS), Vector3(hh,0,0), Vector3(0,hv,0), Vector3(0,0,1), col)
				elif not _nb_is_water(bd, nb_data, cols, x, ly, z, 0, 1):
					_add_quad(st, Vector3(px, py, pz + hh + EPS), Vector3(hh,0,0), Vector3(0,hv,0), Vector3(0,0,1), col)
				# Back face (-z)
				if z > 0:
					if grid[(ly * cols + (z - 1)) * cols + x] == 0:
						_add_quad(st, Vector3(px, py, pz - hh - EPS), Vector3(hh,0,0), Vector3(0,hv,0), Vector3(0,0,-1), col)
				elif not _nb_is_water(bd, nb_data, cols, x, ly, z, 0, -1):
					_add_quad(st, Vector3(px, py, pz - hh - EPS), Vector3(hh,0,0), Vector3(0,hv,0), Vector3(0,0,-1), col)
	return st.commit()

## ── _nb_is_water: kiểm tra nước tại (x+dx, z+dz), băng qua biên chunk ───────
static func _nb_is_water(bd: _BlockData, nb_data: Dictionary, cols: int,
		x: int, ly: int, z: int, dx: int, dz: int) -> bool:
	var nx: int = x + dx
	var nz: int = z + dz
	if nx >= 0 and nx < cols and nz >= 0 and nz < cols:
		return _is_water_bid(bd.get_block(nx, ly, nz))
	var dir: String
	if nx < 0: dir = "w"
	elif nx >= cols: dir = "e"
	elif nz < 0: dir = "n"
	else: dir = "s"
	if not nb_data.has(dir):
		return false
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
		return false
	return _is_water_bid(nb_bd.get_block(tx, ly, tz))

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

## ── refresh_boundary_water: rebuild water mesh của chunk + 4 lân cận ────────
func refresh_boundary_water() -> void:
	if _has_water:
		rebuild_water_mesh()
	var parent := get_parent()
	if parent == null: return
	var chunks: Dictionary
	if "_chunks" in parent:
		chunks = parent._chunks
	else:
		return
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var key := Vector2i(_cx + off.x, _cz + off.y)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb and nb.block_data and nb._has_water:
				nb.rebuild_water_mesh()

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

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
	float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
	float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
	VERTEX.y += w1 + w2 + w3;
}

void fragment() {
	float density = COLOR.r;
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, density);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wuv = world_pos.xz * 3.0;
	float c1 = sin(wuv.x * 4.0 + TIME * 1.2) * cos(wuv.y * 3.5 + TIME * 0.9);
	float c2 = sin(wuv.x * 6.0 - TIME * 1.5) * cos(wuv.y * 5.0 + TIME * 1.1);
	float caustic = max(0.0, c1 * c2 * 0.12);
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
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(TIME * wave_speed + world_pos.x * wave_freq + world_pos.z * wave_freq * 0.7) * wave_height;
	float w2 = sin(TIME * wave_speed * 1.7 + world_pos.x * wave_freq * 1.3 + world_pos.z * wave_freq * 0.9) * wave_height * 0.5;
	float w3 = sin(TIME * wave_speed * 2.4 + world_pos.x * wave_freq * 0.6 + world_pos.z * wave_freq * 1.5) * wave_height * 0.3;
	VERTEX.y += w1 + w2 + w3;
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
	_sediment_mesh_instance = null
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

	var sediment_mesh: ArrayMesh = data.get("sediment_mesh")
	if sediment_mesh:
		var mi_s := MeshInstance3D.new()
		mi_s.mesh = sediment_mesh
		mi_s.material_override = _Terrain.get_sediment_material()
		mi_s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi_s)
		_sediment_mesh_instance = mi_s

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
		for i in range(gxforms.size()):
			mm.set_instance_transform(i, gxforms[i] as Transform3D)
			mm.set_instance_color(i, gcolors[i] as Color)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

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

	# Collision trên worker thread — kết quả được queue vào CollisionQueue
	# thay vì call_deferred trực tiếp để rate-limit trên main thread
	var mesh_ref: ArrayMesh = mesh
	var chunk_id: int = get_instance_id()  # dùng ID thay vì reference trực tiếp
	WorkerThreadPool.add_task(func():
		var shape: Shape3D = mesh_ref.create_trimesh_shape()
		var chunk_inst = instance_from_id(chunk_id)
		if is_instance_valid(chunk_inst):
			CollisionQueue.push(chunk_inst, shape)
	, false, "collision")

	# Spawn đèn đường — dùng positions đã tính sẵn trên worker thread
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		var lamp_positions: Array = data.get("lamp_positions", [])
		if not lamp_positions.is_empty():
			_RoadLamp.spawn_from_data(self, lamp_positions)

	# Spawn plant props (taro, seaweed) — throttle 2 props/frame
	_prop_queue = data.get("plant_props", []).duplicate()
	if not _prop_queue.is_empty():
		set_process(true)

	_built = true

## Process prop queue — 2 props/frame để tránh spike
func _process(delta: float) -> void:
	var count: int = mini(2, _prop_queue.size())
	for _i in range(count):
		if _prop_queue.is_empty():
			break
		var pd: Dictionary = _prop_queue.pop_front()
		var ptype: String = pd.get("type", "weed")
		if ptype == "palm":
			var prop := _PalmProp.new(150, DestroyableProp.WeaponReq.AXE, "palm_wood")
			prop.position = pd["pos"]
			prop.setup(pd.get("variant", "river"))
			add_child(prop)
		else:
			var prop := PlantProp.new(50, DestroyableProp.WeaponReq.SWORD,
				"tropical_seaweed" if ptype == "weed" else "taro")
			prop.position = pd["pos"]
			prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0),
				pd.get("has_silt", false), pd.get("water_gap", 1.0))
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
	_pending_chunks[ck] = self
	WorkerThreadPool.add_task(
		_thread_rebuild_decorative.bind(ck, _cx, _cz, _size, _dimension_id),
		true, "decorative")

static func _thread_rebuild_decorative(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	chunk.call_deferred("apply_decorative", {
		"grass_blade_data": data.get("grass_blade_data", {}),
		"sediment_mesh": data.get("sediment_mesh"),
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
		for i in range(gxforms.size()):
			mm.set_instance_transform(i, gxforms[i] as Transform3D)
			mm.set_instance_color(i, gcolors[i] as Color)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mmi)

	var sediment_mesh := data.get("sediment_mesh") as ArrayMesh
	if sediment_mesh:
		if _sediment_mesh_instance != null and is_instance_valid(_sediment_mesh_instance):
			_sediment_mesh_instance.queue_free()
		var mi_s := MeshInstance3D.new()
		mi_s.mesh = sediment_mesh
		mi_s.material_override = _Terrain.get_sediment_material()
		mi_s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi_s)
		_sediment_mesh_instance = mi_s

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

	# Rebuild textured block (ore) overlay meshes — chỉ khi chunk có ore
	if _has_ores:
		var ore_meshes := _build_textured_block_meshes(block_data, _cols)
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

	block_data.dirty = false

## ── Cập nhật _top_ly_cache cho 1 column sau khi block đổi ────────────────────
func _update_top_ly_cache(at: Vector3i) -> void:
	var idx := at.x * _cols + at.z
	var old_top: int = _top_ly_cache[idx]
	var blk := block_data.get_block(at.x, at.y, at.z)
	if blk != _Data.BlockID.AIR and not _is_water_bid(blk):
		# Block solid mới — nâng top nếu đặt cao hơn bề mặt hiện tại
		_top_ly_cache[idx] = maxi(old_top, at.y)
	elif at.y >= old_top:
		# Block trên đỉnh bị phá / thay bằng air/water — tìm top solid mới
		var ly := at.y - 1
		while ly >= 0:
			var b := block_data.get_block(at.x, ly, at.z)
			if b != _Data.BlockID.AIR and not _is_water_bid(b):
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
				if blk != _Data.BlockID.AIR and not _is_water_bid(blk):
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
		rebuild_mesh(blk)
	_trigger_neighbor_water_tick(blk.x, blk.z)
	return true

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
			if nb and nb._has_water:
				nb._water_tick_timer = 0.0
				nb.rebuild_water_mesh()
	if lx == _cols - 1:
		var key := Vector2i(_cx + 1, _cz)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb and nb._has_water:
				nb._water_tick_timer = 0.0
				nb.rebuild_water_mesh()
	if lz == 0:
		var key := Vector2i(_cx, _cz - 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb and nb._has_water:
				nb._water_tick_timer = 0.0
				nb.rebuild_water_mesh()
	if lz == _cols - 1:
		var key := Vector2i(_cx, _cz + 1)
		if chunks.has(key):
			var nb := chunks[key] as WorldChunk
			if nb and nb._has_water:
				nb._water_tick_timer = 0.0
				nb.rebuild_water_mesh()

## ── _add_quad (shared helper, delegates to Terrain) ─────────────────────────
static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3, col: Color) -> void:
	_Terrain._add_quad(st, center, u, v, n, col)
