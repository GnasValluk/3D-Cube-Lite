extends Node3D
class_name WorldChunk

const _Data  = preload("chunk_data.gd")
const _Noise = preload("chunk_noise.gd")
const _Road  = preload("chunk_road.gd")
const _Detail = preload("chunk_detail.gd")
const _Aquatic = preload("chunk_aquatic.gd")
const _BlockData = preload("chunk_block_data.gd")
const _WoodLamp = preload("res://scripts/world/props/wood_lamp.gd")

## Khoảng cách giữa 2 đèn đường dọc theo curve (world units) — thưa
const LAMP_SPACING: float = 28.0
## Offset ngang từ tâm đường ra lề — đủ xa để không trùng mặt đường
const LAMP_SIDE_OFFSET: float = 2.8
## Xác suất bỏ qua mỗi vị trí hợp lệ (để thêm ngẫu nhiên, tỉ lệ spawn thấp)
const LAMP_SKIP_CHANCE: float = 0.45

var _cx: int = 0
var _cz: int = 0
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Data._Dim.DimensionID.TWILIGHT
var _built: bool = false

## Block data — cho phép set_block / get_block sau này (build/mine)
var block_data: _BlockData = null

## References to non-terrain meshes (preserved across rebuilds)
var _water_mesh_instance: MeshInstance3D = null
var _aquatic_mesh_instance: MeshInstance3D = null
var _sediment_mesh_instance: MeshInstance3D = null
var _lotus_lights: Array[OmniLight3D] = []
var _prop_queue: Array = []

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}

static func _noise_for_dim(dim_id: int) -> Dictionary:
	return _Noise._noise_for_dim(dim_id)

static func clear_noise_cache() -> void:
	_Noise.clear_cache()
	_mesh_cache.clear()

static func _is_on_road(wx: float, wz: float) -> bool:
	return _Road.is_on_road(wx, wz)

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

func setup(cx: int, cz: int, size: int,
		dimension_id: int = _Data._Dim.DimensionID.TWILIGHT, sync: bool = false) -> void:
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_cols = int(_size / _Data.VOXEL)
	_tiles_per_chunk = int(_cols / _Data.TILE_W)
	_init_materials()

	var ck: String = _cache_key(cx, cz, dimension_id)
	if _mesh_cache.has(ck):
		apply_chunk(_mesh_cache[ck])
		return

	if sync:
		apply_chunk(compute_chunk(cx, cz, size, dimension_id))
		return

	_pending_chunks[ck] = self
	WorkerThreadPool.add_task(
		_thread_build.bind(ck, cx, cz, size, dimension_id), true, "chunk")

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	if chunk != null and is_instance_valid(chunk) and chunk.is_inside_tree():
		chunk.call_deferred("apply_chunk", data)

