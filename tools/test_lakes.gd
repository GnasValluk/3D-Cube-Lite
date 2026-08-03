extends Node3D

## test_lakes — Hồ nội địa (hồ spawn): đồng cỏ DARK_GRASS sâu trong lục địa
## phải có hồ nước thật, không chỉ đầm ngập ven biển / hồ cát sa mạc.
## Quy tắc thật trong world_chunk._generate_base: DARK_GRASS + lake_val>0.68
## + cách biển >40 ô → SILT/MUDDY_SAND, đáy sâu hơn WATER_Y.
## Chạy qua tools/test_lakes.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")

const SEEDS := [20260804, 20260805, 123456789, 777]
const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const HALF := 1200.0
const STEP := 4.0
const LAKE_T := 0.68
const MIN_LAKE_CELLS := 150
const NEAR_SPAWN := 600.0

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

## Quét lưới thô mô phỏng quy tắc hồ DARK_GRASS; trả
## {"cells": int, "nearest": float (khoảng cách hồ gần gốc nhất, INF nếu thiếu),
##  "nearest_pos": Vector2 (vị trí hồ gần nhất)}
func _scan_lakes(nd: Dictionary) -> Dictionary:
	var n_lake: FastNoiseLite = nd["lake"]
	var size := int(HALF * 2.0 / STEP)
	var od := PackedInt32Array()
	od.resize(size * size)
	od.fill(-1)
	var queue: Array[Vector2i] = []
	for ix in range(size):
		for iz in range(size):
			var wx: float = -HALF + float(ix) * STEP + 0.5
			var wz: float = -HALF + float(iz) * STEP + 0.5
			if _W._ocean_mask_at(nd, wx, wz):
				od[ix * size + iz] = 0
				queue.append(Vector2i(ix, iz))
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]; head += 1
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= size or n.y < 0 or n.y >= size: continue
			if od[n.x * size + n.y] >= 0: continue
			od[n.x * size + n.y] = od[c.x * size + c.y] + 1
			queue.append(n)
	var cells := 0
	var nearest := INF
	var nearest_pos := Vector2.ZERO
	var nearest_core := INF
	var nearest_core_pos := Vector2.ZERO
	for ix in range(size):
		for iz in range(size):
			var wx: float = -HALF + float(ix) * STEP + 0.5
			var wz: float = -HALF + float(iz) * STEP + 0.5
			var odv: int = od[ix * size + iz]
			if odv >= 0 and odv <= 40: continue
			if _W._Noise._biome_at(wx, wz, RW) != _D.TileType.DARK_GRASS: continue
			var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
			if lake_val > LAKE_T:
				cells += 1
				var dist: float = sqrt(wx * wx + wz * wz)
				if dist < nearest:
					nearest = dist
					nearest_pos = Vector2(wx, wz)
				if lake_val > 0.80 and dist < nearest_core:
					nearest_core = dist
					nearest_core_pos = Vector2(wx, wz)
	return { "cells": cells, "nearest": nearest, "nearest_pos": nearest_pos,
			"nearest_core_pos": nearest_core_pos }

