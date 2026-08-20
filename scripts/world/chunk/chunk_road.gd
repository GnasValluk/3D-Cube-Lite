extends RefCounted

const _Data = preload("chunk_data.gd")

static var _road_curves: Array[PackedVector2Array] = []
static var _road_curve_bboxes: Array[Rect2] = []
static var _road_spatial: Dictionary = {}
static var _road_ready: bool = false
static var _int_cache: Dictionary = {}
static var _node_has_cache: Dictionary = {}
static var _road_lock := Mutex.new()

## Chỉ dùng bởi tool test concurrency: xóa cache để worker rebuild lại từ đầu.
static func _reset_for_test() -> void:
	_road_lock.lock()
	_road_ready = false
	_road_curves.clear()
	_road_curve_bboxes.clear()
	_road_spatial.clear()
	_int_cache.clear()
	_node_has_cache.clear()
	_rd_seed = -1
	_road_lock.unlock()

static var _native_rd: Object = null
static var _rd_seed: int = -1

## Native WorldRoad bridge (S6a road_grid) — lazy tạo 1 lần; null nếu thiếu DLL.
static func _native_road() -> Object:
	if _native_rd == null and ClassDB.class_exists("WorldRoad"):
		_native_rd = ClassDB.instantiate("WorldRoad")
	return _native_rd

## Gọi trong prewarm worker thread (sau _ensure_roads) để dựng index C++ sớm.
static func _native_warm() -> void:
	_ensure_roads()
	var rd := _native_road()
	if rd == null:
		return
	var s := SeedSnapshot.ensure()
	if _rd_seed == s:
		return
	rd.set_curves(s, _road_curves)
	_rd_seed = s

## Paint road_grid qua native: 1 call thay gather + segment loop GDScript.
## Trả PackedByteArray cols×cols x-major; rỗng nếu native không có → caller
## fallback paint_road_grid GDScript.
static func paint_road_grid_native(wx0: float, wz0: float, size: int,
		cols: int) -> PackedByteArray:
	_ensure_roads()
	var rd := _native_road()
	if rd == null:
		return PackedByteArray()
	var s := SeedSnapshot.ensure()
	if _rd_seed != s:
		rd.set_curves(s, _road_curves)
		_rd_seed = s
	return rd.paint_grid(wx0, wz0, size, cols)

## 4 hướng nối của node lưới (has[d]: d=0→E, 1→S, 2→W, 3→N), luôn ≥2.
## Deterministic theo SeedSnapshot — dùng chung với _ensure_roads().
static func _node_has(gx: int, gz: int) -> Array:
	var key: Vector2i = Vector2i(gx, gz)
	if _node_has_cache.has(key):
		return _node_has_cache[key]
	var seed_base: int = SeedSnapshot.ensure() + 7777
	var h: int = seed_base + gx * 40009 + gz * 70003
	h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
	var r0: float = float(h & 0x7FFFFFFF) / 2147483648.0
	h = h * 16807 + 1; var r1: float = float(h & 0x7FFFFFFF) / 2147483648.0
	h = h * 16807 + 1; var r2: float = float(h & 0x7FFFFFFF) / 2147483648.0
	h = h * 16807 + 1; var r3: float = float(h & 0x7FFFFFFF) / 2147483648.0
	var has: Array = [r0 < 0.40, r1 < 0.40, r2 < 0.15, r3 < 0.15]
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
	_node_has_cache[key] = has
	return has

## Bậc nút đường: 2 = đường thẳng/góc, 3 = ngã 3, 4 = ngã tư.
static func intersection_degree(gx: int, gz: int) -> int:
	var cnt: int = 0
	for v in _node_has(gx, gz):
		if v:
			cnt += 1
	return cnt

## Bản sao mảng has (không cho phép sửa vào cache).
static func intersection_has(gx: int, gz: int) -> Array:
	return _node_has(gx, gz).duplicate()

## Tọa độ tâm node lưới.
static func intersection_point(gx: int, gz: int) -> Vector2:
	return _intersection(gx, gz)

