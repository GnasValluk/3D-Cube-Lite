extends RefCounted

const _Data  = preload("chunk_data.gd")
const _BlockData = preload("chunk_block_data.gd")

## Profiler sub-section (benchmark test bật; mặc định tắt)
static var _prof: bool = false
static var _p_last: int = 0
static func _p(tag: String) -> void:
	if not _prof:
		return
	var now := Time.get_ticks_usec()
	print("    [p] %-20s %6.2fms" % [tag, (now - _p_last) * 0.001])
	_p_last = now

## ── _fill_blocks: map biome/height → slab block IDs ─────────────────────────
## BEDROCK LAYER: Layer 0 (Y_MIN) luôn là BEDROCK (không thể phá vỡ)
## STONE fill từ layer 1 đến top_slab-2
## Hồ có đáy STONE chắc chắn, không rớt void
## ── Bãi cỏ non trên đồng bằng ────────────────────────────────────────────────
## Không sample noise ở đây: loại surface block (GRASS/DARK_GRASS/YOUNG_GRASS/
## GRASS_DIRT/MUDDY_SAND/...) được phân loại cell-level trong
## world_chunk.compute_chunk theo HÌNH THẾ địa hình (hb_rise, khoảng biển, hồ).
## fill_blocks chỉ map TileType.YOUNG_GRASS → BlockID.YOUNG_GRASS.
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
				_Data.TileType.GRASS_DIRT:
					top_block = B.GRASS_DIRT
				_Data.TileType.DARK_GRASS:
					top_block = B.DARK_GRASS
				_Data.TileType.TWILIGHT_GRASS:
					top_block = B.TWILIGHT_GRASS
				_Data.TileType.TWILIGHT_DIRT:
					top_block = B.TWILIGHT_DIRT
				_Data.TileType.YOUNG_GRASS:
					top_block = B.YOUNG_GRASS  # bãi cỏ non (cơ chế bãi đất)
				_Data.TileType.DRY_GRASS:
					top_block = B.DRY_GRASS     # cỏ già khô — như cỏ thường
				_Data.TileType.SPARSE_GRASS:
					top_block = B.SPARSE_GRASS  # cỏ thưa lẫn đất — như cỏ thường
				_Data.TileType.SAND:       top_block = B.SAND
				_Data.TileType.SAND_WHITE: top_block = B.OCEAN_SAND
				_Data.TileType.DIRT:       top_block = B.DIRT
				_Data.TileType.DESERT:     top_block = B.SAND
				_Data.TileType.SAND_DEEP:  top_block = B.SAND_DEEP
				_Data.TileType.PALE_SAND:  top_block = B.PALE_SAND
				_Data.TileType.STONE_PATCH:
					top_block = _stone_patch_top(x, z, cx, cz, size)
				_Data.TileType.SILT:       top_block = B.SILT
				_Data.TileType.MUDDY_SAND: top_block = B.MUDDY_SAND
				_Data.TileType.MANGROVE_MUD: top_block = B.MANGROVE_MUD
				_Data.TileType.FROST:      top_block = B.SNOW
				_Data.TileType.FROST_SNOW: top_block = B.SNOW
				_Data.TileType.SWAMP_MUD:      top_block = B.SWAMP_MUD
				_Data.TileType.SWAMP_DIRT:     top_block = B.SWAMP_DIRT
				_Data.TileType.SWAMP:      top_block = B.SWAMP_MUD
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
			# Chỉ fill tới max(top_slab, water_top_slab): trên đó là AIR (buffer
			# đã zero = AIR) — trước đây quét đủ CHUNK_H (69 layer) mỗi cột.
			var ly_max: int = mini(maxi(top_slab, water_top_slab), CHUNK_H - 1)
			for ly in range(ly_max + 1):
				var blk: int = B.AIR
				if ly == 0:
					blk = top_block if top_slab == 0 else B.BEDROCK
				elif ly <= top_slab - 2:
					blk = B.STONE
				elif ly == top_slab - 1 and top_slab > 1:
					if biome == _Data.TileType.STONE_PATCH:
						blk = B.STONE
					elif top_block == B.MANGROVE_MUD:
						blk = B.MANGROVE_MUD  # bùn sâu bên dưới bãi bùn triều
					elif top_block == B.SWAMP_MUD:
						blk = B.SWAMP_DIRT  # đất đầm lầy bên dưới bùn sình
					elif top_block == B.SWAMP_DIRT:
						blk = B.SWAMP_DIRT  # mô bùn cao: đất đầm lầy xuống sâu
					elif top_block == B.DARK_GRASS or top_block == B.YOUNG_GRASS or top_block == B.DIRT \
							or top_block == B.GRASS_DIRT or top_block == B.GRASS \
							or top_block == B.DRY_GRASS or top_block == B.SPARSE_GRASS \
							or top_block == B.TWILIGHT_GRASS or top_block == B.TWILIGHT_DIRT \
							or top_block == B.SNOW:
						blk = B.FROST_DIRT if top_block == B.SNOW \
								else (B.DARK_DIRT if top_block != B.TWILIGHT_GRASS and top_block != B.TWILIGHT_DIRT \
									else B.TWILIGHT_DIRT)
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
## Đồng bằng cỏ (GRASS_DIRT): chủ yếu quặng than + sắt hiếm, tỷ lệ spawn thấp hơn.
const ORE_HILL_MIN_DIST: float = 100.0   # cách spawn (0,0) tối thiểu (block)
const ORE_HILL_CHANCE: int = 28          # xác suất 1 chunk có đồi (%)
const ORE_HILL_PLAINS_CHANCE: int = 14   # đồng bằng cỏ: thấp hơn (chỉ than + sắt hiếm)
const ORE_HILL_PLAINS_IRON_PCT: int = 12 # đồng bằng cỏ: xác suất quặng là sắt (%)

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

