extends Node3D
class_name WorldChunk

const _Data = preload("chunk_data.gd")
const _Noise = preload("chunk_noise.gd")
const _Road = preload("chunk_road.gd")
const _Detail = preload("chunk_detail.gd")
const _Aquatic = preload("chunk_aquatic.gd")

var _cx: int = 0
var _cz: int = 0
var _size: int = 0
var _cols: int = 0
var _tiles_per_chunk: int = 0
var _biome_grid: Array[Array] = []
var _dimension_id: int = _Data._Dim.DimensionID.TWILIGHT
var _built: bool = false

static var _mesh_cache: Dictionary = {}
static var _pending_chunks: Dictionary = {}

static func _noise_for_dim(dim_id: int) -> Dictionary:
	return _Noise._noise_for_dim(dim_id)

static func _is_on_road(wx: float, wz: float) -> bool:
	return _Road.is_on_road(wx, wz)

static func _cache_key(cx: int, cz: int, dim: int) -> String:
	return "%d,%d,%d" % [cx, cz, dim]

func setup(cx: int, cz: int, size: int, dimension_id: int = _Data._Dim.DimensionID.TWILIGHT, sync: bool = false) -> void:
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
	WorkerThreadPool.add_task(_thread_build.bind(ck, cx, cz, size, dimension_id), true, "chunk")

static func _thread_build(ck: String, cx: int, cz: int, size: int, dim_id: int) -> void:
	var data: Dictionary = compute_chunk(cx, cz, size, dim_id)
	var chunk = _pending_chunks.get(ck)
	_pending_chunks.erase(ck)
	if chunk != null and is_instance_valid(chunk) and chunk.is_inside_tree():
		chunk.call_deferred("apply_chunk", data)

