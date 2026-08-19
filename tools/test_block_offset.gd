extends Node

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_block_offset ==")
	var BD = load("res://scripts/world/chunk/chunk_block_data.gd")
	var bd = BD.new()
	var cols := 4
	bd.init(cols, cols)

	# Mặc định mọi ô = OFF_CENTER
	_check(bd.get_offset(1, 1, 1) == bd.OFF_CENTER, "offset mặc định = tâm")

	# Đặt offset nhiều vị trí + roundtrip
	for entry in [Vector3i(0, 0, 0), Vector3i(3, 68, 2), Vector3i(2, 10, 3)]:
		var o: int = bd.OFF_CENTER
		match entry:
			Vector3i(0, 0, 0): o = 0
			Vector3i(3, 68, 2): o = 8
			Vector3i(2, 10, 3): o = 3
		bd.set_offset(entry.x, entry.y, entry.z, o)
		_check(bd.get_offset(entry.x, entry.y, entry.z) == o, "offset lưu đúng %s" % str(entry))

	var bytes: PackedByteArray = bd.to_bytes()
	_check(bytes.size() == cols * cols * (bd.Y_MAX - bd.Y_MIN + 1) * 2, "to_bytes gồm offsets (2×)")

	var bd2 = BD.new()
	bd2.from_bytes(bytes, cols, cols)
	_check(bd2.get_offset(0, 0, 0) == 0, "roundtrip offset 0")
	_check(bd2.get_offset(3, 68, 2) == 8, "roundtrip offset 8")
	_check(bd2.get_offset(2, 10, 3) == 3, "roundtrip offset 3")
	_check(bd2.get_offset(1, 1, 1) == 4, "roundtrip mặc định tâm")
	_check(bd2.get_block(1, 1, 1) == 0, "block data roundtrip")

	# Chunk cũ (không offsets) vẫn đọc được — giả format 1×
	var old_bytes: PackedByteArray = bytes.slice(0, cols * cols * (bd.Y_MAX - bd.Y_MIN + 1))
	var bd3 = BD.new()
	bd3.from_bytes(old_bytes, cols, cols)
	_check(bd3.get_offset(0, 0, 0) == 4, "chunk cũ (1×) → offset tâm")

	# offset_delta decode
	_check(bd.offset_delta(4) == Vector2.ZERO, "delta tâm = 0")
	_check(bd.offset_delta(0) == Vector2(-0.25, -0.25), "delta index 0 = (-0.25,-0.25)")
	_check(bd.offset_delta(2) == Vector2(-0.25, 0.25), "delta index 2 = (-0.25,+0.25)")
	_check(bd.offset_delta(8) == Vector2(0.25, 0.25), "delta index 8 = (+0.25,+0.25)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)