extends Node3D
class_name WorldChunk

const _Data  = preload("chunk_data.gd")
const _Noise = preload("chunk_noise.gd")
const _Road  = preload("chunk_road.gd")
const _Detail = preload("chunk_detail.gd")
const _Aquatic = preload("chunk_aquatic.gd")
const _BlockData = preload("chunk_block_data.gd")

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
var _lotus_lights: Array[OmniLight3D] = []

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}

static func _noise_for_dim(dim_id: int) -> Dictionary:
	return _Noise._noise_for_dim(dim_id)

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

	# ── 3. biome_grid + height_grid (giống cũ) ─────────────────────────────────
	var biome_grid: Array[Array] = []
	biome_grid.resize(cols)
	var height_grid: Array[Array] = []
	height_grid.resize(cols)
	for ivx in range(cols):
		biome_grid[ivx] = []; biome_grid[ivx].resize(cols)
		height_grid[ivx] = []; height_grid[ivx].resize(cols)
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

	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		# Hoist noise dict ra ngoài loop — tránh dictionary lookup 2048 lần
		var nd: Dictionary = _Noise._noise_for_dim(dim_id)
		var n_lake: FastNoiseLite      = nd["lake"]
		var n_lake_type: FastNoiseLite = nd["lake_type"]
		var n_biome: FastNoiseLite     = nd["biome"]
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var d: int = dst[pvx][pvz]
				if biome_grid[ivx][ivz] == _Data.TileType.GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5

					if lake_val > 0.50:
						# Đây là vùng hồ — phân loại hồ bùn hay hồ cát
						# n_lake_type > 0.5 → hồ bùn, ngược lại → hồ cát
						var lake_type_val: float = (n_lake_type.get_noise_2d(wx, wz) + 1.0) * 0.5
						var is_silt_lake: bool = lake_type_val > 0.50

						if is_silt_lake:
							# ── Hồ bùn: ≥60% diện tích là SILT ────────────────────────
							# d=0,1,2,3 → SILT (phần lớn + thành trong)
							# d>=4 → SAND (chỉ mép ngoài 1-2 voxel)
							if d <= 3:
								biome_grid[ivx][ivz] = _Data.TileType.SILT
								if d <= 1:
									height_grid[ivx][ivz] = _Data.WATER_Y
							else:
								biome_grid[ivx][ivz] = _Data.TileType.SAND
								if d <= 1:
									height_grid[ivx][ivz] = _Data.WATER_Y
						else:
							# ── Hồ cát: toàn bộ là SAND ─────────────────────────────────
							biome_grid[ivx][ivz] = _Data.TileType.SAND
							if d <= 1:
								height_grid[ivx][ivz] = _Data.WATER_Y
					else:
						# Không phải hồ — vùng cỏ bình thường ven nước
						biome_grid[ivx][ivz] = _Data.TileType.SAND
						if d <= 1:
							height_grid[ivx][ivz] = _Data.WATER_Y
				elif biome_grid[ivx][ivz] == _Data.TileType.DARK_GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var dn: float = (n_biome.get_noise_2d((wx+500.0)*0.7, (wz+500.0)*0.7) + 1.0) * 0.5
					if dn > 0.70:
						biome_grid[ivx][ivz] = _Data.TileType.DIRT

	# ── 4. Road grid — PackedByteArray thay Array[Array] để tiết kiệm memory ──
	var road_grid: PackedByteArray
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		road_grid.resize(cols * cols)
		for ivx in range(cols):
			for ivz in range(cols):
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				road_grid[ivx * cols + ivz] = 1 if _Road.is_on_road(wx, wz) else 0

	# ── 5. Tạo ChunkBlockData từ biome + height ────────────────────────────────
	var bd := _BlockData.new()
	bd.init(cols, cols)
	_fill_blocks(bd, biome_grid, height_grid, road_grid, cols, dim_id)

	# ── 6. Build terrain mesh từ block data (greedy mesher) ───────────────────
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_terrain_mesh(st, bd, cols, dim_id)

	# ── 6b. Detail mesh — đường mòn, sỏi cát, hoạ tiết đất ──────────────────
	# Render các chi tiết nổi phía trên top surface, dùng biome_grid + road_grid
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for vx in range(cols):
			for vz in range(cols):
				var b: int  = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				# pos.y = top edge của block = height value
				var pos := Vector3(px, h, pz)

				var is_road: bool = road_grid.size() > 0 and road_grid[vx * cols + vz] != 0

				# Đường mòn + hoạ tiết trên đường
				if is_road and b != _Data.TileType.SAND and b != _Data.TileType.SILT:
					_Detail.add_trail_detail(st, cx, cz, size, vx, vz, pos, 0.0)

				# Sỏi trên cát (chỉ cát nổi gần mép nước)
				if b == _Data.TileType.SAND and h > _Data.WATER_Y - 0.04:
					_Detail.add_sand_gravel(st, cx, cz, size, vx, vz, pos, 0.0)

				# Hoạ tiết gò đất
				if b == _Data.TileType.DIRT:
					_Detail.add_dirt_mounds(st, cx, cz, size, vx, vz, pos, 0.0)
	var mesh := st.commit()
	if mesh == null:
		return { "mesh": null, "water_mesh": null, "biome_grid": biome_grid,
				"cols": cols, "block_data_bytes": bd.to_bytes() }

	# ── 7. Water mesh (giữ nguyên logic cũ) ───────────────────────────────────
	var st_water := SurfaceTool.new()
	st_water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vx in range(cols):
		var vz := 0
		while vz < cols:
			if biome_grid[vx][vz] != _Data.TileType.GRASS \
			and biome_grid[vx][vz] != _Data.TileType.SAND \
			and biome_grid[vx][vz] != _Data.TileType.SILT:
				vz += 1; continue
			var start_vz := vz
			while vz < cols and (biome_grid[vx][vz] == _Data.TileType.GRASS \
			or biome_grid[vx][vz] == _Data.TileType.SAND \
			or biome_grid[vx][vz] == _Data.TileType.SILT):
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, _Data.WATER_Y - 0.04, z_mid),
				Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox),
				Vector3(0,1,0), Color(1,1,1))
	var mesh_water := st_water.commit()

	# ── 8. Aquatic mesh (giữ nguyên) ──────────────────────────────────────────
	var mesh_aquatic = null
	var lotus_lights: Array[Vector3] = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var st_aq := SurfaceTool.new()
		st_aq.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vx in range(cols):
			for vz in range(cols):
				var b: int = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				if b != _Data.TileType.SAND and b != _Data.TileType.SILT: continue
				if h >= _Data.WATER_Y - h_vox: continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox,
					b == _Data.TileType.SILT, lotus_lights)
		mesh_aquatic = st_aq.commit()

	return {
		"mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic,
		"lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols,
		"block_data_bytes": bd.to_bytes()
	}

