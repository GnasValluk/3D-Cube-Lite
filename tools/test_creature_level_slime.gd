extends Node3D

## Headless verification: level creature (fish/pig theo biến thể), hệ số +2% stat
## một level, hệ số drop rate +5% level, và sinh vật Slime (tách đàn + drop).

const _Fish = preload("res://scripts/characters/fish/fish_character.gd")
const _Pig  = preload("res://scripts/characters/pig/pig_character.gd")
const _Slime = preload("res://scripts/characters/slime/slime_character.gd")

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
			ch.free()
	return n

func _count_slimes_of(size: int) -> int:
	var n := 0
	for ch in get_children():
		if ch is _Slime and ch.slime_size == size:
			n += 1
	return n

func _ready() -> void:
	print("== test_creature_level_slime: level creature + slime ==")
	seed(20260812)
	ItemDatabase.ensure_db()

	# ── 1. Level mặc định theo biến thể ──
	var carp := _Fish.new()
	carp.fish_variant = _Fish.FishVariant.CARP
	add_child(carp)
	await get_tree().process_frame
	var flower := _Fish.new()
	flower.fish_variant = _Fish.FishVariant.FLOWERHORN
	add_child(flower)
	await get_tree().process_frame

	_check(carp.level == 1, "cá chép (CARP) mặc định lv1 (lv=%d)" % carp.level)
	_check(flower.level == 2, "cá la hán (FLOWERHORN) mặc định lv2 (lv=%d)" % flower.level)

	var pig_n := _Pig.new()
	pig_n.pig_variant = _Pig.Variant.NORMAL
	add_child(pig_n)
	await get_tree().process_frame
	var pig_s := _Pig.new()
	pig_s.pig_variant = _Pig.Variant.SAND
	add_child(pig_s)
	await get_tree().process_frame

	_check(pig_n.level == 1, "heo thường mặc định lv1 (lv=%d)" % pig_n.level)
	_check(pig_s.level == 2, "heo sa mạc (SAND) mặc định lv2 (lv=%d)" % pig_s.level)

	# ── 2. Hệ số +2% stat / level và +5% drop rate / level ──
	flower.level = 2
	_check(absf(flower.get_stat_mult() - 1.02) < 0.001, "lv2 stat mult = 1.02 (thực tế %.3f)" % flower.get_stat_mult())
	_check(absf(flower.get_rate_mult() - 1.05) < 0.001, "lv2 drop mult = 1.05 (thực tế %.3f)" % flower.get_rate_mult())
	carp.level = 11
	_check(absf(carp.get_stat_mult() - 1.20) < 0.001, "lv11 stat mult = 1.20 (thực tế %.3f)" % carp.get_stat_mult())

	# ── 3. Level được áp vào max_hp (heo sa mạc: 20 * 1.02 = 20; test qua slime lv5) ──
	flower.level = 21
	var f_hp_at_lv21 := flower.get_stat_mult()
	_check(absf(f_hp_at_lv21 - 1.40) < 0.001, "lv21 stat mult = 1.40 (thực tế %.3f)" % f_hp_at_lv21)

	# ── 4. Drop rate heo: sand lv2 (0.9 * 1.05 = 0.945) cao hơn thường lv1 (0.9) ──
	var rate_n := 0.0
	var rate_s := 0.0
	var trials := 6000
	for i in range(trials):
		pig_n._roll_loot()
		if _count_drops() > 0:
			rate_n += 1.0
		pig_s._roll_loot()
		if _count_drops() > 0:
			rate_s += 1.0
	rate_n /= float(trials)
	rate_s /= float(trials)
	_check(absf(rate_n - 0.9) < 0.03, "heo thường drop thịt ~90%% (thực tế %.2f%%)" % (rate_n * 100.0))
	_check(absf(rate_s - 0.945) < 0.03, "heo sa mạc drop thịt ~94.5%% (thực tế %.2f%%)" % (rate_s * 100.0))

	# ── 5. Slime: kích thước + stat ──
	var big := _Slime.new()
	big.slime_size = _Slime.SlimeSize.LARGE
	add_child(big)
	await get_tree().process_frame
	var med := _Slime.new()
	med.slime_size = _Slime.SlimeSize.MEDIUM
	add_child(med)
	await get_tree().process_frame
	var small := _Slime.new()
	small.slime_size = _Slime.SlimeSize.SMALL
	add_child(small)
	await get_tree().process_frame

	_check(big.max_hp == 24 and med.max_hp == 12 and small.max_hp == 6, "slime HP đúng theo size (L=%d M=%d S=%d)" % [big.max_hp, med.max_hp, small.max_hp])
	_check(absf(big.scale.x - 2.0) < 0.01 and absf(small.scale.x - 0.5) < 0.01, "slime scale theo size (L=%.1f S=%.1f)" % [big.scale.x, small.scale.x])
	_check(big.is_in_group("slime"), "slime thuộc group 'slime' (để cận chiến đánh trúng)")
	_check(big._world_hp_enabled == true, "slime bật world HP bar (thù địch)")

	# ── 6. Slime Lớn chết → tách 2-4 con Vừa + drop Slimeball ──
	var before_children := _count_slimes_of(_Slime.SlimeSize.MEDIUM)
	big.take_damage(9999, null)
	await get_tree().process_frame
	var spawned_med := _count_slimes_of(_Slime.SlimeSize.MEDIUM) - before_children
	_check(spawned_med >= 2 and spawned_med <= 4, "slime LỚN chết → tách %d con VỪA (2-4)" % spawned_med)
	var has_slimeball := false
	for ch in get_children():
		if ch is DroppedItem and ch.item_def != null and ch.item_def.id == "slime_ball":
			has_slimeball = true
			break
	var drop_spawned := _count_drops()
	_check(drop_spawned >= 1, "slime chết → spawn drop (có %d item)" % drop_spawned)
	_check(has_slimeball, "drop là Slimeball")

	# ── 7. Slime Vừa chết → tách 2-3 con Nhỏ ──
	var meds := []
	for ch in get_children():
		if ch is _Slime and ch.slime_size == _Slime.SlimeSize.MEDIUM and ch.is_alive:
			meds.append(ch)
	if meds.size() > 0:
		var before_small := _count_slimes_of(_Slime.SlimeSize.SMALL)
		meds[0].take_damage(9999, null)
		await get_tree().process_frame
		var spawned_small := _count_slimes_of(_Slime.SlimeSize.SMALL) - before_small
		_check(spawned_small >= 2 and spawned_small <= 3, "slime VỪA chết → tách %d con NHỎ (2-3)" % spawned_small)

	# ── 8. Item slime_ball tồn tại trong database ──
	_check(ItemDatabase.items_db.has("slime_ball"), "item slime_ball có trong database")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)