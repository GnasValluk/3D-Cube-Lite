extends Node

# A/B: WorldBfsDst.bfs_dst (C++) vs `_bfsdst_gd_fallback` (GDScript) — so sánh
# dst (S2 distance map) của bio thật. Cả REAL (base==edge, không BFS) lẫn
# TWILIGHT (base==TWILIGHT_GRASS, edge==TWILIGHT_DIRT → _bfs_manhattan) đều test.

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const _Noise = preload("res://scripts/world/chunk/chunk_noise.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")
const SIZE := 32
const COLS := 32
const PAD := _Data.PAD
const TOTAL := COLS + 2 * PAD

func _ready() -> void:
	print("== NATIVE S2 BFS DST COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var bd2: Object = ClassDB.instantiate("WorldBfsDst") if ClassDB.class_exists("WorldBfsDst") else null
	_check("WorldBfsDst registered", bd2 != null)
	if bd2 == null:
		get_tree().quit(1)
		return
	for dim in [_Data._Dim.DimensionID.REAL_WORLD, _Data._Dim.DimensionID.TWILIGHT]:
		var tag := "REAL" if dim == _Data._Dim.DimensionID.REAL_WORLD else "TWILIGHT"
		for cc in _chunks:
			var bio: Array = _Noise._biome_grid(cc.x * SIZE, cc.y * SIZE, COLS, TOTAL, dim)
			var base_tile: int = _Data.TileType.GRASS_DIRT if dim == _Data._Dim.DimensionID.REAL_WORLD else _Data.TileType.TWILIGHT_GRASS
			var edge_tile: int = _Data.TileType.GRASS_DIRT if dim == _Data._Dim.DimensionID.REAL_WORLD else _Data.TileType.TWILIGHT_DIRT
			var na: PackedInt32Array = bd2.bfs_dst(bio, TOTAL, base_tile, edge_tile, _Data.CONST_INF)
			var gd: PackedInt32Array = WorldChunk._bfsdst_gd_fallback(bio, TOTAL, base_tile, edge_tile)
			_compare(na, gd, tag, cc.x, cc.y)
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


func _compare(a: PackedInt32Array, b: PackedInt32Array, tag: String, cx: int, cz: int) -> void:
	var ok: bool = a.size() == b.size()
	if ok:
		var maxd := 0
		for i in range(a.size()):
			var d: int = absi(a[i] - b[i])
			if d > maxd:
				maxd = d
			if a[i] != b[i]:
				ok = false
				print("    FIRST DIFF %s chunk(%d,%d) idx=%d native=%d gd=%d"
						% [tag, cx, cz, i, a[i], b[i]])
				break
		if ok:
			_check("dst %s chunk(%d,%d) maxdiff=0" % [tag, cx, cz], true)
		else:
			_check("dst %s chunk(%d,%d) (maxdiff=%d)" % [tag, cx, cz, maxd], false)
	else:
		_check("dst %s chunk(%d,%d) size native=%d gd=%d" % [tag, cx, cz, a.size(), b.size()], false)


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)