func _ready() -> void:
	print("== test_lakes: Hồ nước nội địa (DARK_GRASS) ==")

	# ── 1. Quy tắc thế giới: lục địa sâu phải có hồ DARK_GRASS ─────────────
	print("-- 1. Quét %d seed: hồ DARK_GRASS trong bán kính %d block --" % [SEEDS.size(), int(HALF)])
	for s in SEEDS:
		WorldSeed.seed_value = s
		_W._Noise.clear_cache()
		var nd := _W._Noise._noise_for_dim(RW)
		var res: Dictionary = _scan_lakes(nd)
		_check(int(res["cells"]) >= MIN_LAKE_CELLS,
			"seed %d: %d ô hồ DARK_GRASS nội địa (≥%d)" % [s, int(res["cells"]), MIN_LAKE_CELLS])
		_check(float(res["nearest"]) <= NEAR_SPAWN,
			"seed %d: có hồ gần spawn ≤ %.0f block (gần nhất %.0f)" % [s, NEAR_SPAWN, float(res["nearest"])])

	# ── 2. Pipeline thật: chunk chứa hồ → biome hồ + nước thật ─────────────
	print("-- 2. Pipeline thật: hồ qua compute_chunk (seed 20260805) --")
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	var nd2 := _W._Noise._noise_for_dim(RW)
	var res2: Dictionary = _scan_lakes(nd2)
	# Dùng hồ "core" (lake_val > 0.80) — đủ biên để ô pipeline ±1 lệch không tụt
	# dưới ngưỡng 0.74; đồng thời xa bờ (od > 40 trong scan) nên chắc chắn qua
	# điều kiện trong world_chunk.
	var fw: Vector2 = res2.get("nearest_core_pos", Vector2.ZERO)
	if fw == Vector2.ZERO:
		# dự phòng: tìm hồ core qua quét cục bộ
		var best_d2 := INF
		var size := int(HALF * 2.0 / STEP)
		for ix in range(size):
			for iz in range(size):
				var wx: float = -HALF + float(ix) * STEP + 0.5
				var wz: float = -HALF + float(iz) * STEP + 0.5
				var d2: float = wx * wx + wz * wz
				if d2 >= best_d2: continue
				var n_lake: FastNoiseLite = nd2["lake"]
				var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
				if lake_val <= 0.80: continue
				if _W._Noise._biome_at(wx, wz, RW) != _D.TileType.DARK_GRASS: continue
				if _W._ocean_mask_at(nd2, wx, wz): continue
				best_d2 = d2
				fw = Vector2(wx, wz)
	var cx := int(floor(fw.x / SIZE))
	var cz := int(floor(fw.y / SIZE))
	_check(fw != Vector2.ZERO, "tìm thấy ô hồ DARK_GRASS gần spawn")
	if fw == Vector2.ZERO:
		get_tree().quit(1)
		return
	var lx := clampi(int(round(fw.x - (cx * SIZE - 15.5))), 0, SIZE - 1)
	var lz := clampi(int(round(fw.y - (cz * SIZE - 15.5))), 0, SIZE - 1)
	var data := _W.compute_chunk(cx, cz, SIZE, RW)
	var bg: Array = data.get("biome_grid", [])
	var bd = _BD.new()
	bd.from_bytes(data["block_data_bytes"], SIZE, SIZE)
	_check(bg.size() == SIZE and bd != null,
		"chunk (%d,%d) có biome_grid + block data" % [cx, cz])
	if bg.size() != SIZE or bd == null:
		get_tree().quit(1)
		return
	var bio: int = int(bg[lx][lz])
	_check(bio == _D.TileType.SILT or bio == _D.TileType.MUDDY_SAND,
		"ô hồ (%d,%d): biome SILT/MUDDY_SAND (được %d)" % [lx, lz, bio])
	var water_layers := 0
	var solid_below := true
	var floor_ly := -1
	var floor_b := -1
	for ly in range(_BD.CHUNK_H - 1, -1, -1):
		var b: int = bd.get_block(lx, ly, lz)
		if b == _D.BlockID.AIR:
			continue
		if _D.is_water(b):
			water_layers += 1
		elif floor_ly == -1:
			floor_ly = ly
			floor_b = b
	_check(floor_ly >= 0 and (floor_b == _D.BlockID.SILT or floor_b == _D.BlockID.MUDDY_SAND),
		"ô hồ: block đáy = SILT/MUDDY_SAND (được %d ở layer %d)" % [floor_b, floor_ly])
	var below_b: int = _D.BlockID.AIR
	if floor_ly > 0:
		below_b = bd.get_block(lx, floor_ly - 1, lz)
	_check(floor_ly <= 0 or (below_b != _D.BlockID.AIR and not _D.is_water(below_b)),
		"ô hồ: nền dưới đáy solid (được %d)" % below_b)
	_check(water_layers >= 1, "ô hồ: có %d lớp nước phía trên đáy (≥1)" % water_layers)
	var dry_land := 0
	for nx in range(SIZE):
		for nz in range(SIZE):
			for ly in range(_BD.CHUNK_H - 1, -1, -1):
				var b: int = bd.get_block(nx, ly, nz)
				if b != _D.BlockID.AIR and not _D.is_water(b):
					if b == _D.BlockID.DARK_GRASS or b == _D.BlockID.DIRT:
						dry_land += 1
					break
	_check(dry_land >= 50, "hồ nằm giữa đất khô (chunk có %d cột DARK_GRASS/DIRT)" % dry_land)

	# ── 2.5. Đáy hồ thoải: bước chênh ≤ 1.0 block giữa 2 ô kề (bờ → đáy) ──────
	# Regression: trước đây hồ DARK_GRASS đào đáy theo lake_val → bờ dựng
	# đứng ~1.5 block; giờ đáy thoải 0.5/ô theo khoảng cách từ bờ (BFS).
	var is_lake_b: Callable = func(c: Vector2i) -> bool:
		var b: int = int(bg[c.x][c.y])
		return b == _D.TileType.SILT or b == _D.TileType.MUDDY_SAND
	var floor_map: Dictionary = {}
	for c2 in [Vector2i(lx, lz), Vector2i(lx, lz - 1), Vector2i(lx, lz + 1)]:
		if c2.x < 0 or c2.x >= SIZE or c2.y < 0 or c2.y >= SIZE: continue
		for ly in range(_BD.CHUNK_H - 1, -1, -1):
			var b: int = bd.get_block(c2.x, ly, c2.y)
			if b != _D.BlockID.AIR and not _D.is_water(b):
				floor_map[c2] = ly
				break
	var walk := Vector2i(lx, lz)
	var max_step := 0.0
	var last_lake_fl := -999
	while walk.x >= 0 and walk.x < SIZE and is_lake_b.call(walk):
		var fl := -999
		for ly in range(_BD.CHUNK_H - 1, -1, -1):
			var b: int = bd.get_block(walk.x, ly, walk.y)
			if b != _D.BlockID.AIR and not _D.is_water(b):
				fl = ly
				break
		if floor_map.has(walk):
			max_step = maxf(max_step, absf(float(floor_map[walk] - fl)) * _BD.SLAB_HEIGHT)
		else:
			floor_map[walk] = fl
		last_lake_fl = fl
		walk = Vector2i(walk.x + 1, walk.y)
	if walk.x < SIZE and walk.x >= 0:
		for ly in range(_BD.CHUNK_H - 1, -1, -1):
			var b: int = bd.get_block(walk.x, ly, walk.y)
			if b != _D.BlockID.AIR and not _D.is_water(b):
				max_step = maxf(max_step, absf(float(last_lake_fl - ly)) * _BD.SLAB_HEIGHT)
				break
	_check(max_step <= 1.0, "đáy hồ thoải từ bờ: bước chênh max %.1f block (≤1.0)" % max_step)

	# ── 3. Môn ngọt (taro): CẤM ở sa mạc, vẫn mọc ở hồ đồng cỏ ─────────────
	# Regression 2026-08-02: trước đây vùng sa mạc phát hiện bằng cửa sổ 7x7
	# cục bộ → hồ sa mạc nằm sát biên chunk lọt lưới. Giờ dùng desert mask
	# theo base_bio (đúng vùng, không lệ thuộc biên chunk).
	print("-- 3. Môn ngọt: không spawn ở sa mạc --")
	var nd3: Dictionary = _W._Noise._noise_for_dim(RW)
	var n_lake3: FastNoiseLite = nd3["lake"]
	var desert_chunks: Array = []
	var grass_chunks: Array = []
	for x in range(-1600, 1601, 32):
		for z in range(-1600, 1601, 32):
			var wxc: float = float(x) + 0.5
			var wzc: float = float(z) + 0.5
			if _W._ocean_mask_at(nd3, wxc, wzc): continue
			var bb: int = _W._Noise._biome_at(wxc, wzc, RW)
			var lv: float = (n_lake3.get_noise_2d(wxc, wzc) + 1.0) * 0.5
			if lv <= 0.72: continue
			var k := Vector2i(int(floor(wxc / SIZE)), int(floor(wzc / SIZE)))
			if bb == _D.TileType.DESERT:
				if not desert_chunks.has(k) and desert_chunks.size() < 3:
					desert_chunks.append(k)
			else:
				if not grass_chunks.has(k) and grass_chunks.size() < 3:
					grass_chunks.append(k)
	_check(not desert_chunks.is_empty(), "tìm thấy chunk hồ sa mạc (r<1600): %s" % str(desert_chunks))
	_check(not grass_chunks.is_empty(), "tìm thấy chunk hồ đồng cỏ (r<1600): %s" % str(grass_chunks))
	var taro_desert_bad := 0
	var taro_grass := 0
	for k in desert_chunks:
		var data3 := _W.compute_chunk(k.x, k.y, SIZE, RW)
		var bg3: Array = data3.get("biome_grid", [])
		var props3: Array = data3.get("plant_props", [])
		for p in props3:
			if p.get("type", "") != "taro": continue
			var ppos: Vector3 = p.get("pos", Vector3.ZERO)
			var lx3: int = int(floor(ppos.x + SIZE * 0.5))
			var lz3: int = int(floor(ppos.z + SIZE * 0.5))
			if lx3 < 0 or lx3 >= SIZE or lz3 < 0 or lz3 >= SIZE: continue
			# Ô thuộc vùng sa mạc (base_bio) hoặc có đất sa mạc trong 3 ô → cấm
			var wcc3 := Vector2(float(k.x) * SIZE - SIZE * 0.5 + lx3 + 0.5,
				float(k.y) * SIZE - SIZE * 0.5 + lz3 + 0.5)
			if _W._Noise._biome_at(wcc3.x, wcc3.y, RW) == _D.TileType.DESERT:
				taro_desert_bad += 1
				continue
			var found_desert_land := false
			for dx in range(-3, 4):
				for dz in range(-3, 4):
					var nx := lx3 + dx; var nz := lz3 + dz
					if nx < 0 or nx >= SIZE or nz < 0 or nz >= SIZE: continue
					if int(bg3[nx][nz]) == _D.TileType.DESERT:
						found_desert_land = true
						break
				if found_desert_land: break
			if found_desert_land:
				taro_desert_bad += 1
	_check(taro_desert_bad == 0, "hồ sa mạc: 0 cây môn ngọt ở ô sa mạc (có %d)" % taro_desert_bad)
	for k in grass_chunks:
		var data3 := _W.compute_chunk(k.x, k.y, SIZE, RW)
		var props3: Array = data3.get("plant_props", [])
		for p in props3:
			if p.get("type", "") != "taro": continue
			taro_grass += 1
	_check(taro_grass > 0, "hồ đồng cỏ: môn ngọt vẫn mọc (%d cây)" % taro_grass)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
