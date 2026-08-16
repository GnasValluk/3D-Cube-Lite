extends Node

## Headless verification: hệ thống effect làm chậm (5 cấp) + cơ chế trọng lượng quá tải.
## Chạy qua tools/test_effects.tscn (không chạy trực tiếp file .gd).

const _PlayerChar := preload("res://scripts/characters/player/player_character.gd")
const _Inv := preload("res://scripts/items/core/inventory.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260808)
	ItemDatabase.ensure_db()

	# ── 1. Bảng cấp làm chậm ─────────────────────────────────────────────
	print("-- 1. StatusEffects: 5 cấp làm chậm --")
	var fx := StatusEffects.new()
	_check(absf(fx.get_move_multiplier() - 1.0) < 0.0001, "không hiệu ứng → tốc độ 100%")
	_check(fx.can_jump(), "không hiệu ứng → nhảy được")
	_check(fx.can_interact(), "không hiệu ứng → tương tác được")
	_check(not fx.has_active_effect(), "không hiệu ứng → không có effect")

	var expect := {1: 0.85, 2: 0.70, 3: 0.50, 4: 0.30, 5: 0.05}
	for lvl in range(1, 6):
		fx.set_persistent_slow(lvl)
		_check(absf(fx.get_move_multiplier() - expect[lvl]) < 0.0001,
			"làm chậm %d → tốc độ %.0f%%" % [lvl, expect[lvl] * 100.0])
	_check(fx.can_jump() == (fx.get_slow_level() < 4), "cấp 4+ chặn nhảy")
	_check(fx.can_interact() == (fx.get_slow_level() < 5), "cấp 5 chặn tương tác")
	fx.set_persistent_slow(0)
	_check(fx.get_slow_level() == 0 and absf(fx.get_move_multiplier() - 1.0) < 0.0001,
		"tắt làm chậm → khôi phục 100%")

	# ── 2. Làm chậm tạm thời: hết thời gian tự hết ───────────────────────
	print("-- 2. Làm chậm tạm thời theo thời gian --")
	var tmp := StatusEffects.new()
	tmp.apply_slow(1, 2.0)
	_check(tmp.get_slow_level() == 1, "apply_slow(1, 2s) → cấp 1")
	tmp.tick(2.5)
	_check(tmp.get_slow_level() == 0, "hết 2s → hết hiệu ứng")
	tmp.apply_slow(2, 1.0)
	tmp.apply_slow(5, 1.0)
	_check(tmp.get_slow_level() == 5, "cấp cao hơn giữ lại (2 → 5)")
	tmp.clear_slow()
	_check(tmp.get_slow_level() == 0, "clear_slow → về 0")

	# ── 3. Trọng lượng item ──────────────────────────────────────────────
	print("-- 3. ItemDef có trọng lượng --")
	var db := ItemDatabase.items_db
	_check((db["chest"] as ItemDef).weight == 2.0, "rương 2.0")
	_check((db["furnace"] as ItemDef).weight == 2.5, "lò nung 2.5")
	_check((db["pickaxe"] as ItemDef).weight == 1.2, "cúp sắt 1.2")
	_check((db["iron_greatsword"] as ItemDef).weight == 3.0, "đại kiếm 3.0")
	_check((db["watermelon"] as ItemDef).weight == 2.0, "dưa hấu 2.0")
	_check((db["eggplant_fruit"] as ItemDef).weight == 0.3, "cà tím 0.3")
	_check((db["eggplant_seed"] as ItemDef).weight == 0.05, "hạt cà tím 0.05")
	_check(absf((db["carp"] as ItemDef).weight - 0.5) < 0.0001, "cá chép 0.5 (override)")
	_check(absf((db["block_dirt"] as ItemDef).weight - 0.4) < 0.0001,
		"block mặc định 0.4 mỗi khối")

	# ── 4. Tổng trọng lượng kho đồ ───────────────────────────────────────
	print("-- 4. Inventory.get_total_weight --")
	var inv := _Inv.new()
	var egg_seed: ItemDef = db["eggplant_seed"] as ItemDef
	var heavy := ItemDef.new("test_heavy", "Test", ItemDef.Type.BLOCK, Color.WHITE, "H")
	heavy.weight = 30.0
	inv.add_item(egg_seed, 10)
	_check(absf(inv.get_total_weight() - 0.5) < 0.0001, "10 hạt × 0.05 = 0.5")
	inv.add_item(heavy, 4)
	_check(absf(inv.get_total_weight() - 120.5) < 0.0001, "10 hạt + 4 khối nặng = 120.5")
	inv.remove_item_by_id("test_heavy", 4)
	_check(absf(inv.get_total_weight() - 0.5) < 0.0001, "bỏ 4 khối → 0.5")

	# ── 5. Quá tải trên nhân vật ─────────────────────────────────────────
	print("-- 5. Quá tải: vượt ngưỡng → slow 2, vượt 25% → slow 5 --")
	var pc := _PlayerChar.new()
	pc.name = "TestPlayer"
	pc.max_weight = 100.0
	add_child(pc)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(pc.effects.get_slow_level() == 0, "kho rỗng → không quá tải")
	pc.inventory.add_item(heavy, 4)
	pc.update_overload_effects()
	_check(pc.effects.get_slow_level() == 2, "120 > 100 → làm chậm 2")
	_check(absf(pc.get_speed_multiplier() - 0.70) < 0.0001, "slow 2 → tốc độ 70%")
	_check(pc.can_jump(), "slow 2 vẫn nhảy")
	_check(pc.can_interact(), "slow 2 vẫn tương tác")

	pc.inventory.add_item(heavy, 2)
	pc.update_overload_effects()
	_check(pc.effects.get_slow_level() == 5, "180 > 125 (vượt 25%) → làm chậm 5")
	_check(absf(pc.get_speed_multiplier() - 0.05) < 0.0001, "slow 5 → tốc độ 5%")
	_check(not pc.can_jump(), "slow 5 → không nhảy")
	_check(not pc.can_interact(), "slow 5 → không tương tác")

	pc.inventory.remove_item_by_id("test_heavy", 6)
	pc.update_overload_effects()
	_check(pc.effects.get_slow_level() == 0, "dọn kho → hết quá tải")
	_check(absf(pc.get_speed_multiplier() - 1.0) < 0.0001, "tốc độ khôi phục 100%")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)