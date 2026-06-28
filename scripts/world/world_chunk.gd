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
	{ "base": Color(0.30, 0.65, 0.18), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.18, 0.48, 0.10), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.72, 0.64, 0.38), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.26, 0.15, 0.06), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
]

const VOXEL: float = 1.0
const TILE_W: int = 5
const TILE_D: int = 5

var _cx: int = 0
var _cz: int = 0
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Dim.DimensionID.TWILIGHT

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

func setup(cx: int, cz: int, size: int, dimension_id: int = _Dim.DimensionID.TWILIGHT) -> void:
	_cx = cx; _cz = cz; _size = size
	_dimension_id = dimension_id
	_cols = int(_size / VOXEL)
	_tiles_per_chunk = int(_cols / TILE_W)
	_init_materials()
	_build()

func _init_materials() -> void:
	if _mat_cache.has(_dimension_id):
		return
	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		var m_t := StandardMaterial3D.new()
		m_t.vertex_color_use_as_albedo = true
		m_t.roughness = 0.9; m_t.metallic_specular = 0.0
		var m_w := StandardMaterial3D.new()
		m_w.albedo_color = Color(0.06, 0.30, 0.60, 0.55)
		m_w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m_w.cull_mode = BaseMaterial3D.CULL_DISABLED
		m_w.roughness = 0.3; m_w.metallic_specular = 0.1
		_mat_cache[_dimension_id] = { "terrain": m_t, "water": m_w }
		return

	var m_t_cv := StandardMaterial3D.new()
	m_t_cv.vertex_color_use_as_albedo = true
	m_t_cv.roughness = 1.0; m_t_cv.metallic_specular = 0.0
	var m_w_cv := StandardMaterial3D.new()
	m_w_cv.albedo_color = Color(0.10, 0.55, 0.45, 0.65)
	m_w_cv.emission_enabled = true
	m_w_cv.emission = Color(0.08, 0.45, 0.35)
	m_w_cv.emission_energy_multiplier = 2.0
	m_w_cv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_w_cv.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_w_cv.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[_dimension_id] = { "terrain": m_t_cv, "water": m_w_cv }

func _biome_at(wx: float, wz: float) -> int:
	var nd: Dictionary = _noise_for_dim(_dimension_id)
	var n_bio: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]

	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_bio.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5

	var threshold: float = 0.50
	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		threshold = 0.40

	if n < threshold: return TileType.GRASS
	return TileType.DARK_GRASS

