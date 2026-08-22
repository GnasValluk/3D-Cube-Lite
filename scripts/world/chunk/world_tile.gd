extends Node3D
class_name WorldTile

## Tile LOD 4×4 chunk (128×128): gộp 16 mesh thô của chunk con (build_lod_mesh,
## compute lod_mode) thành 1 ArrayMesh + 1 MeshInstance3D — 1 node thay 16 chunk.
## Worker build dữ liệu từng chunk con; khi đủ 16 → gộp trên main.
## Cache `_tile_mesh_cache` tách riêng (không đụng `_mesh_cache`/`_lod_mesh_cache`).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Dim = preload("res://scripts/world/dimension_defs.gd")

const CHUNK_SIZE: int = 32
const CHUNKS_PER_SIDE: int = 4
const TILE_SIZE: int = CHUNK_SIZE * CHUNKS_PER_SIDE  # 128

static var _tile_mesh_cache: Dictionary = {}
static var _tile_mat_cache: Dictionary = {}

var _tx: int = 0
var _tz: int = 0
var _dim: int = 0
var _was_setup: bool = false
var _chunk_data: Dictionary = {}
var _mesh_instance: MeshInstance3D = null
var _built: bool = false

static func _tile_key(tx: int, tz: int, dim: int) -> String:
	return "%d,%d,%d" % [tx, tz, dim]

static func _material_for(dim: int) -> Material:
	if not _tile_mat_cache.has(dim):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		if dim == _Dim.DimensionID.REAL_WORLD:
			m.roughness = 0.9
		else:
			m.roughness = 1.0
		m.metallic_specular = 0.0
		_tile_mat_cache[dim] = m
	return _tile_mat_cache[dim]

## Tile local spans [-TILE_SIZE/2, +TILE_SIZE/2); center = tx*TILE_SIZE + 48
## (8 + {0,32,64,96} offset cho 4 chunk con → phủ đều quanh center).
func _center_x() -> int:
	return _tx * TILE_SIZE + CHUNK_SIZE * (CHUNKS_PER_SIDE / 2)

func _center_z() -> int:
	return _tz * TILE_SIZE + CHUNK_SIZE * (CHUNKS_PER_SIDE / 2)

func setup(tx: int, tz: int, dim: int) -> void:
	_tx = tx; _tz = tz; _dim = dim
	_was_setup = true
	position = Vector3(_center_x(), 0.0, _center_z())
	var tk := _tile_key(tx, tz, dim)
	if _tile_mesh_cache.has(tk):
		_attach_mesh(_tile_mesh_cache[tk])
		return
	var needed := 0
	for cy in range(CHUNKS_PER_SIDE):
		for cxx in range(CHUNKS_PER_SIDE):
			var ck := Vector2i(tx * CHUNKS_PER_SIDE + cxx, tz * CHUNKS_PER_SIDE + cy)
			var wk: String = _W._cache_key(ck.x, ck.y, dim)
			if _W._lod_mesh_cache.has(wk):
				_chunk_data[wk] = _W._lod_mesh_cache[wk]
			else:
				_W._gen_inc()
				_W._track_task(WorkerThreadPool.add_task(
					_thread_build.bind(self, tx, tz, dim, ck.x, ck.y), true, "tile"))
				needed += 1
	if needed == 0:
		_try_combine()

static func _thread_build(tile: Node, tx: int, tz: int, dim: int, cx: int, cz: int) -> void:
	var data: Dictionary = _W.compute_chunk(cx, cz, CHUNK_SIZE, dim, false, true)
	# Lưu kết quả vào `_lod_mesh_cache` để LOD-chunk / tile lân cận (padding) dùng
	# lại thay vì build 16 chunk con tính xong — giảm re-work khi refresh/teleport.
	_W._lod_mesh_cache[_W._cache_key(cx, cz, dim)] = data
	if is_instance_valid(tile):
		tile.call_deferred("_receive_chunk", cx, cz, data)
	_W._gen_dec()

func _receive_chunk(cx: int, cz: int, data: Dictionary) -> void:
	if _built:
		return
	var wk: String = _W._cache_key(cx, cz, _dim)
	if _chunk_data.has(wk):
		return
	_chunk_data[wk] = data
	_try_combine()

func _expected_count() -> int:
	return CHUNKS_PER_SIDE * CHUNKS_PER_SIDE

func _try_combine() -> void:
	if _built or _chunk_data.size() < _expected_count():
		return
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for cy in range(CHUNKS_PER_SIDE):
		for cxx in range(CHUNKS_PER_SIDE):
			var ckx: int = _tx * CHUNKS_PER_SIDE + cxx
			var ckz: int = _tz * CHUNKS_PER_SIDE + cy
			var wk: String = _W._cache_key(ckx, ckz, _dim)
			var data: Dictionary = _chunk_data.get(wk, {})
			if data.is_empty():
				continue
			var m: ArrayMesh = data.get("mesh")
			if m == null:
				continue
			var a: Array = m.surface_get_arrays(0)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX] if a[Mesh.ARRAY_VERTEX] else PackedVector3Array()
			if verts.is_empty():
				continue
			var v0: int = pos.size()
			var off := Vector3(
				ckx * CHUNK_SIZE - _center_x(),
				0.0,
				ckz * CHUNK_SIZE - _center_z())
			for i in verts.size():
				pos.append(verts[i] + off)
			var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] else PackedVector3Array()
			if norms.size() == verts.size():
				nor.append_array(norms)
			var colors: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] else PackedColorArray()
			if colors.size() == verts.size():
				col.append_array(colors)
			var ia: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] else PackedInt32Array()
			if ia.is_empty():
				for i in verts.size():
					idx.append(v0 + i)
			else:
				for i in ia:
					idx.append(v0 + i)
	if pos.is_empty():
		return
	var combined: Array = []
	combined.resize(Mesh.ARRAY_MAX)
	combined[Mesh.ARRAY_VERTEX] = pos
	combined[Mesh.ARRAY_INDEX] = idx
	if nor.size() == pos.size():
		combined[Mesh.ARRAY_NORMAL] = nor
	if col.size() == pos.size():
		combined[Mesh.ARRAY_COLOR] = col
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
	_tile_mesh_cache[_tile_key(_tx, _tz, _dim)] = am
	_attach_mesh(am)

func _attach_mesh(am: ArrayMesh) -> void:
	_built = true
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = _material_for(_dim)
	add_child(mi)
	_mesh_instance = mi

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _was_setup:
		_tile_mesh_cache.erase(_tile_key(_tx, _tz, _dim))
		# Xóa dữ liệu chunk con ta đã lưu vào `_lod_mesh_cache` (chống phình vô
		# hạn khi lướt thế giới). Tile lân cận còn sống trong cùng frame sẽ hit
		# cache trước khi free; sau đó behavior về mặc định như LOD chunk.
		for cy in range(CHUNKS_PER_SIDE):
			for cxx in range(CHUNKS_PER_SIDE):
				var ck := Vector2i(_tx * CHUNKS_PER_SIDE + cxx, _tz * CHUNKS_PER_SIDE + cy)
				_W._lod_mesh_cache.erase(_W._cache_key(ck.x, ck.y, _dim))
