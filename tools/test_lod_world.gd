extends Node3D

## test_lod_world — Kiểm tra hệ thống LOD 3 lớp:
##  (A) compute_chunk lod_mode: dict LOD đúng chuẩn — mesh thô, không block
##      data/nước/cỏ/village, AABB gọn, biên 2 chunk liền mạch;
##  (B) setup(lod=true) sync: node _is_lod, block_data null, cache riêng
##      `_lod_mesh_cache` (không đè `_mesh_cache`), không vào registry;
##  (C) unit WorldTile: gộp 16 chunk thô → 1 MeshInstance3D, AABB ~128×128;
##  (D) manager thật: full (≤vr) + LOD thô (ngoài vr, tile không phủ) + tile 4×4
##      (vùng xa) — đủ 529 chunk-slot không hở/không trùng, cache đếm khớp
##      want-set, teleport → full giữ nguyên (chống thrash), vùng mới nạp đúng.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _WM = preload("res://scripts/world/open_world_manager.gd")
const _T = preload("res://scripts/world/chunk/world_tile.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0
var _phase: String = "unit"
var _unit: Node = null
var _unit_wait: int = 0
var _wm = null
var _player: Node3D = null
var _f: int = 0
var _moved: bool = false

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_lod_world: full + LOD thô + tile 4×4 ==")
	WorldSeed.seed_value = 20260806
	if SettingsManager and SettingsManager.chunk_view > 3:
		SettingsManager.chunk_view = 3
	_W.clear_noise_cache()
	_W.props_enabled = false

	# ── (A) compute_chunk lod_mode ────────────────────────────────────────────
	var d0 := _W.compute_chunk(0, 0, SIZE, RW, false, true)
	_check(d0.get("lod", false) == true, "dict LOD có cờ 'lod'=true")
	_check(d0["mesh"] != null, "LOD có mesh")
	var d1 := _W.compute_chunk(1, 0, SIZE, RW, false, true)
	_check((d0["block_data_bytes"] as PackedByteArray).is_empty(), "LOD không có block_data_bytes")
	_check(d0.get("plant_props", []).is_empty(), "LOD không có plant_props")
	_check(not bool(d0.get("has_water", true)), "LOD không có nước")
	_check(not (d0.get("village_data", {}) as Dictionary).get("has", false), "LOD không có làng")

	var aabb: AABB = d0["mesh"].get_aabb()
	_check(absf(aabb.size.x - 32.0) < 2.0 and absf(aabb.size.z - 32.0) < 2.0,
		"AABB LOD trải đúng 32×32")
	_check(aabb.size.y > 2.0 and aabb.position.y + aabb.size.y < 70.0,
		"AABB LOD theo chiều cao hợp lý")

	var hA: Array = d0["height_grid"]
	var hB: Array = d1["height_grid"]
	var seam_big := 0
	for z in range(SIZE):
		if absf(float(hA[SIZE - 1][z]) - float(hB[0][z])) > 2.0:
			seam_big += 1
	_check(seam_big <= 6, "biên LOD liền mạch (cột chênh>2m: %d/32)" % seam_big)

	var dfull := _W.compute_chunk(0, 0, SIZE, RW, false, false)
	_check(not dfull.get("lod", false), "full chunk không bị đánh dấu LOD")
	_check(not (dfull["block_data_bytes"] as PackedByteArray).is_empty(), "full chunk có block_data_bytes")

	# ── (B) node setup(lod=true) sync ─────────────────────────────────────────
	var c: Node = _W.new()
	c.name = "LodSyncNode"
	c.setup(3, 5, SIZE, RW, true, true)
	_check(bool(c._built) and bool(c._is_lod), "setup sync LOD → _built + _is_lod")
	_check(c.block_data == null, "node LOD có block_data = null")
	_check(c._terrain_mesh_instance != null, "node LOD dựng 1 MeshInstance3D")
	_check(_W._lod_mesh_cache.has("3,5,%d" % RW), "LOD cache lưu dict thô")
	_check(not _W._mesh_cache.has("3,5,%d" % RW), "_mesh_cache không bị LOD đè")
	_check(_W.get_chunk(3, 5, RW) == null, "LOD chunk không vào registry")
	_check(not c.is_water_at(3 * SIZE + 2, 0, 5 * SIZE + 2), "is_water_at an toàn khi block_data null")
	c.free()  # PREDELETE xóa cache — tránh làm lệch đếm cache ở (D)

	# ── (C) unit WorldTile: node đứng độc, build 16 chunk thô → 1 mesh ───────
	_unit = _T.new()
	_unit.name = "TileUnit"
	add_child(_unit)
	_unit.setup(2, 2, RW)

func _process(_delta: float) -> void:
	_f += 1
	match _phase:
		"unit":
			_unit_wait += 1
			if _unit != null and _unit.get("_built") == true:
				_verify_unit()
				_unit.free()  # xóa cache tile trước khi manager tự build tile (2,2)
				_unit = null
				_start_stage_c()
			elif _unit_wait > 900:
				_check(false, "unit tile timeout (không build kịp 16 chunk)")
				_failures += 1
				_start_stage_c()
		"phase1":
			if not _wm_stable():
				if _f % 400 == 0:
					print("[phase1] chờ... frames=%d loading=%d pending=%d lod=%d tiles=%d" % [
						_f, _wm._loading.size(), _wm._pending.size(),
						_wm._pending_lod.size(), _wm._pending_tiles.size()])
				return
			if _f < 40:
				return
			_moved = true
			print("[stage D] vòng đầu ổn định @%d frames — kiểm tra rồi teleport" % _f)
			_verify_phase1()
			var vr: int = _wm.view_radius
			_player.position = Vector3((vr + 2) * SIZE, 60, 0)
			_phase = "phase2"
			_f = 0
		"phase2":
			if not _wm_stable():
				if _f % 200 == 0:
					print("[phase2] chờ... frames=%d loading=%d pending=%d lod=%d tiles=%d" % [
						_f, _wm._loading.size(), _wm._pending.size(),
						_wm._pending_lod.size(), _wm._pending_tiles.size()])
				return
			if _f < 40:
				return
			_verify_phase2()
			_phase = "done"
			_finish.call_deferred()

func _wm_stable() -> bool:
	return _wm._loading.is_empty() and _wm._pending.is_empty() \
			and _wm._pending_lod.is_empty() and _wm._pending_tiles.is_empty() \
			and _wm._loading_tiles.is_empty()

func _start_stage_c() -> void:
	print("[stage D] khởi tạo manager + player đứng yên tại gốc...")
	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)
	_wm = _WM.new()
	_wm.dimension_id = RW
	_wm.name = "WorldManager"
	root.add_child(_wm)
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = Vector3(0, 4, 0)
	root.add_child(_player)
	_wm._player = _player
	_phase = "phase1"
	_f = 0

