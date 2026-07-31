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

			for ly in range(CHUNK_H):
				if ly == 0:
					if top_slab == 0:
						bd.set_block(x, ly, z, top_block)
					else:
						bd.set_block(x, ly, z, B.BEDROCK)
				elif ly <= top_slab - 2:
					bd.set_block(x, ly, z, B.STONE)
				elif ly == top_slab - 1 and top_slab > 1:
					if top_block == B.DARK_GRASS or top_block == B.DIRT:
						bd.set_block(x, ly, z, B.DARK_DIRT)
					else:
						bd.set_block(x, ly, z, B.SAND_DEEP)
				elif ly == top_slab and top_slab > 0:
					bd.set_block(x, ly, z, top_block)
				else:
					if ly <= water_top_slab:
						bd.set_block(x, ly, z, B.WATER_SOURCE)
					else:
						bd.set_block(x, ly, z, B.AIR)

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
				var cluster_size: int = 3 + (s & 3)
				if (s & 4) != 0: cluster_size += 1
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

## ── _build_sediment_mesh ──
static func build_sediment_mesh(bd: _BlockData, cols: int) -> ArrayMesh:
	return WorldChunk._build_textured_block_mesh(bd, cols, _Data.BlockID.SEDIMENT)

## ── _get_sediment_material ──
static func get_sediment_material() -> Material:
	return WorldChunk._get_textured_block_material(_Data.BlockID.SEDIMENT)

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
