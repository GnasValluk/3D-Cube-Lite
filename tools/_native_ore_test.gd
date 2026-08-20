extends Node

# A/B: WorldOre.build_textured_block_mesh (C++) vs `_build_textured_block_meshes`
# (GDScript) — so sánh textured_block_meshes của compute_chunk chạy native
# (_force_s13_gd=false) vs _force_s13_gd=true.
# Mỗi loại ore là 1 ArrayMesh có VERTEX/NORMAL/COLOR/TEX_UV — so từng surface.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S13b ORE TEXTURED BLOCKS COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wt: Object = ClassDB.instantiate("WorldOre") if ClassDB.class_exists("WorldOre") else null
	_check("WorldOre registered", wt != null)
	if wt == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s13_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s13_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s13_gd = true
		_compare_ores(res_gd.get("textured_block_meshes", {}),
				res_na.get("textured_block_meshes", {}), cc.x, cc.y)
	WorldChunk._force_s13_gd = false
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare_ores(gd: Dictionary, na: Dictionary, cx: int, cz: int) -> void:
	var keys_gd: Array = gd.keys()
	var keys_na: Array = na.keys()
	_check("ore ids chunk(%d,%d) gd=%s na=%s" % [cx, cz, keys_gd, keys_na],
			keys_gd == keys_na)
	if keys_gd != keys_na:
		return
	for bid in keys_gd:
		_compare_mesh(gd[bid], na[bid], cx, cz, bid)


func _compare_mesh(a: ArrayMesh, b: ArrayMesh, cx: int, cz: int, bid: int) -> void:
	if a == null or b == null:
		_check("ore mesh %d chunk(%d,%d) null (gd=%s na=%s)" % [bid, cx, cz,
				a != null, b != null], a != null and b != null)
		return
	if a.get_surface_count() == 0 or b.get_surface_count() == 0:
		_check("ore surface %d chunk(%d,%d)" % [bid, cx, cz],
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
	var au: PackedVector2Array = aa[Mesh.ARRAY_TEX_UV]
	var bu: PackedVector2Array = ba[Mesh.ARRAY_TEX_UV]
	var ok: bool = av.size() == bv.size() and an.size() == bn.size() \
			and ac.size() == bc.size() and au.size() == bu.size()
	if ok:
		for i in range(av.size()):
			if not av[i].is_equal_approx(bv[i]):
				ok = false
				print("    FIRST VERT DIFF ore(%d) chunk(%d,%d) idx=%d native=%s gd=%s" % [bid, cx, cz, i, av[i], bv[i]])
				break
	if ok:
		for i in range(an.size()):
			if not an[i].is_equal_approx(bn[i]):
				ok = false
				print("    FIRST NORM DIFF ore(%d) chunk(%d,%d) idx=%d native=%s gd=%s" % [bid, cx, cz, i, an[i], bn[i]])
				break
	if ok:
		for i in range(ac.size()):
			if not ac[i].is_equal_approx(bc[i]):
				ok = false
				print("    FIRST COL DIFF ore(%d) chunk(%d,%d) idx=%d native=%s gd=%s" % [bid, cx, cz, i, ac[i], bc[i]])
				break
	if ok:
		for i in range(au.size()):
			if not au[i].is_equal_approx(bu[i]):
				ok = false
				print("    FIRST UV DIFF ore(%d) chunk(%d,%d) idx=%d native=%s gd=%s" % [bid, cx, cz, i, au[i], bu[i]])
				break
	_check("ore mesh %d chunk(%d,%d) native=%d gd=%d verts" % [bid, cx, cz,
			av.size(), bv.size()], ok)


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)