extends Node3D

## Headless verification: thực vật đồng bằng mới (PlainsFloraProp) —
## Bụi dâu dại (wild_berry/FOOD), Cỏ ba lá (clover/MATERIAL), 3 hoa
## (sunflower/tulip/rose) + hạt giống. Kiểm tra item DB, mesh build, drop chính +
## hạt, spawn trong chunk thật (mọi khối cỏ đồng bằng), icon ItemMesh, và cỏ khô vàng
## (grass zone 1) so với cỏ xanh tươi (zone 0). Chạy qua tools/test_plains_flora.tscn.

const _Grass = preload("res://scripts/world/chunk/chunk_grass.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Flora = preload("res://scripts/world/props/plains_flora_prop.gd")

const RW := _D._Dim.DimensionID.REAL_WORLD
const SIZE := 32

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

func _has_mesh(node: Node) -> bool:
	for ch in node.get_children():
		if ch is MeshInstance3D:
			return true
	return false

func _ready() -> void:
	seed(20260811)
	print("== test_plains_flora: Hoa & thực vật đồng bằng mới ==")

	# ── 1. Items ────────────────────────────────────────────────────────────
	ItemDatabase.ensure_db()
	for id in ["wild_berry", "clover", "sunflower", "sunflower_seed",
			"tulip", "tulip_seed", "rose", "rose_seed"]:
		_check(ItemDatabase.items_db.has(id), "db có item %s" % id)
	var wb: ItemDef = ItemDatabase.items_db.get("wild_berry") as ItemDef
	_check(wb != null and wb.type == ItemDef.Type.FOOD and wb.heal_amount == 6,
		"wild_berry là FOOD, hồi 6 HP")
	var cl: ItemDef = ItemDatabase.items_db.get("clover") as ItemDef
	_check(cl != null and cl.type == ItemDef.Type.MATERIAL, "clover là MATERIAL")

	# ── 2. Mesh build + drop ────────────────────────────────────────────────
	print("-- 2. Prop mesh + drop --")
	var bush := _Flora.new(30, DestroyableProp.WeaponReq.NONE, "wild_berry")
	bush.setup("wild_berry")
	bush.position = Vector3(3, 0.25, 0)
	add_child(bush)
	_check(_has_mesh(bush), "bụi dâu dại có mesh")
	bush.try_destroy("", 999)
	await get_tree().process_frame
	await get_tree().process_frame
	var ids1 := _drop_ids()
	_check("wild_berry" in ids1, "chặt bụi dâu rơi Dâu Mâm Xôi")
	_check(not ("sunflower_seed" in ids1), "bụi dâu không rơi hạt hoa")

	var flower := _Flora.new(30, DestroyableProp.WeaponReq.NONE, "sunflower")
	flower.setup("sunflower")
	flower.position = Vector3(3, 0.25, 4)
	add_child(flower)
	_check(_has_mesh(flower), "hoa hướng dương có mesh")
	flower.try_destroy("", 999)
	await get_tree().process_frame
	await get_tree().process_frame
	var ids2 := _drop_ids()
	_check("sunflower" in ids2 and "sunflower_seed" in ids2,
		"chặt hướng dương rơi hoa + hạt giống")

	# ── 3. Icon ItemMesh ────────────────────────────────────────────────────
	print("-- 3. Icon 3D --")
	for id in ["wild_berry", "clover", "sunflower", "sunflower_seed",
			"tulip", "tulip_seed", "rose", "rose_seed"]:
		var icon := Node3D.new()
		add_child(icon)
		ItemMesh.build(icon, id)
		_check(icon.get_child_count() > 0, "icon %s có mesh (children=%d)" % [id, icon.get_child_count()])
		icon.queue_free()

	# ── 4. 2 style cỏ: xanh tươi (zone 0) vs cỏ khô vàng (zone 1) ────────
	print("-- 4. Cỏ đồng bằng: xanh tươi + cỏ khô vàng --")
	var green_colors: Array = []
	var dry_colors: Array = []
	var zone0_found := false
	var zone1_found := false
	seed(20260811)
	for wx in range(-2000, 2001, 8):
		for wz in range(-2000, 2001, 8):
			var z: int = _Grass._grass_zone(float(wx), float(wz))
			var want: int = -1
			if z == 0 and not zone0_found:
				want = 0
			elif z == 1 and not zone1_found:
				want = 1
			if want < 0:
				continue
			var test := {}
			_gen_grass(Vector2(wx, wz), test)
			if (test.get("colors", []) as Array).is_empty():
				continue
			if want == 0:
				green_colors.assign(test["colors"])
				zone0_found = true
			else:
				dry_colors.assign(test["colors"])
				zone1_found = true
			if zone0_found and zone1_found:
				break
		if zone0_found and zone1_found:
			break
	_check(zone0_found, "có vùng cỏ xanh tươi (zone 0)")
	_check(zone1_found, "có vùng cỏ khô vàng (zone 1)")
	var grn_ok: bool = green_colors.size() > 0
	var grn_dryish := 0
	for c in green_colors:
		var col := c as Color
		if col.r >= col.g:
			grn_dryish += 1
	_check(grn_ok and float(grn_dryish) / float(green_colors.size()) < 0.45,
		"zone xanh: phần lớn lá xanh lục (dry %d/%d)" % [grn_dryish, green_colors.size()])
	var dry_ok: bool = dry_colors.size() > 0
	var dry_greenish := 0
	for c in dry_colors:
		var col := c as Color
		if col.g > col.r:
			dry_greenish += 1
	_check(dry_ok and float(dry_greenish) / float(dry_colors.size()) < 0.45,
		"zone khô: phần lớn lá úa vàng (green %d/%d)" % [dry_greenish, dry_colors.size()])

	# ── 5. Pipeline thật: flora spawn trên MỌI khối cỏ đồng bằng ────────────
	# Trước đây chỉ GRASS_DIRT (dải "nền giữa" mỏng) → gần như không thấy cây.
	print("-- 5. Spawn trong chunk thật (grassy-tile plains) --")
	WorldSeed.seed_value = 20260811
	_W._Noise.clear_cache()
	var nd := _W._Noise._noise_for_dim(RW)
	var found := {}
	var total := {}
	var scan_until := 120
	var scans := 0
	var spawns := 0
	var non_gdir_spawns := 0
	var cand := {}
	for cx in range(-40, 41, 2):
		for cz in range(-40, 41, 2):
			if cand.size() >= 300:
				break
			var wx := float(cx * SIZE) + SIZE * 0.5
			var wz := float(cz * SIZE) + SIZE * 0.5
			if _W._ocean_mask_at(nd, wx, wz):
				continue
			if not _D.is_grass_tile(_W._Noise._biome_at(wx, wz, RW)):
				continue
			cand[Vector2i(cx, cz)] = true
	var keys: Array = cand.keys()
	keys.sort()
	for k in keys:
		if found.size() >= 5 or scans >= scan_until:
			break
		var ck: Vector2i = k
		scans += 1
		var data := _W.compute_chunk(ck.x, ck.y, SIZE, RW)
		var bg: Array = data.get("biome_grid", [])
		for p in data.get("plant_props", []):
			var t: String = p.get("type", "")
			if t in ["clover", "wild_berry", "sunflower", "tulip", "rose"]:
				total[t] = total.get(t, 0) + 1
				found[t] = true
				spawns += 1
				if not bg.is_empty():
					var col_bio: int = bg[clampi(int(p["pos"].x + float(SIZE) * 0.5), 0, SIZE - 1)][clampi(int(p["pos"].z + float(SIZE) * 0.5), 0, SIZE - 1)]
					if col_bio != _D.TileType.GRASS_DIRT:
						non_gdir_spawns += 1
	_check(scans > 0, "quét %d chunk đồng bằng (grassy)" % scans)
	_check(found.has("clover"), "cỏ ba lá spawn trong chunk thật")
	_check(spawns >= 3, "flora đủ dày để nhìn thấy (tổng %d cây)" % spawns)
	_check(non_gdir_spawns > 0, "flora mọc cả trên khối cỏ KHÔNG phải GRASS_DIRT (%d cây)" % non_gdir_spawns)
	var flora_any := found.size() > 0
	_check(flora_any, "thực vật đồng bằng spawn trong chunk thật (%d loài, tổng %d cây)" % [found.size(), spawns])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

## Sinh cỏ tại 1 ô (near water: wdist=0) — trả số lá và gom màu.
func _gen_grass(world: Vector2, out: Dictionary) -> void:
	seed(20260811)
	var xforms: Array = []
	var colors: Array = []
	# green/veg: calling convention add_voxel_grass(vx,vz,pos,out_xforms,out_colors,cols,wdist,hdist)
	# 1 cell, wdist=0 → near_water=true
	var wd := PackedInt32Array([0])
	_Grass.add_voxel_grass(0, 0, Vector3(world.x, 0.1, world.y), xforms, colors, 1, wd)
	out["xforms"] = xforms
	out["colors"] = colors