## ── _stone_patch_top: block bề mặt của BÃI ĐÁ (TileType.STONE_PATCH) ─────────
## Deterministic theo cell: chủ yếu STONE, tỷ lệ nhỏ quặng than (COAL_ORE),
## hiếm sắt (IRON_ORE). Bãi đá chỉ ở đồng bằng → tuân thủ "chỉ than + sắt hiếm"
## (đồng/nhôm không lộ trên bề mặt bãi đá). Gần spawn (≤ ORE_HILL_MIN_DIST)
## không quặng — giữ vùng spawn an toàn cho người chơi mới.
static func _stone_patch_top(x: int, z: int, cx: int, cz: int, size: int) -> int:
	const B := _Data.BlockID
	var wx: float = float(cx * size + x)
	var wz: float = float(cz * size + z)
	if sqrt(wx * wx + wz * wz) < ORE_HILL_MIN_DIST:
		return B.STONE
	var seed_v: int = (cx * size + x) * 73856093 ^ (cz * size + z) * 19349663
	var roll: int = _oh_hash(seed_v, 51) % 100
	if roll < 8:
		return B.COAL_ORE
	if roll < 11:
		return B.IRON_ORE
	return B.STONE

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

	# Đồng bằng cỏ (GRASS_DIRT/GRASS/DARK_GRASS/YOUNG_GRASS): tỷ lệ thấp hơn, chủ yếu than + sắt hiếm
	var is_plains: bool = _Data.is_grass_tile(biome_grid[hx][hz])
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
		if _Data.is_grass_tile(bg) \
				or bg == _Data.TileType.TWILIGHT_GRASS or bg == _Data.TileType.TWILIGHT_DIRT:
			biome_grid[p.x][p.z] = _Data.TileType.DIRT

	return { "cx": hx, "cz": hz, "plains": is_plains }

## ── _build_terrain_mesh: COLUMN-TOP OPTIMIZED ────────────────────────────────
## Mỗi column vẽ 1 top face (strip) + 4 side face theo TỪNG LAYER thực tế:
## mặt bên chỉ vẽ nơi hàng xóm cùng layer là AIR/WATER — không giả định cột
## đặc liền từ top → đáy. Block đặt lơ lửng không tạo tường ảo chạy xuống
## đáy thế giới; block đặt chồng lệch 1 ô không nuốt mặt bên của block dưới.
## Mặt dưới vẽ cho run đặc khi dưới đáy là AIR/WATER (game có 2 góc nhìn).
static var _FAST_PATH := true

