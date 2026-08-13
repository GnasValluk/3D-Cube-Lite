extends Node3D

## Headless verification: cây dưa hấu (WatermelonVineProp — dây bò bám mặt đất,
## tua cuốn lò xo, lá xẻ thùy sâu, hoa sao 5 cánh vàng chanh, quả căng tròn
## vằn xanh đen nhô cao + vệt đất vàng ngà + hạt sao lấp lánh), trái dưa hấu +
## miếng cắt + túi hạt giống, gieo trên đất tơi xốp, thu hoạch rơi trái + hạt,
## dây dưa dại mọc rải rác trên đồng cỏ.
## Chạy qua tools/test_watermelon.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")
const _Recipe = preload("res://scripts/items/core/recipe_database.gd")
const _Watermelon = preload("res://scripts/world/props/watermelon_vine_prop.gd")
const _Growing = preload("res://scripts/world/props/growing_prop.gd")

const SIZE := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count_drops() -> int:
	var n := 0
	for ch in get_children():
		if ch is DroppedItem:
			n += 1
	return n

func _drop_ids() -> Array[String]:
	var ids: Array[String] = []
	for ch in get_children():
		if ch is DroppedItem:
			ids.append(ch.item_def.id)
	return ids

func _drop_counts() -> Dictionary:
	var m := {}
	for ch in get_children():
		if ch is DroppedItem:
			m[ch.item_def.id] = m.get(ch.item_def.id, 0) + 1
	return m

