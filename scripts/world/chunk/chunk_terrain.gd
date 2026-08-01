extends RefCounted

const _Data  = preload("chunk_data.gd")
const _BlockData = preload("chunk_block_data.gd")

## ── _fill_blocks: map biome/height → slab block IDs ─────────────────────────
## BEDROCK LAYER: Layer 0 (Y_MIN) luôn là BEDROCK (không thể phá vỡ)
## STONE fill từ layer 1 đến top_slab-2
## Hồ có đáy STONE chắc chắn, không rớt void
static func fill_blocks(bd: _BlockData, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, dim_id: int, cx: int = 0, cz: int = 0, size: int = 32,
		nd: Dictionary = {}, reef_mask: PackedFloat32Array = PackedFloat32Array()) -> void:
	const SLAB := _BlockData.SLAB_HEIGHT  # 0.5
	const Y_MIN := _BlockData.Y_MIN       # -18 (21 layers: 0..20)
	const CHUNK_H := _BlockData.CHUNK_H   # 21
	const B := _Data.BlockID

	# Inline set_block — 21K method calls/chunk ≈ 100ms; ghi trực tiếp vào buffer
	var data: PackedByteArray = bd._data
	var layer_stride: int = cols
	var layer_size: int = CHUNK_H * cols
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
				_Data.TileType.DESERT:     top_block = B.SAND
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
							top_block = B.STONE
						elif sea_bm < 0.28:
							top_block = B.OCEAN_GRAVEL
						elif sea_bm < 0.52:
							top_block = B.OCEAN_FLOOR
						elif sea_bm < 0.72:
							top_block = B.SAND
						elif sea_bm < 0.88:
							top_block = B.OCEAN_MUD
						else:
							top_block = B.OCEAN_GRAVEL
					if reef_mask.size() > 0 and reef_mask[x * cols + z] > 0.0:
						top_block = B.STONE

			var is_trail: bool = road_grid.size() > 0 and road_grid[x * cols + z] != 0 \
					and biome != _Data.TileType.SAND \
					and biome != _Data.TileType.SAND_WHITE \
					and biome != _Data.TileType.SILT \
					and biome != _Data.TileType.MUDDY_SAND \
					and biome != _Data.TileType.OCEAN_DEEP
			if is_trail:
				top_block = B.TRAIL

			var top_slab: int = floori((h - SLAB) / SLAB) - Y_MIN
			var water_top_slab: int = floori((_Data.WATER_Y - SLAB) / SLAB) - Y_MIN

			var i: int = x * layer_size + z
			for ly in range(CHUNK_H):
				var blk: int = B.AIR
				if ly == 0:
					blk = top_block if top_slab == 0 else B.BEDROCK
				elif ly <= top_slab - 2:
					blk = B.STONE
				elif ly == top_slab - 1 and top_slab > 1:
					if top_block == B.DARK_GRASS or top_block == B.DIRT:
						blk = B.DARK_DIRT
					else:
						blk = B.SAND_DEEP
				elif ly == top_slab and top_slab > 0:
					blk = top_block
				else:
					if ly <= water_top_slab:
						blk = B.WATER_SOURCE
					else:
						blk = B.AIR
				data[i] = blk
				i += layer_stride

## ── Đồi quặng trên bề mặt — chỉ spawn ở khu vực xa spawn ────────────────────
## Deterministic theo chunk (cùng cx,cz → cùng đồi). Tổng block 4~12: đá trộn
## quặng. Ngoài vùng xa spawn có 4 loại quặng: than, sắt, đồng, nhôm.
## Đồng bằng (DARK_GRASS): chủ yếu quặng than + sắt hiếm, tỷ lệ spawn thấp hơn.
const ORE_HILL_MIN_DIST: float = 100.0   # cách spawn (0,0) tối thiểu (block)
const ORE_HILL_CHANCE: int = 28          # xác suất 1 chunk có đồi (%)
const ORE_HILL_PLAINS_CHANCE: int = 14   # đồng bằng: thấp hơn (chỉ than + sắt hiếm)
const ORE_HILL_PLAINS_IRON_PCT: int = 12 # đồng bằng: xác suất quặng là sắt (%)

const _ORE_HILL_ORES: Array[int] = [
	_Data.BlockID.COAL_ORE,
	_Data.BlockID.IRON_ORE,
	_Data.BlockID.COPPER_ORE,
	_Data.BlockID.BAUXITE_ORE,
]
## Ngưỡng trọng số tích lũy cho _ORE_HILL_ORES: than 34%, sắt 25%, đồng 25%, nhôm 16%
const _ORE_HILL_WEIGHTS: Array[int] = [34, 59, 84, 100]

static func _oh_hash(seed_v: int, salt: int) -> int:
	var h: int = seed_v * 374761393 + salt * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF

