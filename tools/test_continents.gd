extends Node3D

## test_continents — Lục địa: spawn luôn trên đất liền, và đi biển không quá
## ~3500 block là gặp lục địa mới (nhiều lục địa xen kẽ bồn biển, không còn
## một bồn biển dài >5000 block như tần số ocean cũ 0.00025).
## Chạy qua tools/test_continents.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const SEEDS := [20260805, 123456789, 777, 20260806]
const STEP := 100.0
const RANGE := 6000.0
const MAX_RUN := 3500.0
const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0
var _nd: Dictionary = {}

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ocean(wx: float, wz: float) -> bool:
	return _W._ocean_mask_at(_nd, wx, wz)

## Quét 1 hướng từ gốc tọa độ: trả [có_biển, đất_sau_biển, biển_liên_tục_max]
func _scan_dir(dx: int, dz: int) -> Array:
	var run := 0
	var max_run := 0
	var ocean_seen := false
	var land_after_ocean := false
	var r := 0.0
	while r <= RANGE:
		if _ocean(float(dx) * r, float(dz) * r):
			run += 1
			max_run = maxi(max_run, run)
			ocean_seen = true
		else:
			if ocean_seen:
				land_after_ocean = true
			run = 0
		r += STEP
	return [ocean_seen, land_after_ocean, max_run]

