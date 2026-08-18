extends Node

## Headless verification: vòng đời theo thời gian game — cây cỏ MẦM → NON → TRƯỞNG THÀNH,
## cây thân gỗ MẦM → TRƯỞNG THÀNH (bỏ hẳn giai đoạn vị thành niên).
## Chạy qua tools/test_growth.tscn (không chạy trực tiếp file .gd).

const _Growing = preload("res://scripts/world/props/growing_prop.gd")
const _Plant = preload("res://scripts/world/props/plant_prop.gd")
const _Palm = preload("res://scripts/world/props/palm_prop.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260801)

	var weed: PlantProp = _Plant.new(50, DestroyableProp.WeaponReq.SWORD, "tropical_seaweed")
	weed.name = "Weed"
	weed.setup("weed", 1234, 5678, true, 1.0)
	add_child(weed)
	weed.global_position = Vector3(10, 0, 10)

	var taro: PlantProp = _Plant.new(50, DestroyableProp.WeaponReq.SWORD, "taro")
	taro.name = "Taro"
	taro.setup("taro", 2222, 3333, true, 1.0)
	add_child(taro)
	taro.global_position = Vector3(20, 0, 10)

	var palm: PalmProp = _Palm.new(150, DestroyableProp.WeaponReq.AXE, "log_palm")
	palm.name = "Palm"
	palm.setup("river")
	add_child(palm)
	palm.global_position = Vector3(30, 0, 10)

	# ── Cây mầm khi tuổi nhỏ ──
	weed.set_birth_age_days(0.5)
	taro.set_birth_age_days(1.0)
	palm.set_birth_age_days(3.0)
	_check(weed._stage == _Growing.Stage.SPROUT, "weed 0.5 ngày = cây mầm")
	_check(taro._stage == _Growing.Stage.SPROUT, "taro 1 ngày = cây mầm")
	_check(palm._stage == _Growing.Stage.SPROUT, "palm 3 ngày = cây mầm")

	# ── Cây non (cây thân gỗ bỏ vị thành niên — palm qua ngưỡng mầm là trưởng thành) ──
	weed.set_birth_age_days(3.0)
	taro.set_birth_age_days(5.0)
	palm.set_birth_age_days(15.0)
	_check(weed._stage == _Growing.Stage.YOUNG, "weed 3 ngày = cây non")
	_check(taro._stage == _Growing.Stage.YOUNG, "taro 5 ngày = cây non")
	_check(palm._stage == _Growing.Stage.MATURE, "palm 15 ngày = trưởng thành (không có non)")

	# ── Trưởng thành ──
	weed.set_birth_age_days(10.0)
	taro.set_birth_age_days(12.0)
	palm.set_birth_age_days(40.0)
	_check(weed._stage == _Growing.Stage.MATURE, "weed 10 ngày = trưởng thành")
	_check(taro._stage == _Growing.Stage.MATURE, "taro 12 ngày = trưởng thành")
	_check(palm._stage == _Growing.Stage.MATURE, "palm 40 ngày = trưởng thành")

	# ── Chuyển giai đoạn khi thời gian trôi qua ngưỡng ──
	weed.set_birth_age_days(1.9)
	weed._check_growth()
	_check(weed._stage == _Growing.Stage.SPROUT, "weed trước ngưỡng 2 ngày: chưa chuyển")
	weed.set_birth_age_days(2.1)
	weed._check_growth()
	_check(weed._stage == _Growing.Stage.YOUNG, "weed qua ngưỡng 2 ngày: chuyển sang non")
	weed.set_birth_age_days(5.1)
	weed._check_growth()
	_check(weed._stage == _Growing.Stage.MATURE, "weed qua ngưỡng 5 ngày: trưởng thành")

	# ── Hình dạng theo giai đoạn (palm) ──
	palm.set_birth_age_days(3.0)
	palm._check_growth()
	_check(palm._stage == _Growing.Stage.SPROUT, "palm 3 ngày = cây mầm (mesh)")
	_check(palm.find_child("CoconutVisual", false, false) == null, "palm mầm: không có CoconutVisual")
	_check(palm.find_child("PalmVisual", false, false) != null, "palm mầm: có tán lá mầm")
	palm.set_birth_age_days(40.0)
	palm._check_growth()
	_check(palm._stage == _Growing.Stage.MATURE, "palm trưởng thành khi già")
	_check(palm.find_child("CoconutVisual", false, false) != null, "palm trưởng thành: có quả dừa")

	# ── Tuổi sinh ổn định theo vị trí ──
	var a := _Growing._hash_position_to_float(Vector3(5, 0, 7))
	var b := _Growing._hash_position_to_float(Vector3(5, 0, 7))
	var c := _Growing._hash_position_to_float(Vector3(5, 0, 8))
	_check(a == b, "hash vị trí: cùng vị trí → cùng tuổi")
	_check(a != c, "hash vị trí: khác vị trí → khác tuổi")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