func _build() -> void:
	var world_ox: float = _cx * _size
	var world_oz: float = _cz * _size
	var half: float = _size * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h_vox: float = VOXEL * 0.5

	const PAD: int = 5
	const WATER_Y: float = VOXEL * 0.5

	var total: int = _cols + 2 * PAD

	var bio: Array[Array] = []
	bio.resize(total)
	for vx in range(total):
		var row: Array = []
		row.resize(total)
		bio[vx] = row
		for vz in range(total):
			var wx: float = world_ox - half + (float(vx - PAD) + 0.5) * VOXEL
			var wz: float = world_oz - half + (float(vz - PAD) + 0.5) * VOXEL
			row[vz] = _biome_at(wx, wz)

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
	biome_grid.resize(_cols)
	var height_grid: Array[Array] = []
	height_grid.resize(_cols)
	for ivx in range(_cols):
		biome_grid[ivx] = []
		biome_grid[ivx].resize(_cols)
		height_grid[ivx] = []
		height_grid[ivx].resize(_cols)
		var pvx: int = ivx + PAD
		for ivz in range(_cols):
			var pvz: int = ivz + PAD
			biome_grid[ivx][ivz] = bio[pvx][pvz]
			if bio[pvx][pvz] == TileType.DARK_GRASS:
				height_grid[ivx][ivz] = VOXEL
			else:
				var d: int = dst[pvx][pvz]
				if d == CONST_INF:
					d = PAD
				height_grid[ivx][ivz] = WATER_Y - min(d, PAD) * VOXEL

	_biome_grid = biome_grid

	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		for ivx in range(_cols):
			var pvx: int = ivx + PAD
			for ivz in range(_cols):
				var pvz: int = ivz + PAD
				var d: int = dst[pvx][pvz]
				if biome_grid[ivx][ivz] == TileType.GRASS and d == 1:
					biome_grid[ivx][ivz] = TileType.SAND
					height_grid[ivx][ivz] = WATER_Y
				elif biome_grid[ivx][ivz] == TileType.GRASS and d >= 2:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
					var nd: Dictionary = _noise_for_dim(_dimension_id)
					var grv: float = (nd["biome"].get_noise_2d(wx + 300.0, wz + 300.0) + 1.0) * 0.5
					if grv > 0.82:
						biome_grid[ivx][ivz] = TileType.SAND
				elif biome_grid[ivx][ivz] == TileType.DARK_GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * VOXEL
					var nd: Dictionary = _noise_for_dim(_dimension_id)
					var dn: float = (nd["biome"].get_noise_2d(wx + 500.0, wz + 500.0) + 1.0) * 0.5
					if dn > 0.78:
						biome_grid[ivx][ivz] = TileType.DIRT

	var tile_cols: Array[Dictionary] = TILE_COLORS_TW if _dimension_id == _Dim.DimensionID.TWILIGHT else TILE_COLORS_RW

	for vx in range(_cols):
		for vz in range(_cols):
			var b: int = biome_grid[vx][vz]
			var h: float = height_grid[vx][vz]
			var top_col: Color = tile_cols[b]["base"] as Color
			var px: float = -half + (float(vx) + 0.5) * VOXEL
			var pz: float = -half + (float(vz) + 0.5) * VOXEL

			var pos := Vector3(px, -h_vox + h, pz)
			_add_quad(st, pos + Vector3(0, h_vox, 0), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * h_vox, Vector3(0,1,0), top_col)

			var side_col: Color = top_col * 0.5

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
			if vx == _cols - 1 or biome_grid[vx + 1][vz] != b or height_grid[vx + 1][vz] != h:
				var rh: float
				if vx < _cols - 1:
					rh = height_grid[vx + 1][vz]
				else:
					rh = WATER_Y - min(dst[PAD + _cols][vz + PAD] if dst[PAD + _cols][vz + PAD] != CONST_INF else PAD, PAD) * VOXEL
					if bio[PAD + _cols][vz + PAD] == TileType.DARK_GRASS:
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
			if vz == _cols - 1 or biome_grid[vx][vz + 1] != b or height_grid[vx][vz + 1] != h:
				var bh: float
				if vz < _cols - 1:
					bh = height_grid[vx][vz + 1]
				else:
					bh = WATER_Y - min(dst[vx + PAD][PAD + _cols] if dst[vx + PAD][PAD + _cols] != CONST_INF else PAD, PAD) * VOXEL
					if bio[vx + PAD][PAD + _cols] == TileType.DARK_GRASS:
						bh = VOXEL
				var fw: float = h - bh
				if fw > 0.0:
					_add_quad(st, Vector3(px, bh + fw * 0.5, pz + h_vox), Vector3(-1,0,0) * h_vox, Vector3(0, fw * 0.5, 0), Vector3(0,0,1), side_col)

	var mesh := st.commit()
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_cache[_dimension_id]["terrain"]
	add_child(mi)

	var st_water := SurfaceTool.new()
	st_water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vx in range(_cols):
		var vz := 0
		while vz < _cols:
			if biome_grid[vx][vz] != TileType.GRASS:
				vz += 1
				continue
			var start_vz := vz
			while vz < _cols and biome_grid[vx][vz] == TileType.GRASS:
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, WATER_Y, z_mid), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox), Vector3(0,1,0), Color(1,1,1))

	var mesh_water := st_water.commit()
	if mesh_water:
		var mi_w := MeshInstance3D.new()
		mi_w.mesh = mesh_water
		mi_w.material_override = _mat_cache[_dimension_id]["water"]
		add_child(mi_w)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)


func is_water_at(wx: float, wz: float, wy: float) -> bool:
	var half: float = _size * 0.5
	var lx: float = (wx - (global_position.x - half)) / VOXEL
	var lz: float = (wz - (global_position.z - half)) / VOXEL
	var vx: int = int(lx)
	var vz: int = int(lz)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols:
		return false
	if _biome_grid[vx][vz] != TileType.GRASS:
		return false
	return wy < VOXEL * 0.5

func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
