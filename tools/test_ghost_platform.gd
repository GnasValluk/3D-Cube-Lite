extends Node

const D = preload("res://scripts/world/chunk/chunk_data.gd")
const BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const MOCK = "res://tools/mock_world.gd"

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _ready() -> void:
	print("== test_ghost_platform ==")
	var PS: Script = load("res://scripts/building/placement_system.gd")
	var root := Node3D.new()
	add_child(root)
	var mock: Node = load(MOCK).new()
	mock.name = "WorldManager"
	root.add_child(mock)
	var ps: Node = PS.new()
	root.add_child(ps)

	var layer: int = 10
	var by: float = (float(layer) + float(BD.Y_MIN)) * BD.SLAB_HEIGHT
	var bx: int = 2
	var bz: int = 3

	# ── Case 1: nền 3×3 còn 1 ô trống → xanh (chồng 1 phần) ──
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			mock.place_block(float(bx + dx), by, float(bz + dz), D.BlockID.STONE_PLATFORM)
	ps._item_id = "block_stone_platform"
	ps._ghost_pos = Vector3(bx, by, bz)
	_check(ps._platform_placeable_cells() == 1, "nền chồng 1 phần còn 1 ô trống (có %d)" % ps._platform_placeable_cells())
	_check(ps._check_ghost_valid(), "ghost XANH khi chồng 1 phần")
	_check(ps._place_platform("block_stone_platform", Vector3(bx, by, bz)), "place được khi chồng 1 phần")

	# ── Case 2: nền lấp kín 9 ô → đỏ (chồng hoàn toàn) ──
	mock.place_block(float(bx), by, float(bz), D.BlockID.STONE_PLATFORM)
	ps._ghost_pos = Vector3(bx, by, bz)
	_check(ps._platform_placeable_cells() == 0, "nền chồng hoàn toàn 0 ô trống")
	_check(not ps._check_ghost_valid(), "ghost ĐỎ khi chồng hoàn toàn")
	_check(not ps._place_platform("block_stone_platform", Vector3(bx, by, bz)), "không place khi chồng hoàn toàn")

	# ── Case 3: block đơn chồng ô đã chiếm → đỏ ──
	ps._item_id = "block_stone"
	ps._ghost_pos = Vector3(bx + 5, by, bz + 5)
	_check(ps._check_ghost_valid(), "block đơn vào ô trống → xanh")
	mock.place_block(float(bx + 5), by, float(bz + 5), D.BlockID.DIRT)
	ps._ghost_pos = Vector3(bx + 5, by, bz + 5)
	_check(not ps._check_ghost_valid(), "block đơn chồng ô bị chiếm → đỏ")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)