static func build_terrain_mesh(st: SurfaceTool, bd: _BlockData,
		cols: int, dim_id: int, top_ly_hint: PackedInt32Array = PackedInt32Array(),
		gen_fresh: bool = false) -> void:
	const Y_MIN  := _BlockData.Y_MIN
	const CHUNK_H := _BlockData.CHUNK_H
	const SLAB   := _BlockData.SLAB_HEIGHT
	const B      := _Data.BlockID
	var hw: float = _Data.VOXEL * 0.5
	var half: float = float(cols) * _Data.VOXEL * 0.5
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW

	var top_ly  := PackedInt32Array()
	var top_blk := PackedByteArray()
	var gap_ly  := PackedInt32Array()
	var gap_blk := PackedByteArray()
	var col_shape := PackedByteArray()  # 1 = cột chứa shaped block (cấm fast path)
	top_ly.resize(cols * cols)
	top_blk.resize(cols * cols)
	gap_ly.resize(cols * cols)
	gap_blk.resize(cols * cols)
	col_shape.resize(cols * cols)
	col_shape.fill(0)
	_p_last = Time.get_ticks_usec()

	# Truy cập buffer trực tiếp (như fill_blocks) — tránh 21K method call/chunk
	var layer_stride: int = cols
	var layer_size: int = CHUNK_H * cols
	var data: PackedByteArray = bd._data

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
		# gap_ly: đỉnh khối đặc phía DƯỚI khe hở (mặt đất dưới block lơ lửng).
		# gen_fresh: fill_blocks luôn tạo cột ĐẶC liền [0..top] (không khe, không
		# shaped block) → bỏ hẳn scan; chỉ rebuild_mesh (sau khi player đào/đặt)
		# mới có khe hở nên cần scan.
		if gen_fresh:
			gap_ly.fill(-1)
			gap_blk.fill(B.AIR)
		else:
			for x in range(cols):
				for z in range(cols):
					var ly: int = top_ly[x * cols + z]
					var gl: int = -1
					var gb: int = B.AIR
					if ly >= 0:
						var i: int = x * layer_size + ly * layer_stride + z
						while ly > 0:
							ly -= 1
							i -= layer_stride
							var b: int = data[i]
							if b == B.STONE_QTR or b == B.STONE_EIGHTH or b == B.STONE_THIN:
								col_shape[x * cols + z] = 1
							if b == B.AIR or b == B.WATER \
									or (b >= B.WATER_SOURCE and b <= B.WATER_LEVEL_1):
								# khe hở — tìm đỉnh khối đặc bên dưới (bỏ qua shape block)
								while ly >= 0:
									var b2: int = data[i]
									if b2 != B.AIR and not (b2 == B.WATER \
											or (b2 >= B.WATER_SOURCE and b2 <= B.WATER_LEVEL_1)) \
											and not (b2 == B.STONE_QTR or b2 == B.STONE_EIGHTH or b2 == B.STONE_THIN):
										gl = ly
										gb = b2
										break
									ly -= 1
									i -= layer_stride
								break
					gap_ly[x * cols + z]  = gl
					gap_blk[x * cols + z] = gb
	else:
		for x in range(cols):
			for z in range(cols):
				var best_ly: int = -1
				var best_blk: int = B.AIR
				for ly in range(CHUNK_H - 1, -1, -1):
					var blk: int = bd.get_block(x, ly, z)
					if blk != B.AIR and not _Data.is_water(blk) \
							and not _Data.is_shaped_block(blk):
						best_ly = ly
						best_blk = blk
						break
				top_ly[x * cols + z]  = best_ly
				top_blk[x * cols + z] = best_blk
				var gl: int = -1
				var gb: int = B.AIR
				if best_ly >= 0:
					var i: int = x * layer_size + best_ly * layer_stride + z
					for ly in range(best_ly - 1, -1, -1):
						i -= layer_stride
						var b2: int = data[i]
						if b2 == B.STONE_QTR or b2 == B.STONE_EIGHTH or b2 == B.STONE_THIN:
							col_shape[x * cols + z] = 1
						if b2 == B.AIR or b2 == B.WATER \
								or (b2 >= B.WATER_SOURCE and b2 <= B.WATER_LEVEL_1):
							var ly2: int = ly
							var i2: int = i
							while ly2 >= 0:
								var b3: int = data[i2]
								if b3 != B.AIR and not (b3 == B.WATER \
										or (b3 >= B.WATER_SOURCE and b3 <= B.WATER_LEVEL_1)) \
										and not (b3 == B.STONE_QTR or b3 == B.STONE_EIGHTH or b3 == B.STONE_THIN):
									gl = ly2
									gb = b3
									break
								ly2 -= 1
								i2 -= layer_stride
							break
				gap_ly[x * cols + z]  = gl
				gap_blk[x * cols + z] = gb
	_p("top_ly+gap_scan")

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
	_p("top_strips")

	# Mặt đất dưới block lơ lửng — vẽ lại top face của khối đặc bên dưới khe hở
	# để không tạo lỗ hổng nhìn/ngã xuống void (collision trimesh cũng kín lại).
	for x in range(cols):
		var z: int = 0
		while z < cols:
			var gl: int = gap_ly[x * cols + z]
			if gl < 0:
				z += 1
				continue
			var gb: int = gap_blk[x * cols + z]
			var z_end: int = z + 1
			while z_end < cols \
					and gap_ly[x * cols + z_end] == gl \
					and gap_blk[x * cols + z_end] == gb:
				z_end += 1
			var strip: int = z_end - z
			var cy_gap: float = float(gl + Y_MIN) * SLAB + SLAB
			var gx_mid: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var gz_mid: float = -half + (float(z) + float(strip) * 0.5) * _Data.VOXEL
			_add_quad(st, Vector3(gx_mid, cy_gap, gz_mid),
				Vector3(hw, 0, 0), Vector3(0, 0, float(strip) * hw),
				Vector3(0, 1, 0), colors[gb])
			z = z_end
	_p("gap_strips")

	# ── Mặt bên + mặt dưới theo layer thực tế ──────────────────────────────
	# Terrain cột đặc liền → tường nơi hàng xóm thấp hơn (tương đương cũ).
	# Block đặt lẻ (lơ lửng / chồng lệch) → mặt bên chỉ vẽ nơi hàng xóm CÙNG
	# layer là AIR/WATER — không bị nuốt mặt, không thấy void xuyên qua.
	# Mặt dưới vẽ khi dưới đáy run là AIR/WATER (2 góc nhìn của game).
	var side_mul: float = 0.62
	var bot_mul: float = 0.40
	var _dirs4 := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for x in range(cols):
		for z in range(cols):
			var tC: int = top_ly[x * cols + z]
			if tC < 0:
				continue
			# ── Fast path: cột đặc liền [0..tC] (gap_ly==-1) + hàng xóm đặc ──
			# Mặt bên chỉ lộ thiên trên độ cao hàng xóm → xác định ngay bằng
			# top_ly, không cần scan từng layer. Mọi hàng xóm trong chunk phải
			# đặc (gap_ly==-1); nếu có khe hổng thì rơi về slow path cho đúng.
			if _FAST_PATH and gap_ly[x * cols + z] == -1 and col_shape[x * cols + z] == 0:
				var fast_ok := true
				for d in _dirs4:
					var nx: int = x + d.x
					var nz: int = z + d.y
					if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
						continue
					if gap_ly[nx * cols + nz] != -1:
						fast_ok = false
						break
				if fast_ok:
					_emit_solid_column(st, data, cols, layer_size, layer_stride,
						x, z, tC, top_ly, half, colors, side_mul)
					continue
			var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
			var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL
			# Liệt kê từng "run" đặc [lo..hi] trong cột (từ đỉnh xuống đáy)
			var run_lo: int = -1
			var run_hi: int = -1
			var lv: int = tC
			var li: int = x * layer_size + tC * layer_stride + z
			while lv >= 0:
				var bb: int = data[li]
				if bb != B.AIR and not _Data.is_water(bb) \
						and not _Data.is_shaped_block(bb):
					if run_hi < 0:
						run_hi = lv
					run_lo = lv
				elif run_hi >= 0:
					_emit_column_run(st, data, cols, layer_size, layer_stride,
						x, z, run_lo, run_hi, cx_f, cz_f, colors, side_mul, bot_mul)
					run_lo = -1
					run_hi = -1
				lv -= 1
				li -= layer_stride
			if run_hi >= 0:
				_emit_column_run(st, data, cols, layer_size, layer_stride,
					x, z, run_lo, run_hi, cx_f, cz_f, colors, side_mul, bot_mul)
	_p("column_runs")

