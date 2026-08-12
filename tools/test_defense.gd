extends Node

## Verify defense actually reduces damage taken (previously take_damage only
## used the base `defense` stat and ignored armor def_bonus entirely).

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _Slime = preload("res://scripts/characters/slime/slime_character.gd")
const _Damage = preload("res://scripts/core/damage_system.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_defense: giáp có tác dụng giảm sát thương ==")
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db
	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	p.max_hp = 500
	p.hp = p.max_hp

	# Không giáp: 20 sát thương với defense 0 → mất đúng 20 HP.
	p.defense = 0
	p.hp = p.max_hp
	p._invul_timer = 0.0
	_Damage.take_damage(p, 20, null, 0)
	await get_tree().physics_frame
	_check(p.hp == p.max_hp - 20, "không giáp: 20 dmg → mất 20 HP (hp=%d)" % p.hp)
	# Đòn trong test này gây chết → hồi sinh trước khi sang kịch bản sau.
	_Damage.revive(p)

	# Defense cơ bản: 8 sát thương với defense 3 → chỉ mất 5.
	p.defense = 3
	p.hp = p.max_hp
	p._invul_timer = 0.0
	_Damage.take_damage(p, 8, null, 0)
	await get_tree().physics_frame
	_check(p.hp == p.max_hp - 5, "defense 3: 8 dmg → mất 5 HP (hp=%d)" % p.hp)

	# Defense tối thiểu: sát thương luôn >= 1.
	p.defense = 50
	p.hp = p.max_hp
	p._invul_timer = 0.0
	_Damage.take_damage(p, 5, null, 0)
	await get_tree().physics_frame
	_check(p.hp == p.max_hp - 1, "defense 50: 5 dmg → vẫn mất 1 HP (hp=%d)" % p.hp)

	# Giáp trang bị phải được cộng vào: nón +1.5, giày +1 → get_total_def = defense + 2.5
	p.defense = 0
	p.equipped_head = db["iron_helmet"]
	p.equipped_feet = db["iron_boots"]
	var total_def: float = p.get_total_def()
	_check(absf(total_def - 2.5) < 0.0001, "nón+giày → get_total_def = 2.5 (có %f)" % total_def)
	# Đòn 6 dmg với giáp 2.5 (int 2) → mất 4 HP.
	p.hp = p.max_hp
	p._invul_timer = 0.0
	_Damage.take_damage(p, 6, null, 0)
	await get_tree().physics_frame
	_check(p.hp == p.max_hp - 4, "mang nón+giày: 6 dmg → mất 4 HP (hp=%d)" % p.hp)

	# Nhân vật khác vẫn có get_total_def (trả defense cơ bản).
	var s := _Slime.new()
	add_child(s)
	await get_tree().process_frame
	s.defense = 5
	_check(absf(s.get_total_def() - 5.0) < 0.0001, "slime get_total_def = defense base")
	s.queue_free()

	p.queue_free()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)