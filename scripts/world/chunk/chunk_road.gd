extends RefCounted

const _Data = preload("chunk_data.gd")

static var _road_curves: Array[PackedVector2Array] = []
static var _road_spatial: Dictionary = {}
static var _road_ready: bool = false
static var _int_cache: Dictionary = {}

static func _intersection(gx: int, gz: int) -> Vector2:
	var key: Vector2i = Vector2i(gx, gz)
	if _int_cache.has(key):
		return _int_cache[key]
	var h: int = WorldSeed.seed_value + 7777 + gx * 73856093 + gz * 19349663
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = h
	var res: Vector2 = Vector2(gx * _Data.ROAD_GRID + rng.randf_range(-_Data.ROAD_OFFSET, _Data.ROAD_OFFSET), gz * _Data.ROAD_GRID + rng.randf_range(-_Data.ROAD_OFFSET, _Data.ROAD_OFFSET))
	_int_cache[key] = res
	return res

static func _point_to_seg_d2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 == 0.0:
		return p.distance_squared_to(a)
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_squared_to(a.lerp(b, t))

static func _make_curve(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var dist: float = a.distance_to(b)
	var off1: float = rng.randf_range(-dist * 0.28, dist * 0.28)
	var off2: float = rng.randf_range(-dist * 0.28, dist * 0.28)
	var p1: Vector2 = a + dir * dist * 0.3 + perp * off1
	var p2: Vector2 = b - dir * dist * 0.3 + perp * off2
	var steps: int = maxi(6, int(dist / 6.0))
	var wp: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		wp.append(u * u * u * a + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * b)
	return wp

static func _index_curves() -> void:
	var cell_sz: float = _Data.ROAD_GRID * 0.5
	for ci in range(_road_curves.size()):
		var wp: PackedVector2Array = _road_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var cx0: int = floori(min(a.x, b.x) / cell_sz)
			var cx1: int = floori(max(a.x, b.x) / cell_sz)
			var cz0: int = floori(min(a.y, b.y) / cell_sz)
			var cz1: int = floori(max(a.y, b.y) / cell_sz)
			for cx in range(cx0 - 1, cx1 + 2):
				for cz in range(cz0 - 1, cz1 + 2):
					var ck: Vector2i = Vector2i(cx, cz)
					if not _road_spatial.has(ck):
						_road_spatial[ck] = PackedInt32Array()
					var arr: PackedInt32Array = _road_spatial[ck]
					if arr.size() == 0 or arr[arr.size() - 1] != ci:
						arr.append(ci)

static func _ensure_roads() -> void:
	if _road_ready:
		return
	_road_ready = true

	var seed_base: int = WorldSeed.seed_value + 7777
	var inters: Dictionary = {}
	for gx in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
		for gz in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
			inters[Vector2i(gx, gz)] = _intersection(gx, gz)

	var degree: Dictionary = {}
	var edge_set: Dictionary = {}

	for gx in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
		for gz in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
			var h: int = seed_base + gx * 40009 + gz * 70003
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = h
			var has: Array = [rng.randf() < 0.40, rng.randf() < 0.40, rng.randf() < 0.15, rng.randf() < 0.15]
			var cnt: int = 0
			for v in has:
				if v: cnt += 1
			if cnt < 2:
				for d in range(4):
					if not has[d]:
						has[d] = true
						cnt += 1
						if cnt >= 2:
							break

			var dirs: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
			for d in range(4):
				if not has[d]:
					continue
				var nk: Vector2i = Vector2i(gx + dirs[d].x, gz + dirs[d].y)
				if not inters.has(nk):
					continue
				var ax: int = mini(gx, nk.x)
				var az: int = mini(gz, nk.y)
				var bx: int = maxi(gx, nk.x)
				var bz: int = maxi(gz, nk.y)
				var ek: String = "%d,%d->%d,%d" % [ax, az, bx, bz]
				if edge_set.has(ek):
					continue
				edge_set[ek] = true
				degree[Vector2i(gx, gz)] = degree.get(Vector2i(gx, gz), 0) + 1
				degree[nk] = degree.get(nk, 0) + 1

	for ek in edge_set:
		var parts: PackedStringArray = ek.split("->")
		var ap: PackedStringArray = parts[0].split(",")
		var bp: PackedStringArray = parts[1].split(",")
		var ak: Vector2i = Vector2i(int(ap[0]), int(ap[1]))
		var bk: Vector2i = Vector2i(int(bp[0]), int(bp[1]))
		var h: int = seed_base + ak.x * 100003 + ak.y * 200003 + bk.x * 300007 + bk.y * 500009
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = h
		_road_curves.append(_make_curve(inters[ak], inters[bk], rng))

	_index_curves()

static func is_on_road(wx: float, wz: float) -> bool:
	_ensure_roads()
	var cell_sz: float = _Data.ROAD_GRID * 0.5
	var ck: Vector2i = Vector2i(int(wx / cell_sz), int(wz / cell_sz))
	var indices: PackedInt32Array = _road_spatial.get(ck, PackedInt32Array())
	if indices.is_empty():
		return false
	var pos: Vector2 = Vector2(wx, wz)
	var md2: float = _Data.ROAD_HALF_W * _Data.ROAD_HALF_W
	for ci in indices:
		var wp: PackedVector2Array = _road_curves[ci]
		for i in range(wp.size() - 1):
			if _point_to_seg_d2(pos, wp[i], wp[i + 1]) <= md2:
				return true
	return false