static func compute_chunk(cx: int, cz: int, size: int, dim_id: int) -> Dictionary:
	var cols: int = int(size / _Data.VOXEL)
	var world_ox: float = cx * size
	var world_oz: float = cz * size
	var half: float = size * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h_vox: float = _Data.VOXEL * 0.5
	var total: int = cols + 2 * _Data.PAD
	var bio: Array[Array] = []
	bio.resize(total)
	for vx in range(total):
		var row: Array = []
		row.resize(total)
		bio[vx] = row
		for vz in range(total):
			var wx: float = world_ox - half + (float(vx - _Data.PAD) + 0.5) * _Data.VOXEL
			var wz: float = world_oz - half + (float(vz - _Data.PAD) + 0.5) * _Data.VOXEL
			row[vz] = _Noise._biome_at(wx, wz, dim_id)

	var dst: Array[Array] = []
	dst.resize(total)
	for vx in range(total):
		var row: Array = []
		row.resize(total)
		dst[vx] = row
		for vz in range(total):
			row[vz] = 0 if bio[vx][vz] == _Data.TileType.DARK_GRASS else _Data.CONST_INF

	for vx in range(total):
		for vz in range(total):
			if bio[vx][vz] != _Data.TileType.GRASS:
				continue
			if (vx > 0 and bio[vx - 1][vz] == _Data.TileType.DARK_GRASS) \
				or (vx < total - 1 and bio[vx + 1][vz] == _Data.TileType.DARK_GRASS) \
				or (vz > 0 and bio[vx][vz - 1] == _Data.TileType.DARK_GRASS) \
				or (vz < total - 1 and bio[vx][vz + 1] == _Data.TileType.DARK_GRASS):
				dst[vx][vz] = 1

	for d in range(2, _Data.PAD + 1):
		for vx in range(total):
			for vz in range(total):
				if dst[vx][vz] != _Data.CONST_INF:
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
		var pvx: int = ivx + _Data.PAD
		for ivz in range(cols):
			var pvz: int = ivz + _Data.PAD
			biome_grid[ivx][ivz] = bio[pvx][pvz]
			if bio[pvx][pvz] == _Data.TileType.DARK_GRASS:
				height_grid[ivx][ivz] = _Data.VOXEL
			else:
				var d: int = dst[pvx][pvz]
				if d == _Data.CONST_INF:
					d = _Data.PAD
				height_grid[ivx][ivz] = _Data.WATER_Y - min(d, _Data.PAD) * _Data.VOXEL

	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		for ivx in range(cols):
			var pvx: int = ivx + _Data.PAD
			for ivz in range(cols):
				var pvz: int = ivz + _Data.PAD
				var d: int = dst[pvx][pvz]
				if biome_grid[ivx][ivz] == _Data.TileType.GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var nd: Dictionary = _Noise._noise_for_dim(dim_id)
					var lake_val: float = (nd["lake"].get_noise_2d(wx, wz) + 1.0) * 0.5
					var is_silt_lake: bool = lake_val > 0.50
					if is_silt_lake:
						if d <= 1:
							biome_grid[ivx][ivz] = _Data.TileType.SAND
							height_grid[ivx][ivz] = _Data.WATER_Y
						else:
							biome_grid[ivx][ivz] = _Data.TileType.SILT
					else:
						biome_grid[ivx][ivz] = _Data.TileType.SAND
						if d <= 1:
							height_grid[ivx][ivz] = _Data.WATER_Y
				elif biome_grid[ivx][ivz] == _Data.TileType.DARK_GRASS:
					var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
					var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
					var nd: Dictionary = _Noise._noise_for_dim(dim_id)
					var dn: float = (nd["biome"].get_noise_2d((wx + 500.0) * 0.7, (wz + 500.0) * 0.7) + 1.0) * 0.5
					if dn > 0.70:
						biome_grid[ivx][ivz] = _Data.TileType.DIRT

	var road_grid: Array[Array] = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		road_grid.resize(cols)
		for ivx in range(cols):
			road_grid[ivx] = []
			road_grid[ivx].resize(cols)
			for ivz in range(cols):
				var wx: float = world_ox - half + (float(ivx) + 0.5) * _Data.VOXEL
				var wz: float = world_oz - half + (float(ivz) + 0.5) * _Data.VOXEL
				road_grid[ivx][ivz] = _Road.is_on_road(wx, wz)

	var tile_cols: Array[Dictionary] = _Data.TILE_COLORS_TW if dim_id == _Data._Dim.DimensionID.TWILIGHT else _Data.TILE_COLORS_RW
	var sub_water_color: Color = tile_cols[_Data.TileType.SAND]["base"]

	for vx in range(cols):
		for vz in range(cols):
			var b: int = biome_grid[vx][vz]
			var h: float = height_grid[vx][vz]
			var top_col: Color = tile_cols[b]["base"] as Color
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var pz: float = -half + (float(vz) + 0.5) * _Data.VOXEL

			if dim_id == _Data._Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != _Data.TileType.SAND and b != _Data.TileType.SILT:
				top_col = _Data.TRAIL_COLOR

			var pos := Vector3(px, -h_vox + h, pz)
			_add_quad(st, pos + Vector3(0, h_vox, 0), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * h_vox, Vector3(0,1,0), top_col)

			if dim_id == _Data._Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != _Data.TileType.SAND and b != _Data.TileType.SILT:
				_Detail.add_trail_detail(st, cx, cz, size, vx, vz, pos, h_vox)

			if b == _Data.TileType.SAND and h > _Data.WATER_Y - 0.04:
				_Detail.add_sand_gravel(st, cx, cz, size, vx, vz, pos, h_vox)
			if b == _Data.TileType.DIRT:
				_Detail.add_dirt_mounds(st, cx, cz, size, vx, vz, pos, h_vox)

			var side_col: Color
			if b == _Data.TileType.SILT:
				side_col = (tile_cols[_Data.TileType.SILT]["base"] as Color) * 0.7
			elif b == _Data.TileType.SAND:
				side_col = sub_water_color * 0.6
			else:
				side_col = top_col * 0.5
			if dim_id == _Data._Dim.DimensionID.REAL_WORLD and road_grid[vx][vz] and b != _Data.TileType.SAND and b != _Data.TileType.SILT:
				side_col = _Data.TRAIL_SIDE

			if vx == 0 or biome_grid[vx - 1][vz] != b or height_grid[vx - 1][vz] != h:
				var lh: float
				if vx > 0:
					lh = height_grid[vx - 1][vz]
				else:
					lh = _Data.WATER_Y - min(dst[_Data.PAD - 1][vz + _Data.PAD] if dst[_Data.PAD - 1][vz + _Data.PAD] != _Data.CONST_INF else _Data.PAD, _Data.PAD) * _Data.VOXEL
					if bio[_Data.PAD - 1][vz + _Data.PAD] == _Data.TileType.DARK_GRASS:
						lh = _Data.VOXEL
				var fh: float = h - lh
				if fh > 0.0:
					_add_quad(st, Vector3(px - h_vox, lh + fh * 0.5, pz), Vector3(0, fh * 0.5, 0), Vector3(0,0,1) * h_vox, Vector3(-1,0,0), side_col)
			if vx == cols - 1 or biome_grid[vx + 1][vz] != b or height_grid[vx + 1][vz] != h:
				var rh: float
				if vx < cols - 1:
					rh = height_grid[vx + 1][vz]
				else:
					rh = _Data.WATER_Y - min(dst[_Data.PAD + cols][vz + _Data.PAD] if dst[_Data.PAD + cols][vz + _Data.PAD] != _Data.CONST_INF else _Data.PAD, _Data.PAD) * _Data.VOXEL
					if bio[_Data.PAD + cols][vz + _Data.PAD] == _Data.TileType.DARK_GRASS:
						rh = _Data.VOXEL
				var fh: float = h - rh
				if fh > 0.0:
					_add_quad(st, Vector3(px + h_vox, rh + fh * 0.5, pz), Vector3(0, fh * 0.5, 0), Vector3(0,0,-1) * h_vox, Vector3(1,0,0), side_col)
			if vz == 0 or biome_grid[vx][vz - 1] != b or height_grid[vx][vz - 1] != h:
				var fh_nb: float
				if vz > 0:
					fh_nb = height_grid[vx][vz - 1]
				else:
					fh_nb = _Data.WATER_Y - min(dst[vx + _Data.PAD][_Data.PAD - 1] if dst[vx + _Data.PAD][_Data.PAD - 1] != _Data.CONST_INF else _Data.PAD, _Data.PAD) * _Data.VOXEL
					if bio[vx + _Data.PAD][_Data.PAD - 1] == _Data.TileType.DARK_GRASS:
						fh_nb = _Data.VOXEL
				var fw: float = h - fh_nb
				if fw > 0.0:
					_add_quad(st, Vector3(px, fh_nb + fw * 0.5, pz - h_vox), Vector3(1,0,0) * h_vox, Vector3(0, fw * 0.5, 0), Vector3(0,0,-1), side_col)
			if vz == cols - 1 or biome_grid[vx][vz + 1] != b or height_grid[vx][vz + 1] != h:
				var bh: float
				if vz < cols - 1:
					bh = height_grid[vx][vz + 1]
				else:
					bh = _Data.WATER_Y - min(dst[vx + _Data.PAD][_Data.PAD + cols] if dst[vx + _Data.PAD][_Data.PAD + cols] != _Data.CONST_INF else _Data.PAD, _Data.PAD) * _Data.VOXEL
					if bio[vx + _Data.PAD][_Data.PAD + cols] == _Data.TileType.DARK_GRASS:
						bh = _Data.VOXEL
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
			if biome_grid[vx][vz] != _Data.TileType.GRASS and biome_grid[vx][vz] != _Data.TileType.SAND and biome_grid[vx][vz] != _Data.TileType.SILT:
				vz += 1
				continue
			var start_vz := vz
			while vz < cols and (biome_grid[vx][vz] == _Data.TileType.GRASS or biome_grid[vx][vz] == _Data.TileType.SAND or biome_grid[vx][vz] == _Data.TileType.SILT):
				vz += 1
			var count: int = vz - start_vz
			var px: float = -half + (float(vx) + 0.5) * _Data.VOXEL
			var z_mid: float = -half + float(start_vz * 2 + count) * h_vox
			_add_quad(st_water, Vector3(px, _Data.WATER_Y - 0.04, z_mid), Vector3(1,0,0) * h_vox, Vector3(0,0,1) * (count * h_vox), Vector3(0,1,0), Color(1,1,1))

	var mesh_water := st_water.commit()

	var mesh_aquatic = null
	var lotus_lights: Array[Vector3] = []
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
		var st_aq := SurfaceTool.new()
		st_aq.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vx in range(cols):
			for vz in range(cols):
				var b: int = biome_grid[vx][vz]
				var h: float = height_grid[vx][vz]
				if b != _Data.TileType.SAND and b != _Data.TileType.SILT:
					continue
				if h >= _Data.WATER_Y - h_vox:
					continue
				var px2: float = -half + (float(vx) + 0.5) * _Data.VOXEL
				var pz2: float = -half + (float(vz) + 0.5) * _Data.VOXEL
				var pos2 := Vector3(px2, h, pz2)
				_Aquatic.add_aquatic_plants(st_aq, cx, cz, size, vx, vz, pos2, h_vox, b == _Data.TileType.SILT, lotus_lights)
		mesh_aquatic = st_aq.commit()

	return { "mesh": mesh, "water_mesh": mesh_water, "aquatic_mesh": mesh_aquatic, "lotus_lights": lotus_lights, "biome_grid": biome_grid, "cols": cols }

