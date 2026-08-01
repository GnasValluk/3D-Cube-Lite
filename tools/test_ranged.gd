extends Node

## Headless verification: cooldown vũ khí tầm xa + ném kích.
## Chạy qua tools/test_ranged.tscn (không chạy trực tiếp file .gd).

const _PC = preload("res://scripts/characters/player/player_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260805)

	# ── 1. Bảng cooldown ───────────────────────────────────────────────────
	_check(_PC.RANGED_COOLDOWNS["crossbow"] == 0.8, "nỏ 0.8s")
	_check(_PC.RANGED_COOLDOWNS["pumpkin_mortar"] == 2.5, "pháo bí đỏ 2.5s")
	_check(_PC.RANGED_COOLDOWNS["watermelon_cannon"] == 5.0, "pháo dưa hấu 5s")
	_check(_PC.RANGED_COOLDOWNS["iron_halberd"] == 4.0, "ném kích 4s")

	# ── 2. Helper cooldown (instance không cần vào tree) ───────────────────
	var pc = _PC.new()
	_check(not pc._ranged_on_cd("crossbow"), "ban đầu không cooldown")
	pc._set_ranged_cd("crossbow")
	_check(pc._ranged_on_cd("crossbow"), "sau khi bắn → đang cooldown")
	pc._tick_ranged_cd(0.5)
	_check(pc._ranged_on_cd("crossbow"), "0.5s chưa hết (cd 0.8s)")
	pc._tick_ranged_cd(0.4)
	_check(not pc._ranged_on_cd("crossbow"), "hết cooldown sau 0.9s")
	pc._set_ranged_cd("iron_halberd")
	pc._tick_ranged_cd(3.9)
	_check(pc._ranged_on_cd("iron_halberd"), "kích 4s: 3.9s vẫn hồi chiêu")
	pc._tick_ranged_cd(0.2)
	_check(not pc._ranged_on_cd("iron_halberd"), "kích 4s: hết sau 4.1s")
	pc._set_ranged_cd("pumpkin_mortar")
	pc._tick_ranged_cd(2.6)
	_check(not pc._ranged_on_cd("pumpkin_mortar"), "pháo bí đỏ hết sau 2.6s")
	pc._set_ranged_cd("watermelon_cannon")
	_check(pc._ranged_on_cd("watermelon_cannon"), "pháo dưa hấu đang hồi chiêu")
	pc._tick_ranged_cd(5.0)
	_check(not pc._ranged_on_cd("watermelon_cannon"), "pháo dưa hấu hết sau 5s")
	_check(pc._ranged_cd.is_empty(), "dict cooldown rỗng khi hết")
	pc.free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
