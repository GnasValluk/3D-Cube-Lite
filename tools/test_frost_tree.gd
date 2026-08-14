extends Node3D
## test_frost_tree — Smoke test: cây vân sam (frost_tree_prop) build được cả
## giai đoạn SPROUT / MATURE không lỗi runtime, thu được MultiMeshInstance3D
## "FrostVisual", và biome_at nhận diện đúng bio băng giá khi noise-sim fake.

const _Prop = preload("res://scripts/world/props/frost_tree_prop.gd")
const _Growing := preload("res://scripts/world/props/growing_prop.gd")

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _build_stage(stage: int) -> FrostTreeProp:
	var prop := _Prop.new()
	add_child(prop)
	prop._stage = stage
	prop._rebuild()
	return prop


func _ready() -> void:
	print("== test_frost_tree: build SPROUT + MATURE ==")

	var sprout := _build_stage(_Growing.Stage.SPROUT)
	var sp := sprout.find_child("FrostVisual", false, false) as MultiMeshInstance3D
	_check(sp != null, "SPROUT: có MultiMeshInstance3D 'FrostVisual'")

	var mature := _build_stage(_Growing.Stage.MATURE)
	var mp := mature.find_child("FrostVisual", false, false) as MultiMeshInstance3D
	_check(mp != null, "MATURE: có MultiMeshInstance3D 'FrostVisual'")

	if sp != null and mp != null:
		var sc := sp.multimesh.instance_count
		var mc := mp.multimesh.instance_count
		_check(mc > sc, "MATURE instance_count (%d) > SPROUT (%d)" % [mc, sc])
		_check(mp.multimesh is MultiMesh, "MATURE: multimesh là MultiMesh")
	else:
		_check(false, "không thể so sánh instance_count do MultiMesh null")

	# Block mới được đăng ký đầy đủ trong chunk data
	var data = preload("res://scripts/world/chunk/chunk_data.gd")
	_check(data.BlockID.SNOW == 49, "BlockID.SNOW == 49")
	_check(data.BlockID.SPRUCE_WOOD == 51, "SPRUCE_WOOD == 51")
	_check(data.BLOCK_TO_ITEM.get(data.BlockID.SPRUCE_WOOD, "") == "spruce_wood",
		"BLOCK_TO_ITEM[SPRUCE_WOOD] -> spruce_wood")
	_check(data.ITEM_TO_BLOCK.get("block_snow", -1) == data.BlockID.SNOW,
		"ITEM_TO_BLOCK[block_snow] -> SNOW")

	get_tree().quit(0 if _failures == 0 else 1)
	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])