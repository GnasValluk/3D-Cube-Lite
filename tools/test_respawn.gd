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
	_check(not p._death_items_spawned, "death drop flag reset (val=%s)" % p._death_items_spawned)
	# Đồ rơi vương vãi thay rương: player chết không còn node DeathChest,
	# nhưng nếu có mang theo đồ thì drop thành DroppedItem tại điểm chết.
	var has_drop := false
	for ch in get_children():
		if ch is DroppedItem:
			has_drop = true
			break
	print("DEBUG | inventory empty=%s has_drop=%s" % [p.inventory.is_empty() if p.inventory else true, has_drop])
	_check(not has_drop, "kho rỗng → không có DroppedItem (thay rương)")
	var no_chest := true
	for ch in get_children():
		if ch.name == "DeathChest":
			no_chest = false
			break
	_check(no_chest, "không còn node DeathChest")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)