extends Node3D

## Headless verification: bụi cherry tím dại (PlainsBushProp — gò lá dày chunky
## kiểu tán cây sồi, chùm nhánh thấp vươn ra, quả cherry tím mọng mọc xòe trên
## mặt tán khi CHÍN), item quả cherry tím, chặt/đập bụi chín rụng quả, và bụi
## dại mọc rải rác trên đồng cỏ chunk thật.
## Chạy qua tools/test_plains_bush.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Bush = preload("res://scripts/world/props/plains_bush_prop.gd")
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
	seed(20260817)
	ItemDatabase.ensure_db()

	# ── 1. Item cherry ─────────────────────────────────────────────────────
	print("-- 1. Item quả cherry tím --")
	var cherry: ItemDef = ItemDatabase.items_db.get("cherry") as ItemDef
	_check(cherry != null, "item cherry tồn tại")
	_check(cherry != null and cherry.type == ItemDef.Type.FOOD, "cherry loại FOOD")
	_check(cherry != null and cherry.heal_amount == 4, "quả cherry hồi 4 HP (có %d)" % (cherry.heal_amount if cherry else -1))
	_check(cherry != null and absf(cherry.eat_time - 1.0) < 0.01, "ăn nhanh 1.0s (có %s)" % (str(cherry.eat_time) if cherry else "null"))
	_check(cherry != null and cherry.max_stack == 16, "cherry stack 16 (có %d)" % (cherry.max_stack if cherry else -1))

	# ── 2. Icon 3D ────────────────────────────────────────────────────────
	print("-- 2. Icon 3D --")
	var icon := Node3D.new()
	add_child(icon)
	ItemMesh.build(icon, "cherry")
	_check(icon.get_child_count() > 0, "icon cherry có mesh (children=%d)" % icon.get_child_count())
	icon.queue_free()

	# ── 3. Giai đoạn phát triển ───────────────────────────────────────────
	print("-- 3. Vòng đời bụi cherry --")
	var bush := _Bush.new(40, DestroyableProp.WeaponReq.SWORD, "cherry")
	bush.setup("plains")
	bush.position = Vector3(4.5, 0.25, 0.5)
	add_child(bush)

	bush.set_birth_age_days(1.0)
	_check(bush._stage == _Growing.Stage.SPROUT, "1 ngày = cây mầm")
	_check(bush.find_child("BushVisual", false, false) != null, "mầm có visual voxel")
	_check(bush._berry_positions.size() == 0, "mầm chưa có quả")

	bush.set_birth_age_days(15.0)
	_check(bush._stage == _Growing.Stage.YOUNG, "15 ngày = bụi non")
	_check(bush._berry_positions.size() == 0, "bụi non chưa có quả")
	_check(bush.find_child("BushCollision", false, false) != null, "bụi có collision")

	bush.set_birth_age_days(32.0)
	_check(bush._stage == _Growing.Stage.MATURE, "32 ngày = bụi trưởng thành")
	_check(bush._berry_positions.size() == 0, "bụi trưởng thành chưa chín quả")

	bush.set_birth_age_days(55.0)
	_check(bush._stage == _Growing.Stage.RIPE, "55 ngày = bụi chín")
	var n_berry: int = bush._berry_positions.size()
	_check(n_berry >= 8, "mặt tán mọc chùm cherry tím (≥8 quả, có %d)" % n_berry)
	_check(bush._berry_colors.size() == n_berry, "số màu quả khớp số quả (%d)" % bush._berry_colors.size())
	if n_berry > 0:
		var max_y: float = -1e9
		for p in bush._berry_positions:
			max_y = maxf(max_y, p.y)
		_check(max_y > 0.1, "quả mọc trên tán (cao nhất y=%.2f)" % max_y)

	# ── 4. Thu hoạch ──────────────────────────────────────────────────────
	print("-- 4. Thu hoạch --")
	_check(bush.try_destroy("iron_sword", 999), "kiếm chặt bụi chín (SWORD req)")
	await get_tree().process_frame
	await get_tree().process_frame
	var ids := _drop_ids()
	_check("cherry" in ids, "bụi chín rơi quả cherry tím (%s)" % str(_drop_counts()))
	_check(_count_drops() >= 1, "rơi được ít nhất 1 quả (có %d)" % _count_drops())

	var before: Dictionary = _drop_counts()
	var young_bush := _Bush.new(40, DestroyableProp.WeaponReq.SWORD, "cherry")
	young_bush.setup("plains")
	young_bush.position = Vector3(6.5, 0.25, 0.5)
	add_child(young_bush)
	young_bush.set_birth_age_days(32.0)
	young_bush.try_destroy("iron_sword", 999)
	await get_tree().process_frame
	await get_tree().process_frame
	var after: Dictionary = _drop_counts()
	_check(after.get("cherry", 0) == before.get("cherry", 0),
		"bụi chưa chín chặt sớm không rơi quả (trước %d → sau %d)"
		% [before.get("cherry", 0), after.get("cherry", 0)])

	# ── 5. Bụi cherry dại trên đồng cỏ ────────────────────────────────────
	print("-- 5. Bụi cherry dại: spawn trong chunk thật --")
	WorldSeed.seed_value = 20260817
	_W._Noise.clear_cache()
	var nd: Dictionary = _W._Noise._noise_for_dim(RW)
	var found := 0
	var total_bush := 0
	var scans := 0
	for x in range(-4000, 4001, SIZE * 8):
		for z in range(-4000, 4001, SIZE * 8):
			if found > 0 or scans >= 6:
				break
			var wx := float(x) + 0.5
			var wz := float(z) + 0.5
			if _W._ocean_mask_at(nd, wx, wz):
				continue
			var bb: int = _W._Noise._biome_at(wx, wz, RW)
			if bb != _D.TileType.GRASS_DIRT:
				continue
			scans += 1
			print("   (compute chunk %d,%d...)" % [int(floor(wx / SIZE)), int(floor(wz / SIZE))])
			var data := _W.compute_chunk(int(floor(wx / SIZE)), int(floor(wz / SIZE)), SIZE, RW)
			var bush_count := 0
			for p in data.get("plant_props", []):
				if p.get("type", "") == "cherry_bush":
					bush_count += 1
			total_bush += bush_count
			if bush_count >= 1:
				found += 1
				print("   (chunk %d,%d: bụi cherry dại=%d)" % [int(floor(wx / SIZE)), int(floor(wz / SIZE)), bush_count])
	_check(found >= 1, "tìm thấy bụi cherry dại trong chunk thật (%d chunk, tổng %d bụi)" % [scans, total_bush])

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)