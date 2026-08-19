extends Node

## Native S5 river grid compare: WorldRiver.factors_grid vs per-cell GDScript.
## Chạy qua tools/_native_river_test.tscn (cần autoload WorldSeed + SeedSnapshot).

const _River = preload("res://scripts/world/chunk/chunk_river.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const SeedSnapshot = preload("res://scripts/core/seed_snapshot.gd")

var _fail := 0
var _wr: Object = null
var _seed := 0

func _ready() -> void:
	print("== NATIVE S5 RIVER GRID COMPARE ==")
	WorldSeed.seed_value = 20260804
	SeedSnapshot.set_seed(WorldSeed.seed_value)
	if not ClassDB.class_exists("WorldRiver"):
		print("FAIL: WorldRiver class not loaded")
		get_tree().quit(1)
		return
	_seed = SeedSnapshot.ensure()

	# Dựng curves GDScript rồi đẩy vào native instance qua đúng bridge game.
	_River._ensure_rivers()
	_wr = _River._native_river()
	if _wr == null:
		print("FAIL: native river bridge null")
		get_tree().quit(1)
		return
	_wr.set_curves(_seed, _River._river_curves)

	var ok := true
	for cxz in [[0, 0], [1, 0], [5, -3], [-302, -230], [-3, 7], [12, -4], [40, 40]]:
		if not _compare_chunk(cxz[0], cxz[1]):
			ok = false
	print(_summary())
	get_tree().quit(0 if _fail == 0 else 1)

func _compare_chunk(cxz: int, czi: int) -> bool:
	var cols := 32
	var wx0: float = float(cxz) * 32.0 - 16.0
	var wz0: float = float(czi) * 32.0 - 16.0
	var nat: PackedFloat32Array = _wr.factors_grid(wx0, wz0, cols)
	if nat.size() != cols * cols:
		_check("grid size chunk(%d,%d)" % [cxz, czi], false)
		return false
	var bad := 0
	var maxdiff := 0.0
	for ivx in range(cols):
		for ivz in range(cols):
			var ref: float = _River.river_distance_factor(wx0 + (float(ivx) + 0.5), wz0 + (float(ivz) + 0.5))
			var n: float = nat[ivx * cols + ivz]
			if ref == -1.0 or n == -1.0:
				if ref != n:
					bad += 1
					if bad <= 8:
						print("  MISMATCH sentinel (%d,%d) cell(%d,%d) wx=%.1f wz=%.1f ref=%f nat=%f"
								% [cxz, czi, ivx, ivz, wx0 + (float(ivx) + 0.5), wz0 + (float(ivz) + 0.5), ref, n])
					continue
			var d := absf(ref - n)
			maxdiff = maxf(maxdiff, d)
			if d > 1e-6:
				bad += 1
				if bad <= 8:
					print("  MISMATCH value (%d,%d) cell(%d,%d) wx=%.1f wz=%.1f ref=%f nat=%f diff=%.2g"
							% [cxz, czi, ivx, ivz, wx0 + (float(ivx) + 0.5), wz0 + (float(ivz) + 0.5), ref, n, d])
	var maxdiff_str := str(maxdiff)
	if maxdiff > 0.0 and maxdiff < 0.01:
		maxdiff_str = "%.8f" % maxdiff
	_check(("grid 1024 cells chunk(%d,%d) maxdiff=%s" % [cxz, czi, maxdiff_str]), bad == 0)
	return bad == 0

## Brute force qua mọi segment (không dùng spatial index) — xác định reference đúng.
func _brute_factor(wx: float, wz: float) -> float:
	var bank_w2: float = _River._bank_width * _River._bank_width
	var min_dist2: float = INF
	for wp in _River._river_curves:
		for i in range(wp.size() - 1):
			var a: Vector2 = wp[i]
			var b: Vector2 = wp[i + 1]
			var abx: float = b.x - a.x
			var aby: float = b.y - a.y
			var len2: float = abx * abx + aby * aby
			var px: float
			var py: float
			if len2 == 0.0:
				px = wx - a.x
				py = wz - a.y
			else:
				var t: float = clamp(((wx - a.x) * abx + (wz - a.y) * aby) / len2, 0.0, 1.0)
				var cx2: float = a.x + abx * t
				var cy2: float = a.y + aby * t
				px = wx - cx2
				py = wz - cy2
			var d2: float = px * px + py * py
			if d2 < min_dist2:
				min_dist2 = d2
	if min_dist2 > bank_w2:
		return -1.0
	return sqrt(min_dist2) / _River._bank_width

func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)

func _summary() -> String:
	return "-- SUMMARY: %d failures" % _fail