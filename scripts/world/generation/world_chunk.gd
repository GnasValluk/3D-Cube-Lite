extends Node3D
class_name WorldChunk

enum TileType { GRASS, DARK_GRASS, SAND, DIRT, SILT }

const _Dim = preload("res://scripts/world/dimension_defs.gd")

const TILE_COLORS_TW: Array[Dictionary] = [
	{ "base": Color(0.06, 0.22, 0.16), "emit": Color(0.08, 0.28, 0.20), "pow": 0.3 },
	{ "base": Color(0.03, 0.12, 0.08), "emit": Color(0.05, 0.16, 0.10), "pow": 0.2 },
	{ "base": Color(0.05, 0.15, 0.10), "emit": Color(0.06, 0.18, 0.12), "pow": 0.2 },
	{ "base": Color(0.04, 0.10, 0.07), "emit": Color(0.05, 0.12, 0.08), "pow": 0.15 },
	{ "base": Color(0.06, 0.14, 0.08), "emit": Color(0.07, 0.16, 0.09), "pow": 0.15 },
]

const TILE_COLORS_RW: Array[Dictionary] = [
	{ "base": Color(0.28, 0.48, 0.18), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.20, 0.35, 0.12), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.90, 0.80, 0.42), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.32, 0.18, 0.08), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.14, 0.14, 0.13), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
]

const VOXEL: float = 1.0
const TILE_W: int = 5
const TILE_D: int = 5
const ROAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const ROAD_SIDE: Color = Color(0.30, 0.30, 0.30)
const TRAIL_COLOR: Color = Color(0.68, 0.52, 0.26)
const TRAIL_SIDE: Color = Color(0.46, 0.36, 0.18)

var _cx: int = 0
var _cz: int = 0
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Dim.DimensionID.TWILIGHT
var _built: bool = false

static var _noise_cache: Dictionary = {}

static func _noise_for_dim(dim_id: int) -> Dictionary:
	if _noise_cache.has(dim_id):
		return _noise_cache[dim_id]

	var base_seed: int = WorldSeed.seed_value + dim_id * 1000
	var freq_bio: float = 0.008
	var freq_warp: float = 0.022

	if dim_id == _Dim.DimensionID.REAL_WORLD:
		freq_bio = 0.012

	var n_bio := FastNoiseLite.new()
	n_bio.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_bio.seed = base_seed
	n_bio.frequency = freq_bio

	var n_warp := FastNoiseLite.new()
	n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_warp.seed = base_seed + 99
	n_warp.frequency = freq_warp

	# Noise riêng để phân loại hồ cát / hồ bùn
	# frequency = 0.018 → patch ~55 unit → vừa đủ để mỗi hồ có 1 loại nhất quán
	var n_lake := FastNoiseLite.new()
	n_lake.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_lake.seed = base_seed + 5555
	n_lake.frequency = 0.018

	var result := { "biome": n_bio, "warp": n_warp, "lake": n_lake }
	_noise_cache[dim_id] = result
	return result

static var _mat_cache: Dictionary = {}

const ROAD_GRID: float = 80.0
const ROAD_OFFSET: float = 22.0
const ROAD_HALF_W: float = 1.5
const ROAD_GRID_R: int = 40

static var _road_curves: Array[PackedVector2Array] = []
static var _road_spatial: Dictionary = {}
static var _road_ready: bool = false
static var _int_cache: Dictionary = {}

static func _intersection(gx: int, gz: int) -> Vector2:
	var key: Vector2i = Vector2i(gx, gz)
	if _int_cache.has(key):
		return _int_cache[key]
	var h: int = WorldSeed.seed_value + 7777 + gx * 73856093 + gz * 19349663
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = h
	var res: Vector2 = Vector2(gx * ROAD_GRID + rng.randf_range(-ROAD_OFFSET, ROAD_OFFSET), gz * ROAD_GRID + rng.randf_range(-ROAD_OFFSET, ROAD_OFFSET))
	_int_cache[key] = res
	return res

static func _point_to_seg_d2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 == 0.0:
		return p.distance_squared_to(a)
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_squared_to(a.lerp(b, t))

