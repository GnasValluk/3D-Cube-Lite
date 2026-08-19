extends Node

# A/B: WorldDist.bfs_grids (C++) vs S6b GDScript replication (seed scan + 4 BFS).
# Không thể đọc wdist/rdist/dland/hdist từ return dict compute_chunk → test trực
# tiếp trên inputs thật (height/biome/road từ compute_chunk).

var _fails: int = 0
var _passes: int = 0
var _chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, -3),
	Vector2i(-302, -230), Vector2i(-3, 7), Vector2i(12, -4), Vector2i(40, 40),
	Vector2i(8, 2), Vector2i(-11, 19)]

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

func _ready() -> void:
	print("== NATIVE S6B BFS DIST GRIDS COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	var wd: Object = ClassDB.instantiate("WorldDist") if ClassDB.class_exists("WorldDist") else null
	_check("WorldDist registered", wd != null)
	if wd == null:
		get_tree().quit(1)
		return
	for cc in _chunks:
		var res: Dictionary = WorldChunk.compute_chunk(cc.x, cc.y, 32, 0, 1.0, 0.0)
		var hg: Array = res["height_grid"]
		var bg: Array = res["biome_grid"]
		var rg: PackedByteArray = res["road_grid"]
		var cols: int = res["cols"]
		var nd: Dictionary = wd.bfs_grids(hg, bg, rg, cols,
				_Data.WATER_Y, _Data.VOXEL, _Data.CONST_INF, _Data.TileType.DESERT)
		var gw := _gd_s6b(hg, bg, rg, cols)
		_compare("bfs wdist", nd["wdist"], gw[0], cc.x, cc.y)
		_compare("bfs rdist", nd["rdist"], gw[1], cc.x, cc.y)
		_compare("bfs dland", nd["dland"], gw[2], cc.x, cc.y)
		_compare("bfs hdist", nd["hdist"], gw[3], cc.x, cc.y)
	print("-- SUMMARY: %d failures, %d passes" % [_fails, _passes])
	get_tree().quit(1 if _fails else 0)


static func _gd_s6b(hg: Array, bg: Array, rg: PackedByteArray, cols: int) -> Array:
	var wdist := PackedInt32Array()
	var rdist := PackedInt32Array()
	var dland := PackedInt32Array()
	var hdist := PackedInt32Array()
	wdist.resize(cols * cols); wdist.fill(-1)
	rdist.resize(cols * cols); rdist.fill(-1)
	dland.resize(cols * cols); dland.fill(-1)
	hdist.resize(cols * cols); hdist.fill(-1)
	for vx in range(cols):
		for vz in range(cols):
			var i2: int = vx * cols + vz
			if hg[vx][vz] <= _Data.WATER_Y:
				wdist[i2] = 0
			if rg.size() > 0 and rg[i2] != 0:
				rdist[i2] = 0
			if bg[vx][vz] == _Data.TileType.DESERT and hg[vx][vz] > _Data.WATER_Y:
				dland[i2] = 0
			var h0: float = hg[vx][vz]
			for dq in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var qx: int = vx + dq[0]
				var qz: int = vz + dq[1]
				if qx < 0 or qz < 0 or qx >= cols or qz >= cols:
					continue
				if absf(hg[qx][qz] - h0) >= _Data.VOXEL * 0.75:
					hdist[i2] = 0
					break
	_bfs_chebyshev(wdist, cols)
	_bfs_chebyshev(rdist, cols)
	_bfs_chebyshev(dland, cols)
	_bfs_chebyshev(hdist, cols)
	return [wdist, rdist, dland, hdist]


static func _bfs_chebyshev(dmap: PackedInt32Array, cols: int) -> void:
	var frontier := PackedInt32Array()
	for i in range(dmap.size()):
		if dmap[i] == 0:
			frontier.append(i)
	var fhead := 0
	while fhead < frontier.size():
		var idx: int = frontier[fhead]
		fhead += 1
		var nd: int = dmap[idx] + 1
		var cx: int = idx / cols
		var cz: int = idx % cols
		for dx in range(-1, 2):
			var nx: int = cx + dx
			if nx < 0 or nx >= cols:
				continue
			for dz in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nz: int = cz + dz
				if nz < 0 or nz >= cols:
					continue
				var ni: int = nx * cols + nz
				if dmap[ni] == -1:
					dmap[ni] = nd
					frontier.append(ni)
	for i in range(dmap.size()):
		if dmap[i] == -1:
			dmap[i] = _Data.CONST_INF


func _compare(tag: String, native: PackedInt32Array, gd: PackedInt32Array, cx: int, cz: int) -> void:
	var bad: int = 0
	if native.size() != gd.size():
		bad = -1
	else:
		for i in range(native.size()):
			if native[i] != gd[i]:
				bad += 1
	print("  %s chunk(%d,%d) bad=%d" % [tag, cx, cz, bad])
	_check("%s chunk(%d,%d) bad=%d" % [tag, cx, cz, bad], bad == 0)


func _check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("  PASS: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)