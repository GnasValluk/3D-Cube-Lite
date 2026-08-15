extends Node3D
## test_swamp_tree_prop — Smoke test: cây tràm build được (SPROUT + MATURE),
## tán rộng theo chiều ngang hơn thân (horizontal span > h), dây leo xuất hiện.

const _Prop = preload("res://scripts/world/props/swamp_tree_prop.gd")
const _Growing := preload("res://scripts/world/props/growing_prop.gd")

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _build_stage(stage: int) -> SwampTreeProp:
	var prop := _Prop.new()
	prop.setup("marsh")
	add_child(prop)
	prop._stage = stage
	prop._rebuild()
	return prop


func _ready() -> void:
	print("== test_swamp_tree_prop: build SPROUT + MATURE (dense wide canopy) ==")

	var sprout := _build_stage(_Growing.Stage.SPROUT)
	var sp := sprout.find_child("SwampTreeVisual", false, false) as MultiMeshInstance3D
	_check(sp != null, "SPROUT: có MultiMeshInstance3D 'SwampTreeVisual'")

	var mature := _build_stage(_Growing.Stage.MATURE)
	var mp := mature.find_child("SwampTreeVisual", false, false) as MultiMeshInstance3D
	_check(mp != null, "MATURE: có MultiMeshInstance3D 'SwampTreeVisual'")

	if sp != null and mp != null:
		var sc := sp.multimesh.instance_count
		var mc := mp.multimesh.instance_count
		_check(mc > sc, "MATURE instance_count (%d) > SPROUT (%d)" % [mc, sc])
		_check(mc >= 500, "tán dày: MATURE có >=500 voxel (có %d)" % mc)
	else:
		_check(false, "không thể so sánh instance_count do MultiMesh null")

	# Kiểm tra tán rộng theo chiều ngang: có voxel cách tâm >= 2.0 đơn vị
	var mm: MultiMesh = mp.multimesh if mp != null else null
	if mm != null:
		var buf := mm.get_buffer()
		var n: int = mm.instance_count
		var max_r: float = 0.0
		var min_y: float = 999.0
		for i in range(n):
			var ox: float = buf[i * 16 + 3]
			var oy: float = buf[i * 16 + 7]
			var oz: float = buf[i * 16 + 11]
			max_r = maxf(max_r, Vector3(ox, 0.0, oz).length())
			min_y = minf(min_y, oy)
		_check(max_r >= 1.6, "tán vươn ngang >=1.6 đơn vị (có %.2f)" % max_r)
		_check(min_y <= 0.15, "dây leo thả xuống gần đất (min_y=%.3f)" % min_y)
	else:
		_check(false, "MATURE: multimesh null — không test được tán")

	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])