func _make_water_shader(dim_id: int) -> ShaderMaterial:
	var s := Shader.new()
	if dim_id == _Data._Dim.DimensionID.REAL_WORLD:
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

static var _mat_cache: Dictionary = {}

func _init_materials() -> void:
	if _mat_cache.has(_dimension_id):
		return
	if _dimension_id == _Data._Dim.DimensionID.REAL_WORLD:
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

	var lotus_lights: Array[Vector3] = data.get("lotus_lights", [] as Array[Vector3])
	for lpos in lotus_lights:
		var is_weed_light: bool = lpos.x > 400.0
		var real_pos := Vector3(lpos.x - (500.0 if is_weed_light else 0.0), lpos.y, lpos.z)
		var light := OmniLight3D.new()
		light.light_color      = Color(0.45, 0.85, 1.0)
		light.light_energy     = 0.0
		light.omni_range       = 2.0 if is_weed_light else 3.0
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
	// height_factor: chỉ áp dụng sway cho thân rong đứng, lá sen nằm ngang (y ~ WATER_Y) không bị ảnh hưởng
	// WATER_Y = 0.25 — lá sen ở y ≈ 0.23, thân rong bắt đầu từ đáy (y âm) lên trên
	float h = VERTEX.y;
	// Lá sen nằm ngang: normal.y gần 1.0 → không sway
	float is_flat = step(0.85, abs(NORMAL.y));
	float height_factor = max(0.0, h + 0.5) * 0.7 * (1.0 - is_flat);

	// Phase offset độc lập theo vị trí để mỗi cây đung đưa lệch pha nhau
	float phase_x = VERTEX.x * 3.7 + VERTEX.z * 1.3;
	float phase_z = VERTEX.z * 3.1 + VERTEX.x * 1.7;

	// Lớp sóng chính — chậm, biên độ lớn
	float w1 = sin(TIME * sway_speed + phase_x) * sway_amount * height_factor;
	float w1z = sin(TIME * sway_speed * 0.73 + phase_z + 1.1) * sway_amount * 0.6 * height_factor;

	// Lớp sóng phụ — nhanh hơn, biên độ nhỏ, tạo rung rinh tự nhiên
	float w2 = sin(TIME * sway_speed * 2.1 + phase_x * 0.5 + 0.4) * sway_amount * 0.3 * height_factor;
	float w2z = sin(TIME * sway_speed * 1.85 + phase_z * 0.6 + 2.2) * sway_amount * 0.25 * height_factor;

	// Lớp sóng vi mô — rất nhanh, biên độ rất nhỏ (giả lập dòng nước nhỏ)
	float w3 = sin(TIME * sway_speed * 4.3 + phase_x * 1.2) * sway_amount * 0.12 * height_factor;

	VERTEX.x += w1 + w2 + w3;
	VERTEX.z += w1z + w2z;
	// KHÔNG dịch VERTEX.y để lá sen không bị chìm
}

void fragment() {
	vec4 col = COLOR * albedo_tint;
	if (col.a < 0.35) discard;
	ALBEDO = col.rgb;
	ALPHA  = col.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

func is_water_at(wx: float, wz: float, wy: float) -> bool:
	if _biome_grid.is_empty():
		return false
	var half: float = _size * 0.5
	var lx: float = (wx - (global_position.x - half)) / _Data.VOXEL
	var lz: float = (wz - (global_position.z - half)) / _Data.VOXEL
	var vx: int = int(lx)
	var vz: int = int(lz)
	if vx < 0 or vx >= _cols or vz < 0 or vz >= _cols:
		return false
	if _biome_grid[vx][vz] != _Data.TileType.SAND and _biome_grid[vx][vz] != _Data.TileType.SILT:
		return false
	return wy < _Data.VOXEL * 0.46

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
