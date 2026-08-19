extends RefCounted

const _Data = preload("chunk_data.gd")

static var _river_curves: Array[PackedVector2Array] = []
static var _river_spatial: Dictionary = {}
static var _river_ready: bool = false
static var _int_cache: Dictionary = {}
static var _river_lock := Mutex.new()

static var _native_rv: Object = null
static var _rv_seed: int = -1

## Native WorldRiver bridge — lazy tạo 1 lần; null nếu thiếu DLL.
static func _native_river() -> Object:
	if _native_rv == null and ClassDB.class_exists("WorldRiver"):
		_native_rv = ClassDB.instantiate("WorldRiver")
	return _native_rv

## Gọi trong prewarm worker thread (sau _ensure_rivers) để dựng index C++ sớm.
static func _native_warm() -> void:
	_ensure_rivers()
	var rv := _native_river()
	if rv == null:
		return
	var s := SeedSnapshot.ensure()
	if _rv_seed == s:
		return
	rv.set_curves(s, _river_curves)
	_rv_seed = s

## Grid river_distance_factor: 1 call native thay 1024 lần gọi GDScript. Trả
## PackedFloat32Array cols×cols (thứ tự x-major, wx = wx0 + (x+0.5), wz tương tự).
## Fallback: loop GDScript cũ (bit-exact).
static func river_distance_factors(wx0: float, wz0: float, cols: int) -> PackedFloat32Array:
	_ensure_rivers()
	var rv := _native_river()
	if rv != null:
		var s := SeedSnapshot.ensure()
		if _rv_seed != s:
			rv.set_curves(s, _river_curves)
			_rv_seed = s
		var res: PackedFloat32Array = rv.factors_grid(wx0, wz0, cols)
		if res.size() == cols * cols:
			return res
	var out := PackedFloat32Array()
	out.resize(cols * cols)
	for ivx in range(cols):
		for ivz in range(cols):
			out[ivx * cols + ivz] = river_distance_factor(
				wx0 + (float(ivx) + 0.5), wz0 + (float(ivz) + 0.5))
	return out

## Chỉ dùng bởi tool test concurrency: xóa cache để worker rebuild lại từ đầu.
static func _reset_for_test() -> void:
	_river_lock.lock()
	_river_ready = false
	_river_curves.clear()
	_river_spatial.clear()
	_int_cache.clear()
	_noise_river = null
	_rv_seed = -1
	_river_lock.unlock()

static func _intersection(gx: int, gz: int) -> Vector2:
	var key: Vector2i = Vector2i(gx, gz)
	if _int_cache.has(key):
		return _int_cache[key]
	var h: int = SeedSnapshot.ensure() + 8888 + gx * 73856093 + gz * 19349663
	h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
	var rx: float = float(h & 0x7FFFFFFF) / 2147483648.0
	h = h * 16807 + 1
	var rz: float = float(h & 0x7FFFFFFF) / 2147483648.0
	var res: Vector2 = Vector2(
		gx * _Data.RIVER_GRID + (rx - 0.5) * 2.0 * _Data.RIVER_OFFSET,
		gz * _Data.RIVER_GRID + (rz - 0.5) * 2.0 * _Data.RIVER_OFFSET
	)
	_int_cache[key] = res
	return res

static func _point_to_seg_d2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var abx: float = b.x - a.x
	var aby: float = b.y - a.y
	var len2: float = abx * abx + aby * aby
	var px: float = p.x
	var py: float = p.y
	var ddx: float
	var ddy: float
	if len2 == 0.0:
		ddx = px - a.x
		ddy = py - a.y
		return ddx * ddx + ddy * ddy
	var t: float = clamp(((px - a.x) * abx + (py - a.y) * aby) / len2, 0.0, 1.0)
	var cx: float = a.x + abx * t
	var cy: float = a.y + aby * t
	ddx = px - cx
	ddy = py - cy
	return ddx * ddx + ddy * ddy

static var _noise_river: FastNoiseLite = null

static func _get_noise() -> FastNoiseLite:
	if _noise_river == null:
		_noise_river = FastNoiseLite.new()
		_noise_river.seed = SeedSnapshot.ensure() + 12121
		_noise_river.noise_type = FastNoiseLite.TYPE_PERLIN
		_noise_river.frequency = 0.012
	return _noise_river

static func _make_curve_hash(a: Vector2, b: Vector2, h: int) -> PackedVector2Array:
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var dist: float = a.distance_to(b)
	var hh: int = h * 16807 + 1
	var r1: float = float(h  & 0x7FFFFFFF) / 2147483648.0 - 0.5
	var r2: float = float(hh & 0x7FFFFFFF) / 2147483648.0 - 0.5
	hh = hh * 16807 + 1
	var t1: float = 0.15 + float(hh & 0x7F) / 256.0 * 0.35
	hh = hh * 16807 + 1
	var t2: float = 0.15 + float(hh & 0x7F) / 256.0 * 0.35
	var p1: Vector2 = a + dir * dist * t1 + perp * (r1 * 2.0 * dist * 0.85)
	var p2: Vector2 = b - dir * dist * t2 + perp * (r2 * 2.0 * dist * 0.85)
	var steps: int = maxi(16, int(dist / 3.0))
	var wp: PackedVector2Array = PackedVector2Array()
	wp.resize(steps + 1)
	var noise := _get_noise()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		var base: Vector2 = u*u*u*a + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*b
		var nx: float = noise.get_noise_2d(base.x * 0.08, base.y * 0.08)
		var nz: float = noise.get_noise_2d(base.x * 0.08 + 100.0, base.y * 0.08 + 100.0)
		var off: float = t * (1.0 - t) * 4.0
		wp[i] = base + perp * (nx * 14.0 * off) + dir * (nz * 7.0 * off)
	return wp
	return wp

