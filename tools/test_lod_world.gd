extends Node3D

## test_lod_world — Kiểm tra LOD ring (Distant-Horizons style):
##  (A) compute_chunk lod_mode: dict LOD đúng chuẩn — mesh thô, không block
##      data/nước/cỏ/village/props, mesh nằm gọn trong AABB chunk, mặt đất liền
##      mạch ngang biên 2 chunk LOD cạnh nhau;
##  (B) setup(lod=true) sync: node _is_lod, block_data null, cache riêng
##      `_lod_mesh_cache` (không đè `_mesh_cache`), không vào registry;
##  (C) manager thật + player đứng yên: vòng LOD ngoài view_radius tự nạp đủ,
##      chunk trong bán kính là full (block_data != null), ngoài là LOD thô;
##      teleport đổi chunk → biên refresh đúng (chunk cũ LOD→full, vòng ngoài
##      evict), cache không leak (mesh_cache = full, lod cache = ring).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _WM = preload("res://scripts/world/open_world_manager.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0
var _stage_c_done: bool = false
var _wm = null
var _player: Node3D = null
var _f: int = 0
var _moved: bool = false

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_lod_world: LOD ring — mesh thô ngoài, full trong ==")
	WorldSeed.seed_value = 20260806
	_W.clear_noise_cache()
	_W.props_enabled = false

	# ── (A) compute_chunk lod_mode ────────────────────────────────────────────
	var d0 := _W.compute_chunk(0, 0, SIZE, RW, false, true)
	_check(d0.get("lod", false) == true, "dict LOD có cờ 'lod'=true")
	_check(d0["mesh"] != null, "LOD có mesh")
	var d1 := _W.compute_chunk(1, 0, SIZE, RW, false, true)
	_check(d1.get("lod", false) == true, "chunk (1,0) cũng LOD")
	_check((d0["block_data_bytes"] as PackedByteArray).is_empty(), "LOD không có block_data_bytes")
	_check(d0.get("plant_props", []).is_empty(), "LOD không có plant_props")
	_check((d0.get("top_ly_hint", PackedInt32Array()) as PackedInt32Array).is_empty(), "LOD không có top_ly_hint")
	_check(not bool(d0.get("has_water", true)), "LOD không có nước")
	_check(not (d0.get("village_data", {}) as Dictionary).get("has", false), "LOD không có làng")

	# AABB mesh LOD phải nằm gọn trong chunk[−16,16]
	var aabb: AABB = d0["mesh"].get_aabb()
	_check(absf(aabb.size.x - 32.0) < 2.0 and absf(aabb.size.z - 32.0) < 2.0,
		"AABB LOD trải đúng 32×32 (%.1f×%.1f→%.1f)" % [aabb.size.x, aabb.size.z, aabb.size.y])
	_check(aabb.size.y > 2.0 and aabb.position.y + aabb.size.y < 70.0,
		"AABB LOD theo chiều cao hợp lý (y=%.0f..%.0f)" % [aabb.position.y, aabb.position.y + aabb.size.y])

	# Liền mạch ngang biên: height_grid cột biên của (0,0) nối tiếp (1,0)
	var hA: Array = d0["height_grid"]
	var hB: Array = d1["height_grid"]
	var seam_diff := 0.0
	var seam_big := 0
	for z in range(SIZE):
		var dd := absf(float(hA[SIZE - 1][z]) - float(hB[0][z]))
		seam_diff += dd
		if dd > 2.0:
			seam_big += 1
	var interior_diff := 0.0
	for z in range(SIZE):
		interior_diff += absf(float(hA[SIZE - 2][z]) - float(hA[SIZE - 1][z]))
	interior_diff /= maxi(SIZE, 1)
	seam_diff /= maxi(SIZE, 1)
	_check(seam_big <= 6, "biên LOD liền mạch (cột chênh>2m: %d/32)" % seam_big)
	_check(seam_diff <= interior_diff * 2.0 + 1.0,
		"chênh biên (%.2f) ~ mức chênh nội bộ (%.2f)" % [seam_diff, interior_diff])

	# Full chunk đối chứng: có block data, không mang cờ LOD
	var dfull := _W.compute_chunk(0, 0, SIZE, RW, false, false)
	_check(not dfull.has("lod") or dfull.get("lod", false) == false, "full chunk không bị đánh dấu LOD")
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

	await _run_stage_c()
	await _W.wait_for_tasks_async(get_tree())
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

## ── (C) manager thật: vòng LOD tự nạp, refresh đúng khi teleport ────────────
func _run_stage_c() -> void:
	print("[stage C] khởi tạo manager + player đứng yên tại gốc (view_radius=%d)..." % _current_view_radius())
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
	_stage_c_done = true

