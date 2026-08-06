extends Node

## Headless verification: cây cam (thân nhỏ nhiều nhánh, quả cam rực + hạt cam
## trồng được) & cây rừng rậm (tán um tùm nhiều nhánh chi tiết, chặt ra gỗ cứng)
## — items, recipe, prop build 3 giai đoạn, spawn trong chunk thật.
## Chạy qua tools/test_orange_tree.tscn (không chạy trực tiếp file .gd).

const _Orange = preload("res://scripts/world/props/orange_tree_prop.gd")
const _Dense = preload("res://scripts/world/props/dense_tree_prop.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _RD = preload("res://scripts/items/core/recipe_database.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260803)
	ItemDatabase.ensure_db()

	# ── 1. Items ───────────────────────────────────────────────────────────
	for id in ["orange", "orange_seed", "block_hard_wood"]:
		_check(ItemDatabase.items_db.has(id), "item %s tồn tại" % id)
	var orange: ItemDef = ItemDatabase.items_db.get("orange") as ItemDef
	_check(orange != null and orange.type == ItemDef.Type.FOOD, "quả cam là FOOD")
	_check(orange != null and orange.heal_amount > 0, "quả cam hồi máu > 0")
	_check(orange != null and orange.eat_time == 2.2, "quả cam ăn nhanh 2.2s")
	var orange_seed: ItemDef = ItemDatabase.items_db.get("orange_seed") as ItemDef
	_check(orange_seed != null and orange_seed.type == ItemDef.Type.MATERIAL, "hạt cam MATERIAL")
	var hard_wood: ItemDef = ItemDatabase.items_db.get("block_hard_wood") as ItemDef
	_check(hard_wood != null and hard_wood.type == ItemDef.Type.BLOCK, "gỗ cứng là BLOCK")
	_check(_D.BlockID.HARD_WOOD == 39, "BlockID.HARD_WOOD = 39")
	_check(_D.ITEM_TO_BLOCK.get("block_hard_wood") == _D.BlockID.HARD_WOOD, "block_hard_wood → HARD_WOOD")
	_check(_D.BLOCK_TO_ITEM.get(_D.BlockID.HARD_WOOD) == "block_hard_wood", "HARD_WOOD → block_hard_wood")
	_check(_D.is_axable(_D.BlockID.HARD_WOOD), "gỗ cứng chặt được bằng rìu")

	# ── 2. Recipe orange_seed ──────────────────────────────────────────────
	_RD.ensure()
	var found_recipe := false
	for r in _RD.recipes:
		var rd := r as Dictionary
		if rd.get("id", "") == "orange_seed":
			found_recipe = true
			_check(rd["ingredients"].get("orange", 0) == 1, "recipe orange_seed: cần 1 quả cam")
			_check(rd["count"] == 2, "recipe orange_seed: ra 2 hạt giống")
	_check(found_recipe, "recipe orange_seed tồn tại")

	# ── 3. Seed gieo trồng ─────────────────────────────────────────────────
	_check(_Placement._is_seed_item("orange_seed"), "orange_seed là seed trồng được")

	# ── 4. Cây cam: 3 giai đoạn ───────────────────────────────────────────
	var orange_tree := _Orange.new(150, DestroyableProp.WeaponReq.AXE, "orange")
	orange_tree.setup("plains")
	orange_tree.position = Vector3(2.5, 0.5, 2.5)
	add_child(orange_tree)
	_check(orange_tree.get_child_count() > 0, "cây cam dựng xong (visual/collision)")

	# Mầm
	orange_tree.set_birth_age_days(3.0)
	_check(orange_tree._ordered.size() > 0, "mầm cam có voxel")
	_check(orange_tree.find_child("FruitVisual", false, false) == null, "mầm cam không có quả")

	# Không còn vị thành niên: 15 ngày (trước đây là non) đã trưởng thành
	orange_tree.set_birth_age_days(15.0)
	var young_voxels: int = orange_tree._ordered.size()
	_check(orange_tree._stage == GrowingProp.Stage.MATURE, "cây cam 15 ngày đã trưởng thành (không có non)")
	_check(young_voxels > 0, "cây cam trưởng thành có thân/tán")

	# Trưởng thành già hơn: đủ tán + quả (cả 2 đều đủ hình)
	orange_tree.set_birth_age_days(80.0)
	var mature_voxels: int = orange_tree._ordered.size()
	_check(mature_voxels >= young_voxels * 0.8, "cây cam 80 ngày vẫn đầy đủ thân/tán/quả (có %d)" % mature_voxels)
	var fruit_mmi := orange_tree.find_child("FruitVisual", false, false) as MultiMeshInstance3D
	_check(fruit_mmi != null and fruit_mmi.multimesh != null and fruit_mmi.multimesh.instance_count >= 30,
		"cây cam trưởng thành có quả cam trên tán (có %d voxel quả)"
			% (fruit_mmi.multimesh.instance_count if fruit_mmi != null else 0))
	var cam_count := _count_orange_voxels(orange_tree._grid)
	_check(cam_count >= 50, "có ≥50 voxel quả màu cam rực trong cây (có %d)" % cam_count)
	var trunk_avg := _avg_grid_color(orange_tree._grid)
	_check(trunk_avg.r > trunk_avg.b and trunk_avg.g > 0.25 and trunk_avg.g < 0.55,
		"thân cây cam nâu gỗ (r=%.2f g=%.2f b=%.2f)"
			% [trunk_avg.r, trunk_avg.g, trunk_avg.b])
	orange_tree.queue_free()

	# ── 5. Cây rừng rậm: 3 giai đoạn, tán um tùm ──────────────────────────
	var dense_tree := _Dense.new(200, DestroyableProp.WeaponReq.AXE, "block_hard_wood")
	dense_tree.setup("plains")
	dense_tree.position = Vector3(5.5, 0.5, 2.5)
	add_child(dense_tree)
	_check(dense_tree.get_child_count() > 0, "cây rừng rậm dựng xong (visual/collision)")

	dense_tree.set_birth_age_days(3.0)
	_check(dense_tree._ordered.size() > 0, "mầm rừng có voxel")

	dense_tree.set_birth_age_days(20.0)
	var dense_young: int = dense_tree._ordered.size()
	_check(dense_tree._stage == GrowingProp.Stage.MATURE, "cây rừng 20 ngày đã trưởng thành (không có non)")
	_check(dense_young > 0, "cây rừng trưởng thành có thân/tán")

	dense_tree.set_birth_age_days(120.0)
	var dense_mature: int = dense_tree._ordered.size()
	_check(dense_mature >= dense_young * 0.8, "cây rừng 120 ngày đầy đủ hình (có %d voxel)" % dense_mature)
	_check(dense_mature >= 600, "cây rừng trưởng thành tán um tùm (có %d voxel)" % dense_mature)
	var dense_h: float = dense_tree._get_h()
	_check(dense_h >= 3.0 and dense_h <= 6.0, "cây rừng cỡ lớn (h=%.2f)" % dense_h)
	var leaf_count := _count_green_voxels(dense_tree._grid)
	_check(leaf_count >= 400, "tán lá xanh dày đặc (có %d voxel lá)" % leaf_count)
	dense_tree.queue_free()

	# ── 6. Chunk thật: prop queue có cây cam + cây rừng rậm, không ptype lạ ──
	var chunk := _W.new()
	chunk.name = "FruitTreeChunk"
	add_child(chunk)
	chunk.setup(3, 5, SIZE, RW, true)
	_check(chunk.block_data != null, "chunk setup sync ok")
	if chunk.block_data != null:
		var known := ["palm", "oak", "eggplant", "watermelon", "pumpkin",
			"weed", "taro", "seagrass", "orange_tree", "dense_tree"]
		var bad: Array[String] = []
		var has_orange := false
		var has_dense := false
		for pd in chunk._prop_queue:
			var ptype: String = (pd as Dictionary).get("type", "")
			if ptype not in known:
				bad.append(ptype)
			if ptype == "orange_tree":
				has_orange = true
			if ptype == "dense_tree":
				has_dense = true
		_check(bad.is_empty(), "prop queue không có ptype lạ (có %d)" % bad.size())
		# Gen thêm vài chunk để chắc chắn có cây cam/cây rừng mọc ra
		var total_orange := 0
		var total_dense := 0
		for i in range(8):
			var coords: Array[int] = [0, 0, 7, 3, 2, 8, -3, 4, 5, -2, -6, 6, 9, 1, -1, 9]
			var c2 := _W.new()
			c2.name = "FruitTreeChunk2_%d" % i
			add_child(c2)
			c2.setup(coords[i * 2], coords[i * 2 + 1], SIZE, RW, true)
			for pd in c2._prop_queue:
				var ptype: String = (pd as Dictionary).get("type", "")
				if ptype == "orange_tree":
					total_orange += 1
				elif ptype == "dense_tree":
					total_dense += 1
			c2.queue_free()
		total_orange += 1 if has_orange else 0
		total_dense += 1 if has_dense else 0
		_check(total_orange >= 1, "cây cam mọc trong chunk thật (có %d)" % total_orange)
		_check(total_dense >= 1, "cây rừng rậm mọc trong chunk thật (có %d)" % total_dense)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func _count_orange_voxels(grid: Dictionary) -> int:
	var n := 0
	for c in grid.values():
		var col := c as Color
		if col.r > 0.55 and col.r > col.g + 0.12 and col.r > col.b + 0.25:
			n += 1
	return n

func _count_green_voxels(grid: Dictionary) -> int:
	var n := 0
	for c in grid.values():
		var col := c as Color
		if col.g > col.r and col.g > col.b:
			n += 1
	return n

func _avg_grid_color(grid: Dictionary) -> Color:
	var r := 0.0; var g := 0.0; var b := 0.0
	var n := 0
	for c in grid.values():
		var col := c as Color
		r += col.r; g += col.g; b += col.b
		n += 1
	if n == 0:
		return Color.BLACK
	return Color(r / n, g / n, b / n)
