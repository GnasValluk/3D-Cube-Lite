extends Node3D

## Headless verification: cây cà tím (EggplantProp — bụi thảo phân cành thấp,
## lá to gân tím, hoa sao 5 cánh nhị vàng chanh, quả tím hoàng gia highlight +
## hạt lấp lánh), trái cà tím + trái bổ đôi + túi hạt giống, gieo trên đất
## tơi xốp, thu hoạch rơi trái + hạt, cây dại mọc rải rác trên đồng cỏ.
## Chạy qua tools/test_eggplant.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")
const _Recipe = preload("res://scripts/items/core/recipe_database.gd")
const _Eggplant = preload("res://scripts/world/props/eggplant_prop.gd")
const _Growing = preload("res://scripts/world/props/growing_prop.gd")
const _Road = preload("res://scripts/world/chunk/chunk_road.gd")

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

func _ready() -> void:
	seed(20260807)
	ItemDatabase.ensure_db()

	# ── 1. Items ────────────────────────────────────────────────────────────
	print("-- 1. Items cà tím --")
	var fruit: ItemDef = ItemDatabase.items_db.get("eggplant_fruit") as ItemDef
	var slice: ItemDef = ItemDatabase.items_db.get("eggplant_slice") as ItemDef
	var seed_item: ItemDef = ItemDatabase.items_db.get("eggplant_seed") as ItemDef
	_check(fruit != null and fruit.type == ItemDef.Type.FOOD, "item eggplant_fruit, loại FOOD")
	_check(fruit != null and fruit.heal_amount == 10, "trái cà tím hồi 10 HP")
	_check(fruit != null and absf(fruit.eat_time - 2.5) < 0.01, "ăn trái cà tím mất 2.5s")
	_check(slice != null and slice.type == ItemDef.Type.FOOD and slice.heal_amount == 6,
		"item eggplant_slice, loại FOOD, hồi 6 HP")
	_check(seed_item != null and seed_item.type == ItemDef.Type.MATERIAL
		and seed_item.max_stack == 16, "item eggplant_seed, MATERIAL, stack 16")

	# ── 2. Recipe ───────────────────────────────────────────────────────────
	print("-- 2. Recipe bổ đôi + lấy hạt --")
	_Recipe.ensure()
	_check(_Recipe.recipes.is_empty(), "toàn bộ công thức chế tạo đã bị xoá (còn %d)" % _Recipe.recipes.size())
	var slice_r: Dictionary = _Recipe.match_counts({"eggplant_fruit": 1})
	_check(slice_r.is_empty(), "không còn recipe bổ đôi cà tím (đã xoá)")

	# ── 3. Gieo trồng ──────────────────────────────────────────────────────
	print("-- 3. Gieo hạt trên đất tơi xốp --")
	_check(_Placement._is_seed_item("eggplant_seed"), "eggplant_seed là seed item")
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
	_check(ps._can_plant_seed("eggplant_seed", Vector3(0, 0.5, 0)), "đất tơi xốp → gieo được")
	_check(not ps._can_plant_seed("eggplant_seed", Vector3(0, 1.0, 0)), "cỏ thường → không gieo")
	ps._plant_seed("eggplant_seed", Vector3(0, 0.5, 0))
	var planted := false
	for ch in wm.get_children():
		if ch is _Eggplant:
			planted = true
	_check(planted, "_plant_seed tạo EggplantProp trên đất tơi xốp")

	# ── 4. Cây cà tím 4 giai đoạn ──────────────────────────────────────────
	print("-- 4. Giai đoạn phát triển --")
	var eg := _Eggplant.new(40, DestroyableProp.WeaponReq.SWORD, "eggplant_fruit")
	eg.setup()
	eg.position = Vector3(4.5, 0.25, 0.5)
	add_child(eg)

	# Mầm: 2 lá mầm tím nhẹ, chưa có lá thật/bụi
	eg.set_birth_age_days(1.0)
	_check(eg._stage == _Growing.Stage.SPROUT, "1 ngày = cây mầm")
	_check(eg._vox_leaf == 6, "mầm có đúng 2 lá mầm (6 micro-voxel)")
	_check(eg._vox_bud == 0 and eg._vox_fruit == 0, "mầm chưa có nụ hoa/quả")
	_check(eg.find_child("EggplantFruitVisual", false, false) == null, "mầm không có quả")
	_check(eg.find_child("EggplantGlow", false, false) == null, "mầm không có ánh sáng chín")

	# Cây lớn: bụi lá xòe + nụ hoa tím, chưa hoa nở/quả
	eg.set_birth_age_days(6.0)
	_check(eg._stage == _Growing.Stage.YOUNG, "6 ngày = cây lớn")
	_check(eg._vox_leaf >= 20, "cây lớn có bụi lá (≥20 micro-voxel, có %d)" % eg._vox_leaf)
	_check(eg._vox_bud >= 8, "cây lớn có nụ hoa tím (≥8, có %d)" % eg._vox_bud)
	_check(eg._vox_flower == 0 and eg._vox_fruit == 0, "cây lớn chưa hoa nở/quả")
	_check(eg.find_child("EggplantFruitVisual", false, false) == null, "cây lớn không có quả")

	# Trưởng thành: hoa nở + quả tím chín treo model thật + hạt lấp lánh + glow
	eg.set_birth_age_days(20.0)
	_check(eg._stage == _Growing.Stage.MATURE, "20 ngày = trưởng thành (chín thu hoạch)")
	_check(eg._vox_flower >= 8, "hoa nở 5 cánh + nhị vàng chanh (≥8, có %d)" % eg._vox_flower)
	_check(eg._vox_sparkle >= 3, "hạt lấp lánh tỏa quanh quả chín (≥3, có %d)" % eg._vox_sparkle)
	_check(eg._real_fruit_nodes.size() >= 2, "quả cà tím treo model thật dưới nhánh lá (≥2, có %d)" % eg._real_fruit_nodes.size())
	var eg_fruit_ok := eg._real_fruit_nodes.size() > 0
	for rf in eg._real_fruit_nodes:
		if is_instance_valid(rf) and rf.get_child_count() == 0:
			eg_fruit_ok = false
	_check(eg_fruit_ok, "mỗi trái cà tím có đủ mesh model (cuống + thân quả)")
	_check(eg._bush_h >= 0.85, "cây cà tím cao hơn (bụi ≥0.85, có %.2f)" % eg._bush_h)
	_check(eg._vox_leaf >= 40, "cây lớn nhiều tầng lá (≥40 micro-voxel, có %d)" % eg._vox_leaf)
	_check(eg.find_child("EggplantFruitVisual", false, false) != null, "có quả cà tím (visual riêng)")
	_check(eg.find_child("EggplantGlow", false, false) != null, "có ánh sáng tím báo quả chín")

	# ── 5. Thu hoạch: chặt bằng kiếm, rơi trái + hạt ───────────────────────
	print("-- 5. Thu hoạch --")
	_check(eg.try_destroy("iron_sword", 999), "kiếm chặt cà tím (SWORD req)")
	await get_tree().process_frame
	await get_tree().process_frame
	var ids := _drop_ids()
	_check("eggplant_fruit" in ids, "thu hoạch rơi trái cà tím")
	_check("eggplant_seed" in ids, "thu hoạch rơi hạt giống (trồng lại)")
	_check(_count_drops() >= 3, "rơi ít nhất 2-3 trái + 1 túi hạt (có %d)" % _count_drops())

	# ── 6. Icons ────────────────────────────────────────────────────────────
	print("-- 6. Icon 3D --")
	for id in ["eggplant_fruit", "eggplant_slice", "eggplant_seed"]:
		var icon := Node3D.new()
		add_child(icon)
		ItemMesh.build(icon, id)
		_check(icon.get_child_count() > 0, "icon %s có mesh (children=%d)" % [id, icon.get_child_count()])
		icon.queue_free()

	# ── 7. Cây dại trên đồng cỏ ────────────────────────────────────────────
	# Cà tím dại cần đường cách ≤2 ô (rdist<=2). Quần đảo mới: lòng đồng cỏ
	# sát đường thưa hơn → quét ĐỘNG theo tâm chunk (đất + gần đường + GRASS_DIRT),
	# tính tối đa 120 chunk cho tới khi thấy cây.
	print("-- 7. Cây cà tím dại: spawn trong chunk thật --")
	WorldSeed.seed_value = 20260807
	_W._Noise.clear_cache()
	var nd: Dictionary = _W._Noise._noise_for_dim(RW)
	var _cand := {}
	for cx in range(-40, 41, 2):
		for cz in range(-40, 41, 2):
			if _cand.size() >= 300:
				break
			var wx := float(cx * SIZE) + SIZE * 0.5
			var wz := float(cz * SIZE) + SIZE * 0.5
			if _W._ocean_mask_at(nd, wx, wz):
				continue
			if _W._Noise._biome_at(wx, wz, RW) != _D.TileType.GRASS_DIRT:
				continue
			var near_road := false
			for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
					Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
				if _Road.is_on_road(wx + off.x * 2.0, wz + off.y * 2.0):
					near_road = true
					break
			if not near_road:
				continue
			_cand[Vector2i(cx, cz)] = true
	var keys: Array = _cand.keys()
	keys.sort()
	var found := 0
	var total_eg := 0
	var scans := 0
	for k in keys:
		if found > 0 or scans >= 120:
			break
		var ck: Vector2i = k
		scans += 1
		print("   (compute chunk %d,%d...)" % [ck.x, ck.y])
		var data := _W.compute_chunk(ck.x, ck.y, SIZE, RW)
		var eg_count := 0
		for p in data.get("plant_props", []):
			if p.get("type", "") == "eggplant":
				eg_count += 1
		total_eg += eg_count
		if eg_count >= 1:
			found += 1
			print("   (chunk %d,%d: cà tím dại=%d)" % [ck.x, ck.y, eg_count])
	_check(found >= 1, "tìm thấy cà tím dại trong chunk thật (%d chunk, tổng %d cây)" % [scans, total_eg])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
