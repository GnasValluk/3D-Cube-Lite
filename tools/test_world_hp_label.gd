extends Node3D

## Headless verification: WorldHPBar hiển thị label Lv + tên phía trên thanh HP.

const _Slime = preload("res://scripts/characters/slime/slime_character.gd")
const _WorldHPBar = preload("res://scripts/ui/hud/world_hp_bar.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	print("== test_world_hp_label: label Lv + tên trên thanh HP ==")
	ItemDatabase.ensure_db()
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 1, 40)
	floor_col.shape = floor_box
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -1.5, 0)
	add_child(floor_body)

	var s := _Slime.new()
	s.global_position = Vector3(0, 3, 0)
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	for i in range(60):
		await get_tree().physics_frame
		if s.is_on_floor():
			break

	var bar: WorldHPBar = null
	for child in s.get_children():
		if child is WorldHPBar:
			bar = child as WorldHPBar
			break
	_check(bar != null, "slime có WorldHPBar con (theo class)")
	if bar:
		_check(bar._label != null, "WorldHPBar có Label3D")
		if bar._label:
			var lv: int = s.level
			var expected: String = "Lv.%d %s" % [lv, s.character_name]
			_check(bar._label.text == expected, "label = '%s' (thực tế '%s')" % [expected, bar._label.text])
			_check(bar._label.position.y > 0.0, "label nằm phía trên thanh HP")
	_check(bar == null or bar._label == null or bar._label.billboard != BaseMaterial3D.BILLBOARD_DISABLED,
		"label billboard bật (hướng camera)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)