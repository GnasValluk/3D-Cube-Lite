extends Node3D
## test_mangrove_gen — Rừng ngập mặn (gen + block + item):
##  1. Nhiều seed: _noise_for_dim(RW) chứa đủ 3 noise mangrove (mangrove /
##     mangrove_inner / mangrove_terr); tồn tại điểm _mangrove_strength_at >= 0.5
##     ven biển trong bán kính khảo sát; find_mangrove() tìm được lõi (>= 0.60).
##  2. Block mới (MANGROVE_MUD = 47, MANGROVE_WOOD = 48): mapping id↔tên hai
##     chiều khớp nhau, BLOCK_HARDNESS đúng (bùn xẻng 1.3, gỗ rìu 1.5), is_soil/till.
##  3. Item mới + bộ Giáp Biển tồn tại trong ItemDatabase, recipe sea_* khả dụng.
## Chạy qua tools/test_mangrove_gen.tscn (không chạy trực tiếp .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")

const SEEDS := [20260805, 123456789, 777, 20260806]
const RW := _D._Dim.DimensionID.REAL_WORLD
const B := _D.BlockID

const SCAN_STEP := 600.0
const SCAN_MAX := 24000.0

var _failures: int = 0
var _nd: Dictionary = {}

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _fresh_nd(s: int) -> Dictionary:
	WorldSeed.seed_value = s
	_W._Noise.clear_cache()
	return _W._noise_for_dim(RW)

## Quét vòng xoắn thô (bước 600) tìm điểm có cường độ rừng đước >= threshold.
## Trả Vector2 hoặc Vector2.ZERO nếu không tìm thấy trong SCAN_MAX.
func _find_sample(pmin: float) -> Vector2:
	var origin := Vector2.ZERO
	var r := SCAN_STEP
	while r <= SCAN_MAX:
		var samples: int = max(8, int(r / SCAN_STEP * TAU))
		for i in range(samples):
			var a: float = float(i) / float(samples) * TAU
			var sp := origin + Vector2(cos(a), sin(a)) * r
			if _W._mangrove_strength_at(_nd, sp.x, sp.y) >= pmin:
				return sp
		r += SCAN_STEP
	return Vector2.ZERO

