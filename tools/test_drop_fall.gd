extends Node3D

## Verify dropped items spawned without a launch velocity fall to the ground
## instead of hovering in the sky (e.g. block drops, missed arrows).

const _DroppedItem := preload("res://scripts/items/entities/dropped_item.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1.0, 20)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)
	return body

func _ready() -> void:
	print("== test_drop_fall: vật phẩm rớt xuống đất ==")
	_make_floor()
	await get_tree().process_frame
	await get_tree().physics_frame
	ItemDatabase.ensure_db()

	var def: ItemDef = ItemDatabase.items_db["block_stone"]
	_check(def != null, "db có cobblestone")

	# Rơi từ cao (y=12) không có vận tốc — phải rớt xuống sát đất.
	var item := _DroppedItem.spawn(self, def, Vector3(0, 12, 0), 1)
	_check(item != null and not item.get("_flying"), "spawn không launch → không bay")
	var start_y: float = item.position.y if item else 9999
	_check(absf(start_y - 12.2) < 0.01, "spawn ở độ cao 12 (y=%f)" % (item.position.y if item else -1))

	for i in range(300):
		await get_tree().physics_frame
		if item == null or not is_instance_valid(item):
			break
		if item.get("_settled"):
			break

	_check(item != null and is_instance_valid(item), "item còn tồn tại")
	if item != null and is_instance_valid(item):
		_check(item.get("_settled"), "item đã chạm đất (_settled)")
		_check(item.position.y < 4.0, "item đã rơi xuống thấp (y=%f)" % item.position.y)
		_check(item.position.y <= 1.1, "item dừng sát mặt đất (y=%f <= 1.1)" % item.position.y)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
