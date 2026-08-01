extends Node

## Headless verification: mob chết phải gọi _die() override → roll loot → spawn DroppedItem.

const _Pig  = preload("res://scripts/characters/pig/pig_character.gd")
const _Fish = preload("res://scripts/characters/fish/fish_character.gd")

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
	return n

func _ready() -> void:
	seed(20260731)
	ItemDatabase.ensure_db()

	var pigs := []
	for i in range(4):
		var p: CharacterBase = _Pig.new()
		p.name = "Pig%d" % i
		add_child(p)
		p.global_position = Vector3(i * 2, 2, 0)
		pigs.append(p)

	var fish: CharacterBase = _Fish.new()
	fish.name = "Fish1"
	add_child(fish)
	fish.global_position = Vector3(0, 2, 4)

	var before := _count_drops()
	for p in pigs:
		p.take_damage(9999, null)
	fish.take_damage(9999, null)
	var after := _count_drops()

	_check(after > before, "kill pig+fish -> drops spawned (before=%d after=%d)" % [before, after])
	_check(_count_drops() >= 1, "at least 1 dropped item exists in world")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
