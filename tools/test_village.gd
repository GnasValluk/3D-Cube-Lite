extends Node

## test_village — Ngôi Làng (làng quê đồng bằng) + cầu tre trên đường.
## Ghim WorldSeed.seed_value = 20260805 (như mọi test thế giới).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const SIZE := 32
const SEED := 20260805

# Tọa độ làng ổn định với SEED (đã hunt 2026-08-02 sau khi hồ to hơn): (cx, cz)
const VILLAGE_GATE := Vector2i(-7, 0)    # có cổng làng (bắc ngang đường)
const VILLAGE_FULL := Vector2i(-22, -19) # đầy đủ: nhà, đình, giếng, lò, chợ, chòi, bến
const VILLAGE_HOUSE := Vector2i(-12, 0)  # có nhà ba gian + đình + giếng + lò + chợ
const VILLAGE_NO_ROAD := Vector2i(9, -21)  # làng ven sông (không đường): chòi + bến
const NO_VILLAGE := Vector2i(3, 1)       # không có làng (seed này)
const NO_VILLAGE2 := Vector2i(-3, -2)    # không có làng (seed này)

# Tọa độ chunk có cầu tre (đường cắt sông) — hunt 2026-08-02 (hồ/lake thay đổi)
const BRIDGE_A := Vector2i(-8, 8)
const BRIDGE_B := Vector2i(-21, 7)
const BRIDGE_C := Vector2i(-16, 0)

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		print("  FAIL: %s" % label)

