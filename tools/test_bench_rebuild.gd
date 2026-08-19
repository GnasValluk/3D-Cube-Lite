extends Node

## test_bench_rebuild — đo thời gian thật của rebuild_mesh trên chunk 32×32
## sau khi đặt block (single vs bulk). Cho biết mỗi lần place tốn bao nhiêu ms.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Terrain = preload("res://scripts/world/chunk/chunk_terrain.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD
const _FAILURES: int = 0

func _ready() -> void:
	print("== test_bench_rebuild ==")
	WorldSeed.seed_value = 20260806
	_W.props_enabled = false
	_W.clear_noise_cache()

	var d := _W.compute_chunk(0, 0, 32, REAL, false, false)
	var bd := _BD.new()
	bd.from_bytes(d["block_data_bytes"], 32, 32)
	var chunk := _W.new()
	chunk._cols = 32
	chunk._cx = 0
	chunk._cz = 0
	chunk._dimension_id = REAL
	chunk.block_data = bd
	chunk._init_materials()
	add_child(chunk)

	chunk.rebuild_mesh()

	var t := Time.get_ticks_usec()
	chunk.rebuild_mesh()
	print("rebuild_mesh full (no change): %.2f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	# ── Breakdown từng mảnh của rebuild full ──
	var st := SurfaceTool.new()
	var mesh: ArrayMesh = null
	t = Time.get_ticks_usec()
	chunk._top_ly_cache = chunk._build_top_ly_cache()
	var ms_top := Time.get_ticks_usec() - t

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	t = Time.get_ticks_usec()
	_Terrain.build_terrain_mesh(st, chunk.block_data, 32, REAL, chunk._top_ly_cache, false)
	var ms_terrain := Time.get_ticks_usec() - t

	t = Time.get_ticks_usec()
	mesh = st.commit()
	var ms_commit := Time.get_ticks_usec() - t

	t = Time.get_ticks_usec()
	var tri: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	var ms_trimesh := Time.get_ticks_usec() - t
	print("breakdown: top_ly=%.2fms terrain=%.2fms commit=%.2fms trimesh=%.2fms" % [
		ms_top / 1000.0, ms_terrain / 1000.0, ms_commit / 1000.0, ms_trimesh / 1000.0])
	print("verts=%d tris collider=%s" % [
		mesh.get_faces().size(), "yes" if tri != null else "no"])

	var tl: int = chunk._top_ly_cache[16 * 32 + 16]
	var wby: float = (float(tl + _BD.Y_MIN) + 0.5) * _BD.SLAB_HEIGHT
	print("surface y at (16,16) = %.2f (top layer %d)" % [wby, tl])

	t = Time.get_ticks_usec()
	var ok: bool = chunk.place_block_at(16.5, wby, 15.5, _D.BlockID.STONE_PLATFORM, _BD.OFF_CENTER)
	print("place_block_at 1 block: ok=%s rebuild %.2f ms" % [str(ok), (Time.get_ticks_usec() - t) / 1000.0])

	var positions: Array[Vector3] = []
	var bids: Array[int] = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			positions.append(Vector3(16.0 + dx, wby, 16.0 + dz))
			bids.append(_D.BlockID.STONE_PLATFORM)
	t = Time.get_ticks_usec()
	var n: int = chunk.place_blocks_at(positions, bids, _BD.OFF_CENTER)
	print("place_blocks_at bulk 9: placed=%d rebuild %.2f ms" % [n, (Time.get_ticks_usec() - t) / 1000.0])

	# ── Bulk biome block (DIRT xây nền) — rebuild terrain nhưng top_ly theo cột ──
	var tl2: int = chunk._top_ly_cache[11 * 32 + 11]
	var wby2: float = _BD.layer_to_world_y(tl2 + 1)
	var pos2: Array[Vector3] = []
	var bid2: Array[int] = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			pos2.append(Vector3(11.0 + dx, wby2, 11.0 + dz))
			bid2.append(_D.BlockID.DIRT)
	t = Time.get_ticks_usec()
	var n2: int = chunk.place_blocks_at(pos2, bid2, _BD.OFF_CENTER)
	print("place_blocks_at bulk biome 9: placed=%d rebuild %.2f ms" % [n2, (Time.get_ticks_usec() - t) / 1000.0])

	chunk.queue_free()
	print("== test_bench_rebuild done (%d fail) ==" % _FAILURES)
	get_tree().quit(0)