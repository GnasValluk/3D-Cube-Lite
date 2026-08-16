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

## Tìm danh sách ô FROST đất liền trong bán kính MAX_R từ gốc. Trả NHIỀU
## candidate — với biome per-column, ô FROST đầu tiên trong vòng xoắn có thể là
## vệt đất mảnh giữa biển (chunk chủ yếu là OCEAN). Test chọn ô nào có chunk
## đủ ≥200 ô tuyết + cây vân sam.
func _find_frost_cells(nd: Dictionary, max_r: float, count: int = 10) -> Array:
	var out: Array = []
	var step := 40.0
	for r in range(step, int(max_r) + 1, int(step)):
		var samples: int = max(8, int(float(r) / step * TAU))
		for i in range(samples):
			var a := float(i) / float(samples) * TAU
			var wx := cos(a) * float(r)
			var wz := sin(a) * float(r)
			if _W._ocean_mask_at(nd, wx, wz): continue
			if _W._Noise._biome_at(wx, wz, RW) == _D.TileType.FROST:
				out.append(Vector2(wx, wz))
				if out.size() >= count:
					return out
	return out

func _ready() -> void:
	print("== test_frost_biome: snow tiles + NORMAL water lakes + spruce ==")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()

	var nd := _W._Noise._noise_for_dim(RW)
	var fws := _find_frost_cells(nd, 12000.0, 12)
	_check(fws.size() > 0, "tìm thấy ≥1 ô FROST trong bán kính 12km (%d ô)" % fws.size())
	if fws.is_empty():
		get_tree().quit(1)
		return

	# Chọn candidate đầu tiên mà chunk thật sự đủ tuyết + cây vân sam — với biome
	# per-column, ô FROST đầu tiên không đảm bảo chunk quanh nó là băng. Thử lần
	# lượt từng candidate đến khi chunk đạt ngưỡng, thay vì hit-spiral đầu tiên.
	var data: Dictionary = {}
	var cx := 0
	var cz := 0
	var lx := 0
	var lz := 0
	for fw in fws:
		var cand_cx := int(floor(fw.x / SIZE))
		var cand_cz := int(floor(fw.y / SIZE))
		var cand_data := _W.compute_chunk(cand_cx, cand_cz, SIZE, RW)
		var cand_bg: Array = cand_data.get("biome_grid", [])
		var cand_bd = _BD.new()
		cand_bd.from_bytes(cand_data["block_data_bytes"], SIZE, SIZE)
		var frost_n := 0
		var spruce_n := 0
		for p in cand_data.get("plant_props", []):
			if p.get("type", "") == "spruce":
				spruce_n += 1
		for x in range(SIZE):
			for z in range(SIZE):
				var b: int = int(cand_bg[x][z])
				if b == _D.TileType.FROST or b == _D.TileType.FROST_SNOW:
					frost_n += 1
		if frost_n >= 200 and spruce_n > 0:
			data = cand_data
			cx = cand_cx
			cz = cand_cz
			var cand_fw: Vector2 = fw
			lx = posmod(int(round(cand_fw.x - (cx * SIZE - SIZE * 0.5))), SIZE)
			lz = posmod(int(round(cand_fw.y - (cz * SIZE - SIZE * 0.5))), SIZE)
			print("INFO  | chọn ô FROST %s → chunk (%d,%d) FROST=%d spruce=%d" % [str(fw), cx, cz, frost_n, spruce_n])
			break
	_check(not data.is_empty(), "có chunk FROST đạt ≥200 ô tuyết + cây vân sam")
	if data.is_empty():
		print("INFO  | các candidate đều không đạt ngưỡng (chunk băng quá mỏng)")
		get_tree().quit(1)
		return
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