extends Node

# A/B: WorldRoad.paint_grid (C++) vs `_Road.paint_road_grid` (GDScript) — so
# sánh road_grid của compute_chunk chạy native (_force_s6_gd=false) vs GD.
# road_grid là PackedByteArray cols×cols x-major, từng byte phải bằng nhau.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S6a ROAD GRID COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wt: Object = ClassDB.instantiate("WorldRoad") if ClassDB.class_exists("WorldRoad") else null
	_check("WorldRoad registered", wt != null)
	if wt == null:
		get_tree().quit(1)
		return
	WorldChunk._force_s6_gd = true
	var dim: int = _Data._Dim.DimensionID.REAL_WORLD
	var total_nat: int = 0
	var total_gd: int = 0
	for cc in _chunks:
		var res_gd: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s6_gd = false
		var res_na: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, dim, false, false)
		WorldChunk._force_s6_gd = true
		var g: PackedByteArray = res_gd.get("road_grid", PackedByteArray())
		var n: PackedByteArray = res_na.get("road_grid", PackedByteArray())
		var g_cnt: int = 0
		var n_cnt: int = 0
		for i in range(g.size()):
			if g[i] != 0: g_cnt += 1
		for i in range(n.size()):
			if n[i] != 0: n_cnt += 1
		total_gd += g_cnt
		total_nat += n_cnt
		var ok: bool = g.size() == n.size() and g.size() == 1024
		if ok:
			for i in range(g.size()):
				if g[i] != n[i]:
					ok = false
					var gx: int = i / 32
					var gz: int = i % 32
					print("    FIRST DIFF chunk(%d,%d) cell(%d,%d) gd=%d nat=%d" % [cc.x, cc.y, gx, gz, g[i], n[i]])
					break
		_check("road_grid chunk(%d,%d) native=%d gd=%d cells" % [cc.x, cc.y, n_cnt, g_cnt], ok)
	WorldChunk._force_s6_gd = false
	print("  totals native=%d gd=%d road cells" % [total_nat, total_gd])
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)