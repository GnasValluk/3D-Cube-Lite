extends Node

# A/B: S5 river override — compute_chunk chạy native (_force_s5_gd=false) vs
# GDScript (_force_s5_gd=true). So sánh biome_grid + height_grid + river_flag
# trong return dict (S5 ghi đè cả 3).

var _fail := 0
var _pass := 0

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S5 RIVER OVERRIDE COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wt: Object = ClassDB.instantiate("WorldRiver") if ClassDB.class_exists("WorldRiver") else null
	_check("WorldRiver registered", wt != null)
	if wt == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s5_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	for cc in [[0, 0], [1, 0], [5, -3], [-302, -230], [-3, 7], [12, -4], [40, 40], [8, 2], [-11, 19]]:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc[0], cc[1], 32, dim, false, false)
		WorldChunk._force_s5_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc[0], cc[1], 32, dim, false, false)
		WorldChunk._force_s5_gd = true
		_compare(cc, res_gd, res_na)
	WorldChunk._force_s5_gd = false
	print("-- SUMMARY: %d failures, %d passes" % [_fail, _pass])
	get_tree().quit(1 if _fail else 0)

func _compare(cc: Array, g: Dictionary, n: Dictionary) -> void:
	var biome_g: Array = g.get("biome_grid", [])
	var biome_n: Array = n.get("biome_grid", [])
	var hgt_g: Array = g.get("height_grid", [])
	var hgt_n: Array = n.get("height_grid", [])
	var rf_g: PackedByteArray = g.get("river_flag", PackedByteArray())
	var rf_n: PackedByteArray = n.get("river_flag", PackedByteArray())
	var bad := 0
	var cnt := 0
	if biome_g.size() == 32 and biome_n.size() == 32 and hgt_g.size() == 32 and hgt_n.size() == 32 \
			and rf_g.size() == 1024 and rf_n.size() == 1024:
		for vx in range(32):
			for vz in range(32):
				if rf_g[vx * 32 + vz] != 0:
					cnt += 1
				if biome_g[vx][vz] != biome_n[vx][vz]:
					bad += 1
					if bad <= 5:
						print("  BIOME DIFF chunk(%d,%d) (%d,%d) gd=%d nat=%d" % [cc[0], cc[1], vx, vz, biome_g[vx][vz], biome_n[vx][vz]])
				if absf(float(hgt_g[vx][vz]) - float(hgt_n[vx][vz])) > 1e-9:
					bad += 1
					if bad <= 5:
						print("  HEIGHT DIFF chunk(%d,%d) (%d,%d) gd=%.6f nat=%.6f" % [cc[0], cc[1], vx, vz, float(hgt_g[vx][vz]), float(hgt_n[vx][vz])])
				if rf_g[vx * 32 + vz] != rf_n[vx * 32 + vz]:
					bad += 1
					if bad <= 5:
						print("  RFLAG DIFF chunk(%d,%d) (%d,%d) gd=%d nat=%d" % [cc[0], cc[1], vx, vz, rf_g[vx * 32 + vz], rf_n[vx * 32 + vz]])
	else:
		bad += 1
		print("  SIZE DIFF chunk(%d,%d) b=%d/%d h=%d/%d rf=%d/%d" % [cc[0], cc[1], biome_g.size(), biome_n.size(), hgt_g.size(), hgt_n.size(), rf_g.size(), rf_n.size()])
	_check("chunk(%d,%d) %d river cells bit-exact" % [cc[0], cc[1], cnt], bad == 0)

func _check(name: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS: " + name)
	else:
		_fail += 1
		print("  FAIL: " + name)