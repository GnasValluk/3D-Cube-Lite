extends Node

## Headless verification: đồi quặng trên bề mặt ở khu vực xa spawn.
## 1. Trong bán kính ORE_HILL_MIN_DIST quanh (0,0): không có block quặng nào.
## 2. Chunk xa: nếu có đồi → tổng block 4~12, đá + quặng, quặng lộ trên mặt đồi.
## 3. Quặng chỉ thuộc 4 loại: than, sắt, đồng, nhôm.
## 4. Đồng bằng (GRASS_DIRT): đồi chỉ có than + sắt hiếm, sắt ≤ 30% quặng.
## 5. Đồng bằng tỷ lệ spawn thấp hơn (hằng số ORE_HILL_PLAINS_CHANCE < ORE_HILL_CHANCE).
## 6. hint == fullscan vẫn nhất quán khi có đồi.
## 7. Deterministic: compute 2 lần → block data giống hệt.
## Chạy qua tools/test_ore_hills.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _T = preload("res://scripts/world/chunk/chunk_terrain.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

## 4 loại quặng được phép ở khu xa spawn
const ALLOWED_ORES: Dictionary = {
	_D.BlockID.COAL_ORE: true,
	_D.BlockID.IRON_ORE: true,
	_D.BlockID.COPPER_ORE: true,
	_D.BlockID.BAUXITE_ORE: true,
}

## Block nền tự nhiên của fill_blocks (top_block theo biome) — dùng để tách
## phần đồi ra khỏi mặt đất thật. STONE không nằm trong set: chỉ có rạn ngầm
## dùng STONE làm top nhưng rạn luôn ở dưới nước → cột dưới nước bị loại trước.
## (Đã hợp nhất đồng bằng + cao nguyên: đất cỏ = GRASS_DIRT — "đồng bằng cỏ".)
const NATURAL_TOPS: Dictionary = {
	_D.BlockID.GRASS: true, _D.BlockID.DARK_GRASS: true, _D.BlockID.SAND: true,
	_D.BlockID.DIRT: true, _D.BlockID.SILT: true, _D.BlockID.MUDDY_SAND: true,
	_D.BlockID.OCEAN_SAND: true, _D.BlockID.TRAIL: true,
	_D.BlockID.OCEAN_FLOOR: true, _D.BlockID.OCEAN_GRAVEL: true, _D.BlockID.OCEAN_MUD: true,
	_D.BlockID.YOUNG_GRASS: true, _D.BlockID.DARK_DIRT: true, _D.BlockID.SAND_DEEP: true,
	_D.BlockID.GRASS_DIRT: true, _D.BlockID.DESERT_PLATEAU: true,
	_D.BlockID.DRY_GRASS: true, _D.BlockID.SPARSE_GRASS: true, _D.BlockID.PALE_SAND: true,
}

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _bd_from(data: Dictionary):
	var bd := _BD.new()
	bd.from_bytes(data["block_data_bytes"], COLS, COLS)
	return bd

## Đếm block đồng quặng trong chunk: solid nằm trên block nền tự nhiên,
## bỏ qua cột dưới nước (rạn STONE), cột bãi đá (STONE_PATCH — đá lộ thiên
## tự nhiên ở đồng bằng, không phải đồi quặng).
func _hill_blocks(bd, masks: Array = []) -> int:
	var count := 0
	for x in range(COLS):
		for z in range(COLS):
			var skip := false
			for m in masks:
				if m.size() > 0 and m[x * COLS + z] != 0:
					skip = true
					break
			if skip:
				continue
			var top_solid := -1
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var b: int = bd.get_block(x, ly, z)
				if b != _D.BlockID.AIR and not _D.is_water(b):
					top_solid = ly
					break
			if top_solid < 0 or top_solid <= 18:
				continue  # cột rỗng hoặc dưới mực nước (WATER_Y=0.5 → layer ≤ 18)
			for ly in range(top_solid, -1, -1):
				var b: int = bd.get_block(x, ly, z)
				if NATURAL_TOPS.has(b):
					break
				count += 1
	return count

## Đếm block quặng + kiểm tra quặng nào nằm ở đỉnh cột (lộ mặt).
func _ore_stats(bd) -> Array:
	var total := 0
	var bad_type := 0
	var buried := 0
	for x in range(COLS):
		for z in range(COLS):
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var b: int = bd.get_block(x, ly, z)
				if b == _D.BlockID.AIR or _D.is_water(b):
					continue
				if b >= _D.BlockID.COPPER_ORE and b <= _D.BlockID.COAL_ORE and _D.is_pickaxable(b):
					total += 1
					if not ALLOWED_ORES.has(b):
						bad_type += 1
					if ly < _top_solid_of(bd, x, z):
						buried += 1
				break
	return [total, bad_type, buried]

