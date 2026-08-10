extends Node

## Smoke test RemotePlayer health/food bar + apply_state + apply_inventory.
## Không cần multiplayer: tạo RemotePlayer trực tiếp, gọi apply_state/apply_inventory,
## verify các field + bar được build + cập nhật.

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_remote_player_state ==")
	var rp := RemotePlayer.new()
	add_child(rp)
	rp.setup(42, "Bob", Vector3(0, 0, 0))
	_check(rp.is_remote_for(42), "is_remote_for(42) true")
	_check(rp.display_name == "Bob", "display_name == Bob")
	_check(rp.hp == 100 and rp.max_hp == 100, "default hp/max_hp 100")
	_check(rp.food == 20 and rp.max_food == 20, "default food/max_food 20")

	rp.apply_state(55, 80, 12, 20, 4, 7, true)
	_check(rp.hp == 55, "apply_state cập nhật hp=55")
	_check(rp.max_hp == 80, "apply_state cập nhật max_hp=80")
	_check(rp.food == 12, "apply_state cập nhật food=12")
	_check(rp.shield == 4, "apply_state cập nhật shield=4")
	_check(rp.level == 7, "apply_state cập nhật level=7")
	_check(rp.alive, "apply_state cập nhật alive=true")
	_check(rp.get("_health_vbar") != null, "health bar đã được build")
	_check(rp.get("_food_vbar") != null, "food bar đã được build")

	var hp_bar: VoxelBar = rp.get("_health_vbar")
	_check(int(hp_bar.get("_value")) == 55, "health bar value == 55 sau apply_state")
	var food_bar: VoxelBar = rp.get("_food_vbar")
	_check(int(food_bar.get("_value")) == 12, "food bar value == 12 sau apply_state")

	var data: Array = [null, {"id": "carp", "count": 3}]
	rp.apply_inventory(data)
	_check(rp.inventory_data.size() == 2, "apply_inventory lưu 2 slot")
	_check(str(rp.inventory_data[1].get("id", "")) == "carp", "slot 1 chứa carp")

	# Chết → visual ẩn đi (rig, tên, bar); respawn → hiện lại.
	var rig: Node3D = rp.get("_mesh").rig
	var label_vis_target: Node3D = rp.get("_label")
	var bar_target: Node3D = rp.get("_bar_mesh")
	_check(rig.visible, "ban đầu rig hiện")
	rp.apply_state(0, 80, 12, 20, 4, 7, false)
	_check(not rp.alive, "apply_state alive=false khi chết")
	_check(not rig.visible, "rig ẩn khi chết")
	_check(not label_vis_target.visible, "tên ẩn khi chết")
	_check(not bar_target.visible, "bar ẩn khi chết")
	rp.apply_state(80, 80, 16, 20, 4, 7, true)
	_check(rp.alive, "apply_state alive=true khi respawn")
	_check(rig.visible, "rig hiện lại sau respawn")
	_check(label_vis_target.visible, "tên hiện lại sau respawn")
	_check(bar_target.visible, "bar hiện lại sau respawn")

	rp.set_name_label("Alice")
	_check(rp.display_name == "Alice", "set_name_label cập nhật tên")

	rp.free()
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)