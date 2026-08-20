extends Node

# A/B: WorldGrass.add_grass_chunk + add_seagrass_chunk (C++) vs
# _grass_gd_fallback + _Grass.add_voxel_seagrass (GDScript) — so sánh
# grass_blade_data của compute_chunk chạy native vs _force_s9_gd/_force_s11_gd.
# Cả 2 path deterministic (sin-noise + LCG, không randf) → xforms/colors phải
# bit-exact. Seagrass (S11) native append vào cùng mảng sau S9 ở cả 2 path.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S9 GRASS COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var g2: Object = ClassDB.instantiate("WorldGrass") if ClassDB.class_exists("WorldGrass") else null
	_check("WorldGrass registered", g2 != null)
	if g2 == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s9_gd = true
	WorldChunk._force_s11_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	var gd_total: int = 0
	var na_total: int = 0
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s9_gd = false
		WorldChunk._force_s11_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s9_gd = true
		WorldChunk._force_s11_gd = true
		var na_d: Dictionary = res_na.get("grass_blade_data", {})
		var gd_d: Dictionary = res_gd.get("grass_blade_data", {})
		var na: Array = na_d.get("xforms", [])
		var nac: Array = na_d.get("colors", [])
		var gd: Array = gd_d.get("xforms", [])
		var gdc: Array = gd_d.get("colors", [])
		na_total += na.size()
		gd_total += gd.size()
		_compare_grass(na, nac, gd, gdc, cc.x, cc.y)
	WorldChunk._force_s9_gd = false
	print("  totals native=%d gd_fallback=%d" % [na_total, gd_total])
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare_grass(a: Array, ac: Array, b: Array, bc: Array, cx: int, cz: int) -> void:
	var ok: bool = a.size() == b.size() and ac.size() == bc.size()
	if ok:
		for i in range(a.size()):
			if not _xf_eq(a[i], b[i]) or not _col_eq(ac[i], bc[i]):
				ok = false
				print("    FIRST DIFF chunk(%d,%d) idx=%d\n      native xf=%s col=%s\n      gd     xf=%s col=%s"
						% [cx, cz, i, a[i], ac[i], b[i], bc[i]])
				break
	_check("grass_blade_data chunk(%d,%d) native=%d gd=%d" % [cx, cz, a.size(), b.size()], ok)


static func _xf_eq(a: Transform3D, b: Transform3D) -> bool:
	if (a.origin - b.origin).length_squared() > 1e-12:
		return false
	for row in range(3):
		var av: Vector3 = [a.basis.x, a.basis.y, a.basis.z][row]
		var bv: Vector3 = [b.basis.x, b.basis.y, b.basis.z][row]
		if (av - bv).length_squared() > 1e-9:
			return false
	return true


static func _col_eq(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 1e-6 and absf(a.g - b.g) < 1e-6 \
			and absf(a.b - b.b) < 1e-6 and absf(a.a - b.a) < 1e-6


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)