func _top_solid_of(bd, x: int, z: int) -> int:
	for ly in range(_BD.CHUNK_H - 1, -1, -1):
		var b: int = bd.get_block(x, ly, z)
		if b != _D.BlockID.AIR and not _D.is_water(b):
			return ly
	return -1

func _hint_matches(bd, hint: PackedInt32Array) -> bool:
	for x in range(COLS):
		for z in range(COLS):
			var top := _top_solid_of(bd, x, z)
			if hint[x * COLS + z] != top:
				return false
	return true

func _ready() -> void:
	# WorldSeed tự randomize mỗi process → ghim seed cố định để terrain ổn định
	WorldSeed.seed_value = 20260805
	seed(20260805)

	# ── 1. Gần spawn: không quặng nào nằm trong ORE_HILL_MIN_DIST (=100) ──
	# Quét cửa sổ ±3 chunk (đủ phủ bán kính 100): quặng trên đỉnh núi đá
	# (mountain STONE_PATCH) chỉ xuất hiện ở cột cách spawn ≥ 100 (seen qua
	# _stone_patch_top), nên phải so theo từng cột theo bán kính thật.
	var near_ore := 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var data := _W.compute_chunk(dx, dz, SIZE, RW)
			var bd = _bd_from(data)
			for x in range(COLS):
				for z in range(COLS):
					var wx: float = float(dx * SIZE + x)
					var wz: float = float(dz * SIZE + z)
					if sqrt(wx * wx + wz * wz) >= 100.0:
						continue  # ngoài vùng an toàn spawn
					for ly in range(_BD.CHUNK_H - 1, -1, -1):
						var b: int = bd.get_block(x, ly, z)
						if b == _D.BlockID.AIR or _D.is_water(b):
							break
						if b >= _D.BlockID.COPPER_ORE and b <= _D.BlockID.COAL_ORE and _D.is_pickaxable(b):
							near_ore += 1
						break
	_check(near_ore == 0, "gần spawn: 0 quặng trong bán kính %d (got %d)" % [100, near_ore])

	# ── 2. Chunk xa spawn ──────────────────────────────────────────────────
	# Danh sách ghim theo seed 20260805: đồng bằng (GRASS_DIRT) + không-đồng-bằng
	var far_coords := [
		Vector2i(-3, 4), Vector2i(-3, 7), Vector2i(-5, 6), Vector2i(-6, 5),
		Vector2i(-7, 6), Vector2i(0, 5), Vector2i(-5, -2), Vector2i(-2, 7),
		Vector2i(4, 8), Vector2i(22, -9), Vector2i(31, 20), Vector2i(8, -4),
		Vector2i(12, -8), Vector2i(10, 3), Vector2i(-9, 5), Vector2i(9, 9),
		Vector2i(6, -14), Vector2i(13, 13), Vector2i(-15, 9), Vector2i(16, -5),
		Vector2i(17, 7), Vector2i(5, -16), Vector2i(18, 12), Vector2i(19, 1),
	]
	var hills_found := 0
	var plains_hills := 0
	var plains_ore_bad := 0
	var plains_iron := 0
	var plains_ore_total := 0
	var non_plains_non_coal_hills := 0
	var total_hill_blocks := 0
	var total_ore_blocks := 0
	var bad_type := 0
	var buried := 0
	var hint_mismatch := 0
	var surface_ore_missing := 0  # quặng lộ mặt (núi/đồng) nhưng thiếu overlay mesh
	var surface_ore_total := 0  # tổng block quặng lộ mặt
	for c in far_coords:
		var data := _W.compute_chunk(c.x, c.y, SIZE, RW)
		var bd = _bd_from(data)
		if not _hint_matches(bd, data["top_ly_hint"]):
			hint_mismatch += 1
		# Mọi quặng LỘ MẶT (layer == top_ly_hint) phải có textured overlay mesh,
		# kể cả khi chunk không có đồi (đỉnh núi STONE_PATCH sinh quặng trực tiếp).
		for x in range(COLS):
			for z in range(COLS):
				var ly: int = data["top_ly_hint"][x * COLS + z]
				if ly < 0:
					continue
				var b: int = bd.get_block(x, ly, z)
				if b >= _D.BlockID.COPPER_ORE and b <= _D.BlockID.COAL_ORE and _D.is_pickaxable(b):
					surface_ore_total += 1
					if not (data["textured_block_meshes"] as Dictionary).has(b):
						surface_ore_missing += 1
		var hill := _hill_blocks(bd, [
			data.get("stone_patch_mask", PackedByteArray()),
		])
		var stats := _ore_stats(bd)
		if hill > 0:
			hills_found += 1
			total_hill_blocks += hill
			total_ore_blocks += stats[0]
			bad_type += stats[1]
			buried += stats[2]
			# ── Đồng bằng (GRASS_DIRT) → chỉ than + sắt hiếm ──
			var oi: Dictionary = data.get("ore_hill", {})
			if oi.get("cx", -1) == -1:
				_check(false, "chunk %s: có đồi nhưng thiếu ore_hill info" % c)
			elif oi.get("plains", false):
				plains_hills += 1
				var non_allowed := 0
				var iron := 0
				var ores := 0
				for x in range(COLS):
					for z in range(COLS):
						for ly in range(_BD.CHUNK_H - 1, -1, -1):
							var b: int = bd.get_block(x, ly, z)
							if b == _D.BlockID.AIR or _D.is_water(b):
								continue
							if b >= _D.BlockID.COPPER_ORE and b <= _D.BlockID.COAL_ORE and _D.is_pickaxable(b):
								ores += 1
								if b == _D.BlockID.IRON_ORE:
									iron += 1
								elif b != _D.BlockID.COAL_ORE:
									non_allowed += 1
							break
				plains_ore_total += ores
				plains_iron += iron
				if non_allowed > 0:
					plains_ore_bad += 1
					_check(false, "chunk %s: đồng bằng có %d quặng không phải than/sắt" % [c, non_allowed])
			else:
				var has_non_coal := false
				for x in range(COLS):
					for z in range(COLS):
						for ly in range(_BD.CHUNK_H - 1, -1, -1):
							var b: int = bd.get_block(x, ly, z)
							if b == _D.BlockID.AIR or _D.is_water(b):
								continue
							if b >= _D.BlockID.COPPER_ORE and b <= _D.BlockID.COAL_ORE and _D.is_pickaxable(b):
								if b != _D.BlockID.COAL_ORE:
									has_non_coal = true
							break
				if has_non_coal:
					non_plains_non_coal_hills += 1
			if hill < 4 or hill > 12:
				_check(false, "chunk %s: đồi %d block (cần 4~12)" % [c, hill])
			else:
				_check(true, "chunk %s: đồi %d block (4~12)" % [c, hill])
	_check(hills_found >= 2, "có ≥2 chunk xa có đồi (thực tế %d)" % hills_found)
	_check(plains_hills >= 1, "có ≥1 đồi ở đồng bằng (thực tế %d)" % plains_hills)
	_check(plains_ore_bad == 0, "đồng bằng: không quặng ngoài than/sắt (vi phạm=%d)" % plains_ore_bad)
	_check(plains_ore_total > 0, "đồng bằng: có quặng trong đồi (got %d)" % plains_ore_total)
	_check(plains_iron <= plains_ore_total * 3 / 10,
		"đồng bằng: sắt hiếm ≤30%% quặng (%d/%d)" % [plains_iron, plains_ore_total])
	_check(non_plains_non_coal_hills >= 1,
		"có ≥1 đồi không-đồng-bằng có quặng khác than (got %d)" % non_plains_non_coal_hills)
	_check(hint_mismatch == 0, "hint == fullscan ở mọi chunk xa (mismatch=%d)" % hint_mismatch)
	_check(bad_type == 0, "mọi quặng thuộc than/sắt/đồng/nhôm (bad=%d)" % bad_type)
	_check(buried == 0, "mọi quặng lộ trên mặt đồi (buried=%d)" % buried)
	_check(surface_ore_missing == 0,
		"quặng lộ mặt luôn có texture overlay (missing=%d/%d)" % [surface_ore_missing, surface_ore_total])
	_check(total_ore_blocks >= 2, "tổng quặng trong đồi ≥ 2 (got %d)" % total_ore_blocks)
	# ── Đồng bằng tỷ lệ thấp hơn — kiểm tra qua hằng số ─────────────────────
	_check(_T.ORE_HILL_PLAINS_CHANCE < _T.ORE_HILL_CHANCE,
		"plains chance (%d%%) < thường (%d%%)" % [_T.ORE_HILL_PLAINS_CHANCE, _T.ORE_HILL_CHANCE])

	# ── 3. Deterministic ───────────────────────────────────────────────────
	var d1 := _W.compute_chunk(5, 5, SIZE, RW)
	var d2 := _W.compute_chunk(5, 5, SIZE, RW)
	_check(d1["block_data_bytes"] == d2["block_data_bytes"],
		"compute 2 lần cùng chunk → block data giống hệt")
	_check(d1["top_ly_hint"] == d2["top_ly_hint"], "hint giống hệt giữa 2 lần compute")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
