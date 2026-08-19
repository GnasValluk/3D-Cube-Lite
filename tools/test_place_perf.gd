extends Node

## test_place_perf — kiểm tra tối ưu placement:
## - Đặt hàng loạt (bulk) chỉ rebuild mesh 1 lần thay vì 1 lần/cell (gây giật).
## - So sánh thời gian per-cell vs bulk trên mock world.

const MockWorld = preload("res://tools/mock_world.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")

const PLANK: int = _D.BlockID.STONE_PLATFORM

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _place_one_by_one(mock: Node) -> int:
	var placed: int = 0
	for i in range(9):
		if mock.place_block(float(i), 0.0, 0.0, PLANK, _BD.OFF_CENTER):
			placed += 1
	return placed

func _place_bulk(mock: Node) -> int:
	var positions: Array[Vector3] = []
	var bids: Array[int] = []
	for i in range(9):
		positions.append(Vector3(float(i), 0.0, 0.0))
		bids.append(PLANK)
	return mock.place_blocks_bulk(positions, bids, _BD.OFF_CENTER)

func _ready() -> void:
	print("== test_place_perf ==")

	var mock := MockWorld.new()
	add_child(mock)

	mock.place_block(3.0, 0.0, 0.0, _D.BlockID.STONE, _BD.OFF_CENTER)
	mock.place_block(4.0, 0.0, 0.0, _D.BlockID.STONE, _BD.OFF_CENTER)
	_check(mock.rebuild_count == 2, "setup: 2 ô đặc, 2 lần rebuild")

	var t0 := Time.get_ticks_usec()
	var placed_a: int = _place_one_by_one(mock)
	var t1 := Time.get_ticks_usec()
	var rebuilds_a: int = mock.rebuild_count - 2

	_check(placed_a == 7, "per-cell: 9 ô bỏ 2 ô đặc = 7")
	_check(rebuilds_a == 7, "per-cell: 7 ô đặt được = 7 lần rebuild (lag cũ)")

	var mock_b := MockWorld.new()
	add_child(mock_b)
	mock_b.place_block(3.0, 0.0, 0.0, _D.BlockID.STONE, _BD.OFF_CENTER)
	mock_b.place_block(4.0, 0.0, 0.0, _D.BlockID.STONE, _BD.OFF_CENTER)
	var rb_before: int = mock_b.rebuild_count
	var t2 := Time.get_ticks_usec()
	var placed_b: int = _place_bulk(mock_b)
	var t3 := Time.get_ticks_usec()
	var rebuilds_b: int = mock_b.rebuild_count - rb_before

	_check(placed_b == 7, "bulk: 9 ô bỏ 2 ô đặc = 7")
	_check(rebuilds_b == 1, "bulk: chỉ 1 lần rebuild (không giật)")

	print("time per-cell 9 place: %d us | bulk 9 place: %d us" % [int(t1 - t0), int(t3 - t2)])
	print("rebuild count per-cell=%d, bulk=%d" % [rebuilds_a, rebuilds_b])

	mock.queue_free()
	mock_b.queue_free()

	print("== test_place_perf %s (%d fail) ==" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