func _ready() -> void:
	print("== test_continents: Lục địa + spawn trên đất ==")

	# ── 1. Spawn (0,0): không biển + biome GRASS_DIRT/DESERT (đất khô) ─────
	print("-- 1. Spawn luôn trên đất liền (nhiều seed) --")
	for s in SEEDS:
		WorldSeed.seed_value = s
		_W._Noise.clear_cache()
		_nd = _W._Noise._noise_for_dim(RW)
		_check(not _ocean(0.0, 0.0), "seed %d: spawn (0,0) không phải biển" % s)
		var bio: int = _W._Noise._biome_at(0.0, 0.0, RW)
		_check(bio == _D.TileType.GRASS_DIRT or bio == _D.TileType.DESERT,
			"seed %d: spawn là đất cao 1.0 (GRASS_DIRT/DESERT, được %d)" % [s, bio])

	# ── 2. Đi biển không quá ~3500 block là gặp lục địa mới ────────────────
	print("-- 2. Lục địa mới sau biển (4 hướng, tối đa %d block) --" % int(MAX_RUN))
	for s in SEEDS:
		WorldSeed.seed_value = s
		_W._Noise.clear_cache()
		_nd = _W._Noise._noise_for_dim(RW)
		for d in [[1, 0], [0, 1], [-1, 0], [0, -1]]:
			var res: Array = _scan_dir(d[0], d[1])
			var dir_name: String = ["E", "S", "W", "N"][[[1, 0], [0, 1], [-1, 0], [0, -1]].find(d)]
			_check(bool(res[0]), "seed %d: hướng %s có biển trong %d block" % [s, dir_name, int(RANGE)])
			_check(bool(res[1]), "seed %d: hướng %s có lục địa MỚI sau biển" % [s, dir_name])
			_check(float(res[2]) * STEP <= MAX_RUN,
				"seed %d: hướng %s biển liên tục tối đa %d block (≤%d)" % [s, dir_name, int(float(res[2]) * STEP), int(MAX_RUN)])

	# ── 3. Pipeline thật: chunk (0,0) ô spawn không phải biển ───────────────
	print("-- 3. Pipeline thật khớp mask --")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	_nd = _W._Noise._noise_for_dim(RW)
	var data := _W.compute_chunk(0, 0, SIZE, RW)
	var bg: Array = data.get("biome_grid", [])
	_check(bg.size() == SIZE, "chunk (0,0) có biome_grid")
	_check(bg.size() == SIZE and int(bg[16][16]) != _D.TileType.OCEAN_DEEP,
		"chunk (0,0): ô spawn (16,16) không phải biển (bias qua pipeline thật)")

	# ── 4. Điểm biển xa → chunk tương ứng là OCEAN_DEEP ─────────────────────
	var fc := Vector2i.ZERO   # chunk
	var fl := Vector2i.ZERO   # ô cục bộ
	var fp := Vector2.ZERO    # center thật của ô (mask lấy đúng tại đây)
	var fr := 900.0
	# Cửa sổ phải đủ WIDE (bán kính 22 ô) để điểm nằm GIỮA biển sâu, không phải
	# vịnh/lạch nông ven bờ: pipeline intertidal sẽ gán MANGROVE_MUD cho ô biển
	# gần đất liền ≤ MANGROVE_SEA_RANGE(20) khi mask mangrore hợp — window hẹp
	# 3x3 cũ bắt nhầm lạch nông ở tần số quần đảo mới (nhiều bờ biển hơn).
	const OCEAN_R: int = 22
	while fr < 4000.0 and fp == Vector2.ZERO:
		for i in range(16):
			var a: float = float(i) / 16.0 * TAU
			var wx: float = cos(a) * fr
			var wz: float = sin(a) * fr
			var cx: int = int(floor(wx / SIZE))
			var cz: int = int(floor(wz / SIZE))
			var lx: int = clampi(int(round(wx - (cx * SIZE - 16.5))), 0, SIZE - 1)
			var lz: int = clampi(int(round(wz - (cz * SIZE - 16.5))), 0, SIZE - 1)
			var cxp: float = cx * SIZE - 16 + lx + 0.5
			var czp: float = cz * SIZE - 16 + lz + 0.5
			var all_oc := true
			for ox in range(-OCEAN_R, OCEAN_R + 1):
				for oz in range(-OCEAN_R, OCEAN_R + 1):
					if not _ocean(cxp + ox, czp + oz):
						all_oc = false
						break
				if not all_oc:
					break
			if all_oc:
				fc = Vector2i(cx, cz)
				fl = Vector2i(lx, lz)
				fp = Vector2(cxp, czp)
				break
		fr += 200.0
	_check(fp != Vector2.ZERO, "tìm thấy điểm biển ngoài vùng spawn (r<4000)")
	if fp != Vector2.ZERO:
		var cd := _W.compute_chunk(fc.x, fc.y, SIZE, RW)
		var cbg: Array = cd.get("biome_grid", [])
		_check(cbg.size() == SIZE and fl.x >= 0 and fl.x < SIZE and fl.y >= 0 and fl.y < SIZE,
			"chunk (%d,%d) chứa điểm biển tại ô (%d,%d)" % [fc.x, fc.y, fl.x, fl.y])
		_check(cbg.size() == SIZE and int(cbg[fl.x][fl.y]) == _D.TileType.OCEAN_DEEP,
			"ô biển mask = OCEAN_DEEP qua pipeline (được %d)" % (int(cbg[fl.x][fl.y]) if cbg.size() == SIZE else -1))

	# ── 5. DIAGNOSTIC quần đảo: mỗi đảo 1 biome + phân bố kích thước đảo ─────
	print("-- 5. Hình dạng quần đảo (mỗi đảo nên 1 biome) --")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	_nd = _W._Noise._noise_for_dim(RW)
	var island_count := 0
	var max_iso := 0
	var min_iso := 1 << 30
	var total_iso := 0
	var mixed := 0
	var seen := {}
	const SAMP: int = 8
	const CELLS: int = 12
	const REG: int = int(_D.ISLAND_CELL * CELLS)
	var px := -REG
	while px <= REG:
		var pz := -REG
		while pz <= REG:
			if not _ocean(px, pz) and not seen.has(Vector2i(px, pz)):
				# BFS quần đảo
				var q: Array = [Vector2i(px, pz)]
				seen[Vector2i(px, pz)] = true
				var size := 0
				var expected: int = -1
				var px2_: int = px
				while not q.is_empty():
					var c: Vector2i = q.pop_back()
					size += 1
					var bio: int = _W._Noise._biome_at(float(c.x), float(c.y), RW)
					if expected == -1:
						expected = bio
					elif bio != expected:
						mixed += 1
					for off in [Vector2i(SAMP, 0), Vector2i(-SAMP, 0), Vector2i(0, SAMP), Vector2i(0, -SAMP)]:
						var n: Vector2i = Vector2i(c.x + off.x, c.y + off.y)
						if not seen.has(n) and not _ocean(float(n.x), float(n.y)) \
								and absf(float(n.x)) <= REG and absf(float(n.y)) <= REG:
							seen[n] = true
							q.append(n)
				# mật độ: mỗi sample = SAMP*SAMP block
				var blk := size * SAMP * SAMP
				island_count += 1
				max_iso = maxi(max_iso, blk)
				min_iso = mini(min_iso, blk)
				total_iso += blk
				if island_count <= 12:
					print("  island %d: ~%.0f blocks biome=%d" % [island_count, float(blk), expected])
			pz += SAMP
		px += SAMP
	if island_count > 0:
		var region_blk := (2.0 * REG) * (2.0 * REG)
		print("ISLAND-STAT: count=%d avg=%.0fblk min=%.0f max=%.0f mixed_points=%d land_pct=%.0f%%" % [
			island_count, float(total_iso) / float(island_count),
			float(min_iso), float(max_iso), mixed,
			float(total_iso) / region_blk * 100.0])
	else:
		print("ISLAND-STAT: 0 islands trong vùng quét")

	# ── 6. BIỂN KHÔNG CẮT ĐỊA HÌNH NÚI: mọi ô lõi núi (mtn_t>0.50) là đất ─────
	# Khớp `_ocean_mask_compute` + height_grid: mask núi không được phép phủ
	# địa hình núi thành biển (MOUNTAIN_LAND_T=0.5). Quét lưới xa spawn.
	print("-- 6. Núi luôn đất (mtn_t > 0.50 => không biển) --")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	_nd = _W._Noise._noise_for_dim(RW)
	var cut := 0
	var mtn_total := 0
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			var wx: float = float(gx) * 900.0 + 250.0
			var wz: float = float(gz) * 900.0 + 250.0
			var mtn: float = (_nd["mountain"].get_noise_2d(wx, wz) + 1.0) * 0.5
			var mtn_t: float = clamp((mtn - 0.58) / 0.14, 0.0, 1.0)
			mtn_t = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
			if mtn_t > 0.50:
				mtn_total += 1
				if _ocean(wx, wz):
					cut += 1
	print("  núi scanned=%d cut_by_sea=%d" % [mtn_total, cut])
	_check(mtn_total > 0, "có lõi núi ngoài vùng spawn đủ để kiểm tra (%d)" % mtn_total)
	_check(cut == 0, "không ô núi nào bị biển phủ (%d vi phạm)" % cut)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