## ── _lod_surface_block: block đại diện của ô biome cho mesh LOD ─────────────
## Bản rút gọn của match trong fill_blocks — chỉ cho màu, không ghi block data.
static func _lod_surface_block(biome: int) -> int:
	const B := _Data.BlockID
	match biome:
		_Data.TileType.GRASS_DIRT:          return B.GRASS_DIRT
		_Data.TileType.DARK_GRASS:          return B.DARK_GRASS
		_Data.TileType.TWILIGHT_GRASS:      return B.TWILIGHT_GRASS
		_Data.TileType.TWILIGHT_DIRT:       return B.TWILIGHT_DIRT
		_Data.TileType.YOUNG_GRASS:         return B.YOUNG_GRASS
		_Data.TileType.DRY_GRASS:           return B.DRY_GRASS
		_Data.TileType.SPARSE_GRASS:        return B.SPARSE_GRASS
		_Data.TileType.GRASS:               return B.GRASS
		_Data.TileType.SAND:                return B.SAND
		_Data.TileType.SAND_WHITE:          return B.OCEAN_SAND
		_Data.TileType.SAND_DEEP:           return B.SAND_DEEP
		_Data.TileType.PALE_SAND:           return B.PALE_SAND
		_Data.TileType.DIRT:                return B.DIRT
		_Data.TileType.DESERT:              return B.SAND
		_Data.TileType.STONE_PATCH:         return B.STONE
		_Data.TileType.SILT:                return B.SILT
		_Data.TileType.MUDDY_SAND:          return B.MUDDY_SAND
		_Data.TileType.MANGROVE_MUD:        return B.MANGROVE_MUD
		_Data.TileType.FROST:               return B.SNOW
		_Data.TileType.FROST_SNOW:          return B.SNOW
		_Data.TileType.SWAMP_MUD:           return B.SWAMP_MUD
		_Data.TileType.SWAMP_DIRT:          return B.SWAMP_DIRT
		_Data.TileType.SWAMP:               return B.SWAMP_MUD
		_Data.TileType.OCEAN_DEEP:          return B.OCEAN_FLOOR
	return B.GRASS_DIRT