## ── compute_chunk: tạo block data + build mesh ───────────────────────────────
static func compute_chunk(cx: int, cz: int, size: int, dim_id: int) -> Dictionary:
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
			if bio[vx][vz] != _Data.TileType.GRASS: continue
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

		# ── Ocean mask (BFS padded) — bờ biển bất quy tắc nhờ domain warping ──
		const OCEAN_PAD: int = 26
		var oct_total: int = cols + 2 * OCEAN_PAD
		var oct: Array[Array] = []
		oct.resize(oct_total)
		var ow: FastNoiseLite = nd["ocean_warp"]
		for pvx in range(oct_total):
			oct[pvx] = []; oct[pvx].resize(oct_total)
			for pvz in range(oct_total):
				var wx: float = world_ox - half + (float(pvx - OCEAN_PAD) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(pvz - OCEAN_PAD) + 0.5) * _Data.VOXEL
				# Domain warping: bẻ cong tọa độ bằng noise → bờ biển lồi lõm
				var warp_x: float = ow.get_noise_2d(wx * 0.5, wz * 0.5) * 200.0
				var warp_z: float = ow.get_noise_2d(wx * 0.5 + 100.0, wz * 0.5 + 100.0) * 200.0
				oct[pvx][pvz] = (n_ocean_pre.get_noise_2d(wx + warp_x, wz + warp_z) + 1.0) * 0.5 > _Data.OCEAN_THRESHOLD

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

					# Núi ngầm — chỉ ở vùng sâu, có thể trồi gần mặt nước
					if raw_depth_t > 0.25:
						var mt_n: float = nd["sea_mountain"].get_noise_2d(wx * 0.8, wz * 0.8)
						var mt_h: float = max(0.0, mt_n - 0.35) / 0.65
						mt_h = mt_h * mt_h * (0.3 + raw_depth_t * 2.5)
						var mt_mask: float = (nd["sea_large"].get_noise_2d(wx * 2.0, wz * 2.0) + 1.0) * 0.5
						mt_h *= max(0.0, mt_mask)
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

					# Chặn không trồi lên mặt nước
					height_grid[ivx][ivz] = min(base_h, -0.3)
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

						# Kiểm tra warped ocean mask trực tiếp — không cho hồ ở biển
						var is_ocean: bool = oct[ivx + OCEAN_PAD][ivz + OCEAN_PAD]
						if not is_ocean and lake_val > 0.58 and (od == _Data.CONST_INF or od > 40):
							var lake_type_val: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
							if lake_type_val > 0.50:
								biome_grid[ivx][ivz] = _Data.TileType.SILT if d <= _Data.PAD else _Data.TileType.MUDDY_SAND
							else:
								biome_grid[ivx][ivz] = _Data.TileType.MUDDY_SAND if d <= _Data.PAD else _Data.TileType.SAND
							height_grid[ivx][ivz] = _Data.WATER_Y if d <= 1 else _Data.WATER_Y - min(d, _Data.PAD) * _BlockData.SLAB_HEIGHT
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
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				road_grid[ivx * cols + ivz] = 1 if _Road.is_on_road(wx, wz) else 0

	# ── 5. Tạo ChunkBlockData từ biome + height ────────────────────────────────
	var bd := _BlockData.new()
	bd.init(cols, cols)
	_fill_blocks(bd, biome_grid, height_grid, road_grid, cols, dim_id, cx, cz, size, nd)

	# ── 6. Build terrain mesh từ block data (greedy mesher) ───────────────────
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_terrain_mesh(st, bd, cols, dim_id)

	# ── 6b. Detail mesh — đường mòn, sỏi cát, hoạ tiết đất ──────────────────
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
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

				# Sỏi xám trên cát vàng hồ — cát trắng biển không có sỏi
				if b == _Data.TileType.SAND and h >= _Data.VOXEL * 0.9:
					_Detail.add_sand_gravel(st, cx, cz, size, vx, vz, pos, 0.0)

				if b == _Data.TileType.DIRT:
					_Detail.add_dirt_mounds(st, cx, cz, size, vx, vz, pos, 0.0)
	var mesh := st.commit()
	if mesh == null:
		return { "mesh": null, "water_mesh": null, "biome_grid": biome_grid,
				"cols": cols, "block_data_bytes": bd.to_bytes() }

	# ── 7. Water mesh — hồ nội địa + biển ────────────────────────────────────
	var st_water := SurfaceTool.new()
	st_water.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 7a. Nước hồ (GRASS/SAND/SILT) — greedy strip theo Z như cũ
	for vx in range(cols):
		var vz := 0
		while vz < cols:
			var b: int = biome_grid[vx][vz]
			if b != _Data.TileType.GRASS \
			and b != _Data.TileType.SAND \
			and b != _Data.TileType.SAND_WHITE \
			and b != _Data.TileType.SILT \
			and b != _Data.TileType.MUDDY_SAND:
				vz += 1; continue
			var start_vz := vz
			while vz < cols:
				var bb: int = biome_grid[vx][vz]
				if bb != _Data.TileType.GRASS \
				and bb != _Data.TileType.SAND \
				and bb != _Data.TileType.SAND_WHITE \
				and bb != _Data.TileType.SILT \
				and bb != _Data.TileType.MUDDY_SAND:
					break
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, _Data.WATER_Y - 0.04, z_mid),
				Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox),
				Vector3(0,1,0), Color(1,1,1))

	# 7b. Nước biển (OCEAN_DEEP) — tint xanh đậm
	for vx in range(cols):
		var vz := 0
		while vz < cols:
			var b: int = biome_grid[vx][vz]
			if b != _Data.TileType.OCEAN_DEEP:
				vz += 1; continue
			var start_vz := vz
			while vz < cols and biome_grid[vx][vz] == _Data.TileType.OCEAN_DEEP:
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, _Data.WATER_Y - 0.04, z_mid),
				Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox),
				Vector3(0,1,0), Color(0.55, 0.82, 1.0))

	var mesh_water := st_water.commit()

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
				if h >= _Data.WATER_Y + h_vox: continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox,
					b == _Data.TileType.SILT, b, lotus_lights, plant_props)
		mesh_aquatic = st_aq.commit()

	# ── 9. Lamp positions ──────────────────────────────────────────────────────
	var lamp_positions: Array = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		lamp_positions = _compute_lamp_positions_static(cx, cz, size, biome_grid, height_grid, cols)

	return {
		"mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic,
		"lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols,
		"block_data_bytes": bd.to_bytes(), "lamp_positions": lamp_positions,
		"sediment_mesh": _build_sediment_mesh(bd, cols),
		"plant_props": plant_props
	}

## ── _add_quad_uv: quad với UV (dùng cho sediment texture) ──────────────────
static func _add_quad_uv(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0, 0)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1, 0)); st.add_vertex(center + u - v)
	st.set_uv(Vector2(1, 1)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0, 0)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1, 1)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0, 1)); st.add_vertex(center - u + v)

