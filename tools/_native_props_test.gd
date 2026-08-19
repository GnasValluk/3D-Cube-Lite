extends Node

# A/B: WorldProps.props (C++) vs `_props_gd_fallback` (GDScript hash) — so sánh
# plant_props của compute_chunk chạy native vs _force_s12_gd=true. Fallback thay
# randf() bằng _cell_hash01(vx+S1,vz+S2) + road_grid[i]!=0 → cả 2 path deterministic,
# plant_props (gồm aquatic đầu + land props + sort cost) phải bit-exact bằng nhau.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S12 PLANT PROPS COMPARE (hash determinism) ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wp: Object = ClassDB.instantiate("WorldProps") if ClassDB.class_exists("WorldProps") else null
	_check("WorldProps registered", wp != null)
	if wp == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s12_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	var gd_total: int = 0
	var na_total: int = 0
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s12_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s12_gd = true
		var na: Array = res_na.get("plant_props", [])
		var gd: Array = res_gd.get("plant_props", [])
		na_total += na.size()
		gd_total += gd.size()
		_compare_props(na, gd, cc.x, cc.y)
	WorldChunk._force_s12_gd = false
	print("  totals native=%d gd_fallback=%d" % [na_total, gd_total])
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare_props(a: Array, b: Array, cx: int, cz: int) -> void:
	var ok := a.size() == b.size()
	if ok:
		for i in range(a.size()):
			if not _prop_eq(a[i], b[i]):
				ok = false
				print("    FIRST DIFF chunk(%d,%d) idx=%d native=%s gd=%s"
						% [cx, cz, i, a[i], b[i]])
				break
	_check("plant_props chunk(%d,%d) native=%d gd=%d" % [cx, cz, a.size(), b.size()], ok)


static func _prop_eq(a: Dictionary, b: Dictionary) -> bool:
	if a.get("type") != b.get("type"):
		return false
	if a.get("variant") != b.get("variant"):
		return false
	var pa: Vector3 = a.get("pos", Vector3.ZERO)
	var pb: Vector3 = b.get("pos", Vector3.ZERO)
	return (pa - pb).length_squared() < 1e-12


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)