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
	# Toàn bộ công thức chế tạo ĐÃ BỊ XÓA theo thiết kế hiện tại (same as
	# test_mangrove_gen/test_eggplant): không còn recipe hạt cam.
	_RD.ensure()
	_check(_RD.recipes.is_empty(), "toàn bộ công thức đã bị xoá (còn %d)" % _RD.recipes.size())
	var orange_r: Dictionary = _RD.match_counts({"orange": 1})
	_check(orange_r.is_empty(), "không còn recipe orange_seed (đã xoá cùng mọi recipe)")

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
	var fruit_mmi := orange_tree.find_child("OrangeVisual", false, false) as MultiMeshInstance3D
	_check(fruit_mmi != null and fruit_mmi.multimesh != null and fruit_mmi.multimesh.instance_count >= 30,
		"cây cam trưởng thành có tán + quả cam gộp trong OrangeVisual (có %d voxel)"
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
			"weed", "taro", "seagrass", "orange_tree", "dense_tree",
			"clover", "wild_berry", "sunflower", "tulip", "rose"]
		var bad: Array[String] = []
		for pd in chunk._prop_queue:
			var ptype: String = (pd as Dictionary).get("type", "")
			if ptype not in known:
				bad.append(ptype)
		_check(bad.is_empty(), "prop queue không có ptype lạ (có %d)" % bad.size())
		# Quần đảo mới: lòng đảo nhỏ → cây cam/rừng thưa ở từng chunk riêng;
		# quét xoắn ốc quanh gốc (đảo nhà đồng cỏ rộng) tới khi gặp cả 2 loại.
		# Re-seed trước khi quét để stream RNG chunk-gen ổn định, không phụ
		# thuộc số randf() của các prop dựng ở phần 4-5.
		WorldSeed.seed_value = 20260803
		_W._Noise.clear_cache()
		seed(20260803)
		var total_orange := 0
		var total_dense := 0
		var attempts := 0
		var r := 0
		while (total_orange == 0 or total_dense == 0) and attempts < 120:
			if r == 0:
				var c0 := _W.new()
				c0.name = "Fs_%d" % attempts
				add_child(c0)
				c0.setup(0, 0, SIZE, RW, true)
				for pd in c0._prop_queue:
					var ptype: String = (pd as Dictionary).get("type", "")
					if ptype == "orange_tree":
						total_orange += 1
					elif ptype == "dense_tree":
						total_dense += 1
				c0.queue_free()
				attempts += 1
			else:
				for vx in range(-r, r):
					var c1 := _W.new()
					c1.name = "Fs_%d" % attempts
					add_child(c1)
					c1.setup(vx, -r, SIZE, RW, true)
					for pd in c1._prop_queue:
						var ptype: String = (pd as Dictionary).get("type", "")
						if ptype == "orange_tree":
							total_orange += 1
						elif ptype == "dense_tree":
							total_dense += 1
					c1.queue_free()
					attempts += 1
					if (total_orange > 0 and total_dense > 0) or attempts >= 120:
						break
				if (total_orange > 0 and total_dense > 0) or attempts >= 120:
					break
				for vz in range(-r, r):
					var c2 := _W.new()
					c2.name = "Fs_%d" % attempts
					add_child(c2)
					c2.setup(r, vz, SIZE, RW, true)
					for pd in c2._prop_queue:
						var ptype: String = (pd as Dictionary).get("type", "")
						if ptype == "orange_tree":
							total_orange += 1
						elif ptype == "dense_tree":
							total_dense += 1
					c2.queue_free()
					attempts += 1
					if (total_orange > 0 and total_dense > 0) or attempts >= 120:
						break
				if (total_orange > 0 and total_dense > 0) or attempts >= 120:
					break
				for vx in range(-r, r):
					var c3 := _W.new()
					c3.name = "Fs_%d" % attempts
					add_child(c3)
					c3.setup(-vx, r, SIZE, RW, true)
					for pd in c3._prop_queue:
						var ptype: String = (pd as Dictionary).get("type", "")
						if ptype == "orange_tree":
							total_orange += 1
						elif ptype == "dense_tree":
							total_dense += 1
					c3.queue_free()
					attempts += 1
					if (total_orange > 0 and total_dense > 0) or attempts >= 120:
						break
				if (total_orange > 0 and total_dense > 0) or attempts >= 120:
					break
				for vz in range(-r, r):
					var c4 := _W.new()
					c4.name = "Fs_%d" % attempts
					add_child(c4)
					c4.setup(-r, -vz, SIZE, RW, true)
					for pd in c4._prop_queue:
						var ptype: String = (pd as Dictionary).get("type", "")
						if ptype == "orange_tree":
							total_orange += 1
						elif ptype == "dense_tree":
							total_dense += 1
					c4.queue_free()
					attempts += 1
					if (total_orange > 0 and total_dense > 0) or attempts >= 120:
						break
			r += 1
		_check(total_orange >= 1, "cây cam mọc trong chunk thật (quét %d chunk, có %d)" % [attempts, total_orange])
		_check(total_dense >= 1, "cây rừng rậm mọc trong chunk thật (quét %d chunk, có %d)" % [attempts, total_dense])

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