## Thu bán kính test xuống 3 để tổng chunk nhỏ (49 full + 176 LOD), worker thải
## kịp trong khung thời gian test. Nếu SettingsManager không tồn tại (đứng độc).
func _current_view_radius() -> int:
	if SettingsManager and SettingsManager.chunk_view > 3:
		SettingsManager.chunk_view = 3
	return SettingsManager.chunk_view if SettingsManager else 3

func _process(_delta: float) -> void:
	if not _stage_c_done:
		return
	_f += 1
	if _f % 120 == 0:
		print("  ..f=%d chunks=%d loading=%d pending=%d pending_lod=%d vr=%d" % [
			_f, _wm._chunks.size(), _wm._loading.size(),
			_wm._pending.size(), _wm._pending_lod.size(), _wm.view_radius])

	var vr: int = _wm.view_radius
	var lod_r: int = vr + _WM.LOD_RING_EXTRA

	# Chờ vòng đầu nạp xong rồi kiểm tra, sau đó teleport một lần.
	if not _moved:
		if _f > 1500:
			print("TIMEOUT (phase 1: vòng đầu không ổn định) @%d frames" % _f)
			_failures += 1
			_moved = true
			_stage_c_done = false
			return
		if _wm._loading.is_empty() and _wm._pending.is_empty() and _wm._pending_lod.is_empty():
			if _f < 30:
				return
			_moved = true
			print("[stage C] vòng đầu ổn định @%d frames — kiểm tra rồi teleport" % _f)
			_verify_steady(vr, lod_r)
			_player.position = Vector3((vr + 0.6) * SIZE, 60, 0)
		return
	if not (_wm._loading.is_empty() and _wm._pending.is_empty() and _wm._pending_lod.is_empty()):
		return
	if _f > 1700:
		print("TIMEOUT (phase 2: sau teleport không ổn định) @%d frames" % _f)
		_failures += 1
	else:
		_verify_after_move(vr, lod_r)
		_verify_memory(vr, lod_r)
	_stage_c_done = false

func _verify_steady(vr: int, lod_r: int) -> void:
	var total := (2 * lod_r + 1) * (2 * lod_r + 1)
	_check(_wm._chunks.size() == total, "đủ %d chunk so với ring LOD (%d nạp)" % [total, _wm._chunks.size()])
	var bad := 0
	for key in _wm._chunks:
		var c: Node = _wm._chunks[key]
		var d := maxi(absi(int(key.x)), absi(int(key.y)))
		var wanted_lod: bool = d > vr
		if bool(c._is_lod) != wanted_lod:
			bad += 1
			continue
		if wanted_lod and c.block_data != null:
			bad += 1
		if not wanted_lod and c.block_data == null:
			bad += 1
	_check(bad == 0, "phân loại đúng: trong=%dfull ngoài=%dLOD (%d sai)" % [
		(2 * vr + 1) * (2 * vr + 1), (2 * lod_r + 1) * (2 * lod_r + 1) - (2 * vr + 1) * (2 * vr + 1), bad])

func _verify_after_move(vr: int, lod_r: int) -> void:
	var key := Vector2i(vr, 0)
	var c: Node = _wm._chunks.get(key)
	_check(c != null and not bool(c._is_lod) and c.block_data != null,
		"sau teleport chunk (với chebyshev=%d) được nâng thành FULL" % vr)
	var far := Vector2i(lod_r, 0)
	var far_c: Node = _wm._chunks.get(far)
	_check(far_c != null and bool(far_c._is_lod) and far_c.block_data == null,
		"chunk xa chebyshev=%d vẫn ở dạng LOD" % lod_r)
	# Những chunk ngoài LOD ring mới bị evict
	var outer := Vector2i(lod_r + 1, 0)
	_check(not _wm._chunks.has(outer) and not _wm._loading.has(outer),
		"chunk ngoài ring mới đã bị evict (%s)" % str(_wm._chunks.has(outer)))

func _verify_memory(vr: int, lod_r: int) -> void:
	var expect_full := (2 * vr + 1) * (2 * vr + 1)
	var expect_lod := (2 * lod_r + 1) * (2 * lod_r + 1) - expect_full
	_check(_W._mesh_cache.size() == expect_full, "mesh_cache giữ đúng %d dict full (%d)" % [expect_full, _W._mesh_cache.size()])
	_check(_W._lod_mesh_cache.size() == expect_lod, "lod_mesh_cache giữ đúng %d dict LOD (%d)" % [expect_lod, _W._lod_mesh_cache.size()])