## ── _get_sediment_material: tạo 8x8 texture procedural kiểu Minecraft ──────
static var _sediment_mat: Material = null
static func _get_sediment_material() -> Material:
	if _sediment_mat != null:
		return _sediment_mat
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var base := Color(0.50, 0.20, 0.10)
	for y in range(8):
		for x in range(8):
			var h: int = x * 374761393 + y * 668265263 + 12345
			h = (h ^ (h >> 13)) * 1274126177
			h = h ^ (h >> 16)
			var r := float(h & 0x7FFFFFFF) / 2147483648.0
			var c := Color(
				base.r + (r - 0.5) * 0.25,
				base.g + (r - 0.5) * 0.15,
				base.b + (r - 0.5) * 0.10
			)
			# Thêm hạt khoáng đỏ đồng và nâu đất xen kẽ
			h = h * 16807 + 1
			var speck := float(h & 0x7FFFFFFF) / 2147483648.0
			if speck > 0.92:
				c = Color(0.55, 0.18, 0.08)  # hạt nâu đậm
			elif speck < 0.06:
				c = Color(0.65, 0.30, 0.12)  # hạt đỏ đồng sáng
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mat.metallic_specular = 0.0
	_sediment_mat = mat
	return mat

## ── _build_sediment_mesh: tách SEDIMENT ra mesh riêng có UV ─────────────────
static func _build_sediment_mesh(bd: _BlockData, cols: int) -> ArrayMesh:
	const Y_MIN := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB := _BlockData.SLAB_HEIGHT
	const B := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5

	# Tìm top layer SEDIMENT cho mỗi column
	var top_ly := PackedInt32Array()
	top_ly.resize(cols * cols)
	top_ly.fill(-1)
	for x in range(cols):
		for z in range(cols):
			for ly in range(CHUNK_H - 1, -1, -1):
				if bd.get_block(x, ly, z) == B.SEDIMENT:
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

			# Top face (offset 0.005 để overlay lên main mesh tránh z-fighting)
			_add_quad_uv(st, Vector3(cx_f, cy_top + 0.005, cz_f),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0))

			# Bottom face (chỉ render nếu block bên dưới là AIR/WATER)
			if ly > 0:
				var below: int = bd.get_block(x, ly - 1, z)
				if below == B.AIR or below == B.WATER:
					_add_quad_uv(st, Vector3(cx_f, cy_bot, cz_f),
						Vector3(-hw, 0, 0), Vector3(0, 0, hw), Vector3(0, -1, 0))

			# Side faces — render khi kế bên không có SEDIMENT hoặc thấp hơn
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
				_add_quad_uv(st, Vector3(cx_f + off.x * 0.5, cy_mid, cz_f + off.z * 0.5),
					side_u, Vector3(0, side_h * 0.5, 0), nrm)

	return st.commit()