## ── build_lod_mesh: mesh THÔ cho chunk xa (Distant-Horizons style) ───────────
## Không cần block data: chỉ đọc biome_grid + height_grid + road_grid rồi vẽ
## quads trên lưới thô `step`. Cột nước → mặt phẳng ở WATER_Y (đại dương/hồ
## xa trông như mặt nước). Mặt bên vẽ nơi mẫu lân cận thấp hơn → địa hình
## không có lỗ nhìn/đổ sụt khi nhìn từ xa. Rẻ: 1 MeshInstance3D thay vì cả tá.
static func build_lod_mesh(st: SurfaceTool, biome_grid: Array, height_grid: Array,
		road_grid: PackedByteArray, cols: int, dim_id: int, step: int = 4) -> void:
	const WATER_Y  := _Data.WATER_Y
	const B        := _Data.BlockID
	const ROUTE    := B.TRAIL
	var use_rw: bool = dim_id == _Data._Dim.DimensionID.REAL_WORLD
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW if use_rw else _Data.BLOCK_COLORS_TW
	var half: float = float(cols) * 0.5
	var hw: float = float(step) * 0.5
	var water_col: Color = colors[B.WATER_SOURCE]
	var water_c: Color = Color(water_col.r, water_col.g, water_col.b, 1.0)

	var n: int = ceili(float(cols) / float(step))
	var surf_y := PackedFloat32Array()
	var surf_land := PackedByteArray()
	var surf_c := PackedColorArray()
	surf_y.resize(n * n)
	surf_land.resize(n * n)
	surf_c.resize(n * n)
	for k in range(n):
		var ci: int = mini(k * step, cols - 1)
		for l in range(n):
			var cz_i: int = mini(l * step, cols - 1)
			var i: int = k * n + l
			var h: float = height_grid[ci][cz_i]
			if h <= WATER_Y:
				surf_y[i] = WATER_Y
				surf_land[i] = 0
				surf_c[i] = water_c
			else:
				surf_y[i] = h
				surf_land[i] = 1
				var blk: int = _lod_surface_block(biome_grid[ci][cz_i])
				if road_grid.size() > 0 and road_grid[ci * cols + cz_i] != 0:
					blk = ROUTE
				surf_c[i] = colors[blk]

	# Top quads — lưới thô phủ trọn chunk (ô tâm lệch nửa step → khớp biên giữa
	# 2 chunk láng giềng mà không đè đôi/không hở: ô cuối dừng tại biên khoảng).
	for k in range(n):
		for l in range(n):
			var i: int = k * n + l
			var cx: float = -half + (float(k) * step + 0.5)
			var cz: float = -half + (float(l) * step + 0.5)
			_add_quad(st, Vector3(cx, surf_y[i], cz),
				Vector3(hw, 0, 0), Vector3(0, 0, hw), Vector3(0, 1, 0), surf_c[i])

	# Mặt bên: tường dọc tại mặt phẳng chung của 2 mẫu kề (+x và +z), chỉ khi
	# một bên cao hơn; nước bên dưới coi như nền mực nước (WATER_Y).
	var side_mul: float = 0.62
	for k in range(n):
		for l in range(n):
			var i0: int = k * n + l
			# +x
			if k + 1 < n:
				var i1: int = i0 + n
				_emit_lod_wall(st,
					-half + (float(k) * step + 0.5) + hw,
					-half + (float(l) * step + 0.5), hw,
					surf_y[i0], surf_y[i1], surf_land[i0], surf_land[i1],
					surf_c[i0], surf_c[i1], Vector3(1, 0, 0), side_mul)
			# +z
			if l + 1 < n:
				var i1: int = i0 + 1
				_emit_lod_wall(st,
					-half + (float(k) * step + 0.5),
					-half + (float(l) * step + 0.5) + hw, hw,
					surf_y[i0], surf_y[i1], surf_land[i0], surf_land[i1],
					surf_c[i0], surf_c[i1], Vector3(0, 0, 1), side_mul)