static func _intersection(gx: int, gz: int) -> Vector2:
	var key: Vector2i = Vector2i(gx, gz)
	if _int_cache.has(key):
		return _int_cache[key]
	# Hash function nhanh thay vì RandomNumberGenerator.new()
	var h: int = SeedSnapshot.ensure() + 7777 + gx * 73856093 + gz * 19349663
	h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
	var rx: float = float(h & 0x7FFFFFFF) / 2147483648.0
	h = h * 16807 + 1
	var rz: float = float(h & 0x7FFFFFFF) / 2147483648.0
	var res: Vector2 = Vector2(
		gx * _Data.ROAD_GRID + (rx - 0.5) * 2.0 * _Data.ROAD_OFFSET,
		gz * _Data.ROAD_GRID + (rz - 0.5) * 2.0 * _Data.ROAD_OFFSET
	)
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

## Phiên bản không dùng RNG object — chỉ dùng hash integer
static func _make_curve_hash(a: Vector2, b: Vector2, h: int) -> PackedVector2Array:
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var dist: float = a.distance_to(b)
	var h2: int = h * 16807 + 1
	var r1: float = float(h  & 0x7FFFFFFF) / 2147483648.0 - 0.5
	var r2: float = float(h2 & 0x7FFFFFFF) / 2147483648.0 - 0.5
	var p1: Vector2 = a + dir * dist * 0.3 + perp * (r1 * 2.0 * dist * 0.28)
	var p2: Vector2 = b - dir * dist * 0.3 + perp * (r2 * 2.0 * dist * 0.28)
	var steps: int = maxi(6, int(dist / 6.0))
	var wp: PackedVector2Array = PackedVector2Array()
	wp.resize(steps + 1)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		wp[i] = u*u*u*a + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*b
	return wp

static func _index_curves() -> void:
	var cell_sz: float = 8.0
	for ci in range(_road_curves.size()):
		var wp: PackedVector2Array = _road_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var cx0: int = floori(min(a.x, b.x) / cell_sz)
			var cx1: int = floori(max(a.x, b.x) / cell_sz)
			var cz0: int = floori(min(a.y, b.y) / cell_sz)
			var cz1: int = floori(max(a.y, b.y) / cell_sz)
			# Lưu theo SEGMENT (ci*10000+i) vào đúng cell segment đi qua — truy
			# vấn quét 3x3 cell lân cận (bán kính đường 1.5 << cell 8) nên không
			# cần margin, index nhỏ ~9x so với trước, build nhanh hơn nhiều.
			var skey: int = ci * 10000 + i
			for cx in range(cx0, cx1 + 1):
				for cz in range(cz0, cz1 + 1):
					var ck: Vector2i = Vector2i(cx, cz)
					if not _road_spatial.has(ck):
						_road_spatial[ck] = PackedInt32Array()
					var arr: PackedInt32Array = _road_spatial[ck]
					arr.append(skey)

## Cache bounding box của từng curve — compute_positions gọi mỗi chunk.
## Các bbox được pre-fill toàn bộ trong _build_roads_locked() → chỉ đọc, an toàn
## với mọi worker thread (trước đây lazy-fill += resize khi idle → race).
static func curve_bbox(ci: int) -> Rect2:
	if _road_curve_bboxes.size() > ci and _road_curve_bboxes[ci].size != Vector2.ZERO:
		return _road_curve_bboxes[ci]
	var wp: PackedVector2Array = _road_curves[ci]
	var rect := Rect2(wp[0], Vector2.ZERO)
	for pt in wp:
		rect = rect.expand(pt)
	if _road_curve_bboxes.size() <= ci:
		_road_curve_bboxes.resize(ci + 1)
	_road_curve_bboxes[ci] = rect
	return rect

static func _ensure_roads() -> void:
	if _road_ready:
		return
	_road_lock.lock()
	if _road_ready:
		_road_lock.unlock()
		return
	_build_roads_locked()
	_road_ready = true
	_road_lock.unlock()

