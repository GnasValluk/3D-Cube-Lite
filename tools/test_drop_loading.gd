extends Node

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_drop_loading: DroppedItem.spawn khi current_scene là CanvasLayer ==")
	await get_tree().process_frame
	await get_tree().process_frame

	var world3d := Node3D.new()
	world3d.name = "WorldInstance"
	get_tree().root.add_child(world3d)

	var loading := CanvasLayer.new()
	loading.name = "LoadingScreen"
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading

	var def := ItemDef.new("test_drop_item", "Test Drop Item", ItemDef.Type.MATERIAL,
		Color.WHITE, "T")

	var item: Node = _DroppedItem.spawn(loading, def, Vector3(1, 5, 2), 3, Vector3(0, 3, 0), 5.0)
	_check(item != null, "spawn không trả null")
	if item != null:
		_check(item.get_parent() == world3d, "item gắn vào world 3D thật (không phải CanvasLayer)")
		_check(item.item_count == 3, "item_count == 3")
		_check(not item.is_queued_for_deletion(), "item chưa bị queue_free")

	var item2 := _DroppedItem.spawn(world3d, def, Vector3(0, 0, 0), 1)
	_check(item2 != null and item2.get_parent() == world3d, "spawn với world Node3D vẫn hoạt động")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)