## ── _emit_lod_wall: tường dọc giữa 2 mẫu surface (yo bên thấp → yo bên cao) ─
## Vẽ trên mặt phẳng chung xp (hoặc zp). Bên cao tô màu của nó; nếu cả hai cùng
## nước (ngang nhau) thì không vẽ. `normal` là hướng về phía bên thấp hơn.
static func _emit_lod_wall(st: SurfaceTool, xp: float, zp: float, hw: float,
		ya: float, yb: float, land_a: int, land_b: int,
		ca: Color, cb: Color, n: Vector3, side_mul: float) -> void:
	# v_axis: trục dọc theo mặt tường (vuông góc với pháp tuyến trong mặt phẳng xz)
	var v_axis := Vector3(1, 0, 0) if absf(n.z) > 0.5 else Vector3(0, 0, 1)
	if absf(ya - yb) < 0.001:
		return
	if ya > yb:
		if land_a == 0:
			return
		var c := Color(ca.r * side_mul, ca.g * side_mul, ca.b * side_mul, ca.a)
		_emit_lod_wall_band(st, xp, zp, hw, v_axis, yb, ya, n, c)
	else:
		if land_b == 0:
			return
		var c := Color(cb.r * side_mul, cb.g * side_mul, cb.b * side_mul, cb.a)
		var nn: Vector3 = -n
		_emit_lod_wall_band(st, xp, zp, hw, v_axis, ya, yb, nn, c)

static func _emit_lod_wall_band(st: SurfaceTool, xp: float, zp: float, hw: float,
		v_axis: Vector3, y_lo: float, y_hi: float, n: Vector3, col: Color) -> void:
	var cy: float = (y_lo + y_hi) * 0.5
	var hy: float = (y_hi - y_lo) * 0.5
	_add_quad(st, Vector3(xp, cy, zp),
		Vector3(0, hy, 0), v_axis * hw, n, col)

## ── _emit_solid_column: FAST PATH mặt bên cho cột đặc liền [0..top] ────────
## Mặt bên chỉ lộ thiên ở các layer TRÊN đỉnh hàng xóm (chunk biên: cả cột).
## Trục u luôn theo hướng mặt; block thay đổi giữa span thì tách span màu.
static var _SOLID_FACES: Array = _make_solid_faces()
static func _make_solid_faces() -> Array:
	var hw: float = _Data.VOXEL * 0.5
	return [
		[0, -1, Vector3(0, 0, -1), Vector3(hw, 0, 0)],
		[0, 1,  Vector3(0, 0, 1),  Vector3(-hw, 0, 0)],
		[-1, 0, Vector3(-1, 0, 0), Vector3(0, 0, -hw)],
		[1, 0,  Vector3(1, 0, 0),  Vector3(0, 0, hw)],
	]

