extends Node

## Verify the crossbow arrow gets the increased speed and doubled flight range
## (fire at full charge → ArrowProjectile._speed / _max_range).

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _Bow = preload("res://scripts/characters/player/player_bow.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_bow_range: crossbow speed + tầm bay ==")
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db
	_check(db.has("crossbow"), "db có crossbow")
	_check(db.has("arrow"), "db có arrow")

	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	p.equipped_weapon = db["crossbow"]
	p._bow_aiming = true
	p._bow_charge = p._bow_max_charge
	p._bow_aim_dir = Vector3.FORWARD
	p.inventory.add_item(db["arrow"], 5)

	_Bow.fire(p)
	await get_tree().process_frame

	var arrow: Node = null
	for ch in get_children():
		if ch is ArrowProjectile:
			arrow = ch
			break
	_check(arrow != null, "bắn ra mũi tên")
	if arrow != null:
		var spd: float = arrow.get("_speed")
		var rng: float = arrow.get("_max_range")
		_check(spd >= 60.0, "tốc độ mũi tên cao hơn (speed=%.1f)" % spd)
		_check(rng >= 95.0, "tầm bay tối đa tăng gấp đôi (range=%.1f)" % rng)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)