func _ready() -> void:
	seed(20260809)
	ItemDatabase.ensure_db()

	# ── 1. Items ────────────────────────────────────────────────────────────
	print("-- 1. Items dưa hấu --")
	var fruit: ItemDef = ItemDatabase.items_db.get("watermelon") as ItemDef
	var slice: ItemDef = ItemDatabase.items_db.get("watermelon_slice") as ItemDef
	var seed_item: ItemDef = ItemDatabase.items_db.get("watermelon_seed") as ItemDef
	_check(fruit != null and fruit.type == ItemDef.Type.FOOD, "item watermelon, loại FOOD")
	_check(fruit != null and fruit.heal_amount == 14, "trái dưa hấu hồi 14 HP")
	_check(fruit != null and absf(fruit.eat_time - 3.0) < 0.01, "ăn trái dưa hấu mất 3.0s")
	_check(slice != null and slice.type == ItemDef.Type.FOOD and slice.heal_amount == 6,
		"item watermelon_slice, loại FOOD, hồi 6 HP")
	_check(seed_item != null and seed_item.type == ItemDef.Type.MATERIAL
		and seed_item.max_stack == 16, "item watermelon_seed, MATERIAL, stack 16")

	# ── 2. Recipe ───────────────────────────────────────────────────────────
	print("-- 2. Recipe cắt lát + lấy hạt --")
	_Recipe.ensure()
	_check(_Recipe.recipes.is_empty(), "toàn bộ công thức chế tạo đã bị xoá (còn %d)" % _Recipe.recipes.size())
	var slice_r: Dictionary = _Recipe.match_counts({"watermelon": 1})
	_check(slice_r.is_empty(), "không còn recipe cắt miếng dưa hấu (đã xoá)")

	# ── 3. Gieo trồng ──────────────────────────────────────────────────────
	print("-- 3. Gieo hạt trên đất tơi xốp --")
	_check(_Placement._is_seed_item("watermelon_seed"), "watermelon_seed là seed item")
	var stub := GDScript.new()
	stub.source_code = "extends Node3D\nfunc get_block(_x: float, _y: float, _z: float) -> int:\n\treturn %d if _y < 0.25 else %d\n" % [_D.BlockID.TILLED_SOIL, _D.BlockID.GRASS]
	stub.reload()
	var holder := Node3D.new()
	add_child(holder)
	var wm := Node3D.new()
	wm.name = "WorldManager"
	wm.set_script(stub)
	holder.add_child(wm)
	var ps := _Placement.new()
	holder.add_child(ps)
	_check(ps._can_plant_seed("watermelon_seed", Vector3(0, 0.5, 0)), "đất tơi xốp → gieo được")
	_check(not ps._can_plant_seed("watermelon_seed", Vector3(0, 1.0, 0)), "cỏ thường → không gieo")
	ps._plant_seed("watermelon_seed", Vector3(0, 0.5, 0))
	var planted := false
	for ch in wm.get_children():
		if ch is _Watermelon:
			planted = true
	_check(planted, "_plant_seed tạo WatermelonVineProp trên đất tơi xốp")

	# ── 4. Cây dưa hấu 4 giai đoạn ─────────────────────────────────────────
	print("-- 4. Giai đoạn phát triển --")
	var vine := _Watermelon.new(40, DestroyableProp.WeaponReq.SWORD, "watermelon")
	vine.setup()
	vine.position = Vector3(4.5, 0.25, 0.5)
	add_child(vine)

	# Mầm: 2 lá mầm xanh nõn, chưa có dây/lá thật
	vine.set_birth_age_days(1.0)
	_check(vine._stage == _Growing.Stage.SPROUT, "1 ngày = cây mầm")
	_check(vine._vox_leaf == 6, "mầm có đúng 2 lá mầm (6 micro-voxel)")
	_check(vine._vox_vine == 0 and vine._vox_bud == 0 and vine._vox_fruit == 0, "mầm chưa có dây/nụ/quả")
	_check(vine.find_child("WatermelonFruitVisual", false, false) == null, "mầm không có quả")
	_check(vine.find_child("WatermelonGlow", false, false) == null, "mầm không có ánh sáng chín")

	# Dây leo: dây bò uốn lượn + lá xẻ thùy + nụ hoa vàng, chưa hoa/quả
	vine.set_birth_age_days(4.0)
	_check(vine._stage == _Growing.Stage.YOUNG, "4 ngày = dây leo (cây non)")
	_check(vine._vox_vine >= 10, "dây bò lan rộng (≥10 micro-voxel, có %d)" % vine._vox_vine)
	_check(vine._vox_leaf >= 20, "thảm lá xẻ thùy (≥20 micro-voxel, có %d)" % vine._vox_leaf)
	_check(vine._vox_bud >= 3, "nụ hoa vàng ở nách lá (≥3, có %d)" % vine._vox_bud)
	_check(vine._vox_flower == 0 and vine._vox_fruit == 0, "dây leo chưa hoa nở/quả")
	_check(vine.find_child("WatermelonFruitVisual", false, false) == null, "dây leo không có quả")

	# Đơm quả non: hoa tàn, quả nắm tay xanh nhạt chưa vằn
	vine.set_birth_age_days(8.0)
	_check(vine._stage == _Growing.Stage.MATURE, "8 ngày = đơm quả non")
	_check(vine._vox_flower >= 8, "hoa sao 5 cánh vàng chanh + nhụy cam (≥8, có %d)" % vine._vox_flower)
	_check(vine._vox_fruit >= 8, "quả non nắm tay (≥8 micro-voxel, có %d)" % vine._vox_fruit)
	_check(vine._vox_stripe == 0, "quả non chưa có vằn xanh đen")
	_check(vine._vox_sparkle == 0, "quả non chưa lấp lánh")
	_check(vine.find_child("WatermelonFruitVisual", false, false) != null, "quả non có visual riêng")
	_check(vine.find_child("WatermelonGlow", false, false) == null, "quả non không có ánh sáng chín")

	# Chín: trái dưa to dùng model thật 1 block + hạt sao lấp lánh + glow
	vine.set_birth_age_days(16.0)
	_check(vine._stage == _Growing.Stage.RIPE, "16 ngày = chín thu hoạch")
	_check(vine._real_fruit_nodes.size() >= 1, "trái dưa model thật đặt lệch khỏi gốc (≥1, có %d)" % vine._real_fruit_nodes.size())
	var wm_ok := vine._real_fruit_nodes.size() > 0
	for rf in vine._real_fruit_nodes:
		if is_instance_valid(rf) and rf.get_child_count() == 0:
			wm_ok = false
	_check(wm_ok, "mỗi trái dưa có đủ mesh model (vỏ + vằn + cuống)")
	_check(vine._vox_sparkle >= 3, "hạt sao vàng lấp lánh quanh quả chín (≥3, có %d)" % vine._vox_sparkle)
	_check(vine.find_child("WatermelonGlow", false, false) != null, "có ánh sáng vàng dịu báo chín")
	var fmmi := vine.find_child("WatermelonFruitVisual", false, false) as MultiMeshInstance3D
	if fmmi != null and fmmi.multimesh != null and fmmi.multimesh.mesh != null:
		var fmat := fmmi.multimesh.mesh.material as StandardMaterial3D
		_check(fmat != null and absf(fmat.roughness - 0.30) < 0.01,
			"vỏ quả bóng mờ nhẹ (roughness 0.30, có %s)" % (str(fmat.roughness) if fmat else "null"))
	else:
		_check(false, "vỏ quả bóng mờ nhẹ (roughness 0.30)")

	# ── 5. Thu hoạch: chặt bằng kiếm khi chín, rơi trái + hạt ──────────────
	print("-- 5. Thu hoạch --")
	_check(vine.try_destroy("iron_sword", 999), "kiếm chặt dây dưa (SWORD req)")
	await get_tree().process_frame
	await get_tree().process_frame
	var ids := _drop_ids()
	_check("watermelon" in ids, "thu hoạch rơi trái dưa hấu")
	_check("watermelon_seed" in ids, "thu hoạch rơi hạt giống (trồng lại)")
	_check(_count_drops() >= 2, "rơi 1 trái + 1 túi hạt (có %d)" % _count_drops())

	# Chặt khi chưa chín (quả non) → không rơi thêm trái
	var before: Dictionary = _drop_counts()
	var young_vine := _Watermelon.new(40, DestroyableProp.WeaponReq.SWORD, "watermelon")
	young_vine.setup()
	young_vine.position = Vector3(6.5, 0.25, 0.5)
	add_child(young_vine)
	young_vine.set_birth_age_days(8.0)
	young_vine.try_destroy("iron_sword", 999)
	await get_tree().process_frame
	await get_tree().process_frame
	var after: Dictionary = _drop_counts()
	_check(after.get("watermelon", 0) == before.get("watermelon", 0)
		and after.get("watermelon_seed", 0) == before.get("watermelon_seed", 0),
		"quả non chặt sớm không rơi trái/hạt mới (trước %d/%d → sau %d/%d)"
		% [before.get("watermelon", 0), before.get("watermelon_seed", 0),
		   after.get("watermelon", 0), after.get("watermelon_seed", 0)])

	# ── 6. Icons ────────────────────────────────────────────────────────────
	print("-- 6. Icon 3D --")
	for id in ["watermelon", "watermelon_slice", "watermelon_seed"]:
		var icon := Node3D.new()
		add_child(icon)
		ItemMesh.build(icon, id)
		_check(icon.get_child_count() > 0, "icon %s có mesh (children=%d)" % [id, icon.get_child_count()])
		icon.queue_free()

	# ── 7. Dây dưa dại trên đồng cỏ ────────────────────────────────────────
	# Dưa hấu dại cần nước cách ≤2 ô (wdist<=2). Mức quét lưới thô theo lake_val
	# (chunk có hồ → chắc chắn có nước): bước thô STEP=18 (đồng cỏ), TT=0.68.
	print("-- 7. Dây dưa hấu dại: spawn trong chunk thật --")
	WorldSeed.seed_value = 20260809
	_W._Noise.clear_cache()
	var nd: Dictionary = _W._Noise._noise_for_dim(RW)
	var n_lake: FastNoiseLite = nd["lake"]
	var found := 0
	var total_wm := 0
	var scans := 0
	for x in range(-1600, 1601, SIZE * 8):
		for z in range(-1600, 1601, SIZE * 8):
			if found > 0 or scans >= 14:
				break
			var wx := float(x) + 0.5
			var wz := float(z) + 0.5
			if _W._ocean_mask_at(nd, wx, wz):
				continue
			var bb: Variant = _W._Noise._biome_at(wx, wz, RW)
			if bb != _D.TileType.GRASS_DIRT:
				continue
			var has_water := false
			for off in [Vector2.ZERO, Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2),
					Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
				var lv: float = (n_lake.get_noise_2d(wx + off.x, wz + off.y) + 1.0) * 0.5
				if lv > 0.68:
					has_water = true
					break
			if not has_water:
				continue
			scans += 1
			print("   (compute chunk %d,%d...)" % [int(floor(wx / SIZE)), int(floor(wz / SIZE))])
			var data := _W.compute_chunk(int(floor(wx / SIZE)), int(floor(wz / SIZE)), SIZE, RW)
			var wm_count := 0
			for p in data.get("plant_props", []):
				if p.get("type", "") == "watermelon":
					wm_count += 1
			total_wm += wm_count
			if wm_count >= 1:
				found += 1
				print("   (chunk %d,%d: dưa hấu dại=%d)" % [int(floor(wx / SIZE)), int(floor(wz / SIZE)), wm_count])
	_check(found >= 1, "tìm thấy dây dưa dại trong chunk thật (%d chunk, tổng %d cây)" % [scans, total_wm])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