static func _emit_solid_column(st: SurfaceTool, data: PackedByteArray, cols: int,
		layer_size: int, layer_stride: int, x: int, z: int, top: int,
		top_ly: PackedInt32Array, half: float,
		colors: Array[Color], side_mul: float) -> void:
	const B := _Data.BlockID
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	var hw: float = _Data.VOXEL * 0.5
	var cx_f: float = -half + (float(x) + 0.5) * _Data.VOXEL
	var cz_f: float = -half + (float(z) + 0.5) * _Data.VOXEL

	var faces: Array = _SOLID_FACES
	for f in faces:
		var nx: int = x + f[0]
		var nz: int = z + f[1]
		var lo: int
		if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
			lo = 0
		else:
			var nt: int = top_ly[nx * cols + nz]
			if nt >= top:
				continue  # hàng xóm cao/ngang → không lộ thiên
			lo = nt + 1
		var n: Vector3 = f[2]
		var u: Vector3 = f[3]
		var face_off: Vector3 = n * hw
		# Gộp span cùng block từ top xuống lo
		var i: int = x * layer_size + top * layer_stride + z
		var span_lo: int = -1
		var span_hi: int = -1
		var span_blk: int = -1
		var lv: int = top
		while lv >= lo:
			var blk: int = data[i]
			if span_lo < 0:
				span_hi = lv
				span_blk = blk
			elif blk != span_blk:
				_emit_side_span(st, cx_f, cz_f, n, face_off, u, span_lo,
					span_hi, span_blk, colors, side_mul)
				span_hi = lv
				span_blk = blk
			span_lo = lv
			lv -= 1
			i -= layer_stride
		if span_lo >= 0:
			_emit_side_span(st, cx_f, cz_f, n, face_off, u, span_lo, span_hi,
				span_blk, colors, side_mul)

## ── _add_quad_uv: quad với UV (dùng cho ore texture) ────────────────────────
## tscale: số lần lặp texture theo (u, v) — mặt bên đặt 1 họa tiết/slab.
static func _add_quad_uv(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3,
		n: Vector3, tscale: Vector2 = Vector2(1, 1)) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0 * tscale.x, 0 * tscale.y)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1 * tscale.x, 0 * tscale.y)); st.add_vertex(center + u - v)
	st.set_uv(Vector2(1 * tscale.x, 1 * tscale.y)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0 * tscale.x, 0 * tscale.y)); st.add_vertex(center - u - v)
	st.set_uv(Vector2(1 * tscale.x, 1 * tscale.y)); st.add_vertex(center + u + v)
	st.set_uv(Vector2(0 * tscale.x, 1 * tscale.y)); st.add_vertex(center - u + v)

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