## ── _fill_blocks: map biome/height → slab block IDs ─────────────────────────
## BEDROCK LAYER: Layer 0 (Y_MIN) luôn là BEDROCK (không thể phá vỡ)
## STONE fill từ layer 1 đến top_slab-2
## Hồ có đáy STONE chắc chắn, không rớt void
static func _fill_blocks(bd: _BlockData, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, dim_id: int) -> void:
	const SLAB := _BlockData.SLAB_HEIGHT  # 0.5
	const Y_MIN := _BlockData.Y_MIN       # -6 (9 layers: 0..8)
	const CHUNK_H := _BlockData.CHUNK_H   # 9
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
				_Data.TileType.DIRT:       top_block = B.DIRT
				_Data.TileType.SILT:       top_block = B.SILT

			# Road override — TRAIL block, cùng chiều cao block bình thường
			var is_trail: bool = road_grid.size() > 0 and road_grid[x * cols + z] != 0 \
					and biome != _Data.TileType.SAND and biome != _Data.TileType.SILT
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
	var side_mul: float = 0.62
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
		s.code = """
shader_type spatial;
render_mode blend_mix;
uniform vec4 water_color : source_color = vec4(0.08, 0.36, 0.68, 0.72);
void fragment() {
	ALBEDO = water_color.rgb; ALPHA = water_color.a;
	METALLIC = 0.05; ROUGHNESS = 0.25;
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

	# Khôi phục block_data từ bytes đã serialize
	var bdbytes: PackedByteArray = data.get("block_data_bytes", PackedByteArray())
	if not bdbytes.is_empty():
		block_data = _BlockData.new()
		block_data.from_bytes(bdbytes, _cols, _cols)

	var mesh: ArrayMesh = data["mesh"]
	if mesh == null:
		_built = true; return

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	add_child(mi)

	var water_mesh = data.get("water_mesh")
	if water_mesh:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = water_mesh
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		add_child(mi_w)
		_water_mesh_instance = mi_w

	var aquatic_mesh = data.get("aquatic_mesh")
	if aquatic_mesh:
		var mi_aq := MeshInstance3D.new()
		mi_aq.mesh = aquatic_mesh
		if not _mat_cache[_dimension_id].has("aquatic"):
			_mat_cache[_dimension_id]["aquatic"] = _make_aquatic_mat()
		mi_aq.material_override = _mat_cache[_dimension_id]["aquatic"]
		mi_aq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi_aq)
		_aquatic_mesh_instance = mi_aq

	var lotus_positions: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	for lpos in lotus_positions:
		var is_weed_light: bool = lpos.x > 400.0
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		light.light_color      = Color(0.45, 0.85, 1.0)
		light.light_energy     = 0.0
		light.omni_range       = 2.0 if is_weed_light else 3.0
		light.omni_attenuation = 2.5
		light.shadow_enabled   = false
		light.light_specular   = 0.0
		light.position         = real_pos + Vector3(0, 0.15, 0)
		add_child(light)
		_lotus_lights.append(light)
		LotusLightManager.register(light)

	# Collision: build trimesh shape trên thread, apply trên main thread
	# Tránh stutter do create_trimesh_shape() nặng
	var mesh_ref: ArrayMesh = mesh
	WorkerThreadPool.add_task(func():
		var shape: Shape3D = mesh_ref.create_trimesh_shape()
		call_deferred("_apply_collision", shape)
	, false, "collision")

	# Spawn đèn đường dọc theo các road curve đi qua chunk này
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
		_spawn_road_lamps()

	_built = true

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
			if mi != _water_mesh_instance and mi != _aquatic_mesh_instance:
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
func _make_aquatic_mat() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sway_speed  : hint_range(0.1, 5.0) = 1.6;
uniform float sway_amount : hint_range(0.0, 0.5) = 0.07;
uniform float sway_freq   : hint_range(0.1, 8.0) = 2.8;
void vertex() {
	float is_flat = step(0.85, abs(NORMAL.y));
	float height_factor = max(0.0, VERTEX.y + 0.5) * 0.7 * (1.0 - is_flat);
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
	return m

## ── is_water_at (legacy API cho OpenWorldManager) ────────────────────────────
func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if _biome_grid.is_empty(): return false
	var half: float = _size * 0.5
	var vx: int = int((wx - (global_position.x - half)) / _Data.VOXEL)
	var vz: int = int((wz - (global_position.z - half)) / _Data.VOXEL)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols: return false
	if _biome_grid[vx][vz] != _Data.TileType.SAND \
	and _biome_grid[vx][vz] != _Data.TileType.SILT: return false
	return wy < _Data.VOXEL * 0.46

## ── _spawn_road_lamps: đặt đèn đường dọc theo road curves trong chunk ────────
## - Spawn bên lề đường (offset đủ xa khỏi mặt đường ROAD_HALF_W)
## - Hướng cánh tay đèn quay vào lòng đường theo từng đoạn curve
## - Tỉ lệ spawn thưa, có random skip
func _spawn_road_lamps() -> void:
	_Road._ensure_roads()

	var half:     float = _size * 0.5
	var cx_world: float = _cx * _size
	var cz_world: float = _cz * _size
	var min_x:    float = cx_world - half
	var max_x:    float = cx_world + half
	var min_z:    float = cz_world - half
	var max_z:    float = cz_world + half

	var pad: float = LAMP_SPACING

	# RNG deterministic theo chunk để không thay đổi mỗi lần load
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldSeed.seed_value + _cx * 100003 + _cz * 200003 + 54321

	var placed_positions: Array[Vector2] = []

	for curve in _Road._road_curves:
		if curve.size() < 2:
			continue

		# AABB check nhanh
		var c_min_x: float = curve[0].x; var c_max_x: float = curve[0].x
		var c_min_z: float = curve[0].y; var c_max_z: float = curve[0].y
		for pt in curve:
			c_min_x = min(c_min_x, pt.x); c_max_x = max(c_max_x, pt.x)
			c_min_z = min(c_min_z, pt.y); c_max_z = max(c_max_z, pt.y)
		if c_max_x < min_x - pad or c_min_x > max_x + pad: continue
		if c_max_z < min_z - pad or c_min_z > max_z + pad: continue

		var dist_acc:       float = 0.0
		# Offset ngẫu nhiên cho đèn đầu tiên trên mỗi curve
		var next_lamp_dist: float = rng.randf_range(LAMP_SPACING * 0.3, LAMP_SPACING * 0.7)

		for i in range(curve.size() - 1):
			var a: Vector2 = curve[i]
			var b: Vector2 = curve[i + 1]
			var seg_len: float = a.distance_to(b)
			if seg_len < 0.001:
				continue

			var seg_dir:  Vector2 = (b - a) / seg_len
			# Lề phải chiều đi (đèn spawn bên này)
			var seg_perp: Vector2 = Vector2(seg_dir.y, -seg_dir.x)

			var t_end: float = dist_acc + seg_len

			while next_lamp_dist <= t_end:
				var frac:    float   = (next_lamp_dist - dist_acc) / seg_len
				var road_pt: Vector2 = a.lerp(b, frac)
				# Vị trí đèn = lề phải, đủ xa mặt đường
				var lamp_2d: Vector2 = road_pt + seg_perp * LAMP_SIDE_OFFSET

				var lx: float = lamp_2d.x
				var lz: float = lamp_2d.y

				if lx >= min_x and lx < max_x and lz >= min_z and lz < max_z:
					# Random skip để tỉ lệ thưa
					if rng.randf() < LAMP_SKIP_CHANCE:
						next_lamp_dist += LAMP_SPACING
						continue

					# Kiểm tra không đặt đèn trùng chỗ
					var too_close: bool = false
					var min_dist2: float = (LAMP_SPACING * 0.55) * (LAMP_SPACING * 0.55)
					for prev in placed_positions:
						if prev.distance_squared_to(lamp_2d) < min_dist2:
							too_close = true
							break
					if not too_close:
						placed_positions.append(lamp_2d)
						var local_x: float = lx - cx_world
						var local_z: float = lz - cz_world
						var lamp := WoodLamp.new()
						lamp.position = Vector3(local_x, 1.0, local_z)
						lamp.road_dir = seg_dir
						add_child(lamp)

				next_lamp_dist += LAMP_SPACING

			dist_acc = t_end

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
