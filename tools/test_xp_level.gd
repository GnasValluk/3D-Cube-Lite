extends Node3D

const _Fish = preload("res://scripts/characters/fish/fish_character.gd")
const _Pig = preload("res://scripts/characters/pig/pig_character.gd")
const _ExpOrb = preload("res://scripts/items/entities/experience_orb.gd")
const _CharBase = preload("res://scripts/core/character_base.gd")

var _failures: int = 0
var _lv_signals: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

## Đếm + dọn các ExperienceOrb đẻ trực tiếp dưới `parent` (cha = current_scene
## của player/fish/pig trong runtime — ở đây chính là self).
func _count_and_clear_orbs(parent: Node) -> int:
	var n := 0
	for child in parent.get_children():
		if child is ExperienceOrb:
			n += 1
			parent.remove_child(child)
			child.queue_free()
	return n

func _ready() -> void:
	print("== test_xp_level: hạt exp, giới hạn level 100, màu LV box ==")

	# ── 1. add_exp cộng dồn + level_up signal ──
	var ch := _CharBase.new()
	add_child(ch)
	await get_tree().process_frame
	_lv_signals = 0
	ch.level_up.connect(func(_lv: int): _lv_signals += 1)
	ch.level = 1
	ch.exp = 0
	ch.exp_to_next = 100
	var exp_before: int = ch.exp
	ch.add_exp(10)
	_check(ch.exp == exp_before + 10, "add_exp cộng 10 XP (exp=%d)" % ch.exp)
	ch.exp = 95
	await get_tree().process_frame
	ch.add_exp(10)
	_check(ch.level == 2 and ch.exp == 5, "95+10 XP → vượt 100 → level 2, dư 5 (lv=%d exp=%d)" % [ch.level, ch.exp])
	_check(_lv_signals == 1, "level_up signal bắn 1 lần")

	# ── 2. Giới hạn MAX_LEVEL = 100 ──
	ch.level = 99
	ch.exp = 90
	ch.exp_to_next = 100
	await get_tree().process_frame
	ch.add_exp(50)
	_check(ch.level == 100, "level 99 + 50XP → level 100 (lv=%d)" % ch.level)
	ch.add_exp(200)
	_check(ch.level == 100, "không vượt quá level 100 (lv=%d)" % ch.level)

	# ── 3. ExperienceOrb: spawn + collect cho 1 XP ──
	ch.level = 1
	ch.exp = 0
	ch.exp_to_next = 100
	var orb := _ExpOrb.spawn(self, Vector3(0, 0, 0))
	_check(orb != null and is_instance_valid(orb), "spawn ExperienceOrb thành công")
	await get_tree().process_frame
	await get_tree().process_frame
	orb._can_pickup = true
	var collected: bool = orb.collect(ch)
	await get_tree().process_frame
	_check(collected, "nhặt hạt exp → collect() trả true")
	_check(ch.exp == 1, "nhặt 1 hạt → +1 XP (exp=%d)" % ch.exp)

	# ── 4. Fish 5% / Pig 7% — test tỷ lệ (chạy đồng bộ, không await frame) ──
	# _roll_exp_drop dùng get_tree().current_scene = self (Node3D) làm cha.
	var fish := _Fish.new()
	add_child(fish)
	await get_tree().process_frame
	var fish_drops := 0
	var fish_trials := 4000
	for i in range(fish_trials):
		fish._roll_exp_drop()
		fish_drops += _count_and_clear_orbs(self)
	var fish_rate: float = float(fish_drops) / float(fish_trials)
	_check(absf(fish_rate - 0.05) < 0.03, "cá drop hạt exp ~5%% (thực tế %.2f%%)" % (fish_rate * 100.0))

	var pig := _Pig.new()
	add_child(pig)
	await get_tree().process_frame
	var pig_drops := 0
	var pig_trials := 4000
	for i in range(pig_trials):
		pig._roll_exp_drop()
		pig_drops += _count_and_clear_orbs(self)
	var pig_rate: float = float(pig_drops) / float(pig_trials)
	_check(absf(pig_rate - 0.07) < 0.03, "heo drop hạt exp ~7%% (thực tế %.2f%%)" % (pig_rate * 100.0))

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)