static func _make_curve(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var dist: float = a.distance_to(b)
	var off1: float = rng.randf_range(-dist * 0.28, dist * 0.28)
	var off2: float = rng.randf_range(-dist * 0.28, dist * 0.28)
	var p1: Vector2 = a + dir * dist * 0.3 + perp * off1
	var p2: Vector2 = b - dir * dist * 0.3 + perp * off2
	var steps: int = maxi(6, int(dist / 6.0))
	var wp: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		wp.append(u * u * u * a + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * b)
	return wp

static func _index_curves() -> void:
	var cell_sz: float = ROAD_GRID * 0.5
	for ci in range(_road_curves.size()):
		var wp: PackedVector2Array = _road_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var cx0: int = floori(min(a.x, b.x) / cell_sz)
			var cx1: int = floori(max(a.x, b.x) / cell_sz)
			var cz0: int = floori(min(a.y, b.y) / cell_sz)
			var cz1: int = floori(max(a.y, b.y) / cell_sz)
			for cx in range(cx0 - 1, cx1 + 2):
				for cz in range(cz0 - 1, cz1 + 2):
					var ck: Vector2i = Vector2i(cx, cz)
					if not _road_spatial.has(ck):
						_road_spatial[ck] = PackedInt32Array()
					var arr: PackedInt32Array = _road_spatial[ck]
					if arr.size() == 0 or arr[arr.size() - 1] != ci:
						arr.append(ci)

static func _ensure_roads() -> void:
	if _road_ready:
		return
	_road_ready = true

	var seed_base: int = WorldSeed.seed_value + 7777
	var inters: Dictionary = {}
	for gx in range(-ROAD_GRID_R, ROAD_GRID_R + 1):
		for gz in range(-ROAD_GRID_R, ROAD_GRID_R + 1):
			inters[Vector2i(gx, gz)] = _intersection(gx, gz)

	var degree: Dictionary = {}
	var edge_set: Dictionary = {}

	for gx in range(-ROAD_GRID_R, ROAD_GRID_R + 1):
		for gz in range(-ROAD_GRID_R, ROAD_GRID_R + 1):
			var h: int = seed_base + gx * 40009 + gz * 70003
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = h
			var has: Array = [rng.randf() < 0.40, rng.randf() < 0.40, rng.randf() < 0.15, rng.randf() < 0.15]
			var cnt: int = 0
			for v in has:
				if v: cnt += 1
			if cnt < 2:
				for d in range(4):
					if not has[d]:
						has[d] = true
						cnt += 1
						if cnt >= 2:
							break

			var dirs: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
			for d in range(4):
				if not has[d]:
					continue
				var nk: Vector2i = Vector2i(gx + dirs[d].x, gz + dirs[d].y)
				if not inters.has(nk):
					continue
				var ax: int = mini(gx, nk.x)
				var az: int = mini(gz, nk.y)
				var bx: int = maxi(gx, nk.x)
				var bz: int = maxi(gz, nk.y)
				var ek: String = "%d,%d->%d,%d" % [ax, az, bx, bz]
				if edge_set.has(ek):
					continue
				edge_set[ek] = true
				degree[Vector2i(gx, gz)] = degree.get(Vector2i(gx, gz), 0) + 1
				degree[nk] = degree.get(nk, 0) + 1

	for ek in edge_set:
		var parts: PackedStringArray = ek.split("->")
		var ap: PackedStringArray = parts[0].split(",")
		var bp: PackedStringArray = parts[1].split(",")
		var ak: Vector2i = Vector2i(int(ap[0]), int(ap[1]))
		var bk: Vector2i = Vector2i(int(bp[0]), int(bp[1]))
		var h: int = seed_base + ak.x * 100003 + ak.y * 200003 + bk.x * 300007 + bk.y * 500009
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = h
		_road_curves.append(_make_curve(inters[ak], inters[bk], rng))

	_index_curves()

static func _is_on_road(wx: float, wz: float) -> bool:
	_ensure_roads()
	var cell_sz: float = ROAD_GRID * 0.5
	var ck: Vector2i = Vector2i(int(wx / cell_sz), int(wz / cell_sz))
	var indices: PackedInt32Array = _road_spatial.get(ck, PackedInt32Array())
	if indices.is_empty():
		return false
	var pos: Vector2 = Vector2(wx, wz)
	var md2: float = ROAD_HALF_W * ROAD_HALF_W
	for ci in indices:
		var wp: PackedVector2Array = _road_curves[ci]
		for i in range(wp.size() - 1):
			if _point_to_seg_d2(pos, wp[i], wp[i + 1]) <= md2:
				return true
	return false

func setup(cx: int, cz: int, size: int, dimension_id: int = _Dim.DimensionID.TWILIGHT, sync: bool = false) -> void:
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_cols = int(_size / VOXEL)
	_tiles_per_chunk = int(_cols / TILE_W)
	_init_materials()

	var ck: String = _cache_key(cx, cz, dimension_id)
	if _mesh_cache.has(ck):
		apply_chunk(_mesh_cache[ck])
		return

	if sync:
		apply_chunk(compute_chunk(cx, cz, size, dimension_id))
		return

	_pending_chunks[ck] = self
	WorkerThreadPool.add_task(_thread_build.bind(ck, cx, cz, size, dimension_id), true, "chunk")

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	if chunk != null and is_instance_valid(chunk) and chunk.is_inside_tree():
		chunk.call_deferred("apply_chunk", data)

func _make_water_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	if dim_id == _Dim.DimensionID.REAL_WORLD:
		s.code = """
shader_type spatial;
render_mode blend_mix;

uniform vec4 water_color : source_color = vec4(0.08, 0.36, 0.68, 0.72);

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	METALLIC = 0.05;
	ROUGHNESS = 0.25;
}
"""
	else:
		s.code = """
shader_type spatial;
render_mode blend_mix, unshaded;

uniform vec4 water_color : source_color = vec4(0.10, 0.55, 0.45, 0.70);
uniform vec4 emit_color : source_color = vec4(0.08, 0.45, 0.35, 1.0);

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	EMISSION = emit_color.rgb * 2.0;
}
"""

	var m := ShaderMaterial.new()
	m.shader = s
	return m

func _init_materials() -> void:
	if _mat_cache.has(_dimension_id):
		return
	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		var m_t := StandardMaterial3D.new()
		m_t.vertex_color_use_as_albedo = true
		m_t.roughness = 0.9; m_t.metallic_specular = 0.0
		var m_w := _make_water_shader(_dimension_id)
		_mat_cache[_dimension_id] = { "terrain": m_t, "water": m_w }
		return

	var m_t_cv := StandardMaterial3D.new()
	m_t_cv.vertex_color_use_as_albedo = true
	m_t_cv.roughness = 1.0; m_t_cv.metallic_specular = 0.0
	var m_w_cv := _make_water_shader(_dimension_id)
	_mat_cache[_dimension_id] = { "terrain": m_t_cv, "water": m_w_cv }

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

static func _biome_at(wx: float, wz: float, dim_id: int) -> int:
	var nd: Dictionary = _noise_for_dim(dim_id)
	var n_bio: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	var threshold: float = 0.50
	if dim_id == _Dim.DimensionID.REAL_WORLD:
		threshold = 0.40

	if n < threshold: return TileType.GRASS
	return TileType.DARK_GRASS

static func compute_chunk(cx: int, cz: int, size: int, dim_id: int) -> Dictionary:
	var cols: int = int(size / VOXEL)
	var world_ox: float = cx * size
	var world_oz: float = cz * size
	var half: float = size * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h_vox: float = VOXEL * 0.5

	const PAD: int = 5
	const WATER_Y: float = VOXEL * 0.5

	var total: int = cols + 2 * PAD

	var bio: Array[Array] = []
	bio.resize(total)
	for vx in range(total):
		var row: Array = []
		row.resize(total)
		bio[vx] = row
		for vz in range(total):
			var wx: float = world_ox - half + (float(vx - PAD) + 0.5) * VOXEL
			var wz: float = world_oz - half + (float(vz - PAD) + 0.5) * VOXEL
			row[vz] = _biome_at(wx, wz, dim_id)

	var CONST_INF: int = 999
	var dst: Array[Array] = []
	dst.resize(total)
	for vx in range(total):
		var row: Array = []
		row.resize(total)
		dst[vx] = row
		for vz in range(total):
			row[vz] = 0 if bio[vx][vz] == TileType.DARK_GRASS else CONST_INF

	for vx in range(total):
		for vz in range(total):
			if bio[vx][vz] != TileType.GRASS:
				continue
			if (vx > 0 and bio[vx - 1][vz] == TileType.DARK_GRASS) \
				or (vx < total - 1 and bio[vx + 1][vz] == TileType.DARK_GRASS) \
				or (vz > 0 and bio[vx][vz - 1] == TileType.DARK_GRASS) \
				or (vz < total - 1 and bio[vx][vz + 1] == TileType.DARK_GRASS):
				dst[vx][vz] = 1

	for d in range(2, PAD + 1):
		for vx in range(total):
			for vz in range(total):
				if dst[vx][vz] != CONST_INF:
					continue
				if (vx > 0 and dst[vx - 1][vz] == d - 1) \
					or (vx < total - 1 and dst[vx + 1][vz] == d - 1) \
					or (vz > 0 and dst[vx][vz - 1] == d - 1) \
					or (vz < total - 1 and dst[vx][vz + 1] == d - 1):
					dst[vx][vz] = d

	var biome_grid: Array[Array] = []
	biome_grid.resize(cols)
	var height_grid: Array[Array] = []
	height_grid.resize(cols)
	for ivx in range(cols):
		biome_grid[ivx] = []
		biome_grid[ivx].resize(cols)
		height_grid[ivx] = []
		height_grid[ivx].resize(cols)
		var pvx: int = ivx + PAD
		for ivz in range(cols):
			var pvz: int = ivz + PAD
			biome_grid[ivx][ivz] = bio[pvx][pvz]
			if bio[pvx][pvz] == TileType.DARK_GRASS:
				height_grid[ivx][ivz] = VOXEL
			else:
				var d: int = dst[pvx][pvz]
				if d == CONST_INF:
					d = PAD
				height_grid[ivx][ivz] = WATER_Y - min(d, PAD) * VOXEL

	if dim_id == _Dim.DimensionID.REAL_WORLD:
		for ivx in range(cols):
			var pvx: int = ivx + PAD
			for ivz in range(cols):
				var pvz: int = ivz + PAD
				var d: int = dst[pvx][pvz]
				if biome_grid[ivx][ivz] == TileType.GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
					var nd: Dictionary = _noise_for_dim(dim_id)

					# Noise riêng cho loại hồ — độc lập hoàn toàn với biome noise
					# n_lake.frequency = 0.018 → patch ~55 unit, 50% hồ cát / 50% hồ bùn
					var lake_val: float = (nd["lake"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var is_silt_lake: bool = lake_val > 0.50

					if is_silt_lake:
						# Hồ bùn: cả SILT và SAND đều theo logic depth giống nhau
						# d <= 1 → ngang mặt nước (bờ nông), d > 1 → sâu hơn theo dst
						if d <= 1:
							biome_grid[ivx][ivz] = TileType.SAND
							height_grid[ivx][ivz] = WATER_Y
						else:
							biome_grid[ivx][ivz] = TileType.SILT
							# height giữ nguyên từ dst — giống logic SAND hoàn toàn
					else:
						# Hồ cát: toàn bộ SAND, cùng logic depth
						biome_grid[ivx][ivz] = TileType.SAND
						if d <= 1:
							height_grid[ivx][ivz] = WATER_Y

				elif biome_grid[ivx][ivz] == TileType.DARK_GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
					var nd: Dictionary = _noise_for_dim(dim_id)
					var dn: float = (nd["biome"].get_noise_2d((wx + 500.0) * 0.7, (wz + 500.0) * 0.7) + 1.0) * 0.5
					if dn > 0.70:
						biome_grid[ivx][ivz] = TileType.DIRT

	var road_grid: Array[Array] = []
	if dim_id == _Dim.DimensionID.REAL_WORLD:
		road_grid.resize(cols)
		for ivx in range(cols):
			road_grid[ivx] = []
			road_grid[ivx].resize(cols)
			for ivz in range(cols):
				var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
				road_grid[ivx][ivz] = _is_on_road(wx, wz)

	var tile_cols: Array[Dictionary] = TILE_COLORS_TW if dim_id == _Dim.DimensionID.TWILIGHT else TILE_COLORS_RW
	var sub_water_color: Color = tile_cols[TileType.SAND]["base"]

	for vx in range(cols):
		for vz in range(cols):
			var b: int = biome_grid[vx][vz]
			var h: float = height_grid[vx][vz]
			var top_col: Color = tile_cols[b]["base"] as Color
			var px: float = -half + (float(vx) + 0.5) * VOXEL
			var pz: float = -half + (float(vz) + 0.5) * VOXEL

			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND and b != TileType.SILT:
				top_col = TRAIL_COLOR

			var pos := Vector3(px, -h_vox + h, pz)
			_add_quad(st, pos + Vector3(0, h_vox, 0), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * h_vox, Vector3(0,1,0), top_col)

			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND and b != TileType.SILT:
				_add_trail_detail(st, cx, cz, size, vx, vz, pos, h_vox)

			if b == TileType.SAND and h > WATER_Y - 0.04:
				_add_sand_gravel(st, cx, cz, size, vx, vz, pos, h_vox)
			if b == TileType.DIRT:
				_add_dirt_mounds(st, cx, cz, size, vx, vz, pos, h_vox)

			var side_col: Color
			if b == TileType.SILT:
				side_col = (tile_cols[TileType.SILT]["base"] as Color) * 0.7
			elif b == TileType.SAND:
				side_col = sub_water_color * 0.6
			else:
				side_col = top_col * 0.5
			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND and b != TileType.SILT:
				side_col = TRAIL_SIDE

			if vx == 0 or biome_grid[vx - 1][vz] != b or height_grid[vx - 1][vz] != h:
				var lh: float
				if vx > 0:
					lh = height_grid[vx - 1][vz]
				else:
					lh = WATER_Y - min(dst[PAD - 1][vz + PAD] if dst[PAD - 1][vz + PAD] != CONST_INF else PAD, PAD) * VOXEL
					if bio[PAD - 1][vz + PAD] == TileType.DARK_GRASS:
						lh = VOXEL
				var fh: float = h - lh
				if fh > 0.0:
					_add_quad(st, Vector3(px - h_vox, lh + fh * 0.5, pz), Vector3(0, fh * 0.5, 0), Vector3(0,0,1) * h_vox, Vector3(-1,0,0), side_col)
			if vx == cols - 1 or biome_grid[vx + 1][vz] != b or height_grid[vx + 1][vz] != h:
				var rh: float
				if vx < cols - 1:
					rh = height_grid[vx + 1][vz]
				else:
					rh = WATER_Y - min(dst[PAD + cols][vz + PAD] if dst[PAD + cols][vz + PAD] != CONST_INF else PAD, PAD) * VOXEL
					if bio[PAD + cols][vz + PAD] == TileType.DARK_GRASS:
						rh = VOXEL
				var fh: float = h - rh
				if fh > 0.0:
					_add_quad(st, Vector3(px + h_vox, rh + fh * 0.5, pz), Vector3(0, fh * 0.5, 0), Vector3(0,0,-1) * h_vox, Vector3(1,0,0), side_col)
			if vz == 0 or biome_grid[vx][vz - 1] != b or height_grid[vx][vz - 1] != h:
				var fh_nb: float
				if vz > 0:
					fh_nb = height_grid[vx][vz - 1]
				else:
					fh_nb = WATER_Y - min(dst[vx + PAD][PAD - 1] if dst[vx + PAD][PAD - 1] != CONST_INF else PAD, PAD) * VOXEL
					if bio[vx + PAD][PAD - 1] == TileType.DARK_GRASS:
						fh_nb = VOXEL
				var fw: float = h - fh_nb
				if fw > 0.0:
					_add_quad(st, Vector3(px, fh_nb + fw * 0.5, pz - h_vox), Vector3(1,0,0) * h_vox, Vector3(0, fw * 0.5, 0), Vector3(0,0,-1), side_col)
			if vz == cols - 1 or biome_grid[vx][vz + 1] != b or height_grid[vx][vz + 1] != h:
				var bh: float
				if vz < cols - 1:
					bh = height_grid[vx][vz + 1]
				else:
					bh = WATER_Y - min(dst[vx + PAD][PAD + cols] if dst[vx + PAD][PAD + cols] != CONST_INF else PAD, PAD) * VOXEL
					if bio[vx + PAD][PAD + cols] == TileType.DARK_GRASS:
						bh = VOXEL
				var fw: float = h - bh
				if fw > 0.0:
					_add_quad(st, Vector3(px, bh + fw * 0.5, pz + h_vox), Vector3(-1,0,0) * h_vox, Vector3(0, fw * 0.5, 0), Vector3(0,0,1), side_col)

	var mesh := st.commit()
	if mesh == null:
		return { "mesh": null, "water_mesh": null, "biome_grid": biome_grid, "cols": cols }

	var st_water := SurfaceTool.new()
	st_water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vx in range(cols):
		var vz := 0
		while vz < cols:
			if biome_grid[vx][vz] != TileType.GRASS and biome_grid[vx][vz] != TileType.SAND and biome_grid[vx][vz] != TileType.SILT:
				vz += 1
				continue
			var start_vz := vz
			while vz < cols and (biome_grid[vx][vz] == TileType.GRASS or biome_grid[vx][vz] == TileType.SAND or biome_grid[vx][vz] == TileType.SILT):
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, WATER_Y - 0.04, z_mid), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox), Vector3(0,1,0), Color(1,1,1))

	var mesh_water := st_water.commit()

	# ── Thực vật thuỷ sinh ──────────────────────────────────────────────────
	# Chỉ render trong REAL_WORLD
	var mesh_aquatic = null
	var lotus_lights: Array[Vector3] = []   # vị trí bông sen thạch anh để spawn ánh sáng
	if dim_id == _Dim.DimensionID.REAL_WORLD:
		var st_aq := SurfaceTool.new()
		st_aq.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vx in range(cols):
			for vz in range(cols):
				var b: int = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				if b != TileType.SAND and b != TileType.SILT:
					continue
				if h >= WATER_Y - h_vox:
					continue
				var px2: float = -half + (float(vx) + 0.5) * VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * VOXEL
				var pos2 := Vector3(px2, h, pz2)
				_add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox, b == TileType.SILT, lotus_lights)
		mesh_aquatic = st_aq.commit()

	return { "mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic, "lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols }

