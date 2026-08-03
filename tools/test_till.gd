extends Node

## Headless verification: cuốc đất → đất tơi xốp, ẩm/khô theo nước bán kính 3,
## item db + seed planting hooks.
## Chạy qua tools/test_till.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

## Đỉnh mặt trên dùng tint nguyên (khô r≈1, ẩm r≈0.55) — mặt dưới/cạnh bị tối nên
## phải so theo giá trị max của kênh R.
func _max_red(mesh: ArrayMesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return -1.0
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var m := 0.0
	for i in range(colors.size()):
		if colors[i].r > m:
			m = colors[i].r
	return m

func _ready() -> void:
	WorldSeed.seed_value = 20260802
	seed(20260802)

	# ── 1. Bảng dữ liệu ────────────────────────────────────────────────────
	_check(_D.is_tillable(_D.BlockID.GRASS), "cuốc được GRASS")
	_check(_D.is_tillable(_D.BlockID.DARK_GRASS), "cuốc được DARK_GRASS")
	_check(_D.is_tillable(_D.BlockID.DIRT), "cuốc được DIRT")
	_check(_D.is_tillable(_D.BlockID.DARK_DIRT), "cuốc được DARK_DIRT")
	_check(_D.is_tillable(_D.BlockID.YOUNG_GRASS), "cuốc được YOUNG_GRASS")
	_check(not _D.is_tillable(_D.BlockID.STONE), "không cuốc được STONE")
	_check(not _D.is_tillable(_D.BlockID.SAND), "không cuốc được SAND")
	_check(not _D.is_tillable(_D.BlockID.BEDROCK), "không cuốc được BEDROCK")
	_check(not _D.is_tillable(_D.BlockID.TILLED_SOIL), "không cuốc lại đất tơi xốp")
	_check(_D.is_soil(_D.BlockID.TILLED_SOIL), "is_soil(TILLED_SOIL) đúng")
	_check(not _D.is_soil(_D.BlockID.GRASS), "is_soil(GRASS) sai → false")
	_check(_D.SOIL_RADIUS == 3, "SOIL_RADIUS == 3")
	_check(_D.ITEM_TO_BLOCK.get("block_tilled_soil", 0) == _D.BlockID.TILLED_SOIL,
		"ITEM_TO_BLOCK[block_tilled_soil] → 32")
	_check(_D.BLOCK_TO_ITEM.get(_D.BlockID.TILLED_SOIL, "") == "block_tilled_soil",
		"BLOCK_TO_ITEM[32] → block_tilled_soil")
	_check(_D.ITEM_TO_BLOCK.get("block_young_grass", 0) == _D.BlockID.YOUNG_GRASS,
		"ITEM_TO_BLOCK[block_young_grass] → 38")
	_check(_D.BLOCK_TO_ITEM.get(_D.BlockID.YOUNG_GRASS, "") == "block_young_grass",
		"BLOCK_TO_ITEM[38] → block_young_grass")

	# ── 2. Item database ───────────────────────────────────────────────────
	ItemDatabase.ensure_db()
	var hoe: ItemDef = ItemDatabase.items_db.get("hoe") as ItemDef
	var soil: ItemDef = ItemDatabase.items_db.get("block_tilled_soil") as ItemDef
	var cseed: ItemDef = ItemDatabase.items_db.get("coconut_seed") as ItemDef
	var tseed: ItemDef = ItemDatabase.items_db.get("taro_seed") as ItemDef
	var sseed: ItemDef = ItemDatabase.items_db.get("seaweed_seed") as ItemDef
	_check(hoe != null and hoe.type == ItemDef.Type.TOOL, "hoe tồn tại, loại TOOL")
	_check(hoe != null and hoe.atk_bonus == 2, "hoe sát thương 2")
	_check(soil != null and soil.type == ItemDef.Type.BLOCK, "block_tilled_soil là BLOCK")
	var yg: ItemDef = ItemDatabase.items_db.get("block_young_grass") as ItemDef
	_check(yg != null and yg.type == ItemDef.Type.BLOCK, "block_young_grass là BLOCK")
	_check(cseed != null and tseed != null and sseed != null, "3 mầm cây tồn tại")
	_check(cseed != null and cseed.max_stack == 16, "mầm stack 16")
	_check(_Placement._is_seed_item("coconut_seed"), "coconut_seed là seed item")
	_check(_Placement._is_seed_item("seaweed_seed"), "seaweed_seed là seed item")
	_check(not _Placement._is_seed_item("hoe"), "hoe không phải seed item")
	_check(_Placement._is_seaweed_bed(_D.BlockID.OCEAN_SAND), "nền rong: cát đại dương")
	_check(_Placement._is_seaweed_bed(_D.BlockID.OCEAN_MUD), "nền rong: bùn đại dương")
	_check(not _Placement._is_seaweed_bed(_D.BlockID.STONE), "nền rong: đá → false")

	# ── 3. Cuốc trên chunk thật ───────────────────────────────────────────
	var chunk := _W.new()
	chunk.name = "TillChunk"
	add_child(chunk)
	chunk.setup(0, 0, SIZE, RW, true)
	_check(chunk.block_data != null, "chunk setup sync ok")

	if chunk.block_data != null:
		var dig_x := -1
		var dig_z := -1
		var dig_top := -1
		for x in range(COLS):
			for z in range(COLS):
				var t := chunk._top_ly_cache[x * COLS + z]
				if t >= 1 and _D.is_tillable(chunk.block_data.get_block(x, t, z)):
					dig_x = x; dig_z = z; dig_top = t
					break
			if dig_x >= 0:
				break
		_check(dig_x >= 0, "tìm được cột có thể cuốc (%d,%d)" % [dig_x, dig_z])

		if dig_x >= 0:
			var half_sz := SIZE * 0.5
			var wx := chunk.global_position.x - half_sz + (dig_x + 0.5) * _D.VOXEL
			var wy := _BD.layer_to_world_y(dig_top)
			var wz := chunk.global_position.z - half_sz + (dig_z + 0.5) * _D.VOXEL

			var old_b: int = chunk.till_block_at(wx, wy, wz)
			_check(_D.is_tillable(old_b), "till trả về block cũ (%d)" % old_b)
			_check(chunk.block_data.get_block(dig_x, dig_top, dig_z) == _D.BlockID.TILLED_SOIL,
				"block sau cuốc = TILLED_SOIL")
			_check(chunk._top_ly_cache[dig_x * COLS + dig_z] == dig_top,
				"top cache không đổi sau cuốc")
			_check(chunk._has_soil, "_has_soil = true")
			_check(chunk._scan_has_soil(), "_scan_has_soil tìm thấy đất")

			var old_stone: int = chunk.till_block_at(wx, wy - _D.VOXEL, wz)
			_check(old_stone == 0, "cuốc STONE → 0 (không cuốc được)")

			# ── Khô → đặt nước lên → ẩm → bỏ nước → khô ──
			var mi := chunk._textured_block_mesh_instances.get(_D.BlockID.TILLED_SOIL) as MeshInstance3D
			_check(mi != null and mi.mesh != null, "có soil mesh instance")
			_check(_max_red(mi.mesh) > 0.9, "đất khô: tint sáng (r≈1)")

			chunk.place_block_at(wx, wy + _D.VOXEL, wz, _D.BlockID.WATER_SOURCE)
			chunk.rebuild_soil_mesh()
			mi = chunk._textured_block_mesh_instances.get(_D.BlockID.TILLED_SOIL) as MeshInstance3D
			_check(_max_red(mi.mesh) < 0.7, "đất ẩm khi có nước kề bên (tint xanh)")
			_check(chunk._has_soil, "vẫn có soil sau khi ẩm")

			chunk.break_block_at(wx, wy + _D.VOXEL, wz)
			chunk.rebuild_soil_mesh()
			mi = chunk._textured_block_mesh_instances.get(_D.BlockID.TILLED_SOIL) as MeshInstance3D
			_check(_max_red(mi.mesh) > 0.9, "bỏ nước → đất khô lại")

			# ── place_block_at đặt trực tiếp đất tơi xốp ──
			var placed: bool = chunk.place_block_at(wx, wy + 2.0 * _D.VOXEL, wz, _D.BlockID.TILLED_SOIL)
			_check(placed, "place_block_at đặt TILLED_SOIL ok")
			_check(chunk._scan_has_soil(), "scan thấy đất sau khi đặt")

			# ── Phá hết đất → scan rỗng ──
			chunk.break_block_at(wx, wy + 2.0 * _D.VOXEL, wz)
			chunk.break_block_at(wx, wy, wz)
			chunk.rebuild_soil_mesh()
			_check(not chunk._scan_has_soil(), "hết đất → scan rỗng")
			_check(not chunk._has_soil, "_has_soil = false khi hết đất")

	# ── 4. Mesh rỗng không crash ──
	var empty_bd := _BD.new()
	empty_bd.init(COLS, COLS)
	var empty_mesh := _W._build_soil_mesh(empty_bd, COLS, {})
	_check(empty_mesh == null or empty_mesh.get_surface_count() == 0,
		"không có đất → mesh rỗng, không crash")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
