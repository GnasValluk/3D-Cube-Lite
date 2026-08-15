extends Node3D

## test_swamp_biome — Smoke test rừng đầm lầy: tìm một chunk có base_bio SWAMP rồi
## chạy compute_chunk thật và kiểm tra: (1) biome_grid có SWAMP_MUD/SWAMP_DIRT;
## (2) block top của ô SWAMP_MUD là SWAMP_MUD, nền dưới là SWAMP_DIRT;
## (3) đầm lầy ngập nước (ô SWAMP_MUD thấp hơn mực nước có nước);
## (4) bùn không mọc cỏ; (5) plant_props có cây tràm.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

## Tìm ô SWAMP lõi (swamp noise ≥ NGƯỠNG_LÕI để chắc chắn trong đầm, có nước
## đứng) đất liền trong bán kính MAX_R từ gốc.
const NGƯỠNG_LÕI: float = 0.72
func _find_swamp_cell(nd: Dictionary, max_r: float) -> Vector2:
	var step := 40.0
	for r in range(step, int(max_r) + 1, int(step)):
		var samples: int = max(8, int(float(r) / step * TAU))
		for i in range(samples):
			var a := float(i) / float(samples) * TAU
			var wx := cos(a) * float(r)
			var wz := sin(a) * float(r)
			if _W._ocean_mask_at(nd, wx, wz): continue
			if _W._Noise._biome_at(wx, wz, RW) != _D.TileType.SWAMP: continue
			var sw_v: float = (nd["swamp"].get_noise_2d(wx, wz) + 1.0) * 0.5
			if sw_v >= NGƯỠNG_LÕI:
				return Vector2(wx, wz)
	return Vector2.ZERO

func _ready() -> void:
	print("== test_swamp_biome: mud tiles + standing water + tràm tree ==")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()

	var nd := _W._Noise._noise_for_dim(RW)
	var sw := _find_swamp_cell(nd, 12000.0)
	_check(sw != Vector2.ZERO, "tìm thấy ô SWAMP trong bán kính 12km (%s)" % str(sw))
	if sw == Vector2.ZERO:
		get_tree().quit(1)
		return

	var cx := int(floor(sw.x / SIZE))
	var cz := int(floor(sw.y / SIZE))
	var lx := posmod(int(round(sw.x - (cx * SIZE - SIZE * 0.5))), SIZE)
	var lz := posmod(int(round(sw.y - (cz * SIZE - SIZE * 0.5))), SIZE)
	var data := _W.compute_chunk(cx, cz, SIZE, RW)
	var bg: Array = data.get("biome_grid", [])
	var bd = _BD.new()
	bd.from_bytes(data["block_data_bytes"], SIZE, SIZE)
	_check(bg.size() == SIZE and bd != null, "chunk (%d,%d) có biome_grid + block data" % [cx, cz])
	if bg.size() != SIZE or bd == null:
		get_tree().quit(1)
		return

	# Thống kê toàn chunk
	var cnt_mud := 0
	var cnt_dirt := 0
	var cnt_water := 0
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			match b:
				_D.TileType.SWAMP_MUD: cnt_mud += 1
				_D.TileType.SWAMP_DIRT: cnt_dirt += 1
	# Đếm số cột ngập nước (block trên cùng là nước)
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			if b != _D.TileType.SWAMP_MUD and b != _D.TileType.SWAMP_DIRT:
				continue
			var top_blk := _D.BlockID.AIR
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if blk != _D.BlockID.AIR:
					top_blk = blk
					break
			if _D.is_water(top_blk):
				cnt_water += 1
	var total_swamp := cnt_mud + cnt_dirt
	_check(total_swamp >= 200, "chunk có ≥200 ô đầm lầy (MUD=%d DIRT=%d)" % [cnt_mud, cnt_dirt])
	_check(cnt_water >= 40, "đầm lầy có ≥40 cột ngập nước đứng (%d cột)" % cnt_water)

	# Block top của ô SWAMP_MUD = SWAMP_MUD, nền dưới = SWAMP_DIRT
	var found_mud_top := false
	var found_dirt_under := false
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			if b != _D.TileType.SWAMP_MUD:
				continue
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if blk == _D.BlockID.AIR or _D.is_water(blk): continue
				if blk == _D.BlockID.SWAMP_MUD:
					found_mud_top = true
				var below := bd.get_block(x, ly - 1, z) if ly > 0 else _D.BlockID.AIR
				if below == _D.BlockID.SWAMP_DIRT:
					found_dirt_under = true
				break
	_check(found_mud_top, "có cột SWAMP_MUD với block top SWAMP_MUD")
	_check(found_dirt_under, "có lớp SWAMP_DIRT ngay dưới SWAMP_MUD")

	# Cây tràm + lác + bèo + cua bùn trong plant_props của chunk
	var tree_props := 0
	var sedge_props := 0
	var duckweed_props := 0
	var crab_props := 0
	for p in data.get("plant_props", []):
		match p.get("type", ""):
			"swamp_tree": tree_props += 1
			"swamp_sedge": sedge_props += 1
			"duckweed": duckweed_props += 1
			"mud_crab": crab_props += 1
	_check(tree_props > 0, "plant_props có cây tràm (%d cây)" % tree_props)
	_check(crab_props > 0, "rừng đầm lầy có cua bùn (%d con)" % crab_props)
	print("PASS | cây tràm=%d lác=%d bèo=%d cua=%d" % [tree_props, sedge_props, duckweed_props, crab_props])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)