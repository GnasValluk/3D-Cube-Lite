extends Node

## Headless verification: heo rời khỏi trạng thái invul sau 1 cú đánh.
## Trước đây pig_character override _physics_process mà không giảm _invul_timer
## (base class làm việc đó trong _physics_process của chính nó) → sau cú đánh
## đầu tiên _invul_timer mắc kẹt ở 0.05 mãi mãi → mọi cú đánh sau bị chặn → heo bất tử.

const _Pig  = preload("res://scripts/characters/pig/pig_character.gd")
const _Fish = preload("res://scripts/characters/fish/fish_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _wait_invul() -> void:
	for i in range(6):
		await get_tree().physics_frame

func _ready() -> void:
	seed(20260816)
	ItemDatabase.ensure_db()

	# ── Heo bất tử ─────────────────────────────────────────────────────
	print("-- Pig: nhiều cú đánh liên tiếp phải gây sát thương --")
	var pig: CharacterBase = _Pig.new()
	pig.name = "Pig1"
	add_child(pig)
	pig.global_position = Vector3(0, 2, 0)
	await get_tree().process_frame
	await get_tree().physics_frame

	var dmg_per_hit: int = 5
	var expected_after_1: int = pig.hp - maxi(1, dmg_per_hit - int(pig.get_total_def()))
	pig.take_damage(dmg_per_hit, null)
	await _wait_invul()
	_check(pig.hp == expected_after_1, "cú 1: hp=%d (kỳ vọng %d)" % [pig.hp, expected_after_1])

	var expected_after_2: int = pig.hp - maxi(1, dmg_per_hit - int(pig.get_total_def()))
	pig.take_damage(dmg_per_hit, null)
	await _wait_invul()
	_check(pig.hp == expected_after_2 and pig.hp < expected_after_1,
			"cú 2 sau thời gian invul: vẫn trừ máu → không bất tử (hp=%d)" % pig.hp)

	var expected_after_3: int = pig.hp - maxi(1, dmg_per_hit - int(pig.get_total_def()))
	pig.take_damage(dmg_per_hit, null)
	await _wait_invul()
	_check(pig.hp == expected_after_3 and pig.hp < expected_after_2,
			"cú 3 vẫn trừ máu (hp=%d)" % pig.hp)

	# ── Cá cũng mắc lỗi tương tự ───────────────────────────────────────
	print("-- Fish: nhiều cú đánh liên tiếp phải gây sát thương --")
	var fish: CharacterBase = _Fish.new()
	fish.name = "Fish1"
	add_child(fish)
	fish.global_position = Vector3(0, 2, 6)
	await get_tree().process_frame
	await get_tree().physics_frame
	fish.max_hp = 100
	fish.hp = 100
	fish.defense = 0

	fish.take_damage(10, null)
	await _wait_invul()
	_check(fish.hp == 90, "cá cú 1: hp=90 (hp=%d)" % fish.hp)
	fish.take_damage(10, null)
	await _wait_invul()
	_check(fish.hp == 80, "cá cú 2: vẫn trừ máu → không bất tử (hp=%d)" % fish.hp)

	pig.queue_free()
	fish.queue_free()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)