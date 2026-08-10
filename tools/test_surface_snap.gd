extends Node

## Headless verification: cây cối / đèn đường bám ĐÚNG mặt địa hình thật.
## Bề mặt block được lượng tử hoá theo SLAB (top = floor(h/SLAB)*SLAB) nhưng
## prop trước đây gắn theo h thô → trên đồi cao (h phân đoạn) prop lơ lửng tới
## ~0.44m. Test này: với chunk có đồi, y của mọi prop == floor(h/SLAB)*SLAB.
## Chạy qua tools/test_surface_snap.tscn.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const SLAB := 0.5

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _snap(h: float) -> float:
	return _W._snap_surface_y(h)

func _surface_top(h: float) -> float:
	return floorf(h / SLAB) * SLAB

func _ready() -> void:
	WorldSeed.seed_value = 20260805
	seed(20260805)

	# ── 1. Helper khớp định nghĩa top face địa hình ─────────────────────────
	var check_pts: Array[float] = [1.0, 1.25, 1.5, 2.1, 3.375, 5.2, 0.5]
	var all_match := true
	for h in check_pts:
		if absf(_snap(h) - _surface_top(h)) > 1e-6:
			all_match = false
	_check(all_match, "_snap_surface_y == floor(h/SLAB)*SLAB mọi điểm mẫu")

	# ── 2. Quét vài chunk: đếm cell đất liền có h phân đoạn ─────────────────
	# Không thể chạy spawn cây (hệ props phụ thuộc scene), nên test trực tiếp
	# hằng số: hàm dùng trong plant/lamp phải trả về đúng mặt slab.
	var h_offsets := 0
	var h_diff := 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var data := _W.compute_chunk(dx, dz, SIZE, RW)
			var hg: Array = data.get("height_grid", [])
			if hg.is_empty():
				continue
			for vx in range(COLS):
				for vz in range(COLS):
					var h: float = float(hg[vx][vz])
					if h <= _D.WATER_Y:
						continue
					var expected: float = _surface_top(h)
					var got: float = _snap(h)
					if abs(expected - got) > 1e-6:
						h_diff += 1
					var frac: float = h - expected
					if frac > 1e-6:
						h_offsets += 1
	_check(h_diff == 0, "snap khớp top face ở mọi cell đất liền (diff=%d)" % h_diff)
	_check(h_offsets > 0, "có cell có h phân đoạn để test thực sự có nghĩa (got %d)" % h_offsets)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)