static func _index_curves() -> void:
	var cell_sz: float = 8.0
	for ci in range(_river_curves.size()):
		var wp: PackedVector2Array = _river_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var cx0: int = floori(min(a.x, b.x) / cell_sz)
			var cx1: int = floori(max(a.x, b.x) / cell_sz)
			var cz0: int = floori(min(a.y, b.y) / cell_sz)
			var cz1: int = floori(max(a.y, b.y) / cell_sz)
			# Lưu theo SEGMENT (ci*10000+i) vào đúng cell segment đi qua — truy
			# vấn quét 3x3 cell lân cận (bán kính bờ sông 3.0 << cell 8) nên
			# không cần margin, index nhỏ ~9x so với trước, build nhanh hơn.
			var skey: int = ci * 10000 + i
			for cx in range(cx0, cx1 + 1):
				for cz in range(cz0, cz1 + 1):
					var ck: Vector2i = Vector2i(cx, cz)
					if not _river_spatial.has(ck):
						_river_spatial[ck] = PackedInt32Array()
					var arr: PackedInt32Array = _river_spatial[ck]
					arr.append(skey)

static func _ensure_rivers() -> void:
	if _river_ready:
		return
	_river_lock.lock()
	if _river_ready:
		_river_lock.unlock()
		return
	_build_rivers_locked()
	_river_ready = true
	_river_lock.unlock()

static func _build_rivers_locked() -> void:
	var seed_base: int = SeedSnapshot.ensure() + 8888
	var inters: Dictionary = {}
	for gx in range(-_Data.RIVER_GRID_R, _Data.RIVER_GRID_R + 1):
		for gz in range(-_Data.RIVER_GRID_R, _Data.RIVER_GRID_R + 1):
			inters[Vector2i(gx, gz)] = _intersection(gx, gz)

	var degree: Dictionary = {}
	var edge_set: Dictionary = {}

	for gx in range(-_Data.RIVER_GRID_R, _Data.RIVER_GRID_R + 1):
		for gz in range(-_Data.RIVER_GRID_R, _Data.RIVER_GRID_R + 1):
			var h: int = seed_base + gx * 40009 + gz * 70003
			h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
			var r0: float = float(h & 0x7FFFFFFF) / 2147483648.0
			h = h * 16807 + 1; var r1: float = float(h & 0x7FFFFFFF) / 2147483648.0
			h = h * 16807 + 1; var r2: float = float(h & 0x7FFFFFFF) / 2147483648.0
			h = h * 16807 + 1; var r3: float = float(h & 0x7FFFFFFF) / 2147483648.0
			var has: Array = [r0 < 0.16, r1 < 0.16, r2 < 0.05, r3 < 0.05]
			var cnt: int = 0
			for v in has:
				if v: cnt += 1
			if cnt < 1:
				for d in range(4):
					if not has[d]:
						has[d] = true
						cnt += 1
						if cnt >= 1:
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
		h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
		_river_curves.append(_make_curve_hash(inters[ak], inters[bk], h))

	_index_curves()

static var _bank_width: float = _Data.RIVER_HALF_W * 2.0

static func is_on_river(wx: float, wz: float) -> bool:
	return river_distance_factor(wx, wz) >= 0.0

# Returns -1 if not on river, else 0.0 (centerline) → 1.0 (outer bank edge)
static func river_distance_factor(wx: float, wz: float) -> float:
	_ensure_rivers()
	var cell_sz := 8.0
	var c0: int = floori(wx / cell_sz)
	var d0: int = floori(wz / cell_sz)
	# Cache static containers vào local → GDScript không phải resolve member đọc
	# mỗi lần (hot loop gọi hàm này 1024 lần/chunk trong compute_chunk).
	var spat: Dictionary = _river_spatial
	var curves: Array[PackedVector2Array] = _river_curves
	var bank_w2: float = _bank_width * _bank_width
	var min_dist2: float = INF
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var segs: PackedInt32Array = spat.get(Vector2i(c0 + dx, d0 + dz), PackedInt32Array())
			for skey in segs:
				var ci: int = skey / 10000
				var i: int = skey % 10000
				var wp: PackedVector2Array = curves[ci]
				if i >= wp.size() - 1:
					continue
				# Inline _point_to_seg_d2 (tránh 3 Vector2 Variant nhập/trả).
				var ax: float = wp[i].x
				var ay: float = wp[i].y
				var bx: float = wp[i + 1].x
				var by: float = wp[i + 1].y
				var abx: float = bx - ax
				var aby: float = by - ay
				var len2: float = abx * abx + aby * aby
				var px: float
				var py: float
				if len2 == 0.0:
					px = wx - ax
					py = wz - ay
				else:
					var t: float = clamp(((wx - ax) * abx + (wz - ay) * aby) / len2, 0.0, 1.0)
					var cx: float = ax + abx * t
					var cy: float = ay + aby * t
					px = wx - cx
					py = wz - cy
				var d2: float = px * px + py * py
				if d2 < min_dist2:
					min_dist2 = d2
	if min_dist2 > bank_w2:
		return -1.0
	return sqrt(min_dist2) / _bank_width