static func spawn_ore_hills(bd: _BlockData, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, cx: int, cz: int, size: int) -> Dictionary:
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	const B := _Data.BlockID

	var cw_x: float = float(cx) * size + size * 0.5
	var cw_z: float = float(cz) * size + size * 0.5
	if sqrt(cw_x * cw_x + cw_z * cw_z) < ORE_HILL_MIN_DIST:
		return { "cx": -1, "cz": -1 }

	var seed_v: int = cx * 73856093 ^ cz * 19349663

	var hx: int = _oh_hash(seed_v, 2) % cols
	var hz: int = _oh_hash(seed_v, 3) % cols
	if hx < 2 or hx >= cols - 2 or hz < 2 or hz >= cols - 2:
		return { "cx": -1, "cz": -1 }  # giữ đồi nằm trọn trong chunk, không lấn biên
	if biome_grid[hx][hz] == _Data.TileType.OCEAN_DEEP:
		return { "cx": -1, "cz": -1 }
	if height_grid[hx][hz] <= _Data.WATER_Y:
		return { "cx": -1, "cz": -1 }

	# Đồng bằng (DARK_GRASS): tỷ lệ thấp hơn, chủ yếu than + sắt hiếm
	var is_plains: bool = biome_grid[hx][hz] == _Data.TileType.DARK_GRASS \
		or biome_grid[hx][hz] == _Data.TileType.GRASS
	var chance: int = ORE_HILL_PLAINS_CHANCE if is_plains else ORE_HILL_CHANCE
	if _oh_hash(seed_v, 1) % 100 >= chance:
		return { "cx": -1, "cz": -1 }

	# ── Hình dạng: 3x3 (bỏ 0-2 góc) hoặc 5 chữ thập; tâm cao thêm 1-2 lớp ──
	var is_big: bool = _oh_hash(seed_v, 4) % 2 == 0
	var stack: int = 1 + _oh_hash(seed_v, 5) % 2
	var ore_count: int = 1 + _oh_hash(seed_v, 6) % 3

	var ore_type: int = B.COAL_ORE
	if is_plains:
		# Đồng bằng: than là chính, sắt hiếm (12%)
		var pr: int = _oh_hash(seed_v, 12) % 100
		if pr < ORE_HILL_PLAINS_IRON_PCT:
			ore_type = B.IRON_ORE
	else:
		ore_type = _ORE_HILL_ORES[0]
		var roll: int = _oh_hash(seed_v, 7) % 100
		for i in range(_ORE_HILL_WEIGHTS.size()):
			if roll < _ORE_HILL_WEIGHTS[i]:
				ore_type = _ORE_HILL_ORES[i]
				break

	var cells: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				cells.append(Vector2i(hx, hz))
				continue
			if not is_big and abs(dx) + abs(dz) > 1:
				continue
			if dx != 0 and dz != 0 and _oh_hash(seed_v, 10 + dx * 3 + dz) % 100 < 40:
				continue
			cells.append(Vector2i(hx + dx, hz + dz))
	var kept: Array[Vector2i] = []
	for cell in cells:
		if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= cols:
			continue
		if biome_grid[cell.x][cell.y] == _Data.TileType.OCEAN_DEEP:
			continue
		if height_grid[cell.x][cell.y] <= _Data.WATER_Y:
			continue
		if road_grid.size() > 0 and road_grid[cell.x * cols + cell.y] != 0:
			continue
		kept.append(cell)
	cells = kept
	if cells.size() < 4:
		return { "cx": -1, "cz": -1 }

	# ── Đặt block: lớp đáy trên mặt đất + tâm cao thêm ──
	var placed: Array[Vector3i] = []
	for cell in cells:
		var h: float = height_grid[cell.x][cell.y]
		var ly: int = floori((h - SLAB) / SLAB) - Y_MIN + 1
		placed.append(Vector3i(cell.x, ly, cell.y))
		if cell.x == hx and cell.y == hz:
			for extra in range(1, stack + 1):
				placed.append(Vector3i(cell.x, ly + extra, cell.y))

	# Đáy trên cùng mỗi cột → ưu tiên để quặng lộ ra mặt đồi
	var col_max := {}
	for p in placed:
		var key: int = p.x * 1024 + p.z
		if not col_max.has(key) or col_max[key] < p.y:
			col_max[key] = p.y
	var order: Array[int] = []
	for idx in range(placed.size()):
		if col_max[placed[idx].x * 1024 + placed[idx].z] == placed[idx].y:
			order.append(idx)
	for idx in range(placed.size()):
		if col_max[placed[idx].x * 1024 + placed[idx].z] != placed[idx].y:
			order.append(idx)

	var step: int = _oh_hash(seed_v, 9) % 2 + 1
	var start: int = _oh_hash(seed_v, 8) % maxi(order.size(), 1)
	var is_ore := {}
	for k in range(mini(ore_count, order.size())):
		is_ore[order[(start + k * step) % order.size()]] = true

	for idx in range(placed.size()):
		var p := placed[idx]
		var blk: int = B.STONE if not is_ore.has(idx) else ore_type
		bd.set_block(p.x, p.y, p.z, blk)
		var nh: float = float((p.y + Y_MIN) * SLAB + SLAB)
		if height_grid[p.x][p.z] < nh:
			height_grid[p.x][p.z] = nh
		# Đồi quặng không mọc cỏ
		var bg: int = biome_grid[p.x][p.z]
		if bg == _Data.TileType.GRASS or bg == _Data.TileType.DARK_GRASS:
			biome_grid[p.x][p.z] = _Data.TileType.DIRT

	return { "cx": hx, "cz": hz, "plains": is_plains }