func apply_chunk(data: Dictionary) -> void:
	_mesh_cache[_cache_key(_cx, _cz, _dimension_id)] = data
	_biome_grid = data["biome_grid"]
	var mesh: ArrayMesh = data["mesh"]
	if mesh == null:
		_built = true
		return
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

	var aquatic_mesh = data.get("aquatic_mesh")
	if aquatic_mesh:
		var mi_aq := MeshInstance3D.new()
		mi_aq.mesh = aquatic_mesh
		if not _mat_cache[_dimension_id].has("aquatic"):
			_mat_cache[_dimension_id]["aquatic"] = _make_aquatic_mat()
		mi_aq.material_override = _mat_cache[_dimension_id]["aquatic"]
		mi_aq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi_aq)

	# ── Ánh sáng sen thạch anh & rong nước ngọt ─────────────────────────────
	var lotus_lights: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	for lpos in lotus_lights:
		var is_weed_light: bool = lpos.x > 400.0   # prefix +500 = rong
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		light.light_color      = Color(0.45, 0.85, 1.0)
		light.light_energy     = 0.0
		light.omni_range       = 2.0 if is_weed_light else 3.0   # rong yếu hơn sen
		light.omni_attenuation = 2.5
		light.shadow_enabled   = false
		light.light_specular   = 0.0
		light.set_meta("max_energy", 0.25 if is_weed_light else 0.6)
		light.position         = real_pos + Vector3(0, 0.15, 0)
		add_child(light)
		LotusLightManager.register(light)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)
	_built = true

