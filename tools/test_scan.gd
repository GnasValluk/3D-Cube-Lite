extends Node

## Headless verification test cho các tối ưu get_block:
## 1. top_ly_hint (từ height grid) == full scan block_data
## 2. Terrain mesh build với hint == build không hint (vertex count)
## 3. Water mesh bounded scan (max_ly=18) == full scan (69 layers)
## 4. _update_top_ly_cache đúng cho các case đào/đặt
## 5. rebuild_mesh(at) trên chunk thật — không crash, cache nhất quán

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _T = preload("res://scripts/world/chunk/chunk_terrain.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD
const TW := _D._Dim.DimensionID.TWILIGHT

var _failures: int = 0
var _log_path := "user://test_scan_log.txt"

func _log(msg: String) -> void:
	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f:
		f.store_line(msg)
		f.close()

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS | %s" % label)
		print("PASS | %s" % label)
	else:
		_failures += 1
		_log("FAIL | %s" % label)
		printerr("FAIL | %s" % label)

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_log("START")

	# ── 1+2. Hint correctness + mesh equality trên nhiều chunk ─────────────
	var coords := [Vector2i(0, 0), Vector2i(1, 0)]
	for dim in [RW, TW]:
		for c in coords:
			_log("STEP compute dim=%d chunk=%s" % [dim, c])
			var data := _W.compute_chunk(c.x, c.y, SIZE, dim)
			_log("STEP compute done, building bd")
			var bd := _BD.new()
			bd.from_bytes(data["block_data_bytes"], COLS, COLS)
			var hint: PackedInt32Array = data["top_ly_hint"]
			_check(hint.size() == COLS * COLS,
				"hint size dim=%d chunk=%s" % [dim, c])

			var match_all := true
			var non_empty := 0
			for x in range(COLS):
				for z in range(COLS):
					var top := -1
					for ly in range(_BD.CHUNK_H - 1, -1, -1):
						var blk := bd.get_block(x, ly, z)
						if blk != _D.BlockID.AIR and not _D.is_water(blk):
							top = ly
							break
					if hint[x * COLS + z] != top:
						match_all = false
					if top >= 0:
						non_empty += 1
			_check(match_all,
				"hint==fullscan dim=%d chunk=%s non_empty=%d/1024" % [dim, c, non_empty])

			# Mesh equality: với hint vs không hint
			var st1 := SurfaceTool.new()
			st1.begin(Mesh.PRIMITIVE_TRIANGLES)
			_T.build_terrain_mesh(st1, bd, COLS, dim, hint)
			var m1 := st1.commit()
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			_T.build_terrain_mesh(st2, bd, COLS, dim)
			var m2 := st2.commit()
			var v1: int = m1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() if m1 else 0
			var v2: int = m2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() if m2 else 0
			_check(v1 == v2,
				"terrain mesh hint==nohint dim=%d chunk=%s verts=%d" % [dim, c, v1])

			# ── 3. Water mesh bounded == full scan ─────────────────────────
			var h_vox := _D.VOXEL * 0.5
			var half := SIZE * 0.5
			var w_bounded := _W._build_water_mesh(bd, COLS, dim, h_vox, half, {}, -1)
			var w_full := _W._build_water_mesh(bd, COLS, dim, h_vox, half, {}, _BD.CHUNK_H - 1)
			var vb: int = w_bounded.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() if w_bounded else 0
			var vf: int = w_full.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() if w_full else 0
			_check(vb == vf,
				"water bounded==full dim=%d chunk=%s verts=%d" % [dim, c, vb])

	# ── 4. _update_top_ly_cache ────────────────────────────────────────────
	var chunk := _W.new()
	chunk._cols = COLS
	chunk._size = SIZE
	var bd2 := _BD.new()
	bd2.init(COLS, COLS)
	# Column (5,7): solid từ layer 0..8 (GRASS top), air 9+
	var top_ly: int = 8
	for ly in range(0, top_ly + 1):
		for x in range(COLS):
			for z in range(COLS):
				bd2.set_block(x, ly, z, _D.BlockID.GRASS if ly == top_ly else _D.BlockID.BEDROCK)
	chunk.block_data = bd2
	chunk._top_ly_cache = PackedInt32Array()
	chunk._top_ly_cache.resize(COLS * COLS)
	chunk._top_ly_cache.fill(top_ly)

	var idx := 5 * COLS + 7
	# (a) phá block dưới đỉnh → top không đổi
	bd2.set_block(5, 4, 7, _D.BlockID.AIR)
	chunk._update_top_ly_cache(Vector3i(5, 4, 7))
	_check(chunk._top_ly_cache[idx] == top_ly, "break below top -> unchanged")

	# (b) phá block đỉnh → top giảm xuống 7
	bd2.set_block(5, top_ly, 7, _D.BlockID.AIR)
	chunk._update_top_ly_cache(Vector3i(5, top_ly, 7))
	_check(chunk._top_ly_cache[idx] == top_ly - 1, "break top -> decreased")

	# (c) phá tiếp 3 lớp → top giảm tiếp. Lưu ý: layer 4 đã là AIR từ case (a)
	# → scan phải xuyên qua lỗ hổng layer 4 xuống layer 3. Kỳ vọng = 8 - 5.
	for ly in range(top_ly - 1, top_ly - 4, -1):
		bd2.set_block(5, ly, 7, _D.BlockID.AIR)
		chunk._update_top_ly_cache(Vector3i(5, ly, 7))
	_check(chunk._top_ly_cache[idx] == top_ly - 5,
		"break stack through hole -> top follows (got=%d want=%d)" % [chunk._top_ly_cache[idx], top_ly - 5])

	# (d) đặt solid cao hơn → top tăng
	bd2.set_block(5, 12, 7, _D.BlockID.GRASS)
	chunk._update_top_ly_cache(Vector3i(5, 12, 7))
	_check(chunk._top_ly_cache[idx] == 12, "place above top -> raised")

	# (e) đặt nước cao hơn top → top không đổi
	bd2.set_block(5, 15, 7, _D.BlockID.WATER_SOURCE)
	chunk._update_top_ly_cache(Vector3i(5, 15, 7))
	_check(chunk._top_ly_cache[idx] == 12, "place water above top -> unchanged")

	# (f) phá nước trên top → top vẫn không đổi
	bd2.set_block(5, 15, 7, _D.BlockID.AIR)
	chunk._update_top_ly_cache(Vector3i(5, 15, 7))
	_check(chunk._top_ly_cache[idx] == 12, "break water above top -> unchanged")

	# (g) đặt solid đúng tại top → không đổi
	bd2.set_block(5, 12, 7, _D.BlockID.DARK_GRASS)
	chunk._update_top_ly_cache(Vector3i(5, 12, 7))
	_check(chunk._top_ly_cache[idx] == 12, "replace at top -> unchanged")

	# ── 5. rebuild_mesh(at) trên chunk thật ───────────────────────────────
	var real_chunk := _W.new()
	real_chunk.name = "TestChunk"
	add_child(real_chunk)
	real_chunk.setup(0, 0, SIZE, RW, true)
	_check(real_chunk.block_data != null and real_chunk._top_ly_cache.size() == COLS * COLS,
		"setup sync -> block_data + cache ready")

	if real_chunk.block_data != null:
		# Tìm 1 cột có top >= 1 để đào thử
		var dig_x := -1
		var dig_z := -1
		var dig_top := -1
		for x in range(COLS):
			for z in range(COLS):
				var t := real_chunk._top_ly_cache[x * COLS + z]
				if t >= 2:
					dig_x = x; dig_z = z; dig_top = t
					break
			if dig_x >= 0:
				break
		if dig_x >= 0:
			var local_pos := Vector3i(dig_x, dig_top, dig_z)
			var half_sz := SIZE * 0.5
			var wx := real_chunk.global_position.x - half_sz + (dig_x + 0.5) * _D.VOXEL
			var wy := _BD.layer_to_world_y(dig_top)
			var wz := real_chunk.global_position.z - half_sz + (dig_z + 0.5) * _D.VOXEL
			var removed := real_chunk.break_block_at(wx, wy, wz)
			_check(removed != _D.BlockID.AIR, "dig at (%d,%d,%d) -> removed %d" % [dig_x, dig_top, dig_z, removed])
			_check(real_chunk._top_ly_cache[dig_x * COLS + dig_z] == dig_top - 1,
				"dig -> cache decremented (%d->%d)" % [dig_top, real_chunk._top_ly_cache[dig_x * COLS + dig_z]])
			var placed := real_chunk.place_block_at(wx, wy, wz, _D.BlockID.GRASS)
			_check(placed, "re-place solid -> ok")
			_check(real_chunk._top_ly_cache[dig_x * COLS + dig_z] == dig_top,
				"re-place -> cache restored")
			var wplaced := real_chunk.place_block_at(wx, wy + _D.VOXEL, wz, _D.BlockID.WATER_SOURCE)
			_check(wplaced, "place water above -> ok")
			_check(real_chunk._top_ly_cache[dig_x * COLS + dig_z] == dig_top,
				"water above -> cache unchanged")
		else:
			printerr("WARN | no column with top>=2 to dig")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	print("TEST_TIME_MS=%d" % (Time.get_ticks_msec() - t0))
	get_tree().quit(0 if _failures == 0 else 1)