static func _build_roads_locked() -> void:
	var seed_base: int = SeedSnapshot.ensure() + 7777
	var inters: Dictionary = {}
	for gx in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
		for gz in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
			inters[Vector2i(gx, gz)] = _intersection(gx, gz)

	var degree: Dictionary = {}
	var edge_set: Dictionary = {}

	for gx in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
		for gz in range(-_Data.ROAD_GRID_R, _Data.ROAD_GRID_R + 1):
			var has: Array = _node_has(gx, gz)

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
		# Hash thay vì RandomNumberGenerator.new()
		var h: int = seed_base + ak.x * 100003 + ak.y * 200003 + bk.x * 300007 + bk.y * 500009
		h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16)
		_road_curves.append(_make_curve_hash(inters[ak], inters[bk], h))

	_index_curves()

	# Pre-fill mọi bbox ngay sau build → curve_bbox chỉ đọc cache, không ghi
	# trên worker thread (bỏ race resize khi nhiều worker hỏi cùng curve).
	_road_curve_bboxes.resize(_road_curves.size())
	for ci in range(_road_curves.size()):
		var wp: PackedVector2Array = _road_curves[ci]
		var rect := Rect2(wp[0], Vector2.ZERO)
		for pt in wp:
			rect = rect.expand(pt)
		_road_curve_bboxes[ci] = rect

static func is_on_road(wx: float, wz: float) -> bool:
	_ensure_roads()
	var cell_sz: float = 8.0
	var pos: Vector2 = Vector2(wx, wz)
	var c0: int = floori(wx / cell_sz)
	var d0: int = floori(wz / cell_sz)
	var md2: float = _Data.ROAD_HALF_W * _Data.ROAD_HALF_W
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var segs: PackedInt32Array = _road_spatial.get(Vector2i(c0 + dx, d0 + dz), PackedInt32Array())
			if segs.is_empty():
				continue
			for skey in segs:
				var ci: int = skey / 10000
				var i: int = skey % 10000
				var wp: PackedVector2Array = _road_curves[ci]
				if i >= wp.size() - 1:
					continue
				if _point_to_seg_d2(pos, wp[i], wp[i + 1]) <= md2:
					return true
	return false

## Gộp segment keys phủ bbox (margin = bán kính đường) — gather 1 lần/chunk.
static func gather_segments(x0: float, z0: float, x1: float, z1: float) -> PackedInt32Array:
	_ensure_roads()
	var cell_sz: float = 8.0
	var margin: float = _Data.ROAD_HALF_W
	var cx0: int = floori((x0 - margin) / cell_sz)
	var cx1: int = floori((x1 + margin) / cell_sz)
	var cz0: int = floori((z0 - margin) / cell_sz)
	var cz1: int = floori((z1 + margin) / cell_sz)
	var out := PackedInt32Array()
	var seen := {}
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			var segs: PackedInt32Array = _road_spatial.get(Vector2i(cx, cz), PackedInt32Array())
			for skey in segs:
				if not seen.has(skey):
					seen[skey] = true
					out.append(skey)
	return out

## Danh sách index curve có segment đi qua vùng [x0..x1]×[z0..z1] (+margin).
## Dùng cho compute_positions: quét 11612 curve tìm 4 curve gần chunk là phí
## hoàn toàn — dùng spatial index (8×8) lấy thẳng các curve lân cận.
static func gather_curve_indices(x0: float, z0: float, x1: float, z1: float) -> PackedInt32Array:
	_ensure_roads()
	var cell_sz: float = 8.0
	var margin: float = LAMP_QUERY_MARGIN
	var cx0: int = floori((x0 - margin) / cell_sz)
	var cx1: int = floori((x1 + margin) / cell_sz)
	var cz0: int = floori((z0 - margin) / cell_sz)
	var cz1: int = floori((z1 + margin) / cell_sz)
	var out := PackedInt32Array()
	var seen := {}
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			var segs: PackedInt32Array = _road_spatial.get(Vector2i(cx, cz), PackedInt32Array())
			for skey in segs:
				var ci: int = skey / 10000
				if not seen.has(ci):
					seen[ci] = true
					out.append(ci)
	return out

const LAMP_QUERY_MARGIN: float = 40.0

