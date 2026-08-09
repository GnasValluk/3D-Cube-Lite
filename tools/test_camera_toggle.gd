extends Node

const _IsoCam = preload("res://scripts/camera/iso_camera.gd")
const _TPCam = preload("res://scripts/camera/third_person_camera.gd")
const _CharManager = preload("res://scripts/core/character_manager.gd")
const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_camera_toggle: F1 chuyển iso <-> third-person ==")
	var root := Node3D.new()
	root.name = "Root"
	add_child(root)

	var rig := _IsoCam.new()
	rig.name = "CameraRig"
	var iso_cam := Camera3D.new()
	iso_cam.name = "Camera3D"
	iso_cam.current = false
	rig.add_child(iso_cam)
	root.add_child(rig)

	var tprig := _TPCam.new()
	tprig.name = "TPCameraRig"
	var tp_cam := Camera3D.new()
	tp_cam.name = "Camera3D"
	tp_cam.current = true
	tprig.add_child(tp_cam)
	root.add_child(tprig)

	var cm := _CharManager.new()
	cm.name = "CharacterManager"
	var player := _PlayerChar.new()
	player.name = "Player"
	cm.add_child(player)
	root.add_child(cm)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_check(player._iso_rig != null and player._tp_rig != null,
		"player đã tìm thấy 2 camera rig")
	_check(not iso_cam.current, "ban đầu iso KHÔNG current")
	_check(tp_cam.current, "ban đầu TP current (mặc định cam 3)")
	_check(player._use_tp, "mặc định _use_tp == true")
	_check(player._tp_rig._is_active, "TP rig active ngay từ đầu (không cần F1)")
	_check(not player._iso_rig._camera.current, "iso rig chưa kích hoạt cam")

	var ev := InputEventKey.new()
	ev.keycode = KEY_F1
	ev.pressed = true

	# 1. F1 → sang iso
	player._unhandled_key_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not player._use_tp, "sau F1: _use_tp == false")
	_check(iso_cam.current, "sau F1: iso current")
	_check(not tp_cam.current, "sau F1: TP không còn current")

	# 2. F1 lần nữa → về TP
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_F1
	ev2.pressed = true
	player._unhandled_key_input(ev2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player._use_tp, "F1 lần 2: _use_tp == true")
	_check(tp_cam.current, "F1 lần 2: TP current trở lại")
	_check(not iso_cam.current, "F1 lần 2: iso không còn current")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)