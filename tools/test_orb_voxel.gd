extends Node3D

## Headless: ExperienceOrb giờ là 1 voxel lấp lánh xanh-vàng, nhặt được +1 XP.

const _ExperienceOrb = preload("res://scripts/items/entities/experience_orb.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_orb_voxel: voxel xanh-vàng + pickup ==")
	var orb := _ExperienceOrb.new()
	orb.position = Vector3(0, 1, 0)
	add_child(orb)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(orb.get_child_count() >= 3, "orb có 3 node con (voxel, glow, light)")
	_check(orb._voxel != null, "orb có _voxel")
	_check(orb._voxel.get_child_count() == 1, "voxel chứa đúng 1 MeshInstance (_mesh)")
	_check(orb._mesh != null, "orb có _mesh (ArrayMesh)")

	# Giả lập pickup: _can_pickup mặc định đóng 0.8s — mở tay trái.
	orb._can_pickup = true
	var fake := Node3D.new()
	fake.set_script(load("res://tools/test_orb_voxel_player.gd"))
	fake.name = "FakePlayer"
	add_child(fake)
	var ok: bool = orb.collect(fake)
	_check(ok, "collect trả true khi _can_pickup")
	_check(fake.exp_added == 1, "người chơi fake nhận +1 XP")
	await get_tree().process_frame
	_check(not is_instance_valid(orb), "orb queue_free sau khi collect")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)