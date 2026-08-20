extends Node

# A/B: WorldAquatic.build_aquatic (C++) vs `_Aquatic.add_aquatic_plants` (GDScript)
# — so sánh aquatic_mesh + lotus_lights + plant_props của compute_chunk chạy
# native (_force_s11a_gd=false) vs _force_s11a_gd=true.
# Cả 2 path deterministic + bit-exact → 3 output phải bằng nhau từng phần tử.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S11a AQUATIC PLANTS COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wt: Object = ClassDB.instantiate("WorldAquatic") if ClassDB.class_exists("WorldAquatic") else null
	_check("WorldAquatic registered", wt != null)
	if wt == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s11_gd = true
	WorldChunk._force_s11a_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	var chunk_count: int = 0
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s11a_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s11a_gd = true
		chunk_count += 1
		_compare_mesh(res_na.get("aquatic_mesh"), res_gd.get("aquatic_mesh"), cc.x, cc.y)
		_compare_lightlist(res_na.get("lotus_lights", []), res_gd.get("lotus_lights", []), cc.x, cc.y)
		_compare_props(res_na.get("plant_props", []), res_gd.get("plant_props", []), cc.x, cc.y)
	WorldChunk._force_s11_gd = false
	WorldChunk._force_s11a_gd = false
	print("  chunks compared=%d" % chunk_count)
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare_mesh(a, b, cx: int, cz: int) -> void:
	var a_l: int = _mesh_len(a)
	var b_l: int = _mesh_len(b)
	if a_l == 0 or b_l == 0:
		# GD st_aq.commit() trả 1 surface rỗng; native trả null → coi tương đương.
		_check("aquatic_mesh chunk(%d,%d) empty-equiv (gd=%d na=%d verts)" % [cx, cz, b_l, a_l],
				a_l == b_l)
		return
	_compare_mesh_arrays(a, b, cx, cz)


func _mesh_len(m) -> int:
	if m == null:
		return 0
	if m.get_surface_count() == 0:
		return 0
	return m.surface_get_array_len(0)


func _compare_mesh_arrays(a: ArrayMesh, b: ArrayMesh, cx: int, cz: int) -> void:
	if a.get_surface_count() == 0 or b.get_surface_count() == 0:
		_check("aquatic_mesh surface chunk(%d,%d)" % [cx, cz],
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
	_check("aquatic_mesh chunk(%d,%d) native=%d gd=%d verts" % [cx, cz, av.size(), bv.size()], ok)


func _compare_lightlist(a: Array, b: Array, cx: int, cz: int) -> void:
	var ok: bool = a.size() == b.size()
	if ok:
		for i in range(a.size()):
			if not (a[i] as Vector3).is_equal_approx(b[i] as Vector3):
				ok = false
				print("    FIRST LIGHT DIFF chunk(%d,%d) idx=%d native=%s gd=%s" % [cx, cz, i, a[i], b[i]])
				break
	_check("lotus_lights chunk(%d,%d) native=%d gd=%d" % [cx, cz, a.size(), b.size()], ok)


func _compare_props(a: Array, b: Array, cx: int, cz: int) -> void:
	var ok: bool = a.size() == b.size()
	if ok:
		for i in range(a.size()):
			if not _dict_eq(a[i], b[i]):
				ok = false
				print("    FIRST PROP DIFF chunk(%d,%d) idx=%d:\n      native=%s\n      gd=%s" % [cx, cz, i, a[i], b[i]])
				break
	_check("plant_props chunk(%d,%d) native=%d gd=%d" % [cx, cz, a.size(), b.size()], ok)


func _dict_eq(x, y) -> bool:
	var yd: Dictionary = y
	for k in x.keys():
		if not yd.has(k):
			return false
		var a: Variant = x[k]
		var c: Variant = yd[k]
		if a is Vector3 and c is Vector3:
			if not a.is_equal_approx(c):
				return false
		elif a is float and c is float:
			if not is_equal_approx(a, c):
				return false
		elif a != c:
			return false
	return true


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)