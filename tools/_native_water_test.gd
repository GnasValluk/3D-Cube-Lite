extends Node

# A/B: WorldWater.build_water_mesh (C++) vs `_build_water_mesh` (GDScript SurfaceTool)
# — so sánh water_mesh của compute_chunk chạy native vs _force_s10_gd=true.
# Native mirror nb_data={} (generate path, biên luôn -1); cả 2 path deterministic →
# verts/normals/colors phải bằng nhau sau khi wrap qua ArrayMesh.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S10 WATER MESH COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wt: Object = ClassDB.instantiate("WorldWater") if ClassDB.class_exists("WorldWater") else null
	_check("WorldWater registered", wt != null)
	if wt == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s10_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	var gd_total: int = 0
	var na_total: int = 0
	var chunks_with_water: int = 0
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s10_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s10_gd = true
		if res_gd.get("water_mesh") != null and res_na.get("water_mesh") != null:
			chunks_with_water += 1
			na_total += res_na["water_mesh"].surface_get_array_len(0)
			gd_total += res_gd["water_mesh"].surface_get_array_len(0)
			_compare_mesh(res_na["water_mesh"], res_gd["water_mesh"], cc.x, cc.y)
		else:
			_check("water_mesh chunk(%d,%d) both-null (gd=%s na=%s)" % [
				cc.x, cc.y, res_gd.get("water_mesh") != null, res_na.get("water_mesh") != null],
				res_gd.get("water_mesh") == null and res_na.get("water_mesh") == null)
	WorldChunk._force_s10_gd = false
	print("  totals native=%d gd=%d verts (chunks with water=%d)" % [na_total, gd_total, chunks_with_water])
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare_mesh(a: ArrayMesh, b: ArrayMesh, cx: int, cz: int) -> void:
	if a.get_surface_count() == 0 or b.get_surface_count() == 0:
		_check("water_mesh surface chunk(%d,%d)" % [cx, cz],
				a.get_surface_count() == b.get_surface_count())
		return
	var aa: Array = a.surface_get_arrays(0)
	var ba: Array = b.surface_get_arrays(0)
	var av: PackedVector3Array = aa[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = ba[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = aa[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = ba[Mesh.ARRAY_NORMAL]
	var ac: PackedColorArray = aa[Mesh.ARRAY_COLOR]
	var bc: PackedColorArray = ba[Mesh.ARRAY_COLOR]
	var ok: bool = av.size() == bv.size() and an.size() == bn.size() and ac.size() == bc.size()
	if ok:
		for i in range(av.size()):
			if not av[i].is_equal_approx(bv[i]):
				ok = false
				print("    FIRST VERT DIFF chunk(%d,%d) idx=%d native=%s gd=%s" % [cx, cz, i, av[i], bv[i]])
				break
	if ok:
		for i in range(an.size()):
			if not an[i].is_equal_approx(bn[i]):
				ok = false
				print("    FIRST NORM DIFF chunk(%d,%d) idx=%d native=%s gd=%s" % [cx, cz, i, an[i], bn[i]])
				break
	if ok:
		for i in range(ac.size()):
			if not ac[i].is_equal_approx(bc[i]):
				ok = false
				print("    FIRST COL DIFF chunk(%d,%d) idx=%d native=%s gd=%s" % [cx, cz, i, ac[i], bc[i]])
				break
	_check("water_mesh chunk(%d,%d) native=%d gd=%d verts" % [cx, cz, av.size(), bv.size()], ok)


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)