## ── _emit_column_run: mặt bên + mặt dưới cho 1 run đặc [lo..hi] ─────────────
## Mặt bên: gộp các layer liên tiếp mà hàng xóm cùng layer là AIR/WATER/shape
## (hoặc ngoài chunk) thành span → 1 quad/span. Mặt dưới: vẽ khi layer dưới
## đáy run là AIR/WATER — nhìn từ góc dưới không thấy xuyên qua block.
static func _emit_column_run(st: SurfaceTool, data: PackedByteArray, cols: int,
		layer_size: int, layer_stride: int, x: int, z: int, run_lo: int,
		run_hi: int, cx_f: float, cz_f: float, colors: Array[Color],
		side_mul: float, bot_mul: float) -> void:
	const B := _Data.BlockID
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	var hw: float = _Data.VOXEL * 0.5
	var run_blk: int = data[x * layer_size + run_hi * layer_stride + z]
	var top_col: Color = colors[run_blk]

	# Màu đáy theo block ở đáy run — khối cỏ phía trên thì đáy = đất
	var bot_blk: int = data[x * layer_size + run_lo * layer_stride + z]
	var bot_id: int = bot_blk
	var gd: int = _Data.grass_dirt_id(bot_blk)
	if gd >= 0:
		bot_id = gd
	var bot_c: Color = colors[bot_id]
	var bot_col: Color = Color(bot_c.r * bot_mul, bot_c.g * bot_mul,
		bot_c.b * bot_mul, bot_c.a)

	# [normal, offset tâm mặt, trục u]
	var faces: Array = [
		[Vector3(0, 0, -1), Vector3(0, 0, -hw), Vector3(hw, 0, 0)],
		[Vector3(0, 0, 1),  Vector3(0, 0, hw),  Vector3(-hw, 0, 0)],
		[Vector3(-1, 0, 0), Vector3(-hw, 0, 0), Vector3(0, 0, -hw)],
		[Vector3(1, 0, 0),  Vector3(hw, 0, 0),  Vector3(0, 0, hw)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var face_off: Vector3 = f[1]
		var u: Vector3 = f[2]
		var nx: int = x + int(n.x)
		var nz: int = z + int(n.z)
		var span_lo: int = -1
		var span_hi: int = -1
		var span_blk: int = -1
		var nli: int = nx * layer_size + run_hi * layer_stride + nz
		var lv: int = run_hi
		while lv >= run_lo:
			var exposed: bool
			if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
				exposed = true
			else:
				var nb: int = data[nli]
				exposed = nb == B.AIR or _Data.is_water(nb) \
						or _Data.is_shaped_block(nb)
			if exposed:
				var blk: int = data[x * layer_size + lv * layer_stride + z]
				if span_lo < 0:
					span_hi = lv
					span_blk = blk
				elif blk != span_blk:
					# Đổi block giữa span — tách để tô màu riêng từng khối
					_emit_side_span(st, cx_f, cz_f, n, face_off, u, span_lo,
						span_hi, span_blk, colors, side_mul)
					span_hi = lv
					span_blk = blk
				span_lo = lv
			elif span_lo >= 0:
				_emit_side_span(st, cx_f, cz_f, n, face_off, u, span_lo,
					span_hi, span_blk, colors, side_mul)
				span_lo = -1
			lv -= 1
			nli -= layer_stride
		if span_lo >= 0:
			_emit_side_span(st, cx_f, cz_f, n, face_off, u, span_lo, span_hi,
				span_blk, colors, side_mul)

	# Mặt dưới — layer 0 là đáy thế giới, không cần vẽ
	if run_lo > 0:
		var bel: int = data[x * layer_size + (run_lo - 1) * layer_stride + z]
		if bel == B.AIR or _Data.is_water(bel) or _Data.is_shaped_block(bel):
			var y_bot: float = float(run_lo + Y_MIN) * SLAB
			_add_quad(st, Vector3(cx_f, y_bot, cz_f), Vector3(hw, 0, 0),
				Vector3(0, 0, hw), Vector3(0, -1, 0), bot_col)

## ── _emit_side_span: quad mặt bên cho span layer [lo..hi] (đã biết lộ thiên) ─
## Khối cỏ: nửa trên = cỏ (side), nửa dưới = đất (side) — kiểu Minecraft.
static func _emit_side_span(st: SurfaceTool, cx_f: float, cz_f: float,
		n: Vector3, face_off: Vector3, u: Vector3, lo: int, hi: int,
		blk: int, colors: Array[Color], side_mul: float) -> void:
	const SLAB := _BlockData.SLAB_HEIGHT
	const Y_MIN := _BlockData.Y_MIN
	var y_bot: float = float(lo + Y_MIN) * SLAB
	var y_top: float = float(hi + Y_MIN) * SLAB + SLAB
	var dirt_id: int = _Data.grass_dirt_id(blk)
	if dirt_id >= 0:
		var grass_c: Color = colors[blk]
		var dirt_c: Color = colors[dirt_id]
		var grass_side := Color(grass_c.r * side_mul, grass_c.g * side_mul,
			grass_c.b * side_mul, grass_c.a)
		var dirt_side := Color(dirt_c.r * side_mul, dirt_c.g * side_mul,
			dirt_c.b * side_mul, dirt_c.a)
		var mid: float = (y_top + y_bot) * 0.5
		_emit_band(st, cx_f, cz_f, n, face_off, u, mid, y_top, grass_side)
		_emit_band(st, cx_f, cz_f, n, face_off, u, y_bot, mid, dirt_side)
	else:
		var c: Color = colors[blk]
		var col := Color(c.r * side_mul, c.g * side_mul, c.b * side_mul, c.a)
		_emit_band(st, cx_f, cz_f, n, face_off, u, y_bot, y_top, col)

## ── _emit_band: quad mặt bên trong khoảng [y_bot..y_top] ─────────────────────
static func _emit_band(st: SurfaceTool, cx_f: float, cz_f: float,
		n: Vector3, face_off: Vector3, u: Vector3, y_bot: float,
		y_top: float, col: Color) -> void:
	var h: float = (y_top - y_bot) * 0.5
	var cy_mid: float = (y_top + y_bot) * 0.5
	_add_quad(st, Vector3(cx_f + face_off.x, cy_mid, cz_f + face_off.z),
		u, Vector3(0, h, 0), n, col)
