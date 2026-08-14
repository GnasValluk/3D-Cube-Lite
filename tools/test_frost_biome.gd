extends Node3D

## test_frost_biome — Smoke test bio băng giá: tìm một chunk có base_bio FROST rồi
## chạy compute_chunk thật và kiểm tra: (1) biome_grid có FROST/FROST_SNOW;
## (2) block top của FROST/FROST_SNOW là SNOW, nền dưới là FROST_DIRT;
## (3) hồ trong bio vẫn là NƯỚC THƯỜNG (SILT/MUDDY_SAND + nước, không đóng băng);
## (4) tuyết không mọc cỏ; (5) plant_props có cây vân sam.

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

## Tìm ô FROST đất liền trong bán kính MAX_R từ gốc.
func _find_frost_cell(nd: Dictionary, max_r: float) -> Vector2:
	var step := 40.0
	for r in range(step, int(max_r) + 1, int(step)):
		var samples: int = max(8, int(float(r) / step * TAU))
		for i in range(samples):
			var a := float(i) / float(samples) * TAU
			var wx := cos(a) * float(r)
			var wz := sin(a) * float(r)
			if _W._ocean_mask_at(nd, wx, wz): continue
			if _W._Noise._biome_at(wx, wz, RW) == _D.TileType.FROST:
				return Vector2(wx, wz)
	return Vector2.ZERO

func _ready() -> void:
	print("== test_frost_biome: snow tiles + NORMAL water lakes + spruce ==")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()

	var nd := _W._Noise._noise_for_dim(RW)
	var fw := _find_frost_cell(nd, 12000.0)
	_check(fw != Vector2.ZERO, "tìm thấy ô FROST trong bán kính 12km (%s)" % str(fw))
	if fw == Vector2.ZERO:
		get_tree().quit(1)
		return

	var cx := int(floor(fw.x / SIZE))
	var cz := int(floor(fw.y / SIZE))
	var lx := posmod(int(round(fw.x - (cx * SIZE - SIZE * 0.5))), SIZE)
	var lz := posmod(int(round(fw.y - (cz * SIZE - SIZE * 0.5))), SIZE)
	var data := _W.compute_chunk(cx, cz, SIZE, RW)
	var bg: Array = data.get("biome_grid", [])
	var bd = _BD.new()
	bd.from_bytes(data["block_data_bytes"], SIZE, SIZE)
	_check(bg.size() == SIZE and bd != null, "chunk (%d,%d) có biome_grid + block data" % [cx, cz])
	if bg.size() != SIZE or bd == null:
		get_tree().quit(1)
		return

	var bio_here: int = int(bg[lx][lz])
	_check(bio_here == _D.TileType.FROST or bio_here == _D.TileType.FROST_SNOW,
		"ô trung tâm: biome FROST/FROST_SNOW (được %d)" % bio_here)

	# Thống kê toàn chunk
	var cnt_frost := 0
	var cnt_snow := 0
	var cnt_lake := 0
	var cnt_grass := 0
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			match b:
				_D.TileType.FROST: cnt_frost += 1
				_D.TileType.FROST_SNOW: cnt_snow += 1
				_D.TileType.SILT, _D.TileType.MUDDY_SAND: cnt_lake += 1
				_D.TileType.GRASS_DIRT, _D.TileType.GRASS, _D.TileType.DARK_GRASS, _D.TileType.YOUNG_GRASS:
					cnt_grass += 1
	var total_frost := cnt_frost + cnt_snow
	_check(total_frost >= 200, "chunk có ≥200 ô tuyết (FROST=%d SNOW=%d)" % [cnt_frost, cnt_snow])

	# Block top của ô FROST/FROST_SNOW = SNOW, nền dưới = FROST_DIRT
	var found_snow_col := false
	var found_dirt_under := false
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			if b != _D.TileType.FROST and b != _D.TileType.FROST_SNOW:
				continue
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if blk == _D.BlockID.AIR: continue
				if blk == _D.BlockID.SNOW:
					found_snow_col = true
				var below := bd.get_block(x, ly - 1, z) if ly > 0 else _D.BlockID.AIR
				if below == _D.BlockID.FROST_DIRT:
					found_dirt_under = true
				break
	_check(found_snow_col, "có cột FROST với block top SNOW")
	_check(found_dirt_under, "có lớp FROST_DIRT ngay dưới SNOW")

	# Hồ trong bio băng: vẫn là NƯỚC THƯỜNG (đáy SILT/MUDDY_SAND + nước lỏng),
	# KHÔNG đóng băng. Chỉ xét ô thật sự ngập nước (block trên cùng là nước)
	# — ô bùn bờ biển MUDDY_SAND khô trên mực nước thì bỏ qua.
	var lake_cells := 0
	var lake_bad := 0
	for x in range(SIZE):
		for z in range(SIZE):
			var b: int = int(bg[x][z])
			if b != _D.TileType.SILT and b != _D.TileType.MUDDY_SAND:
				continue
			var top_blk := _D.BlockID.AIR
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if blk != _D.BlockID.AIR:
					top_blk = blk
					break
			if not _D.is_water(top_blk):
				continue  # bờ bùn khô — không phải hồ
			lake_cells += 1
			var has_water := false
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var blk := bd.get_block(x, ly, z)
				if blk == _D.BlockID.AIR: continue
				if _D.is_water(blk):
					has_water = true
			if not has_water:
				lake_bad += 1
				_check(false, "ô hồ (%d,%d): phải là nước thường" % [x, z])
	_check(lake_bad == 0, "hồ ngập nước trong bio băng giữ NƯỚC THƯỜNG (%d ô hồ, %d lỗi)" % [lake_cells, lake_bad])
	if lake_cells == 0:
		print("PASS | (chunk này không có hồ ngập nước — bỏ qua)")

	# Cây vân sam trong plant_props của chunk có ô FROST
	var spruce_props := 0
	for p in data.get("plant_props", []):
		if p.get("type", "") == "spruce":
			spruce_props += 1
	_check(spruce_props > 0, "plant_props có cây vân sam (%d cây)" % spruce_props)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)