## ── _fill_blocks: map biome/height → slab block IDs ─────────────────────────
## BEDROCK LAYER: Layer 0 (Y_MIN) luôn là BEDROCK (không thể phá vỡ)
## STONE fill từ layer 1 đến top_slab-2
## Hồ có đáy STONE chắc chắn, không rớt void
static func _fill_blocks(bd: _BlockData, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, dim_id: int, cx: int = 0, cz: int = 0, size: int = 32,
		nd: Dictionary = {}) -> void:
	const SLAB := _BlockData.SLAB_HEIGHT  # 0.5
	const Y_MIN := _BlockData.Y_MIN       # -18 (21 layers: 0..20)
	const CHUNK_H := _BlockData.CHUNK_H   # 21
	const B := _Data.BlockID

	for x in range(cols):
		for z in range(cols):
			var biome: int = biome_grid[x][z]
			var h: float   = height_grid[x][z]

			# Top surface block theo biome
			var top_block: int = B.GRASS
			match biome:
				_Data.TileType.DARK_GRASS: top_block = B.DARK_GRASS
				_Data.TileType.SAND:       top_block = B.SAND
				_Data.TileType.SAND_WHITE: top_block = B.OCEAN_SAND
				_Data.TileType.DIRT:       top_block = B.DIRT
				_Data.TileType.SILT:       top_block = B.SILT
				_Data.TileType.MUDDY_SAND: top_block = B.MUDDY_SAND
				_Data.TileType.OCEAN_DEEP:
					if nd.is_empty() or not nd.has("sea_biome"):
						top_block = B.OCEAN_FLOOR
					else:
						var wx: float = float(cx * size + x)
						var wz: float = float(cz * size + z)
						var sea_bm: float = (nd["sea_biome"].get_noise_2d(wx, wz) + 1.0) * 0.5
						if sea_bm < 0.15:
							top_block = B.STONE       # rạn đá
						elif sea_bm < 0.28:
							top_block = B.OCEAN_GRAVEL  # sỏi biển
						elif sea_bm < 0.52:
							top_block = B.OCEAN_FLOOR   # cát thô xám xanh
						elif sea_bm < 0.72:
							top_block = B.SAND        # cát sáng
						elif sea_bm < 0.88:
							top_block = B.OCEAN_MUD   # bùn biển sâu
						else:
							top_block = B.OCEAN_GRAVEL # sỏi biển

			var is_trail: bool = road_grid.size() > 0 and road_grid[x * cols + z] != 0 \
					and biome != _Data.TileType.SAND \
					and biome != _Data.TileType.SAND_WHITE \
					and biome != _Data.TileType.SILT \
					and biome != _Data.TileType.MUDDY_SAND \
					and biome != _Data.TileType.OCEAN_DEEP
			if is_trail:
				top_block = B.TRAIL

			# top_slab: slab index của block mặt trên cùng
			var top_slab: int = floori((h - SLAB) / SLAB) - Y_MIN

			# TRAIL KHÔNG thay đổi top_slab — cùng layer với terrain
			# Mặt trên thấp hơn vài pixel được xử lý ở mesh build (TRAIL_SINK)

			# water_top_slab: water fill đến đây
			var water_top_slab: int = floori((_Data.WATER_Y - SLAB) / SLAB) - Y_MIN

			# Điền toàn bộ CHUNK_H slab layers từ dưới lên trên
			for ly in range(CHUNK_H):
				if ly == 0:
					# Layer 0: nếu là đáy hồ (top_slab = 0) → đặt TOP block luôn
					# Nếu không phải đáy hồ → BEDROCK
					if top_slab == 0:
						bd.set_block(x, ly, z, top_block)
					else:
						bd.set_block(x, ly, z, B.BEDROCK)
				elif ly <= top_slab - 2:
					# Lớp sâu → đá
					bd.set_block(x, ly, z, B.STONE)
				elif ly == top_slab - 1 and top_slab > 1:
					# Slab ngay dưới mặt → sub-surface (chỉ khi top_slab >= 2)
					if top_block == B.DARK_GRASS or top_block == B.DIRT:
						bd.set_block(x, ly, z, B.DARK_DIRT)
					else:
						bd.set_block(x, ly, z, B.SAND_DEEP)
				elif ly == top_slab and top_slab > 0:
					# Mặt trên cùng (chỉ khi top_slab > 0, vì 0 đã xử lý ở trên)
					bd.set_block(x, ly, z, top_block)
				else:
					# ly > top_slab → trên mặt đất
					if ly <= water_top_slab:
						bd.set_block(x, ly, z, B.WATER)
					else:
						bd.set_block(x, ly, z, B.AIR)

	# ── Trầm tích hồ: cụm 3~7 khối SEDIMENT màu đỏ đồng, tụ lại thành mảng ──
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var dirs: Array[Vector2i] = [
			Vector2i(0,0), Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
			Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)
		]
		for x in range(cols):
			for z in range(cols):
				var biome: int = biome_grid[x][z]
				if biome != _Data.TileType.SAND and biome != _Data.TileType.MUDDY_SAND: continue
				var h: float = height_grid[x][z]
				if h >= _Data.WATER_Y - _BlockData.SLAB_HEIGHT: continue
				var wx2: int = cx * size + x
				var wz2: int = cz * size + z
				var hh: int = wx2 * 374761393 + wz2 * 668265263
				hh = (hh ^ (hh >> 13)) * 1274126177
				hh = hh ^ (hh >> 16)
				var r := float(hh & 0x7FFFFFFF) / 2147483648.0
				if r >= 0.003: continue
				var s: int = hh
				s = s * 16807 + 1
				var cluster_size: int = 3 + (s & 3)  # 3..6
				if (s & 4) != 0: cluster_size += 1  # 3..7
				var placed: int = 0
				for di in dirs.size():
					if placed >= cluster_size: break
					var nx: int = x + dirs[di].x
					var nz: int = z + dirs[di].y
					if nx < 0 or nx >= cols or nz < 0 or nz >= cols: continue
					var nb: int = biome_grid[nx][nz]
					if nb != _Data.TileType.SAND and nb != _Data.TileType.MUDDY_SAND: continue
					var nh: float = height_grid[nx][nz]
					if nh >= _Data.WATER_Y - _BlockData.SLAB_HEIGHT: continue
					var top_slab: int = floori((nh - _BlockData.SLAB_HEIGHT) / _BlockData.SLAB_HEIGHT) - _BlockData.Y_MIN
					if top_slab < 0: continue
					bd.set_block(nx, top_slab, nz, B.SEDIMENT)
					placed += 1

