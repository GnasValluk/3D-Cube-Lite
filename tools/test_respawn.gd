extends Node3D

## Headless verification: player chết → sau death_timer hồi sinh + spawn rương đồ.

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_respawn: player chết → hồi sinh ==")
	ItemDatabase.ensure_db()
	var p := _PlayerChar.new()
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	_check(p.is_alive, "player ban đầu sống (is_alive=%s)" % p.is_alive)
	_check(p.is_physics_processing(), "physics bật ban đầu")

	p.take_damage(9999, null)
	_check(not p.is_alive, "player chết sau take_damage(9999)")

	# Chờ qua death_timer 1.8s + margin
	for i in range(150):
		await get_tree().physics_frame

	_check(p.is_alive, "player hồi sinh lại sau khi chết (is_alive=%s)" % p.is_alive)
	_check(p._active, "player active sau hồi sinh (_active=%s)" % p._active)
	_check(p.is_physics_processing(), "physics bật lại sau hồi sinh")
	_check(p.is_processing_unhandled_input(), "input bật lại sau hồi sinh")
	_check(not p._death_chest_spawned, "death_chest flag reset (val=%s)" % p._death_chest_spawned)
	var has_chest := false
	for ch in get_children():
		if ch.name == "DeathChest":
			has_chest = true
			break
	_check(has_chest, "spawn rương đồ tại điểm chết")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)