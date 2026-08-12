extends Node3D
## test_sea_armor — Rừng ngập mặn: đã LOẠI BỎ hiệu ứng khí độc:
##  - Các hàm độc bị xóa: _tick_mangrove_toxin, _count_sea_armor, _is_in_mangrove.
##  - Đứng trong rừng ngập mặn (có giáp hoặc không) không mất HP theo thời gian.
##  - Bộ Giáp Biển (sea_*) vẫn tồn tại: Type.ARMOR, slot đúng, def_bonus > 0.
##  - 4 công thức crafting bộ Giáp Biển vẫn tồn tại.
## Chạy qua tools/test_sea_armor.tscn (không chạy trực tiếp .gd).

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Recipes = preload("res://scripts/items/core/recipe_database.gd")

const RW := _D._Dim.DimensionID.REAL_WORLD
const SEED := 20260805

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


## Đặt seed + đưa noise về đúng seed rồi trả điểm lõi rừng ngập mặn (để đứng trong).
func _mangrove_spot() -> Vector3:
	WorldSeed.seed_value = SEED
	_W._Noise.clear_cache()
	_W._noise_for_dim(RW)
	var fm := _W.find_mangrove(0.0, 0.0, 4000.0)
	if not bool(fm.get("ok", false)):
		return Vector3.INF
	return Vector3(float(fm["x"]), 1.0, float(fm["z"]))


func _ready() -> void:
	print("== test_sea_armor: rừng ngập mặn không còn độc + bộ Giáp Biển ==")
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db

	# ── 1. Các hàm độc đã bị xóa khỏi PlayerCharacter ──────────────────────
	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	_check(not p.has_method("_tick_mangrove_toxin"), "đã xóa _tick_mangrove_toxin")
	_check(not p.has_method("_count_sea_armor"), "đã xóa _count_sea_armor")
	_check(not p.has_method("_is_in_mangrove"), "đã xóa _is_in_mangrove")

	# ── 2. Đứng trong rừng ngập mặn, không giáp → không mất HP qua thời gian ──
	var spot := _mangrove_spot()
	_check(spot != Vector3.INF, "tìm được lõi rừng ngập mặn (seed %d)" % SEED)
	if spot == Vector3.INF:
		print("TOTAL | FAIL | 0 (không có lõi để test)")
		get_tree().quit(1)
		return

	p.max_hp = 200
	p.hp = 200
	p.global_position = spot
	p.equipped_head = null
	p.equipped_body = null
	p.equipped_legs = null
	p.equipped_feet = null

	var hp_before := p.hp
	for _t in range(5):
		p._process(1.0)
	_check(p.hp == hp_before, "trong rừng không giáp: 5s không mất HP (hp=%d, expected %d)" % [p.hp, hp_before])

	# ── 3. Mặc đủ bộ Giáp Biển trong rừng → cũng không mất HP (không còn cơ chế) ──
	var sea_items := {
		"sea_helmet":     ItemDef.ArmorSlot.HEAD,
		"sea_chestplate": ItemDef.ArmorSlot.BODY,
		"sea_leggings":   ItemDef.ArmorSlot.LEGS,
		"sea_boots":      ItemDef.ArmorSlot.FEET,
	}
	var defs_ok := true
	for id in sea_items.keys():
		var it: ItemDef = db.get(id)
		if it == null:
			defs_ok = false
			continue
		if it.type != ItemDef.Type.ARMOR:
			defs_ok = false
			continue
		if it.armor_slot != sea_items[id]:
			defs_ok = false
			continue
		if it.def_bonus <= 0.0:
			defs_ok = false
	p.equipped_head = db["sea_helmet"]
	p.equipped_body = db["sea_chestplate"]
	p.equipped_legs = db["sea_leggings"]
	p.equipped_feet = db["sea_boots"]
	p.hp = 200
	for _t in range(5):
		p._process(1.0)
	hp_before = 200
	_check(p.hp == hp_before, "trong rừng mặc đủ Giáp Biển: không mất HP (hp=%d)" % p.hp)
	_check(defs_ok, "4 món Giáp Biển: Type.ARMOR + slot đúng + def_bonus > 0")

	# ── 4. Công thức crafting bộ Giáp Biển tồn tại ────────────────────────────
	_Recipes.ensure()
	var recipes: Array = []
	for r in _Recipes.recipes:
		if sea_items.keys().has(r["result"]):
			recipes.append(r)
	_check(recipes.size() == 4, "4 công thức crafting Giáp Biển tồn tại (có %d)" % recipes.size())

	p.queue_free()
	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
