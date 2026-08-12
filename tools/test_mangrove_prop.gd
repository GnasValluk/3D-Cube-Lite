extends Node3D
## test_mangrove_prop — Smoke test: cây đước (mangrove prop) build được cả 3 giai
## đoạn (SPROUT / MATURE) mà không lỗi runtime, và thu được MultiMeshInstancel3D
## "MangroveVisual". Smoke test headless — không render ảnh.

const _Prop = preload("res://scripts/world/props/mangrove_prop.gd")
const _Growing := preload("res://scripts/world/props/growing_prop.gd")

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _build_stage(stage: int) -> MangroveProp:
	var prop := _Prop.new()
	prop._variant = "coast"
	add_child(prop)
	prop._stage = stage
	prop._rebuild()
	return prop


func _ready() -> void:
	print("== test_mangrove_prop: build SPROUT + MATURE ==")

	# SPROUT
	var sprout := _build_stage(_Growing.Stage.SPROUT)
	var sp := sprout.find_child("MangroveVisual", false, false) as MultiMeshInstance3D
	_check(sp != null, "SPROUT: có MultiMeshInstance3D 'MangroveVisual'")

	# MATURE (rẽ nhánh _has_young_stage = false → chỉ SPROUT/MATURE/RIPE)
	var mature := _build_stage(_Growing.Stage.MATURE)
	var mp := mature.find_child("MangroveVisual", false, false) as MultiMeshInstance3D
	_check(mp != null, "MATURE: có MultiMeshInstance3D 'MangroveVisual'")

	# MATURE phải có nhiều voxel hơn SPROUT (thân lớn + tán)
	if sp != null and mp != null:
		var sc := sp.multimesh.instance_count
		var mc := mp.multimesh.instance_count
		_check(mc > sc, "MATURE instance_count (%d) > SPROUT (%d)" % [mc, sc])
	else:
		_check(false, "không thể so sánh instance_count do MultiMesh null")

	# MultiMesh phải được build (dùng TRUNK_SCALE cho thân/gốc, LEAF_SCALE cho tán)
	_check(mp.multimesh is MultiMesh, "MATURE: multimesh là MultiMesh")

	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