## ── _build_terrain_mesh: COLUMN-TOP OPTIMIZED ────────────────────────────────
static func build_terrain_mesh(st: SurfaceTool, bd: _BlockData,
		cols: int, dim_id: int, top_ly_hint: PackedInt32Array = PackedInt32Array()) -> void:
	const Y_MIN  := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB   := _BlockData.SLAB_HEIGHT
	const B      := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var hh: float = SLAB * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW

	var top_ly  := PackedInt32Array()
	var top_blk := PackedByteArray()
	top_ly.resize(cols * cols)
	top_blk.resize(cols * cols)

	if top_ly_hint.size() >= cols * cols:
		# top_ly đã tính sẵn từ height grid (compute_chunk) — chỉ cần đọc block type
		for x in range(cols):
			for z in range(cols):
				top_ly[x * cols + z] = top_ly_hint[x * cols + z]
		for x in range(cols):
			for z in range(cols):
				var ly: int = top_ly[x * cols + z]
				if ly < 0:
					top_blk[x * cols + z] = B.AIR
				else:
					top_blk[x * cols + z] = bd.get_block(x, ly, z)
	else:
		for x in range(cols):
			for z in range(cols):
				var best_ly: int = -1
				var best_blk: int = B.AIR
				for ly in range(CHUNK_H - 1, -1, -1):
					var blk: int = bd.get_block(x, ly, z)
					if blk != B.AIR and not _Data.is_water(blk):
						best_ly = ly
						best_blk = blk
						break
				top_ly[x * cols + z]  = best_ly
				top_blk[x * cols + z] = best_blk

	for x in range(cols):
		var z: int = 0
		while z < cols:
			var ly: int  = top_ly[x * cols + z]
			var blk: int = top_blk[x * cols + z]
			if ly < 0:
				z += 1; continue

			var z_end: int = z + 1
			while z_end < cols \
					and top_ly[x * cols + z_end]  == ly \
					and top_blk[x * cols + z_end] == blk:
				z_end += 1

			var strip: int   = z_end - z
			var cx_f: float  = -half + (float(x) + 0.5) * _Data.VOXEL
			var cy_top: float = float(ly + Y_MIN) * SLAB + SLAB
			var z_mid: float  = -half + (float(z) + float(strip) * 0.5) * _Data.VOXEL
			var top_col: Color = colors[blk]

			_add_quad(st, Vector3(cx_f, cy_top, z_mid),
				Vector3(hw, 0, 0), Vector3(0, 0, float(strip) * hw),
				Vector3(0, 1, 0), top_col)

			z = z_end

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

			var nx_ly: int
			var diff: float

			nx_ly = top_ly[x * cols + (z - 1)] if z > 0 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f, cy_mid, cz_f - hw),
					Vector3(hw, 0, 0), Vector3(0, side_h * 0.5, 0),
					Vector3(0, 0, -1), side_col)

			nx_ly = top_ly[x * cols + (z + 1)] if z < cols - 1 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f, cy_mid, cz_f + hw),
					Vector3(-hw, 0, 0), Vector3(0, side_h * 0.5, 0),
					Vector3(0, 0, 1), side_col)

			nx_ly = top_ly[(x - 1) * cols + z] if x > 0 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f - hw, cy_mid, cz_f),
					Vector3(0, 0, -hw), Vector3(0, side_h * 0.5, 0),
					Vector3(-1, 0, 0), side_col)

			nx_ly = top_ly[(x + 1) * cols + z] if x < cols - 1 else -1
			diff = cy_top - (float(nx_ly + Y_MIN) * SLAB + SLAB if nx_ly >= 0 else (float(Y_MIN) * SLAB))
			if nx_ly < ly:
				var side_h: float = diff
				var cy_mid: float = cy_top - side_h * 0.5
				_add_quad(st, Vector3(cx_f + hw, cy_mid, cz_f),
					Vector3(0, 0, hw), Vector3(0, side_h * 0.5, 0),
					Vector3(1, 0, 0), side_col)

## ── _add_quad_uv: quad với UV (dùng cho ore texture) ────────────────────────
static func _add_quad_uv(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0, 0)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1, 0)); st.add_vertex(center + u - v)
	st.set_uv(Vector2(1, 1)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0, 0)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1, 1)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0, 1)); st.add_vertex(center - u + v)

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