func _ready() -> void:
	WorldSeed.seed_value = SEED
	seed(SEED)

	print("== test_village: Ngôi Làng + cầu tre ==")

	# ── 1. Khu vực spawn không có làng (VILLAGE_MIN_DIST = 120) ────────────
	print("-- 1. Không có làng gần spawn --")
	for cx in range(-3, 4):
		for cz in range(-3, 4):
			var data0 := _W.compute_chunk(cx, cz, SIZE, _D._Dim.DimensionID.REAL_WORLD)
			var vd0: Dictionary = data0.get("village_data", {})
			_check(not vd0.get("has", false), "không có làng tại chunk (%d,%d)" % [cx, cz])

	# ── 2. Chunk không làng: has=false, xforms rỗng ────────────────────────
	print("-- 2. Chunk không làng trả has=false --")
	for nc in [NO_VILLAGE, NO_VILLAGE2]:
		var data1 := _W.compute_chunk(nc.x, nc.y, SIZE, _D._Dim.DimensionID.REAL_WORLD)
		var vd1: Dictionary = data1.get("village_data", {})
		_check(vd1.get("has", true) == false, "chunk %s không có làng (has=false)" % str(nc))
		_check(vd1.get("xforms", []).is_empty(), "chunk %s không có hộp làng" % str(nc))

	# ── 3. Làng có cổng: xforms/colors khớp, info đầy đủ ───────────────────
	print("-- 3. Làng có cổng làng (bắc ngang đường) --")
	var dataG := _W.compute_chunk(VILLAGE_GATE.x, VILLAGE_GATE.y, SIZE,
		_D._Dim.DimensionID.REAL_WORLD)
	var vdG: Dictionary = dataG.get("village_data", {})
	_check(vdG.get("has", false), "làng tồn tại tại %s" % str(VILLAGE_GATE))
	var gx: Array = vdG.get("xforms", [])
	var gc: Array = vdG.get("colors", [])
	_check(gx.size() > 0, "làng có hộp dựng (%d hộp)" % gx.size())
	_check(gx.size() == gc.size(), "xforms.size() == colors.size() (%d==%d)" % [gx.size(), gc.size()])
	var gInfo: Dictionary = vdG.get("info", {})
	_check(gInfo.get("gate", false), "làng có cổng làng")
	_check(gInfo.get("road_dist", -1) > 0.0, "làng có đường gần (%s)" % str(gInfo.get("road_dist", -1)))
	var has_gate_b: bool = false
	for b in gInfo.get("buildings", []):
		if b.type == "gate":
			has_gate_b = true
	_check(has_gate_b, "info.buildings ghi loại 'gate'")

	# ── 4. Làng đầy đủ: đủ các loại công trình ─────────────────────────────
	print("-- 4. Làng đầy đủ công trình --")
	var dataF := _W.compute_chunk(VILLAGE_FULL.x, VILLAGE_FULL.y, SIZE,
		_D._Dim.DimensionID.REAL_WORLD)
	var vdF: Dictionary = dataF.get("village_data", {})
	_check(vdF.get("has", false), "làng tồn tại tại %s" % str(VILLAGE_FULL))
	var fInfo: Dictionary = vdF.get("info", {})
	var ftypes: Array = []
	for b in fInfo.get("buildings", []):
		if not ftypes.has(b.type):
			ftypes.append(b.type)
	for t in ["house", "shrine", "well", "kiln", "market", "hut", "dock"]:
		_check(ftypes.has(t), "làng có công trình '%s' (types=%s)" % [t, str(ftypes)])

	# ── 5. Làng ven sông không đường: chòi + bến nước ──────────────────────
	print("-- 5. Làng ven sông (chòi + bến nước) --")
	var dataR := _W.compute_chunk(VILLAGE_NO_ROAD.x, VILLAGE_NO_ROAD.y, SIZE,
		_D._Dim.DimensionID.REAL_WORLD)
	var vdR: Dictionary = dataR.get("village_data", {})
	_check(vdR.get("has", false), "làng ven sông tồn tại tại %s" % str(VILLAGE_NO_ROAD))
	var rInfo: Dictionary = vdR.get("info", {})
	var rtypes: Array = []
	for b in rInfo.get("buildings", []):
		if not rtypes.has(b.type):
			rtypes.append(b.type)
	_check(rtypes.has("hut"), "làng ven sông có chòi (types=%s)" % str(rtypes))
	_check(rtypes.has("dock"), "làng ven sông có bến nước (types=%s)" % str(rtypes))
	_check(rInfo.get("river_dist", -1) > 0.0, "làng ven sông có sông gần")

	# ── 6. Deterministic: compute 2 lần cùng kết quả ───────────────────────
	print("-- 6. Deterministic theo chunk --")
	var d1a := _W.compute_chunk(VILLAGE_GATE.x, VILLAGE_GATE.y, SIZE, _D._Dim.DimensionID.REAL_WORLD)
	var vd1a: Dictionary = d1a.get("village_data", {})
	var same_x: bool = true
	var same_c: bool = true
	for i in range(gx.size()):
		if i >= vd1a.get("xforms", []).size():
			same_x = false
			break
		var t1: Transform3D = gx[i] as Transform3D
		var t2: Transform3D = vd1a.get("xforms", [])[i] as Transform3D
		if not t1.is_equal_approx(t2):
			same_x = false
			break
	if gx.size() != vd1a.get("xforms", []).size():
		same_x = false
	_check(same_x, "compute_village 2 lần cho xforms giống hệt (%d hộp)" % gx.size())
	_check(gc.size() == vd1a.get("colors", []).size(), "colors giống nhau về số lượng")

	# ── 7. Làng không nằm trên đường (road_grid) ───────────────────────────
	print("-- 7. Công trình làng không nằm trên đường --")
	var bd7: Array = dataG.get("biome_grid", [])
	var rg7: PackedByteArray = dataG.get("road_grid", PackedByteArray())
	var on_road_count := 0
	for b in gInfo.get("buildings", []):
		var wx: float = b.x
		var wz: float = b.z
		var min_x: float = float(VILLAGE_GATE.x) * SIZE - float(SIZE) * 0.5
		var min_z: float = float(VILLAGE_GATE.y) * SIZE - float(SIZE) * 0.5
		var vx: int = int(floor(wx - min_x))
		var vz: int = int(floor(wz - min_z))
		if vx >= 0 and vx < SIZE and vz >= 0 and vz < SIZE:
			if rg7.size() > 0 and rg7[vx * SIZE + vz] != 0:
				on_road_count += 1
	_check(on_road_count == 0, "không công trình làng nào đặt trên đường")

	# ── 7b. Hộp làng phải nằm trong phạm vi chunk-local (chặn double-offset) ─
	var half_sz := SIZE * 0.5
	var all_local: bool = true
	for t in gx:
		var o: Vector3 = (t as Transform3D).origin
		if o.x < -half_sz - 2.0 or o.x > half_sz + 2.0 \
				or o.z < -half_sz - 2.0 or o.z > half_sz + 2.0:
			all_local = false
			break
	_check(all_local, "mọi hộp làng tại %s nằm trong phạm vi chunk-local" % str(VILLAGE_GATE))

	# ── 8. Cầu tre trên đường cắt sông ─────────────────────────────────────
	print("-- 8. Cầu tre tại nơi đường cắt sông --")
	for bc in [BRIDGE_A, BRIDGE_B, BRIDGE_C]:
		var dataB := _W.compute_chunk(bc.x, bc.y, SIZE, _D._Dim.DimensionID.REAL_WORLD)
		var bd8: Dictionary = dataB.get("bridge_data", {})
		var bx: Array = bd8.get("xforms", [])
		var bcol: Array = bd8.get("colors", [])
		_check(bx.size() > 0, "chunk %s có cầu tre (%d hộp)" % [str(bc), bx.size()])
		_check(bx.size() == bcol.size(), "cầu tre xforms/colors khớp tại %s" % str(bc))
		var rf8: PackedByteArray = dataB.get("river_flag", PackedByteArray())
		_check(not rf8.is_empty(), "chunk cầu tre %s có sông (river_flag)" % str(bc))
		var bridge_local: bool = true
		for t in bx:
			var o: Vector3 = (t as Transform3D).origin
			if o.x < -half_sz - 3.0 or o.x > half_sz + 3.0 \
					or o.z < -half_sz - 3.0 or o.z > half_sz + 3.0:
				bridge_local = false
				break
		_check(bridge_local, "hộp cầu tre tại %s nằm trong phạm vi chunk-local" % str(bc))

	# ── 9. Chunk không sông: không có cầu ──────────────────────────────────
	print("-- 9. Không có cầu khi không có sông --")
	var data9 := _W.compute_chunk(VILLAGE_GATE.x, VILLAGE_GATE.y, SIZE, _D._Dim.DimensionID.REAL_WORLD)
	var bd9: Dictionary = data9.get("bridge_data", {})
	_check(bd9.get("xforms", []).is_empty(), "làng %s (không sông) không có cầu tre" % str(VILLAGE_GATE))

	# ── 10. Dimension khác: không có làng/cầu ──────────────────────────────
	print("-- 10. Dimension khác không có làng/cầu --")
	var data10 := _W.compute_chunk(VILLAGE_GATE.x, VILLAGE_GATE.y, SIZE, _D._Dim.DimensionID.TWILIGHT)
	var vd10: Dictionary = data10.get("village_data", {})
	var bd10: Dictionary = data10.get("bridge_data", {})
	_check(not vd10.get("has", true), "TWILIGHT không có làng")
	_check(bd10.get("xforms", []).is_empty(), "TWILIGHT không có cầu tre")

	print("== kết thúc: %d lỗi ==" % _failures)
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(1 if _failures > 0 else 0)
