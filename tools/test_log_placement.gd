extends Node

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_log_placement ==")
	var PS: Script = load("res://scripts/building/placement_system.gd")
	var ps: Node = PS.new()

	# Trục theo hướng bề mặt
	_check(ps._log_axis_for(Vector3(0, 1, 0)) == "ST", "normal.y -> đứng")
	_check(ps._log_axis_for(Vector3(0, -1, 0)) == "ST", "normal.y âm -> đứng")
	_check(ps._log_axis_for(Vector3(1, 0, 0)) == "Z", "normal.x -> nằm dài Z")
	_check(ps._log_axis_for(Vector3(0, 0, 1)) == "X", "normal.z -> nằm dài X")
	_check(ps._log_axis_for(Vector3(0, 0, -1)) == "X", "normal.z âm -> nằm X")

	# Tất cả item log đều là log items
	for it in ["log_oak", "log_hard_wood", "log_spruce", "log_swamp", "log_mangrove", "log_palm"]:
		_check(ps.is_log_item(it), "is_log_item %s" % it)
	_check(not ps.is_log_item("block_stone"), "block_stone không phải log")

	# Đặt model thật xuống thế giới
	var root3d := Node3D.new()
	add_child(root3d)
	ps._place_log_model(root3d, "log_oak", Vector3.ZERO, "X")
	var body := root3d.get_node_or_null("PlacedLog") as StaticBody3D
	_check(body != null, "có PlacedLog StaticBody3D")
	if body:
		var visual := body.get_node_or_null("LogVisualParent") as Node3D
		_check(visual != null, "có LogVisualParent")
		if visual:
			var mmi := visual.get_node_or_null("LogVisual") as MultiMeshInstance3D
			_check(mmi != null and mmi.multimesh != null, "có LogVisual MultiMeshInstance3D")
			if mmi:
				_check(absf(mmi.rotation_degrees.z - 90.0) < 0.01 and mmi.rotation_degrees.x == 0.0,
					"axis X -> model nằm dọc X (rot %s)" % mmi.rotation_degrees)
		var cs: CollisionShape3D = null
		for ch in body.get_children():
			if ch is CollisionShape3D:
				cs = ch
		_check(cs != null and cs.shape is BoxShape3D, "có collider hộp")

	# Hướng đứng: nâng 1.0, X nâng 0.23
	ps._place_log_model(root3d, "log_palm", Vector3.ZERO, "ST")
	_check(root3d.get_child_count() >= 2, "đặt được 2 khúc gỗ")
	var body_st := root3d.get_child(1) as StaticBody3D
	_check(body_st != null and absf(body_st.global_position.y - 1.0) < 0.01,
		"đứng được nâng lên mặt (y=%.2f)" % (body_st.global_position.y if body_st else -1.0))

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)