static func is_on_road_from_segs(wx: float, wz: float, segs: PackedInt32Array) -> bool:
	var pos: Vector2 = Vector2(wx, wz)
	var md2: float = _Data.ROAD_HALF_W * _Data.ROAD_HALF_W
	for skey in segs:
		var ci: int = skey / 10000
		var i: int = skey % 10000
		var wp: PackedVector2Array = _road_curves[ci]
		if i >= wp.size() - 1:
			continue
		if _point_to_seg_d2(pos, wp[i], wp[i + 1]) <= md2:
			return true
	return false

## Vẽ trực tiếp mask road vào road_grid (PackedByteArray cols×cols) từ các
## segment gần chunk — thay vì 1024 cột × segment/ô (check distance từng ô),
## chỉ duyệt segment gần chunk và paint các ô trong ROAD_HALF_W. Segment ít,
## bbox nhỏ → số lần _point_to_seg_d2 giảm mạnh. Worker-safe (ghi vào mảng
## local của caller).
static func paint_road_grid(road_grid: PackedByteArray, cols: int,
		size: int, cx: int, cz: int) -> void:
	_ensure_roads()
	var half: float = size * 0.5
	var wx0: float = float(cx) * size - half
	var wz0: float = float(cz) * size - half
	var md2: float = _Data.ROAD_HALF_W * _Data.ROAD_HALF_W
	var segs := gather_segments(wx0, wz0, wx0 + size, wz0 + size)
	for skey in segs:
		var ci: int = skey / 10000
		var i: int = skey % 10000
		var wp: PackedVector2Array = _road_curves[ci]
		if i >= wp.size() - 1:
			continue
		var a: Vector2 = wp[i]
		var b: Vector2 = wp[i + 1]
		var mn_x: float = minf(a.x, b.x) - _Data.ROAD_HALF_W
		var mx_x: float = maxf(a.x, b.x) + _Data.ROAD_HALF_W
		var mn_z: float = minf(a.y, b.y) - _Data.ROAD_HALF_W
		var mx_z: float = maxf(a.y, b.y) + _Data.ROAD_HALF_W
		var gx0: int = clampi(int(floori((mn_x - wx0) / _Data.VOXEL)), 0, cols - 1)
		var gx1: int = clampi(int(floori((mx_x - wx0) / _Data.VOXEL)), 0, cols - 1)
		var gz0: int = clampi(int(floori((mn_z - wz0) / _Data.VOXEL)), 0, cols - 1)
		var gz1: int = clampi(int(floori((mx_z - wz0) / _Data.VOXEL)), 0, cols - 1)
		for gx in range(gx0, gx1 + 1):
			for gz in range(gz0, gz1 + 1):
				var idx: int = gx * cols + gz
				if road_grid[idx] != 0:
					continue
				var pos := Vector2(wx0 + (float(gx) + 0.5) * _Data.VOXEL,
					wz0 + (float(gz) + 0.5) * _Data.VOXEL)
				if _point_to_seg_d2(pos, a, b) <= md2:
					road_grid[idx] = 1

## Tra cứu theo ô 8×8 với cache local (truyền vào từ caller — worker-safe vì
## cache là biến local mỗi chunk). Mỗi cột 1 lookup thay vì 9 lookup Dictionary.
static func is_on_road_cell_cached(wx: float, wz: float, cache: Dictionary) -> bool:
	var cell_sz: float = 8.0
	var c0: int = floori(wx / cell_sz)
	var d0: int = floori(wz / cell_sz)
	var pos: Vector2 = Vector2(wx, wz)
	var md2: float = _Data.ROAD_HALF_W * _Data.ROAD_HALF_W
	var key: Vector2i = Vector2i(c0, d0)
	var segs: PackedInt32Array
	if cache.has(key):
		segs = cache[key]
	else:
		segs = PackedInt32Array()
		var seen := {}
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cseg: PackedInt32Array = _road_spatial.get(Vector2i(c0 + dx, d0 + dz), PackedInt32Array())
				for skey in cseg:
					if not seen.has(skey):
						seen[skey] = true
						segs.append(skey)
		cache[key] = segs
	for skey in segs:
		var ci: int = skey / 10000
		var i: int = skey % 10000
		var wp: PackedVector2Array = _road_curves[ci]
		if i >= wp.size() - 1:
			continue
		if _point_to_seg_d2(pos, wp[i], wp[i + 1]) <= md2:
			return true
	return false
