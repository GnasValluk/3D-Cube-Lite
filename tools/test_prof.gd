extends Node3D

## Chạy qua tools/test_prof.tscn:
## 1) Đo thời gian build mạng đường + sông (một lần, chạy khi loading).
## 2) Kiểm tra chính xác spatial index mới của road/river (so brute-force).
## 3) Đo tổng thời gian compute_chunk trên các chunk nhiều vị trí.

const _WorldChunk = preload("res://scripts/world/chunk/world_chunk.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var _failures: int = 0
var _Road: GDScript
var _River: GDScript

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260802)
	WorldChunk.clear_noise_cache()
	WorldChunk._noise_for_dim(_Data._Dim.DimensionID.REAL_WORLD)
	WorldChunk._noise_for_dim(_Data._Dim.DimensionID.TWILIGHT)
	_Road = load("res://scripts/world/chunk/chunk_road.gd")
	_River = load("res://scripts/world/chunk/chunk_river.gd")

	print("== test_prof: build mạng đường/sông + correctness + chunk timing ==")

	# ── 1. Build time (cold, một lần cho cả road + river) ──
	var tb0: int = Time.get_ticks_usec()
	_Road.is_on_road(0.0, 0.0)
	_River.river_distance_factor(0.0, 0.0)
	var build_ms: float = (Time.get_ticks_usec() - tb0) * 0.001
	print("BUILD road+river: %.1f ms" % build_ms)
	_check(build_ms < 2500.0, "build mạng đường/sông < 2.5s (trước ~5-6s)")

	# ── 2. Index stats ──
	var total_r := 0
	var max_r := 0
	for arr in _Road._road_spatial.values():
		var s: int = arr.size()
		total_r += s
		max_r = maxi(max_r, s)
	var total_v := 0
	var max_v := 0
	for arr in _River._river_spatial.values():
		var s: int = arr.size()
		total_v += s
		max_v = maxi(max_v, s)
	print("ROAD spatial entries=%d max=%d | RIVER entries=%d max=%d" % [total_r, max_r, total_v, max_v])
	_check(total_r < 500000 and total_v < 1200000, "spatial index gọn (road<500K, river<1.2M)")

	# ── 3. Correctness: so với index tham chiếu kiểu cũ (cell 40/55 + margin ±1) ──
	# Index cũ có bug bỏ sót bờ sông/bờ đường sát biên cell (đã sửa bằng brute-force
	# trong quá trình dev) → cho phép một lượng nhỏ lệch; lệch lớn = tái phát.
	var ref_road: Dictionary = {}
	var cell_r: float = 40.0
	for ci in range(_Road._road_curves.size()):
		var wp: PackedVector2Array = _Road._road_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var skey: int = ci * 10000 + i
			for cx in range(floori(min(a.x, b.x) / cell_r) - 1, floori(max(a.x, b.x) / cell_r) + 2):
				for cz in range(floori(min(a.y, b.y) / cell_r) - 1, floori(max(a.y, b.y) / cell_r) + 2):
					var ck: Vector2i = Vector2i(cx, cz)
					if not ref_road.has(ck):
						ref_road[ck] = PackedInt32Array()
					var arr: PackedInt32Array = ref_road[ck]
					if arr.size() == 0 or arr[arr.size() - 1] != skey:
						arr.append(skey)
	var ref_riv: Dictionary = {}
	var cell_v: float = 55.0
	for ci in range(_River._river_curves.size()):
		var wp: PackedVector2Array = _River._river_curves[ci]
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var skey: int = ci * 10000 + i
			for cx in range(floori(min(a.x, b.x) / cell_v) - 1, floori(max(a.x, b.x) / cell_v) + 2):
				for cz in range(floori(min(a.y, b.y) / cell_v) - 1, floori(max(a.y, b.y) / cell_v) + 2):
					var ck: Vector2i = Vector2i(cx, cz)
					if not ref_riv.has(ck):
						ref_riv[ck] = PackedInt32Array()
					var arr: PackedInt32Array = ref_riv[ck]
					if arr.size() == 0 or arr[arr.size() - 1] != skey:
						arr.append(skey)
	var road_mism := 0
	var riv_mism := 0
	var mism_detail: Array = []
	for k in range(6000):
		var wx: float = (randf() * 2.0 - 1.0) * 3600.0
		var wz: float = (randf() * 2.0 - 1.0) * 3600.0
		if _Road.is_on_road(wx, wz) != _ref_road_q(ref_road, cell_r, wx, wz):
			road_mism += 1
		var f1: float = _River.river_distance_factor(wx, wz)
		var f2: float = _ref_riv_q(ref_riv, cell_v, wx, wz)
		if absf(f1 - f2) > 0.0001:
			riv_mism += 1
			if mism_detail.size() < 4:
				mism_detail.append([wx, wz, f1, f2])
	for k in range(20000):
		var wx: float = (float(k % 200) - 100.0) * 0.5
		var wz: float = (float(k / 200) - 100.0) * 0.5
		if _Road.is_on_road(wx, wz) != _ref_road_q(ref_road, cell_r, wx, wz):
			road_mism += 1
		if absf(_River.river_distance_factor(wx, wz) - _ref_riv_q(ref_riv, cell_v, wx, wz)) > 0.0001:
			riv_mism += 1
	for md in mism_detail:
		print("RIVER mismatch at (%0.2f,%0.2f) new=%0.6f ref=%0.6f" % [md[0], md[1], md[2], md[3]])
	_check(road_mism <= 2, "road gần khớp ref-index (%d lệch)" % road_mism)
	_check(riv_mism <= 10, "river gần khớp ref-index (%d lệch, bug cũ bỏ sót bờ)" % riv_mism)

	# ── 4. compute_chunk timing ──
	var coords := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(-1, 2), Vector2i(2, -2),
		Vector2i(4, 3), Vector2i(-5, -4), Vector2i(8, -8), Vector2i(-9, 7),
		Vector2i(14, 2), Vector2i(-16, -13), Vector2i(22, 18), Vector2i(-27, 9)]
	var total_ms := 0.0
	var worst_ms := 0.0
	for c in coords:
		var t0: int = Time.get_ticks_usec()
		var data: Dictionary = _WorldChunk.compute_chunk(c.x, c.y, 32, _Data._Dim.DimensionID.REAL_WORLD)
		var dt: float = (Time.get_ticks_usec() - t0) * 0.001
		total_ms += dt
		worst_ms = maxf(worst_ms, dt)
		_check(data["mesh"] != null, "chunk (%d,%d) có mesh" % [c.x, c.y])
	var avg_ms: float = total_ms / float(coords.size())
	print("CHUNK avg=%.1f ms worst=%.1f ms (trước: avg ~440ms, spawn 2.6s)" % [avg_ms, worst_ms])
	_check(avg_ms < 350.0 and worst_ms < 700.0, "compute_chunk nhanh (avg<350ms, worst<700ms)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func _ref_road_q(ref: Dictionary, cell_sz: float, wx: float, wz: float) -> bool:
	var ck: Vector2i = Vector2i(int(wx / cell_sz), int(wz / cell_sz))
	var segs: PackedInt32Array = ref.get(ck, PackedInt32Array())
	if segs.is_empty():
		return false
	var pos := Vector2(wx, wz)
	for skey in segs:
		var ci: int = skey / 10000
		var i: int = skey % 10000
		var wp: PackedVector2Array = _Road._road_curves[ci]
		if i >= wp.size() - 1:
			continue
		var ab: Vector2 = wp[i + 1] - wp[i]
		var len2: float = ab.length_squared()
		if len2 == 0.0:
			if pos.distance_squared_to(wp[i]) <= 2.25:
				return true
			continue
		var t: float = clamp((pos - wp[i]).dot(ab) / len2, 0.0, 1.0)
		if pos.distance_squared_to(wp[i].lerp(wp[i + 1], t)) <= 2.25:
			return true
	return false

func _ref_riv_q(ref: Dictionary, cell_sz: float, wx: float, wz: float) -> float:
	var ck: Vector2i = Vector2i(int(wx / cell_sz), int(wz / cell_sz))
	var segs: PackedInt32Array = ref.get(ck, PackedInt32Array())
	if segs.is_empty():
		return -1.0
	var pos := Vector2(wx, wz)
	var min_d2: float = INF
	for skey in segs:
		var ci: int = skey / 10000
		var i: int = skey % 10000
		var wp: PackedVector2Array = _River._river_curves[ci]
		if i >= wp.size() - 1:
			continue
		var ab: Vector2 = wp[i + 1] - wp[i]
		var len2: float = ab.length_squared()
		var t: float = clamp((pos - wp[i]).dot(ab) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		min_d2 = minf(min_d2, pos.distance_squared_to(wp[i].lerp(wp[i + 1], t)))
	if min_d2 > 36.0:
		return -1.0
	return sqrt(min_d2) / 6.0