## ── _build_terrain_mesh: COLUMN-TOP OPTIMIZED ────────────────────────────────
## Terrain này hầu như phẳng → mỗi column X/Z chỉ có 1–2 layer lộ ra.
## Strategy:
##   1. Với mỗi column, tìm top_layer = layer cao nhất có solid block
##   2. Chỉ render: top face của top_layer + side faces nơi kế bên thấp hơn
##   3. Các layer bên dưới KHÔNG render (người chơi không nhìn thấy được)
##   4. Greedy strip theo Z để gộp top faces cùng màu → giảm draw calls
## Kết quả: ~32–128 quads/chunk thay vì 9,216 trước đây
static func _build_terrain_mesh(st: SurfaceTool, bd: _BlockData,
		cols: int, dim_id: int) -> void:
	const Y_MIN  := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB   := _BlockData.SLAB_HEIGHT   # 0.5
	const B      := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5     # 0.5 — half block width/depth
	var hh: float = SLAB * 0.5            # 0.25 — half slab height
	var half: float = float(cols) * _Data.VOXEL * 0.5
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW

	# Bước 1: tính top_layer và top_block cho mỗi column — O(cols²×CHUNK_H)
	# Lưu vào PackedInt32Array để truy cập nhanh, tránh Array[Array] overhead
	var top_ly  := PackedInt32Array()   # top layer index cho column x*cols+z
	var top_blk := PackedByteArray()    # top block id
	top_ly.resize(cols * cols)
	top_blk.resize(cols * cols)

	for x in range(cols):
		for z in range(cols):
			var best_ly: int = -1
			var best_blk: int = B.AIR
			for ly in range(CHUNK_H - 1, -1, -1):
				var blk: int = bd.get_block(x, ly, z)
				if blk != B.AIR and blk != B.WATER:
					best_ly = ly
					best_blk = blk
					break
			top_ly[x * cols + z]  = best_ly
			top_blk[x * cols + z] = best_blk

	# Bước 2: Greedy strip theo Z cho TOP FACES — O(cols²) với hằng số nhỏ
	for x in range(cols):
		var z: int = 0
		while z < cols:
			var ly: int  = top_ly[x * cols + z]
			var blk: int = top_blk[x * cols + z]
			if ly < 0:   # column toàn AIR/WATER
				z += 1; continue

			# Mở rộng strip theo Z: cùng ly, cùng blk
			var z_end: int = z + 1
			while z_end < cols \
					and top_ly[x * cols + z_end]  == ly \
					and top_blk[x * cols + z_end] == blk:
				z_end += 1

			var strip: int   = z_end - z
			var cx_f: float  = -half + (float(x) + 0.5) * _Data.VOXEL
			var cy_top: float = float(ly + Y_MIN) * SLAB + SLAB   # top edge
			var z_mid: float  = -half + (float(z) + float(strip) * 0.5) * _Data.VOXEL
			var top_col: Color = colors[blk]

			# TOP face — 1 quad cho cả dải
			_add_quad(st, Vector3(cx_f, cy_top, z_mid),
				Vector3(hw, 0, 0), Vector3(0, 0, float(strip) * hw),
				Vector3(0, 1, 0), top_col)

			z = z_end

	# Bước 3: SIDE FACES — chỉ render khi kế bên thấp hơn hoặc là void
	# Không greedy để tránh phức tạp — side faces hiếm trên terrain phẳng
	var side_mul: float = 0.50
	for x in range(cols):
		for z in range(cols):
			var ly: int  = top_ly[x * cols + z]
			if ly < 0: continue
			var blk: int = top_blk[x * cols + z]
			var cy_top: float  = float(ly + Y_MIN) * SLAB + SLAB
			var cx_f: float    = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float    = -half + (float(z) + 0.5) * _Data.VOXEL
			var top_col: Color = colors[blk]
			var side_col: Color = Color(top_col.r*side_mul, top_col.g*side_mul,
				top_col.b*side_mul, top_col.a)

			# Kiểm tra 4 hướng — chỉ render khi hàng xóm thấp hơn
			var nx_ly: int
			var diff: float

			# North (-Z)
			nx_ly = top_ly[x * cols + (z - 1)] if z > 0 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f, cy_mid, cz_f - hw),
					Vector3(hw, 0, 0), Vector3(0, side_h * 0.5, 0),
					Vector3(0, 0, -1), side_col)

			# South (+Z)
			nx_ly = top_ly[x * cols + (z + 1)] if z < cols - 1 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f, cy_mid, cz_f + hw),
					Vector3(-hw, 0, 0), Vector3(0, side_h * 0.5, 0),
					Vector3(0, 0, 1), side_col)

			# West (-X)
			nx_ly = top_ly[(x - 1) * cols + z] if x > 0 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f - hw, cy_mid, cz_f),
					Vector3(0, 0, -hw), Vector3(0, side_h * 0.5, 0),
					Vector3(-1, 0, 0), side_col)

			# East (+X)
			nx_ly = top_ly[(x + 1) * cols + z] if x < cols - 1 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f + hw, cy_mid, cz_f),
					Vector3(0, 0, hw), Vector3(0, side_h * 0.5, 0),
					Vector3(1, 0, 0), side_col)

