extends Node

## test_shaped_rebuild — verify light rebuild path cho shaped block
## (platform/tường/đá tay đặt): đặt/break KHÔNG rebuild terrain mesh (80ms),
## chỉ cập nhật shaped overlay + collider. Biome block vẫn rebuild terrain.

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const REAL: int = _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_shaped_rebuild ==")
	WorldSeed.seed_value = 20260806
	_W.props_enabled = false
	_W.clear_noise_cache()

	var d := _W.compute_chunk(0, 0, 32, REAL, false, false)
	var bd := _BD.new()
	bd.from_bytes(d["block_data_bytes"], 32, 32)
	var chunk := _W.new()
	chunk._cols = 32
	chunk._cx = 0
	chunk._cz = 0
	chunk._dimension_id = REAL
	chunk.block_data = bd
	chunk._init_materials()
	add_child(chunk)
	chunk.rebuild_mesh()

	var terrain_old: Node = chunk._terrain_mesh_instance
	_check(terrain_old != null, "có terrain mesh ban đầu")

	var tl: int = chunk._top_ly_cache[16 * 32 + 16]
	var wby: float = _BD.layer_to_world_y(tl + 1)
	_check(chunk.block_data.get_block(16, tl + 1, 16) == _D.BlockID.AIR, "ô (16,%d,16) trống (trên mặt)" % (tl + 1))

	# ── Đặt platform (shaped) → light path, terrain không đổi ──
	var ok: bool = chunk.place_block_at(16.5, wby, 16.5, _D.BlockID.STONE_PLATFORM, _BD.OFF_CENTER)
	_check(ok, "place shaped ok")
	_check(chunk.block_data.get_block(16, tl + 1, 16) == _D.BlockID.STONE_PLATFORM, "block shaped lưu đúng")
	_check(terrain_old == chunk._terrain_mesh_instance, "terrain mesh KHÔNG đổi (light path)")
	await _W.wait_for_tasks_async(get_tree())
	await get_tree().process_frame
	_check(chunk._shaped_block_instances.size() >= 1, "shaped mesh overlay đã cập nhật (async apply)")

	# ── Phá platform (shaped) → light path ──
	var old_id: int = chunk.break_block_at(16.5, wby, 16.5)
	_check(old_id == _D.BlockID.STONE_PLATFORM, "break shaped trả đúng id")
	_check(chunk.block_data.get_block(16, tl + 1, 16) == _D.BlockID.AIR, "ô trống lại sau break")
	_check(terrain_old == chunk._terrain_mesh_instance, "terrain KHÔNG đổi khi break shaped")
	await _W.wait_for_tasks_async(get_tree())
	await get_tree().process_frame
	_check(not chunk._has_shaped_blocks, "cờ shaped tắt khi đã phá hết shaped")

	# ── Đặt biome block (DIRT) → rebuild ASYNC (worker thread) ──
	wby = _BD.layer_to_world_y(tl + 2)
	var ok2: bool = chunk.place_block_at(16.5, wby, 16.5, _D.BlockID.DIRT, _BD.OFF_CENTER)
	_check(ok2, "place biome ok")
	_check(chunk._top_ly_cache[16 * 32 + 16] == tl + 2, "top_ly nâng NGAY (sync, trước mesh apply)")
	await _W.wait_for_tasks_async(get_tree())
	await get_tree().process_frame
	_check(terrain_old != chunk._terrain_mesh_instance, "biome block → terrain mesh ĐỔI (rebuild async)")
	_check(chunk.block_data.get_block(16, tl + 2, 16) == _D.BlockID.DIRT, "block biome lưu đúng")

	chunk.queue_free()
	print("== test_shaped_rebuild %s (%d fail) ==" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)