func _make_aquatic_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # thấy cả hai mặt
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if _biome_grid.is_empty():
		return false
	var half: float = _size * 0.5
	var lx: float = (wx - (global_position.x - half)) / VOXEL
	var lz: float = (wz - (global_position.z - half)) / VOXEL
	var vx: int = int(lx)
	var vz: int = int(lz)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols:
		return false
	if _biome_grid[vx][vz] != TileType.SAND and _biome_grid[vx][vz] != TileType.SILT:
		return false
	return wy < VOXEL * 0.46

static func _add_sand_gravel(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 374761393 + wz * 668265263 + 123456789
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 5915587277 + wz * 4276112413 + 987654321
	h2 = (h2 ^ (h2 >> 13)) * 104395303
	h2 = h2 ^ (h2 >> 16)
	var g := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var mult: float = 2.0 if g > 0.55 else 1.0

	var base_chance: float = 0.10 * mult
	var base_chance2: float = 0.04 * mult
	var count: int = 0
	if r < base_chance: count = 1
	elif r < base_chance + base_chance2: count = 2
	var s: int = h
	for i in range(count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		var ox: float = (rx - 0.5) * 0.6
		var oz: float = (rz - 0.5) * 0.6
		var psize: float = rs * 0.06 + 0.03
		var col: Color = Color(0.50 + rs * 0.15, 0.48 + rs * 0.12, 0.45 + rs * 0.10, 1.0)
		var pc := pos + Vector3(ox, h_vox + 0.015, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func _add_silt_detail(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	# Hash deterministric cho mỗi ô
	var h: int = wx * 481652729 + wz * 924652741 + 556789123
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 312018923 + wz * 719234571 + 112233445
	h2 = (h2 ^ (h2 >> 13)) * 1074126173
	h2 = h2 ^ (h2 >> 16)
	var g := float(h2 & 0x7FFFFFFF) / 2147483648.0

	# Phù sa dày hơn cát: 2–4 mảnh nhỏ mỗi ô
	var count: int = 2
	if r < 0.45: count = 3
	elif r < 0.15: count = 4

	var s: int = h
	for i in range(count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		var ox: float = (rx - 0.5) * 0.75
		var oz: float = (rz - 0.5) * 0.75
		# Màu phù sa: nâu đất bùn, thay đổi nhẹ theo noise
		var br: float = 0.30 + rs * 0.12 + g * 0.08
		var bg_val: float = 0.22 + rs * 0.10 + g * 0.06
		var bb: float = 0.10 + rs * 0.06
		var col: Color = Color(br, bg_val, bb, 1.0)
		# Kích thước mảnh phù sa lớn hơn cát gravel
		var psize: float = rs * 0.10 + 0.05
		var pc := pos + Vector3(ox, h_vox + 0.01, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

# ── Thực vật thuỷ sinh ────────────────────────────────────────────────────────
# pos.y = chiều cao mặt trên đáy tile, has_silt = true → vùng bùn
static func _add_aquatic_plants(st: SurfaceTool, cx: int, cz: int, size: int,
		vx: int, vz: int, pos: Vector3, h_vox: float, has_silt: bool,
		lotus_lights: Array[Vector3] = []) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	const WATER_Y: float = 0.5
	const VOXEL: float = 1.0

	var h1: int = wx * 631152931 + wz * 493781731 + 224488997
	h1 = (h1 ^ (h1 >> 13)) * 1274126177; h1 = h1 ^ (h1 >> 16)
	var r1 := float(h1 & 0x7FFFFFFF) / 2147483648.0
	var h2: int = wx * 198491327 + wz * 374761393 + 887766554
	h2 = (h2 ^ (h2 >> 13)) * 1074126173; h2 = h2 ^ (h2 >> 16)
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var h3: int = wx * 716199923 + wz * 912334613 + 441200317
	h3 = (h3 ^ (h3 >> 13)) * 974126171; h3 = h3 ^ (h3 >> 16)
	var r3 := float(h3 & 0x7FFFFFFF) / 2147483648.0
	var h4: int = wx * 374761393 + wz * 631152931 + 556677889
	h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
	var r4 := float(h4 & 0x7FFFFFFF) / 2147483648.0

	var water_gap: float = WATER_Y - pos.y

	_add_tropical_weed(st, wx, wz, pos, r1, r2, r3, r4, h1, h2, water_gap, has_silt, lotus_lights)

	if has_silt:
		_add_lotus_plant(st, wx, wz, pos, r1, r2, r3, r4, h1, lotus_lights)

# ── Rong nước ngọt nhiệt đới — rong đuôi chó voxel ─────────────────────────
# Thân thẳng, mỗi đốt có vòng lá tỏa ra như ngôi sao (4–6 lá/vòng)
# Hoa nhỏ mọc bên hông một số đốt
static func _add_tropical_weed(st: SurfaceTool, wx: int, wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int, h2: int,
		water_gap: float, has_silt: bool, lotus_lights: Array[Vector3]) -> void:
	const WATER_Y: float = 0.5
	const VOXEL: float   = 1.0

	var chance: float = 0.30 if has_silt else 0.15
	if r1 >= chance:
		return

	# Số đốt 1–5, không vượt mặt nước
	var max_blocks: int = clampi(int(water_gap / VOXEL), 1, 5)
	var block_count: int
	if   r2 < 0.15: block_count = 1
	elif r2 < 0.35: block_count = 2
	elif r2 < 0.60: block_count = 3
	elif r2 < 0.82: block_count = 4
	else:            block_count = 5
	block_count = mini(block_count, max_blocks)
	if block_count < 1: block_count = 1

	var base_x: float = pos.x + (r2 - 0.5) * 0.25
	var base_z: float = pos.z + (r3 - 0.5) * 0.25
	# Độ rộng thân — nhỏ gọn
	var stem_w: float = 0.045 + r4 * 0.025

	# Màu thân — xanh lục nhiệt đới sáng
	var stem_g: float = 0.60 + r3 * 0.25
	var stem_b: float = 0.10 + r3 * 0.08
	var col_stem  := Color(0.04, stem_g,        stem_b,        1.0)
	var col_leaf  := Color(0.06, stem_g * 0.90, stem_b * 0.80, 1.0)  # lá sáng hơn nhẹ
	var col_leaf2 := Color(0.05, stem_g * 1.10, stem_b * 0.70, 1.0)  # lá đầu nhọn sáng

	var s: int = h1

	for seg in range(block_count):
		# Vị trí tâm đốt trên thân
		var seg_y: float = pos.y + float(seg) * VOXEL + VOXEL * 0.5
		var sc := Vector3(base_x, seg_y, base_z)

		# ── Thân voxel nhỏ ───────────────────────────────────────────────
		_add_quad(st, sc, Vector3(stem_w,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0, 1), col_stem)
		_add_quad(st, sc, Vector3(stem_w,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0,-1), col_stem)
		_add_quad(st, sc, Vector3(0,0,stem_w), Vector3(0,VOXEL*0.5,0), Vector3( 1,0,0), col_stem)
		_add_quad(st, sc, Vector3(0,0,stem_w), Vector3(0,VOXEL*0.5,0), Vector3(-1,0,0), col_stem)

		# ── Vòng lá tỏa xung quanh đốt — 6 lá/vòng ─────────────────────
		# Mỗi lá: 2–3 tầng nhỏ tạo cảm giác phân nhánh
		s = s * 16807 + 1
		var leaf_count: int = 5 + (1 if float(s & 0x7FFFFFFF) / 2147483648.0 > 0.5 else 0)
		var leaf_rot_off: float = float(seg) * 0.52   # xoay lệch mỗi đốt

		for li in range(leaf_count):
			var angle: float = float(li) / float(leaf_count) * TAU + leaf_rot_off
			s = s * 16807 + 1
			var lr := float(s & 0x7FFFFFFF) / 2147483648.0
			# Chiều dài lá tầng 1 — tỏa ngang
			var l1: float = 0.22 + lr * 0.12
			var ldir := Vector3(cos(angle), 0.0, sin(angle))   # hướng tỏa ngang
			var lperp := Vector3(-sin(angle), 0.0, cos(angle)) # vuông góc trong plane ngang

			# Điểm gốc lá — nằm trên mặt thân, cao 1/4 đốt
			var lroot := sc + ldir * stem_w + Vector3(0, VOXEL * 0.25, 0)

			# Tầng 1: lá chính — tỏa ngang, nghiêng lên nhẹ
			var l1_end: Vector3 = ldir * l1 + Vector3(0, l1 * 0.25, 0)
			_add_quad(st, lroot + l1_end * 0.5,
				lperp * 0.055,
				l1_end * 0.5,
				lperp.cross(l1_end.normalized()).normalized(),
				col_leaf)

			# Tầng 2: lá con — rẽ nhánh từ giữa lá chính, ngắn hơn
			s = s * 16807 + 1
			var br := float(s & 0x7FFFFFFF) / 2147483648.0
			var branch_angle: float = angle + (br - 0.5) * 0.6
			var bdir := Vector3(cos(branch_angle), 0.18, sin(branch_angle)).normalized()
			var l2: float = l1 * 0.55
			var branch_root: Vector3 = lroot + l1_end * 0.45
			var l2_end: Vector3 = bdir * l2
			_add_quad(st, branch_root + l2_end * 0.5,
				lperp * 0.035,
				l2_end * 0.5,
				lperp.cross(l2_end.normalized()).normalized(),
				col_leaf2)

			# Tầng 3 (đốt trên cùng): thêm lá con nhọn để tạo chùm dày hơn
			if seg == block_count - 1:
				s = s * 16807 + 1
				var tr := float(s & 0x7FFFFFFF) / 2147483648.0
				var tdir := Vector3(cos(angle + 0.35), 0.35, sin(angle + 0.35)).normalized()
				var l3: float = l1 * 0.40
				_add_quad(st, lroot + tdir * l3 * 0.5,
					lperp * 0.025,
					tdir * l3 * 0.5,
					lperp.cross(tdir).normalized(),
					col_leaf2)

		# ── Hoa nhỏ bên hông — mọc ở 1–2 đốt ngẫu nhiên ────────────────
		s = s * 16807 + 1
		var flower_chance: float = float(s & 0x7FFFFFFF) / 2147483648.0
		# 35% mỗi đốt có hoa (trừ đốt đáy)
		if seg > 0 and flower_chance < 0.35:
			s = s * 16807 + 1
			var fc1 := float(s & 0x7FFFFFFF) / 2147483648.0
			s = s * 16807 + 1
			var fc2 := float(s & 0x7FFFFFFF) / 2147483648.0
			s = s * 16807 + 1
			var fc3 := float(s & 0x7FFFFFFF) / 2147483648.0

			# Góc hoa — lệch so với lá
			var fangle: float = leaf_rot_off + fc1 * TAU
			var fdir := Vector3(cos(fangle), 0, sin(fangle))
			var fperp := Vector3(-sin(fangle), 0, cos(fangle))
			# Vị trí hoa: mọc ngang thân, cao ngang giữa đốt
			var flower_pos := sc + fdir * (stem_w + 0.12) + Vector3(0, VOXEL * 0.1, 0)

			# Màu hoa — đa dạng nhiệt đới
			var col_f: Color
			if   fc2 < 0.18: col_f = Color(1.0,  0.25+fc3*0.30, 0.10, 1.0)  # đỏ cam
			elif fc2 < 0.33: col_f = Color(1.0,  0.80+fc3*0.15, 0.10, 1.0)  # vàng
			elif fc2 < 0.48: col_f = Color(0.20, 0.90+fc3*0.08, 0.30, 1.0)  # xanh lá sáng
			elif fc2 < 0.62: col_f = Color(0.10, 0.60+fc3*0.20, 1.00, 1.0)  # xanh lam
			elif fc2 < 0.76: col_f = Color(0.75+fc3*0.20, 0.10, 1.00, 1.0)  # tím
			else:             col_f = Color(1.0,  0.30+fc3*0.25, 0.65+fc2*0.20, 1.0) # hồng

			var fp: float = 0.055 + fc3 * 0.035
			# Hoa: 4 cánh voxel nhỏ tỏa ra
			for fi in range(4):
				var fa: float = float(fi) * PI * 0.5 + fangle
				var fd := Vector3(cos(fa), 0, sin(fa))
				var fp2 := Vector3(-sin(fa), 0, cos(fa))
				_add_quad(st, flower_pos + fd * fp * 0.5,
					fp2 * fp * 0.5, Vector3(0, fp * 0.7, 0), fd, col_f)
				_add_quad(st, flower_pos + fd * fp * 0.5,
					fp2 * fp * 0.5, Vector3(0, fp * 0.7, 0), -fd, col_f)
			# Nhụy vàng nhỏ
			var col_stamen := Color(1.0, 0.95, 0.15, 1.0)
			_add_quad(st, flower_pos + Vector3(0, fp * 0.5, 0),
				Vector3(fp*0.25,0,0), Vector3(0,fp*0.25,0), Vector3(0,0,1), col_stamen)
			_add_quad(st, flower_pos + Vector3(0, fp * 0.5, 0),
				Vector3(0,0,fp*0.25), Vector3(0,fp*0.25,0), Vector3(1,0,0), col_stamen)

			# Đăng ký ánh sáng phát quang nhẹ (prefix +500)
			lotus_lights.append(Vector3(flower_pos.x + 500.0, flower_pos.y, flower_pos.z))

# ── Sen thạch anh ─────────────────────────────────────────────────────────────
static func _add_lotus_plant(st: SurfaceTool, wx: int, wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int,
		lotus_lights: Array[Vector3]) -> void:
	const WATER_Y: float = 0.5
	var h5: int = wx * 912347189 + wz * 678451237 + 119988771
	h5 = (h5 ^ (h5 >> 13)) * 1174126183; h5 = h5 ^ (h5 >> 16)
	var r5 := float(h5 & 0x7FFFFFFF) / 2147483648.0
	if r5 >= 0.10: return
	var h6: int = wx * 556677889 + wz * 334455667 + 223344556
	h6 = (h6 ^ (h6 >> 13)) * 1074126187; h6 = h6 ^ (h6 >> 16)
	var r6 := float(h6 & 0x7FFFFFFF) / 2147483648.0
	var lily_r: float = 0.22 + r5 * 0.14
	var ox3: float = (r5 - 0.5) * 0.4
	var oz3: float = (r6 - 0.5) * 0.4
	var lily_y: float = WATER_Y - 0.02
	var col_lily := Color(0.08, 0.38 + r6 * 0.16, 0.10, 1.0)
	_add_quad(st, Vector3(pos.x+ox3, lily_y, pos.z+oz3),
		Vector3(lily_r,0,0), Vector3(0,0,lily_r), Vector3(0,1,0), col_lily)
	var d45: float = lily_r * 0.707
	_add_quad(st, Vector3(pos.x+ox3, lily_y, pos.z+oz3),
		Vector3(d45,0,d45), Vector3(-d45,0,d45), Vector3(0,1,0), col_lily*0.9)
	if r5 < 0.05:
		var lot_h: float = 0.12 + r6 * 0.08
		var col_lotus := Color(0.90+r6*0.05, 0.65+r5*0.20, 0.68+r6*0.12, 1.0)
		var stem := Vector3(pos.x+ox3, lily_y+lot_h*0.5, pos.z+oz3)
		for ci in range(4):
			var ca: float = float(ci) * PI * 0.5
			_add_quad(st, stem + Vector3(cos(ca)*0.06, 0, sin(ca)*0.06),
				Vector3(cos(ca+PI*0.5)*0.04, 0, sin(ca+PI*0.5)*0.04),
				Vector3(0, lot_h*0.5, 0),
				Vector3(-sin(ca), 0, cos(ca)), col_lotus)
		lotus_lights.append(Vector3(pos.x+ox3, lily_y, pos.z+oz3))

static func _add_trail_detail(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 274761391 + wz * 568265261 + 345678901
	h = (h ^ (h >> 13)) * 1174126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var count: int = 0
	if r < 0.30: count = 1
	elif r < 0.50: count = 2
	elif r < 0.62: count = 3

	var h2: int = wx * 441761393 + wz * 778265263 + 234567891
	h2 = (h2 ^ (h2 >> 13)) * 1474126177
	h2 = h2 ^ (h2 >> 16)
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0

	var extra: int = 0
	if r2 < 0.15: extra = 1

	var s: int = h
	for i in range(count + extra):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rt := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.55
		var oz: float = (rz - 0.5) * 0.55
		var psize: float
		var dh: float
		var col: Color

		if rt < 0.40:
			psize = rs * 0.07 + 0.03
			dh = rs * 0.03 + 0.008
			var b: float = rs * 0.12 - 0.06
			col = Color(0.68 + b, 0.52 + b, 0.26 + b * 0.5, 1.0)
		elif rt < 0.70:
			psize = rs * 0.05 + 0.025
			dh = rs * 0.02 + 0.005
			col = Color(0.55 + rs * 0.15, 0.48 + rs * 0.12, 0.38 + rs * 0.08, 1.0)
		else:
			psize = rs * 0.10 + 0.05
			dh = rs * 0.025 + 0.005
			col = Color(0.60 + rs * 0.12, 0.50 + rs * 0.10, 0.30 + rs * 0.08, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.005 + dh, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func _add_dirt_mounds(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 874761391 + wz * 968265261 + 456789012
	h = (h ^ (h >> 13)) * 1374126177
	h = h ^ (h >> 16)
	var r1 := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 674761391 + wz * 868265261 + 556789012
	h2 = (h2 ^ (h2 >> 13)) * 1274126177
	h2 = h2 ^ (h2 >> 16)
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0

	var mound_count: int = 0
	if r1 < 0.04: mound_count = 1
	elif r1 < 0.06: mound_count = 2

	var gravel_count: int = 0
	if r2 < 0.08: gravel_count = 1

	var s: int = h
	for i in range(mound_count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rh := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.5
		var oz: float = (rz - 0.5) * 0.5
		var mound_size: float = rs * 0.10 + 0.06
		var dh: float = rh * 0.04 + 0.02
		var col: Color = Color(0.36 + rs * 0.12, 0.22 + rs * 0.10, 0.10 + rs * 0.06, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.005, oz)
		_add_quad(st, pc + Vector3(0, dh, 0), Vector3(mound_size, 0, 0), Vector3(0, 0, mound_size), Vector3(0, 1, 0), col)

	s = h2
	for i in range(gravel_count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.6
		var oz: float = (rz - 0.5) * 0.6
		var psize: float = rs * 0.05 + 0.025
		var col: Color = Color(0.45 + rs * 0.15, 0.42 + rs * 0.12, 0.38 + rs * 0.10, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.015, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
