extends Node3D
class_name WorldChunk

enum TileType { GRASS, DARK_GRASS, SAND, DIRT }

const _Dim = preload("res://scripts/world/dimension_defs.gd")

const TILE_COLORS_TW: Array[Dictionary] = [
	{ "base": Color(0.06, 0.22, 0.16), "emit": Color(0.08, 0.28, 0.20), "pow": 0.3 },
	{ "base": Color(0.03, 0.12, 0.08), "emit": Color(0.05, 0.16, 0.10), "pow": 0.2 },
	{ "base": Color(0.05, 0.15, 0.10), "emit": Color(0.06, 0.18, 0.12), "pow": 0.2 },
	{ "base": Color(0.04, 0.10, 0.07), "emit": Color(0.05, 0.12, 0.08), "pow": 0.15 },
]

const TILE_COLORS_RW: Array[Dictionary] = [
	{ "base": Color(0.28, 0.48, 0.18), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.20, 0.35, 0.12), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.90, 0.80, 0.42), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.32, 0.18, 0.08), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
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

	var result := { "biome": n_bio, "warp": n_warp }
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
					biome_grid[ivx][ivz] = TileType.SAND
					if d <= 1:
						height_grid[ivx][ivz] = WATER_Y
				elif biome_grid[ivx][ivz] == TileType.DARK_GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
					var nd: Dictionary = _noise_for_dim(dim_id)
					var dn: float = (nd["biome"].get_noise_2d(wx + 500.0, wz + 500.0) + 1.0) * 0.5
					if dn > 0.78:
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

			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND:
				top_col = TRAIL_COLOR

			var pos := Vector3(px, -h_vox + h, pz)
			_add_quad(st, pos + Vector3(0, h_vox, 0), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * h_vox, Vector3(0,1,0), top_col)

			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND:
				_add_trail_detail(st, cx, cz, size, vx, vz, pos, h_vox)

			if b == TileType.SAND and h > WATER_Y - 0.04:
				_add_sand_gravel(st, cx, cz, size, vx, vz, pos, h_vox)
			if b == TileType.DIRT:
				_add_dirt_mounds(st, cx, cz, size, vx, vz, pos, h_vox)

			var side_col := sub_water_color * 0.6 if (b == TileType.SAND) else top_col * 0.5
			if dim_id == _Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != TileType.SAND:
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
			if biome_grid[vx][vz] != TileType.GRASS and biome_grid[vx][vz] != TileType.SAND:
				vz += 1
				continue
			var start_vz := vz
			while vz < cols and (biome_grid[vx][vz] == TileType.GRASS or biome_grid[vx][vz] == TileType.SAND):
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, WATER_Y - 0.04, z_mid), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox), Vector3(0,1,0), Color(1,1,1))

	var mesh_water := st_water.commit()
	return { "mesh": mesh, "water_mesh": mesh_water, "biome_grid": biome_grid, "cols": cols }

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

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)
	_built = true


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
	if _biome_grid[vx][vz] != TileType.SAND:
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
		var hw: float = rs * 0.06 + 0.03
		var dh: float = rs * 0.08 + 0.05
		var col: Color = Color(0.50 + rs * 0.15, 0.48 + rs * 0.12, 0.45 + rs * 0.10, 1.0)
		var pc := pos + Vector3(ox, h_vox, oz)
		_add_quad_box(st, pc, hw, hw, dh, col)

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
		var hw: float
		var dh: float
		var col: Color

		if rt < 0.40:
			hw = rs * 0.07 + 0.03
			dh = rs * 0.10 + 0.06
			var b: float = rs * 0.12 - 0.06
			col = Color(0.68 + b, 0.52 + b, 0.26 + b * 0.5, 1.0)
		elif rt < 0.70:
			hw = rs * 0.05 + 0.025
			dh = rs * 0.08 + 0.04
			col = Color(0.55 + rs * 0.15, 0.48 + rs * 0.12, 0.38 + rs * 0.08, 1.0)
		else:
			hw = rs * 0.10 + 0.05
			dh = rs * 0.12 + 0.08
			col = Color(0.60 + rs * 0.12, 0.50 + rs * 0.10, 0.30 + rs * 0.08, 1.0)

		var pc := pos + Vector3(ox, h_vox, oz)
		_add_quad_box(st, pc, hw, hw, dh, col)

static func _add_dirt_mounds(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 874761391 + wz * 968265261 + 456789012
	h = (h ^ (h >> 13)) * 1374126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var count: int = 0
	if r < 0.10: count = 1
	elif r < 0.14: count = 2

	var s: int = h
	for i in range(count):
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
		var hw: float = rs * 0.10 + 0.06
		var dh: float = rh * 0.15 + 0.08
		var col: Color = Color(0.36 + rs * 0.12, 0.22 + rs * 0.10, 0.10 + rs * 0.06, 1.0)

		var pc := pos + Vector3(ox, h_vox, oz)
		_add_quad_box(st, pc, hw, hw, dh, col)

static func _add_quad_box(st: SurfaceTool, pos: Vector3, hw_x: float, hw_z: float, height: float, col: Color) -> void:
	_add_quad(st, pos + Vector3(0, height, 0), Vector3(hw_x, 0, 0), Vector3(0, 0, hw_z), Vector3(0, 1, 0), col)
	_add_quad(st, pos + Vector3(0, height * 0.5, hw_z), Vector3(hw_x, 0, 0), Vector3(0, height * 0.5, 0), Vector3(0, 0, 1), col)
	_add_quad(st, pos + Vector3(0, height * 0.5, -hw_z), Vector3(hw_x, 0, 0), Vector3(0, height * 0.5, 0), Vector3(0, 0, -1), col)
	_add_quad(st, pos + Vector3(-hw_x, height * 0.5, 0), Vector3(0, 0, hw_z), Vector3(0, height * 0.5, 0), Vector3(-1, 0, 0), col)
	_add_quad(st, pos + Vector3(hw_x, height * 0.5, 0), Vector3(0, 0, hw_z), Vector3(0, height * 0.5, 0), Vector3(1, 0, 0), col)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