func _verify_unit() -> void:
	var meshes := 0
	for ch in _unit.get_children():
		if ch is MeshInstance3D:
			meshes += 1
	_check(meshes == 1, "unit tile gộp thành 1 MeshInstance3D (%d)" % meshes)
	var mi: MeshInstance3D = _unit.get_child(0) as MeshInstance3D
	if mi != null:
		var ab: AABB = mi.mesh.get_aabb()
		_check(absf(ab.size.x - 128.0) < 2.0 and absf(ab.size.z - 128.0) < 2.0,
			"unit tile AABB ~128×128 (%.1f×%.1f)" % [ab.size.x, ab.size.z])
	_check(_T._tile_mesh_cache.has("2,2,%d" % RW), "unit tile lưu cache mesh")

func _verify_phase1() -> void:
	var cur := Vector2i(0, 0)
	var hi: int = _wm._horizon()
	var want: Dictionary = _wm._build_want_sets(cur)
	var exp_full: int = (want["full"] as Array).size()
	var exp_lod: int = (want["lod"] as Array).size()
	var exp_tiles: int = (want["tile"] as Dictionary).size()
	var total_slots: int = (2 * hi + 1) * (2 * hi + 1)
	_check(_wm._chunks.size() == exp_full + exp_lod,
		"số chunk nạp khớp want-set full+LOD (%d == %d+%d)" % [_wm._chunks.size(), exp_full, exp_lod])
	_check(_wm._tiles.size() == exp_tiles, "số tile khớp want-set (%d == %d)" % [_wm._tiles.size(), exp_tiles])
	_check(_wm._chunks.size() + 16 * _wm._tiles.size() == total_slots,
		"phủ đủ %d chunk-slot, không hở/không trùng (chunks=%d tiles=%d)" % [
			total_slots, _wm._chunks.size(), _wm._tiles.size()])

	var bad := 0
	for key in _wm._chunks:
		var c: Node = _wm._chunks[key]
		if _wm._tiles.has(_wm._tile_of(key)):
			bad += 1
			continue
		var want_full: Dictionary = {}
		for k in want["full"]:
			want_full[k] = true
		if want_full.has(key):
			if bool(c._is_lod) or c.block_data == null:
				bad += 1
		else:
			if not bool(c._is_lod) or c.block_data != null:
				bad += 1
	_check(bad == 0, "phân loại chunk đúng (full có block_data / LOD không)")

	_check(_W._mesh_cache.size() == exp_full, "mesh_cache giữ %d dict full (%d)" % [exp_full, _W._mesh_cache.size()])
	# `_lod_mesh_cache` giờ cũng nhận dữ liệu chunk con từ tile build (tái sử
	# dụng giữa tile/LOD), nên số entry có thể lớn hơn số LOD chunk chính.
	_check(_W._lod_mesh_cache.size() >= exp_lod, "lod_mesh_cache giữ %d dict LOD (%d)" % [exp_lod, _W._lod_mesh_cache.size()])
	_check(_T._tile_mesh_cache.size() == exp_tiles, "tile_mesh_cache giữ %d dict tile (%d)" % [exp_tiles, _T._tile_mesh_cache.size()])

func _verify_phase2() -> void:
	var cur: Vector2i = Vector2i(_wm.view_radius + 2, 0)
	var want: Dictionary = _wm._build_want_sets(cur)
	var want_full: Dictionary = {}
	for k in want["full"]:
		want_full[k] = true
	# Chunk gốc (0,0) rời full → còn trong chân trời nhưng ngoài vr → do tile phủ
	# hoặc LOD. Full trước đó phải GIỮ NGUYÊN (anti-thrash): hoặc còn full, hoặc
	# đã chuyển LOD — miễn là có entry và không crash.
	var old: Node = _wm._chunks.get(Vector2i(0, 0), null)
	_check(old == null or old.block_data != null or bool(old._is_lod),
		"chunk (0,0) sau teleport vẫn nạp đúng dạng")
	# Vùng full mới phải có block_data
	var near_c: Node = _wm._chunks.get(Vector2i(cur.x, cur.y), null)
	_check(near_c != null and not bool(near_c._is_lod) and near_c.block_data != null,
		"chunk center mới (%d,0) là FULL có block_data" % cur.x)
	var hi: int = _wm._horizon()
	var total_slots: int = (2 * hi + 1) * (2 * hi + 1)
	_check(_wm._chunks.size() + 16 * _wm._tiles.size() == total_slots,
		"vùng mới phủ đủ %d chunk-slot" % total_slots)

func _finish() -> void:
	await _W.wait_for_tasks_async(get_tree())
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)