func _ready() -> void:
	print("== test_mangrove_gen: Rừng ngập mặn (gen + block + item) ==")

	# ── 1. Noise đủ 3 kênh mangrove + mask tìm thấy điểm ≥0.5 + find_mangrove ──
	print("-- 1. Noise + mask mangrove (nhiều seed) --")
	for s in SEEDS:
		_nd = _fresh_nd(s)
		_check(_nd.get("mangrove") is FastNoiseLite, "seed %d: noise 'mangrove' có" % s)
		_check(_nd.get("mangrove_inner") is FastNoiseLite, "seed %d: noise 'mangrove_inner' có" % s)
		_check(_nd.get("mangrove_terr") is FastNoiseLite, "seed %d: noise 'mangrove_terr' có" % s)
		var sp := _find_sample(0.5)
		_check(sp != Vector2.ZERO, "seed %d: có điểm strength ≥ 0.5 trong 24000 block" % s)
		if sp != Vector2.ZERO:
			var fm := _W.find_mangrove(sp.x, sp.y, 2000.0)
			_check(bool(fm.get("ok", false)), "seed %d: find_mangrove tìm được lõi gần điểm tìm thấy" % s)
			if bool(fm.get("ok", false)):
				var st: float = _W._mangrove_strength_at(_nd, float(fm["x"]), float(fm["z"]))
				_check(st >= 0.60, "seed %d: lõi teleport có strength ≥ 0.60 (có %f)" % [s, st])
		# Ở giữa đại dương xa bờ → cường độ phải = 0 (bị clamp)
		var far_st: float = _W._mangrove_strength_at(_nd, 0.0, 200000.0)
		_check(far_st == 0.0, "seed %d: xa bờ (đại dương) strength = 0 (có %f)" % [s, far_st])

	# ── 2. Block mới: mapping id↔tên + hardness + soil/till/shovel/axe ─────────
	print("-- 2. Block MANGROVE_MUD / MANGROVE_WOOD --")
	_check(_D.BLOCK_TO_ITEM.get(B.MANGROVE_MUD) == "block_mangrove_mud", "MANGROVE_MUD → item 'block_mangrove_mud'")
	_check(_D.BLOCK_TO_ITEM.get(B.MANGROVE_WOOD) == "mangrove_wood", "MANGROVE_WOOD → item 'mangrove_wood'")
	_check(_D.ITEM_TO_BLOCK.get("block_mangrove_mud") == B.MANGROVE_MUD, "'block_mangrove_mud' → MANGROVE_MUD")
	_check(_D.ITEM_TO_BLOCK.get("mangrove_wood") == B.MANGROVE_WOOD, "'mangrove_wood' → MANGROVE_WOOD")
	_check(B.MANGROVE_MUD == 47 and B.MANGROVE_WOOD == 48, "id đúng: MANGROVE_MUD=47, MANGROVE_WOOD=48")
	_check(absf(_D.BLOCK_HARDNESS.get(B.MANGROVE_MUD, -1.0) - 1.3) < 0.0001, "hardness bùn = 1.3")
	_check(absf(_D.BLOCK_HARDNESS.get(B.MANGROVE_WOOD, -1.0) - 1.5) < 0.0001, "hardness gỗ đước = 1.5")
	_check(_D.is_shovelable(B.MANGROVE_MUD), "MANGROVE_MUD đào được bằng xẻng")
	_check(_D.is_axable(B.MANGROVE_WOOD), "MANGROVE_WOOD chặt được bằng rìu")
	_check(_D.is_tillable(B.MANGROVE_MUD), "MANGROVE_MUD cày được (ruộng lúa đầm lầy)")
	_check(_D.grass_dirt_id(B.MANGROVE_MUD) == B.MANGROVE_MUD, "grass_dirt_id(MANGROVE_MUD) = MANGROVE_MUD")

	# ── 3. Item mới + bộ Giáp Biển + recipe ─────────────────────────────────────
	print("-- 3. Item + Giáp Biển + recipe --")
	ItemDatabase.ensure_db()
	RecipeDatabase.ensure()
	var db := ItemDatabase.items_db
	for kid in ["block_mangrove_mud", "mangrove_wood", "mangrove_seed", "cattail", "mud_crab"]:
		_check(db.has(kid) and db[kid] != null, "item '%s' có trong ItemDatabase" % kid)
	_check(db["mud_crab"].type == ItemDef.Type.FOOD, "mud_crab là FOOD (ăn hồi máu)")
	_check(db["mangrove_seed"].type == ItemDef.Type.MATERIAL, "mangrove_seed là MATERIAL (trồng được)")
	var sea_items := ["sea_helmet", "sea_chestplate", "sea_leggings", "sea_boots"]
	for sid2 in sea_items:
		_check(db.has(sid2) and db[sid2] != null, "giáp biển '%s' có trong ItemDatabase" % sid2)
	var slots := {
		"sea_helmet": ItemDef.ArmorSlot.HEAD,
		"sea_chestplate": ItemDef.ArmorSlot.BODY,
		"sea_leggings": ItemDef.ArmorSlot.LEGS,
		"sea_boots": ItemDef.ArmorSlot.FEET,
	}
	for sid3 in sea_items:
		_check(db[sid3].armor_slot == slots[sid3], "giáp biển '%s' đúng slot (%s)" % [sid3, slots[sid3]])
	# Recipe: 4 món sea_* phải craft được với nguyên liệu ngoài rừng (rong + dừa + sắt).
	var recipe_ids: Array = RecipeDatabase.recipes.map(func(r): return (r as Dictionary).get("id"))
	for rid in sea_items:
		_check(rid in recipe_ids, "recipe '%s' tồn tại" % rid)
	var ingredients_ok := true
	for r in RecipeDatabase.recipes:
		var rd: Dictionary = r
		if String(rd.get("id", "")).begins_with("sea_"):
			var ing: Dictionary = rd.get("ingredients", {})
			if not (ing.has("tropical_seaweed") and ing.has("coconut")):
				ingredients_ok = false
	_check(ingredients_ok, "mọi recipe sea_* chỉ dùng rong biển + dừa (+ sắt) — craft được trước khi vào rừng")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)