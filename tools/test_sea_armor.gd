extends Node3D
## test_sea_armor — Khí độc rừng ngập mặn:
##  - Trong rừng mà MẶC THIẾU giáp biển → mất đúng 4 HP mỗi tick (MANGROVE_TOXIN_DMG),
##    cảnh báo 1 lần (_mangrove_warned).
##  - Đủ 4 món Giáp Biển → không mất máu (bộ giáp là cách duy nhất kháng).
##  - Ngoài rừng ngập mặn → không bị ngấm độc.
## Chạy qua tools/test_sea_armor.tscn (không chạy trực tiếp .gd).

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _Damage = preload("res://scripts/core/damage_system.gd")

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
	print("== test_sea_armor: khí độc rừng ngập mặn + bộ Giáp Biển ==")
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db

	var spot := _mangrove_spot()
	_check(spot != Vector3.INF, "tìm được lõi rừng ngập mặn (seed %d)" % SEED)
	if spot == Vector3.INF:
		print("TOTAL | FAIL | 0 (không có lõi để test)")
		get_tree().quit(1)
		return

	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	p.max_hp = 200
	p.global_position = spot

	# ── 0. _count_sea_armor đếm theo đúng 4 slot ────────────────────────────────
	var partial: int = p._count_sea_armor()
	_check(partial == 0, "chưa mặc gì → _count_sea_armor = 0 (có %d)" % partial)

	# ── 1. Trong rừng, không giáp → -4 HP mỗi tick, warning 1 lần ──────────────
	p.hp = 200
	p._mangrove_warned = false
	p._mangrove_toxin_timer = 0.0
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 196, "không giáp trong rừng: 1 tick → hp 196 (hp=%d)" % p.hp)
	_check(p._mangrove_warned, "không giáp: cảnh báo khí độc 1 lần")
	# Vẫn đứng trong rừng: tick thứ 2 → 192
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 192, "tick thứ 2 → hp 192 (hp=%d)" % p.hp)

	# ── 2. Đủ bộ Giáp Biển 4 món → không mất máu ───────────────────────────────
	p.equipped_head = db["sea_helmet"]
	p.equipped_body = db["sea_chestplate"]
	p.equipped_legs = db["sea_leggings"]
	p.equipped_feet = db["sea_boots"]
	_check(p._count_sea_armor() == 4, "mặc 4 món giáp biển → _count_sea_armor = 4")
	p.hp = 200
	p._mangrove_warned = false
	p._mangrove_toxin_timer = 0.0
	p._tick_mangrove_toxin(1.0)
	p._tick_mangrove_toxin(1.0)
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 200, "đủ giáp biển trong rừng: 3 tick → hp vẫn 200 (hp=%d)" % p.hp)
	_check(not p._mangrove_warned, "đủ giáp biển: không báo khí độc")

	# ── 3. Chỉ 2 món → vẫn ngấm độc (-4) ───────────────────────────────────────
	p.equipped_head = db["sea_helmet"]
	p.equipped_body = db["sea_chestplate"]
	p.equipped_legs = db["iron_leggings"]
	p.equipped_feet = db["iron_boots"]
	_check(p._count_sea_armor() == 2, "mặc 2 món giáp biển + 2 sắt → _count_sea_armor = 2")
	p.hp = 200
	p._mangrove_toxin_timer = 0.0
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 196, "chỉ 2 món giáp biển → vẫn mất 4 HP (hp=%d)" % p.hp)

	# ── 4. Khôi phục giáp đủ, ra ngoài rừng → không ngấm độc ────────────────────
	p.equipped_head = db["sea_helmet"]
	p.equipped_body = db["sea_chestplate"]
	p.equipped_legs = db["sea_leggings"]
	p.equipped_feet = db["sea_boots"]
	p.global_position = Vector3(0.0, 2.0, 0.0)   # spawn (0,0) không phải rừng
	p.hp = 200
	p._mangrove_active = true
	p._mangrove_warned = false
	p._mangrove_toxin_timer = 0.0
	p._tick_mangrove_toxin(1.0)
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 200 and not p._mangrove_active, "ngoài rừng: không ngấm độc (hp=%d, active=%s)" % [p.hp, str(p._mangrove_active)])
	_check(p._is_in_mangrove() == false, "_is_in_mangrove() = false tại (0,0)")

	# ── 5. Tử vong khi HP = 3 trong rừng không giáp ─────────────────────────────
	p.global_position = spot
	p.equipped_head = null
	p.equipped_body = null
	p.equipped_legs = null
	p.equipped_feet = null
	p.max_hp = 200
	p.hp = 3
	p._mangrove_warned = true
	p._mangrove_toxin_timer = 0.0
	p._tick_mangrove_toxin(1.0)
	_check(p.hp == 0, "không giáp, hp=3 trong rừng → hp 0 (hp=%d)" % p.hp)
	_check(not p.is_alive, "không giáp, hp=3 trong rừng → chết (is_alive=false)")
	_Damage.revive(p)

	p.queue_free()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)