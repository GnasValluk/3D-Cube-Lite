extends Node

## Native S4 biome_grid+height compare: compute_chunk với native (default) vs
## `_force_s4_gd` (fallback GDScript). So sánh biome_grid + height_grid bit-exact
## trên nhiều chunk. Chạy qua tools/_native_land_test.tscn.

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

const SIZE: int = 32
const DIM_REAL: int = _Data._Dim.DimensionID.REAL_WORLD

var _fail := 0
var _list := [[0, 0], [1, 0], [5, -3], [-302, -230], [-3, 7], [12, -4], [40, 40], [8, 2], [-11, 19]]

func _ready() -> void:
	print("== NATIVE S4 LAND GRID COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	if not ClassDB.class_exists("WorldLand"):
		print("FAIL: WorldLand class not loaded")
		get_tree().quit(1)
		return

	var ok := true
	for c in _list:
		if not _compare_chunk(c[0], c[1]):
			ok = false
	print(_summary())
	get_tree().quit(0 if _fail == 0 else 1)

func _compare_chunk(cx: int, cz: int) -> bool:
	# Native S4
	WorldChunk._force_s4_gd = false
	var native: Dictionary = WorldChunk.compute_chunk(cx, cz, SIZE, DIM_REAL)

	# GD S4 fallback
	WorldChunk._force_s4_gd = true
	var gd: Dictionary = WorldChunk.compute_chunk(cx, cz, SIZE, DIM_REAL)

	var ng: Array = native["biome_grid"]
	var gg: Array = gd["biome_grid"]
	var nh: Array = native["height_grid"]
	var gh: Array = gd["height_grid"]

	var bad_b := 0
	var bad_h := 0
	var maxdiff := 0.0
	for vx in range(SIZE):
		for vz in range(SIZE):
			if ng[vx][vz] != gg[vx][vz]:
				bad_b += 1
				if bad_b <= 8:
					print("  MISMATCH biome(%d,%d) nat=%d gd=%d" % [vx, vz, ng[vx][vz], gg[vx][vz]])
			var diff := absf(float(nh[vx][vz]) - float(gh[vx][vz]))
			if diff > maxdiff:
				maxdiff = diff
				if diff > 1.0e-6:
					bad_h += 1
					if bad_h <= 8:
						print("  MISMATCH height(%d,%d) nat=%.9f gd=%.9f" % [vx, vz, nh[vx][vz], gh[vx][vz]])

	# reef is float32-packed; compare with bit-level tolerance is heavy — compare via
	# quantized float32 (same as GD stores). beach/dmask should be identical bytes.
	var nr: PackedFloat32Array = native["reef_mask"]
	var gr: PackedFloat32Array = gd["reef_mask"]
	var bad_r := 0
	for i in range(nr.size()):
		var nf := float(nr[i])
		var gf := float(gr[i])
		if nf != gf:
			bad_r += 1
			if bad_r <= 4:
				print("  MISMATCH reef[%d] nat=%g gd=%g" % [i, nf, gf])

	var ok := bad_b == 0 and bad_h == 0 and bad_r == 0
	var mstr := ("%.10f" % maxdiff)
	_check("land chunk(%d,%d) biome=%d height=%d(maxdiff=%s) reef=%d" % [cx, cz, bad_b, bad_h, mstr, bad_r], ok)
	return ok

func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)

func _summary() -> String:
	return "-- SUMMARY: %d failures" % _fail