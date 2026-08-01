extends Node

## Headless verification: rêu bám trên bề mặt đá/quặng.
## 1. Chiều không gian TWILIGHT → 0 rêu (chỉ REAL_WORLD).
## 2. Chunk (0,0) gần spawn: nếu có rêu (vách đá hẻm núi) → mọi tuft sát đá/quặng.
## 3. Chunk xa có đồi quặng → có rêu (số tuft > 0), mọi tuft sát đá/quặng.
## 4. Màu rêu xanh (kênh g cao nhất).
## 5. Deterministic: compute 2 lần → xforms/colors giống hệt.
## Chạy qua tools/test_moss.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _moss_of(data: Dictionary) -> Array:
	var mbd: Dictionary = data.get("moss_blade_data", {})
	return [mbd.get("xforms", []), mbd.get("colors", [])]

## Mỗi tuft phải nằm sát (≤ 0.8 block) một block đá/quặng trong chunk.
func _all_tufts_near_pickaxable(bd, xforms: Array) -> bool:
	for xf in xforms:
		var p: Vector3 = xf.origin
		var ok := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var vx: int = int(floor(p.x + float(SIZE) * 0.5)) + dx
					var vz: int = int(floor(p.z + float(SIZE) * 0.5)) + dz
					var ly: int = _BD.world_y_to_layer(p.y) + dy
					if vx < 0 or vx >= COLS or vz < 0 or vz >= COLS:
						continue
					var b: int = bd.get_block(vx, ly, vz)
					if _D.is_pickaxable(b):
						ok = true
						break
				if ok:
					break
			if ok:
				break
		if not ok:
			return false
	return true

func _colors_greenish(colors: Array) -> bool:
	for c in colors:
		if (c as Color).g <= (c as Color).r or (c as Color).g <= (c as Color).b:
			return false
	return true

func _ready() -> void:
	# WorldSeed tự randomize mỗi process → ghim seed cố định để terrain ổn định
	WorldSeed.seed_value = 20260805
	seed(20260805)

	# ── 1. Chiều TWILIGHT: không rêu (chỉ REAL_WORLD) ───────────────────────
	var tw := _W.compute_chunk(0, 0, SIZE, _D._Dim.DimensionID.TWILIGHT)
	_check(_moss_of(tw)[0].size() == 0, "TWILIGHT: 0 rêu (got %d)" % _moss_of(tw)[0].size())

	# ── 2. Gần spawn: mọi rêu phải sát đá/quặng (vách đá hẻm núi) ──────────
	var near_total := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var d := _W.compute_chunk(dx, dz, SIZE, RW)
			var bdd := _BD.new()
			bdd.from_bytes(d["block_data_bytes"], COLS, COLS)
			var m := _moss_of(d)
			near_total += m[0].size()
			_check(_all_tufts_near_pickaxable(bdd, m[0]),
				"chunk (%d,%d): mọi tuft sát đá/quặng" % [dx, dz])
	print("INFO | rêu gần spawn: %d tuft" % near_total)

	# ── 3. Chunk xa có đồi quặng → có rêu ──────────────────────────────────
	var data := _W.compute_chunk(5, 5, SIZE, RW)
	var bd := _BD.new()
	bd.from_bytes(data["block_data_bytes"], COLS, COLS)
	var m := _moss_of(data)
	var xforms: Array = m[0]
	var colors: Array = m[1]
	_check(xforms.size() > 0, "chunk có đồi quặng: có rêu (%d tuft)" % xforms.size())
	_check(xforms.size() == colors.size(), "xforms/colors cùng số lượng (%d/%d)" % [xforms.size(), colors.size()])
	_check(_all_tufts_near_pickaxable(bd, xforms), "mọi tuft sát block đá/quặng")
	_check(_colors_greenish(colors), "màu rêu xanh lá (g cao nhất)")

	# ── 3. Deterministic ───────────────────────────────────────────────────
	var d2 := _W.compute_chunk(5, 5, SIZE, RW)
	var m2 := _moss_of(d2)
	var same: bool = m2[0].size() == xforms.size() and m2[1].size() == colors.size()
	if same:
		for i in range(xforms.size()):
			if (xforms[i] as Transform3D) != (m2[0][i] as Transform3D) or (colors[i] as Color) != (m2[1][i] as Color):
				same = false
				break
	_check(same, "compute 2 lần → rêu giống hệt")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
