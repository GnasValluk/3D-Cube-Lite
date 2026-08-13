extends Node3D

## Headless: đom đóm rừng ngập mặn — sinh vật nhỏ hp=1 bay lơ lửng,
## giết được, không rớt gì cả.

const _FireflyProp = preload("res://scripts/world/props/firefly_prop.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count_dropped() -> int:
	var n := 0
	for ch in get_children():
		if ch is DroppedItem:
			n += 1
	return n

func _ready() -> void:
	print("== test_firefly: đom đóm hp=1 giết được, không rớt đồ ==")
	var ff := _FireflyProp.new()
	ff.position = Vector3(2, 1.2, 3)
	add_child(ff)
	await get_tree().process_frame

	_check(ff.is_in_group("firefly"), "đom đóm vào group 'firefly'")
	_check(ff.hp == 1, "đom đóm hp = 1")
	_check(ff.hit_radius > 0.0, "đom đóm có hit_radius")
	_check(ff.has_method("take_damage"), "đom đóm có take_damage")

	# Bay lơ lửng: sau vài frame vị trí đổi khỏi điểm ban đầu (nếu có di chuyển).
	var start_pos: Vector3 = ff.position
	for i in range(30):
		await get_tree().process_frame
	_check(is_instance_valid(ff), "đom đóm còn sống sau khi bay")
	print("DEBUG | start=%s now=%s" % [start_pos, ff.position])

	# Bị giết: 1 đòn → chết, không rớt DroppedItem nào.
	var dropped_before := _count_dropped()
	ff.take_damage(1, null)
	_check(not ff.is_alive, "đom đóm chết sau 1 sát thương")
	_check(ff.hp <= 0, "hp giảm về ≤ 0")
	await get_tree().process_frame
	var dropped_after := _count_dropped()
	_check(dropped_after == dropped_before,
		"chết không rớt vật phẩm (dropped=%d)" % dropped_after)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)