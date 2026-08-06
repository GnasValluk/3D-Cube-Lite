extends Node

## test_village — Quán Rượu (half-timbered) mọc bên mép đường tại ngã 3/ngã tư.
## Ghim WorldSeed.seed_value = 20260805 (như mọi test thế giới).
## Tọa độ quán ổn định hunt 2026-08-04: T4 tại chunk (-3,-6) node (-1,-2);
## T3 tại chunk (48,24) node (19,10).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _V = preload("res://scripts/world/chunk/village.gd")

const SIZE := 32
const SEED := 20260805

const T4_CHUNK := Vector2i(-3, -6)   # quán ngã tư: node (-1,-2), pos ≈ (-97.01, -183.06)
const T3_CHUNK := Vector2i(48, 24)   # quán ngã 3: node (19,10), pos ≈ (1538.00, 771.26)
const NO_T4_NB := Vector2i(-3, -7)   # láng giềng T4 — không được có quán
const NO_T3_NB := Vector2i(48, 23)   # láng giềng T3 — không được có quán
const NO_INTERSECT := Vector2i(0, 0) # vùng spawn — không có quán (MIN_DIST=120)

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		print("  FAIL: %s" % label)

func _compute(cx: int, cz: int) -> Dictionary:
	return _W.compute_chunk(cx, cz, SIZE, _D._Dim.DimensionID.REAL_WORLD)

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)

	print("== test_village: Quán Rượu ==")

	# ── 1. Vùng spawn không có quán (TAVERN_MIN_DIST = 120) ────────────────
	print("-- 1. Không có quán gần spawn --")
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			var vd0: Dictionary = _compute(cx, cz).get("village_data", {})
			_check(not vd0.get("has", false), "không có quán tại chunk (%d,%d)" % [cx, cz])

	# ── 2. Chunk không ngã 3/4: has=false, xforms rỗng ─────────────────────
	print("-- 2. Chunk không có quán trả has=false --")
	for nc in [NO_INTERSECT, NO_T4_NB, NO_T3_NB]:
		var vd1: Dictionary = _compute(nc.x, nc.y).get("village_data", {})
		_check(vd1.get("has", true) == false, "chunk %s không có quán (has=false)" % str(nc))
		_check(vd1.get("xforms", []).is_empty(), "chunk %s không có hộp dựng" % str(nc))

	# ── 3. Quán ngã tư T4 ──────────────────────────────────────────────────
	print("-- 3. Quán ngã tư tại %s --" % str(T4_CHUNK))
	var data4 := _compute(T4_CHUNK.x, T4_CHUNK.y)
	var vd4: Dictionary = data4.get("village_data", {})
	_check(vd4.get("has", false), "quán tồn tại tại %s" % str(T4_CHUNK))
	var gx4: Array = vd4.get("xforms", [])
	var gc4: Array = vd4.get("colors", [])
	_check(gx4.size() > 300, "quán dựng đủ hộp (%d hộp)" % gx4.size())
	_check(gx4.size() == gc4.size(), "xforms.size() == colors.size() (%d==%d)" % [gx4.size(), gc4.size()])
	var bl4: Array = vd4.get("info", {}).get("buildings", [])
	_check(bl4.size() == 1, "chính xác 1 quán (%d)" % bl4.size())
	if bl4.size() == 1:
		var b4: Dictionary = bl4[0]
		_check(b4.get("type") == "tavern", "loại công trình là 'tavern'")
		_check(b4.get("deg") == 4, "ngã 4 (deg=%d)" % int(b4.get("deg", -1)))
		_check(b4.get("gx") == -1 and b4.get("gz") == -2, "node (%d,%d)" % [int(b4.get("gx", 0)), int(b4.get("gz", 0))])
		_check(absf(float(b4.get("x", 0.0)) - (-97.01)) < 1.0 and absf(float(b4.get("z", 0.0)) - (-183.06)) < 1.0,
			"vị trí (%.2f, %.2f)" % [float(b4.get("x", 0.0)), float(b4.get("z", 0.0))])

	# ── 4. Quán ngã 3 T3 ───────────────────────────────────────────────────
	print("-- 4. Quán ngã 3 tại %s --" % str(T3_CHUNK))
	var data3 := _compute(T3_CHUNK.x, T3_CHUNK.y)
	var vd3: Dictionary = data3.get("village_data", {})
	_check(vd3.get("has", false), "quán tồn tại tại %s" % str(T3_CHUNK))
	var gx3: Array = vd3.get("xforms", [])
	_check(gx3.size() > 300, "quán dựng đủ hộp (%d hộp)" % gx3.size())
	_check(gx3.size() == vd3.get("colors", []).size(), "xforms/colors khớp tại %s" % str(T3_CHUNK))
	var bl3: Array = vd3.get("info", {}).get("buildings", [])
	_check(bl3.size() == 1, "chính xác 1 quán (%d)" % bl3.size())
	if bl3.size() == 1:
		var b3: Dictionary = bl3[0]
		_check(b3.get("type") == "tavern", "loại công trình là 'tavern'")
		_check(b3.get("deg") == 3, "ngã 3 (deg=%d)" % int(b3.get("deg", -1)))
		_check(b3.get("gx") == 19 and b3.get("gz") == 10, "node (%d,%d)" % [int(b3.get("gx", 0)), int(b3.get("gz", 0))])
		_check(absf(float(b3.get("x", 0.0)) - 1538.0) < 1.0 and absf(float(b3.get("z", 0.0)) - 771.26) < 1.0,
			"vị trí (%.2f, %.2f)" % [float(b3.get("x", 0.0)), float(b3.get("z", 0.0))])

	# ── 5. Deterministic: compute 2 lần cùng kết quả ───────────────────────
	print("-- 5. Deterministic theo chunk --")
	var vd4b: Dictionary = _compute(T4_CHUNK.x, T4_CHUNK.y).get("village_data", {})
	var same_x: bool = true
	var gx4b: Array = vd4b.get("xforms", [])
	if gx4.size() != gx4b.size():
		same_x = false
	else:
		for i in range(gx4.size()):
			if not (gx4[i] as Transform3D).is_equal_approx(gx4b[i] as Transform3D):
				same_x = false
				break
	_check(same_x, "compute 2 lần cho xforms giống hệt (%d hộp)" % gx4.size())
	_check(gc4.size() == vd4b.get("colors", []).size(), "colors giống nhau về số lượng")

	# ── 6. Quán không nằm trên đường (road_grid dưới chân) ─────────────────
	print("-- 6. Chân quán không đè lên đường --")
	var rg6: PackedByteArray = data4.get("road_grid", PackedByteArray())
	var on_road := 0
	for b in bl4:
		var min_x: float = float(T4_CHUNK.x) * SIZE - float(SIZE) * 0.5
		var min_z: float = float(T4_CHUNK.y) * SIZE - float(SIZE) * 0.5
		var vx: int = int(floor(float(b.x) - min_x))
		var vz: int = int(floor(float(b.z) - min_z))
		for dx in range(-_V.FOOT_RX, _V.FOOT_RX + 1):
			for dz in range(-_V.FOOT_RZ, _V.FOOT_RZ + 1):
				var nx: int = vx + dx
				var nz: int = vz + dz
				if nx >= 0 and nx < SIZE and nz >= 0 and nz < SIZE:
					if rg6.size() > 0 and rg6[nx * SIZE + nz] != 0:
						on_road += 1
	_check(on_road == 0, "không ô đường nào dưới chân quán (%d vi phạm)" % on_road)

	# ── 6b. Hộp quán nằm trong phạm vi chunk-local (chặn double-offset) ────
	var half_sz := SIZE * 0.5
	var all_local: bool = true
	for t in gx4:
		var o: Vector3 = (t as Transform3D).origin
		if o.x < -half_sz - 2.0 or o.x > half_sz + 2.0 \
				or o.z < -half_sz - 2.0 or o.z > half_sz + 2.0:
			all_local = false
			break
	_check(all_local, "mọi hộp quán tại %s nằm trong phạm vi chunk-local" % str(T4_CHUNK))

	# ── 7. Dimension khác: không có quán ───────────────────────────────────
	print("-- 7. Dimension khác không có quán --")
	var vd10: Dictionary = _W.compute_chunk(T4_CHUNK.x, T4_CHUNK.y, SIZE,
		_D._Dim.DimensionID.TWILIGHT).get("village_data", {})
	_check(not vd10.get("has", true), "TWILIGHT không có quán")

	print("== kết thúc: %d lỗi ==" % _failures)
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(1 if _failures > 0 else 0)
