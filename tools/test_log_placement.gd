extends Node

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_log_placement ==")
	var D = load("res://scripts/world/chunk/chunk_data.gd")
	var PS = load("res://scripts/building/placement_system.gd")

	# Hướng đứng khi nhắm mặt trên/dưới
	_check(PS._log_bid_for("log_oak", Vector3(0, 1, 0)) == D.BlockID.LOG_OAK_ST, "normal.y → đứng (oak)")
	_check(PS._log_bid_for("log_palm", Vector3(0, -1, 0)) == D.BlockID.LOG_PALM_ST, "normal.y âm → đứng (palm)")
	# Nằm theo trục còn lại khi nhắm mặt bên
	_check(PS._log_bid_for("log_oak", Vector3(1, 0, 0)) == D.BlockID.LOG_OAK_Z, "normal.x → nằm dài Z")
	_check(PS._log_bid_for("log_oak", Vector3(0, 0, 1)) == D.BlockID.LOG_OAK_X, "normal.z → nằm dài X")
	_check(PS._log_bid_for("log_spruce", Vector3(0, 0, -1)) == D.BlockID.LOG_SPRUCE_X, "normal.z âm → nằm X (spruce)")

	# Tất cả hướng có shape + hardness + màu hợp lệ
	for id in [D.BlockID.LOG_OAK_X, D.BlockID.LOG_OAK_Z, D.BlockID.LOG_OAK_ST,
			D.BlockID.LOG_HARD_X, D.BlockID.LOG_SPRUCE_X, D.BlockID.LOG_SWAMP_X,
			D.BlockID.LOG_MANGROVE_X, D.BlockID.LOG_PALM_ST]:
		_check(D.block_shape(id) != Vector3.ZERO, "shape %d" % id)
		_check(D.get_block_hardness(id) > 0.0, "hardness %d" % id)
		_check(D.BLOCK_COLORS_RW[id].r > 0.0, "color %d" % id)
		_check(D.is_shaped_block(id), "is_shaped %d" % id)

	# Các item log đều là log items
	for it in ["log_oak", "log_hard_wood", "log_spruce", "log_swamp", "log_mangrove", "log_palm"]:
		_check(PS.is_log_item(it), "is_log_item %s" % it)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)