## ── Materials ─────────────────────────────────────────────────────────────────
func _make_water_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		# Vertex color tint: hồ = Color(1,1,1) → lake_color, biển = Color(0.55,0.82,1) → ocean_color
		s.code = """
shader_type spatial;
render_mode blend_mix;
uniform vec4 lake_color  : source_color = vec4(0.08, 0.38, 0.72, 0.75);
uniform vec4 ocean_color : source_color = vec4(0.04, 0.28, 0.62, 0.82);
void fragment() {
	float is_ocean = step(COLOR.r, 0.8);
	vec4 base = mix(lake_color, ocean_color, is_ocean);
	ALBEDO    = base.rgb;
	ALPHA     = base.a;
	ROUGHNESS = 0.15;
	METALLIC  = 0.0;
	SPECULAR  = 0.0;
}
"""
	else:
		s.code = """
shader_type spatial;
render_mode blend_mix, unshaded;
uniform vec4 water_color : source_color = vec4(0.10, 0.55, 0.45, 0.70);
uniform vec4 emit_color  : source_color = vec4(0.08, 0.45, 0.35, 1.0);
void fragment() {
	ALBEDO = water_color.rgb; ALPHA = water_color.a;
	EMISSION = emit_color.rgb * 2.0;
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
	_mesh_cache[_cache_key(_cx, _cz, _dimension_id)] = data
	_biome_grid = data["biome_grid"]

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

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	container.add_child(mi)

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
		mi_s.material_override = _get_sediment_material()
		mi_s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi_s)
		_sediment_mesh_instance = mi_s

	var lotus_positions: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	for lpos in lotus_positions:
		var is_weed_light: bool = lpos.x > 400.0
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		if is_weed_light:
			light.light_color      = Color(1.0, 0.82, 0.08)  # vàng quả
			light.light_energy     = 0.6
			light.omni_range       = 1.5
		else:
			light.light_color      = Color(0.45, 0.85, 1.0)  # xanh sen
			light.light_energy     = 0.0
			light.omni_range       = 3.0
		light.omni_attenuation = 2.5
		light.shadow_enabled   = false
		light.light_specular   = 0.0
		light.position         = real_pos + Vector3(0, 0.15, 0)
		container.add_child(light)
		_lotus_lights.append(light)

	# 1 add_child duy nhất vào scene tree → 1 notification thay vì N
	add_child(container)

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
			_lamp_spawn_coroutine(lamp_positions)

	# Spawn plant props (taro, seaweed) — throttle 2 props/frame
	_prop_queue = data.get("plant_props", []).duplicate()
	if not _prop_queue.is_empty():
		set_process(true)

	_built = true

## Process prop queue — 2 props/frame để tránh spike
func _process(_delta: float) -> void:
	var count: int = mini(2, _prop_queue.size())
	for _i in range(count):
		if _prop_queue.is_empty():
			break
		var pd: Dictionary = _prop_queue.pop_front()
		var ptype: String = pd.get("type", "weed")
		var prop := PlantProp.new(50, DestroyableProp.WeaponReq.SWORD,
			"mon_ngot" if ptype == "weed" else "rong_nhiet_doi")
		prop.position = pd["pos"]
		prop.setup(ptype, pd.get("seed_h1", 0), pd.get("seed_h2", 0),
			pd.get("has_silt", false), pd.get("water_gap", 1.0))
		add_child(prop)
	if _prop_queue.is_empty():
		set_process(false)

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

## ── rebuild_mesh: gọi khi block thay đổi (mine/place) ────────────────────────
## Xoá mesh cũ, build lại từ block_data hiện tại. Chạy trên main thread.
func rebuild_mesh() -> void:
	if block_data == null: return

	# Xóa static body cũ (collision)
	for ch in get_children():
		if ch is StaticBody3D:
			ch.queue_free()

	# Xóa terrain mesh cũ (giữ lại water / aquatic / lights)
	for ch in get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi != _water_mesh_instance and mi != _aquatic_mesh_instance and mi != _sediment_mesh_instance:
				mi.queue_free()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_terrain_mesh(st, block_data, _cols, _dimension_id)
	var mesh := st.commit()
	if mesh == null: return

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)

	block_data.dirty = false

## ── Block API (dùng cho building / mining) ───────────────────────────────────
## Đổi tọa độ world → local block index, rồi set_block + rebuild
func world_to_local_block(wx: float, wy: float, wz: float) -> Vector3i:
	var half: float = _size * 0.5
	var lx: int = int(floor(wx - (global_position.x - half)))
	var lz: int = int(floor(wz - (global_position.z - half)))
	var ly: int = _BlockData.world_y_to_layer(wy)
	return Vector3i(lx, ly, lz)

## Phá block tại world position. Trả về block_id đã xoá (0 = không có gì).
## BEDROCK không thể phá vỡ.
func break_block_at(wx: float, wy: float, wz: float) -> int:
	if block_data == null: return 0
	var blk := world_to_local_block(wx, wy, wz)
	var old_id: int = block_data.get_block(blk.x, blk.y, blk.z)
	if old_id == _Data.BlockID.AIR or old_id == _Data.BlockID.WATER: return 0
	if old_id == _Data.BlockID.BEDROCK: return 0   # Bedrock không thể phá vỡ
	block_data.set_block(blk.x, blk.y, blk.z, _Data.BlockID.AIR)
	rebuild_mesh()
	return old_id

## Đặt block tại world position.
func place_block_at(wx: float, wy: float, wz: float, block_id: int) -> bool:
	if block_data == null: return false
	var blk := world_to_local_block(wx, wy, wz)
	var cur: int = block_data.get_block(blk.x, blk.y, blk.z)
	if cur != _Data.BlockID.AIR: return false   # vị trí đã có block
	block_data.set_block(blk.x, blk.y, blk.z, block_id)
	rebuild_mesh()
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

## ── is_water_at: kiểm tra block data thực tế, không dựa vào biome ────────────
func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if block_data == null: return false
	var half: float = _size * 0.5
	var vx: int = int((wx - (global_position.x - half)) / _Data.VOXEL)
	var vz: int = int((wz - (global_position.z - half)) / _Data.VOXEL)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols: return false
	var layer: int = _BlockData.world_y_to_layer(wy)
	return block_data.get_block(vx, layer, vz) == _Data.BlockID.WATER

## ── _compute_lamp_positions_static: chạy trên worker thread ─────────────────
## Static version — không truy cập instance state, an toàn từ thread
## biome_grid + cols được truyền vào để skip vị trí nước/hồ/sông
static func _compute_lamp_positions_static(
		cx: int, cz: int, size: int,
		biome_grid: Array, height_grid: Array, cols: int) -> Array:
	_Road._ensure_roads()

	var half:     float = size * 0.5
	var cx_world: float = cx * size
	var cz_world: float = cz * size
	var min_x:    float = cx_world - half
	var max_x:    float = cx_world + half
	var min_z:    float = cz_world - half
	var max_z:    float = cz_world + half
	var pad:      float = LAMP_SPACING

	var rng := RandomNumberGenerator.new()
	rng.seed = WorldSeed.seed_value + cx * 100003 + cz * 200003 + 54321

	var placed_positions: Array[Vector2] = []
	var result: Array = []

	for curve in _Road._road_curves:
		if curve.size() < 2:
			continue
		var c_min_x: float = curve[0].x; var c_max_x: float = curve[0].x
		var c_min_z: float = curve[0].y; var c_max_z: float = curve[0].y
		for pt in curve:
			c_min_x = min(c_min_x, pt.x); c_max_x = max(c_max_x, pt.x)
			c_min_z = min(c_min_z, pt.y); c_max_z = max(c_max_z, pt.y)
		if c_max_x < min_x - pad or c_min_x > max_x + pad: continue
		if c_max_z < min_z - pad or c_min_z > max_z + pad: continue

		var dist_acc:       float = 0.0
		var next_lamp_dist: float = rng.randf_range(LAMP_SPACING * 0.3, LAMP_SPACING * 0.7)

		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b: Vector2 = curve[i + 1]
			var seg_len: float = a.distance_to(b)
			if seg_len < 0.001:
				continue
			var seg_dir:  Vector2 = (b - a) / seg_len
			var seg_perp: Vector2 = Vector2(seg_dir.y, -seg_dir.x)
			var t_end:    float   = dist_acc + seg_len

			while next_lamp_dist <= t_end:
				var frac:    float   = (next_lamp_dist - dist_acc) / seg_len
				var road_pt: Vector2 = a.lerp(b, frac)
				var lamp_2d: Vector2 = road_pt + seg_perp * LAMP_SIDE_OFFSET
				var lx: float = lamp_2d.x
				var lz: float = lamp_2d.y

				if lx >= min_x and lx < max_x and lz >= min_z and lz < max_z:
					if rng.randf() < LAMP_SKIP_CHANCE:
						next_lamp_dist += LAMP_SPACING
						continue

					# ── Check địa hình — không spawn trên nước/hồ/biển ─────
					var skip_water: bool = false
					if cols > 0 and biome_grid.size() > 0:
						var vx: int = clampi(int((lx - min_x) / _Data.VOXEL), 0, cols - 1)
						var vz: int = clampi(int((lz - min_z) / _Data.VOXEL), 0, cols - 1)
						var biome: int = biome_grid[vx][vz]
						var h: float = height_grid[vx][vz] if height_grid.size() > 0 else 1.0
						# Skip nếu: biome nước, biển, hoặc height âm (dưới mực nước)
						match biome:
							_Data.TileType.SAND, _Data.TileType.SAND_WHITE, \
							_Data.TileType.SILT, _Data.TileType.OCEAN_DEEP:
								skip_water = true
						if not skip_water and h < _Data.WATER_Y:
							skip_water = true
						if not skip_water:
							for ox in [-1, 0, 1]:
								for oz in [-1, 0, 1]:
									var nx: int = clampi(vx + ox, 0, cols - 1)
									var nz: int = clampi(vz + oz, 0, cols - 1)
									var nb: int = biome_grid[nx][nz]
									var nh: float = height_grid[nx][nz] if height_grid.size() > 0 else 1.0
									if nb == _Data.TileType.SAND or nb == _Data.TileType.SAND_WHITE \
									or nb == _Data.TileType.SILT \
									or nb == _Data.TileType.OCEAN_DEEP or nh < _Data.WATER_Y:
										skip_water = true
										break
								if skip_water:
									break

					if skip_water:
						next_lamp_dist += LAMP_SPACING
						continue

					var too_close: bool = false
					var min_dist2: float = (LAMP_SPACING * 0.55) * (LAMP_SPACING * 0.55)
					for prev in placed_positions:
						if prev.distance_squared_to(lamp_2d) < min_dist2:
							too_close = true
							break
					if not too_close:
						placed_positions.append(lamp_2d)
						result.append({
							"x": lx - cx_world,
							"z": lz - cz_world,
							"dx": seg_dir.x,
							"dz": seg_dir.y
						})
				next_lamp_dist += LAMP_SPACING
			dist_acc = t_end
	return result

## ── _spawn_road_lamps_deferred: đọc positions từ data, spawn từng đèn qua frame
func _spawn_road_lamps_deferred() -> void:
	var positions: Array = _compute_lamp_positions()
	if positions.is_empty():
		return
	_lamp_spawn_coroutine(positions)

## Tính toán tất cả vị trí đèn — không tạo node, chỉ trả về Array of Dictionary
func _compute_lamp_positions() -> Array:
	_Road._ensure_roads()

	var half:     float = _size * 0.5
	var cx_world: float = _cx * _size
	var cz_world: float = _cz * _size
	var min_x:    float = cx_world - half
	var max_x:    float = cx_world + half
	var min_z:    float = cz_world - half
	var max_z:    float = cz_world + half
	var pad:      float = LAMP_SPACING

	var rng := RandomNumberGenerator.new()
	rng.seed = WorldSeed.seed_value + _cx * 100003 + _cz * 200003 + 54321

	var placed_positions: Array[Vector2] = []
	var result: Array = []

	for curve in _Road._road_curves:
		if curve.size() < 2:
			continue
		var c_min_x: float = curve[0].x; var c_max_x: float = curve[0].x
		var c_min_z: float = curve[0].y; var c_max_z: float = curve[0].y
		for pt in curve:
			c_min_x = min(c_min_x, pt.x); c_max_x = max(c_max_x, pt.x)
			c_min_z = min(c_min_z, pt.y); c_max_z = max(c_max_z, pt.y)
		if c_max_x < min_x - pad or c_min_x > max_x + pad: continue
		if c_max_z < min_z - pad or c_min_z > max_z + pad: continue

		var dist_acc:       float = 0.0
		var next_lamp_dist: float = rng.randf_range(LAMP_SPACING * 0.3, LAMP_SPACING * 0.7)

		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b: Vector2 = curve[i + 1]
			var seg_len: float = a.distance_to(b)
			if seg_len < 0.001:
				continue
			var seg_dir:  Vector2 = (b - a) / seg_len
			var seg_perp: Vector2 = Vector2(seg_dir.y, -seg_dir.x)
			var t_end:    float   = dist_acc + seg_len

			while next_lamp_dist <= t_end:
				var frac:    float   = (next_lamp_dist - dist_acc) / seg_len
				var road_pt: Vector2 = a.lerp(b, frac)
				var lamp_2d: Vector2 = road_pt + seg_perp * LAMP_SIDE_OFFSET
				var lx: float = lamp_2d.x
				var lz: float = lamp_2d.y

				if lx >= min_x and lx < max_x and lz >= min_z and lz < max_z:
					if rng.randf() < LAMP_SKIP_CHANCE:
						next_lamp_dist += LAMP_SPACING
						continue
					var too_close: bool = false
					var min_dist2: float = (LAMP_SPACING * 0.55) * (LAMP_SPACING * 0.55)
					for prev in placed_positions:
						if prev.distance_squared_to(lamp_2d) < min_dist2:
							too_close = true
							break
					if not too_close:
						placed_positions.append(lamp_2d)
						result.append({
							"x": lx - cx_world,
							"z": lz - cz_world,
							"dx": seg_dir.x,
							"dz": seg_dir.y
						})
				next_lamp_dist += LAMP_SPACING
			dist_acc = t_end
	return result

## Spawn đèn từng cái qua các frame — tối đa 2 đèn/frame để tránh spike
func _lamp_spawn_coroutine(positions: Array) -> void:
	const LAMPS_PER_FRAME: int = 2
	var count: int = 0
	for data in positions:
		if not is_inside_tree():
			return
		var lamp: Node3D = _WoodLamp.new()
		lamp.set_meta("road_dir_x", data["dx"])
		lamp.set_meta("road_dir_y", data["dz"])
		lamp.position = Vector3(data["x"], 1.0, data["z"])
		add_child(lamp)
		count += 1
		if count >= LAMPS_PER_FRAME:
			count = 0
			await get_tree().process_frame

## ── _spawn_road_lamps (legacy — kept for reference) ─────────────────────────
func _spawn_road_lamps() -> void:
	_lamp_spawn_coroutine(_compute_lamp_positions())

## ── _add_quad (shared helper) ────────────────────────────────────────────────
static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
