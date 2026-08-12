extends Node3D

## Verify death+respawn in the real world with FP/TP camera rigs present:
## 1) Respawn happens (is_alive, active, physics on).
## 2) After respawn, the FP camera's rig-visibility state is preserved.

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_respawn_fp: chết khi FP + respawn ==")
	var packed := load("res://scenes/open_world_real.tscn")
	var world: Node = packed.instantiate()
	add_child(world)
	for i in range(300):
		await get_tree().process_frame

	var player: Node3D = world.get_node_or_null("CharacterManager/Player")
	_check(player != null, "world có Player")
	if player == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return

	# Bật FP camera (F1) như người chơi thật.
	player._use_tp = false
	player._sync_camera()
	await get_tree().process_frame
	var fp_rig := world.get_node_or_null("CameraRig")
	var tp_rig := world.get_node_or_null("TPCameraRig")
	_check(fp_rig != null and tp_rig != null, "có CameraRig + TPCameraRig")
	if fp_rig == null or tp_rig == null:
		await WorldChunk.wait_for_tasks_async(get_tree())
		get_tree().quit(1)
		return
	_check(fp_rig.get("_is_active"), "FP rig active sau bật F1")
	_check(not fp_rig.get("_camera").current == false, "FP camera là current")
	if player._rig:
		_check(not player._rig.visible, "FP: model player ẩn khi sống (visible=%s)" % player._rig.visible)

	player.take_damage(9999, null)
	_check(not player.is_alive, "player chết")
	for i in range(150):
		await get_tree().physics_frame

	_check(player.is_alive, "player hồi sinh (is_alive=%s)" % player.is_alive)
	_check(player._active, "player active lại")
	if player._rig:
		_check(not player._rig.visible, "FP: model player VẪN ẩn sau respawn (visible=%s)" % player._rig.visible)
	_check(fp_rig.get("_is_active"), "FP rig vẫn active sau respawn")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)