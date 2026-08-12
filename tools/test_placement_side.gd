extends Node

## test_placement_side — Placement snap theo đúng lưới thế giới (ngang VOXEL=1.0,
## cao slab 0.5): đặt được block sang BÊN (trái/phải) kể cả khi bên dưới là AIR,
## và ghost full-block có kích thước đúng 1.0×0.5×1.0.
## Chạy qua tools/test_placement_side.tscn (không chạy trực tiếp file .gd).

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Chunk = preload("res://scripts/world/chunk/world_chunk.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const CHUNK_SIZE: int = 32
const SLAB: float = _BlockData.SLAB_HEIGHT

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _layer_top_y(ly: int) -> float:
	return (float(ly + _BlockData.Y_MIN) + 1.0) * SLAB

func _layer_bottom_y(ly: int) -> float:
	return float(ly + _BlockData.Y_MIN) * SLAB

func _layer_center_y(ly: int) -> float:
	return _BlockData.layer_to_world_y(ly)

func _ready() -> void:
	seed(20260812)
	print("== test_placement_side: snap lưới thế giới + đặt ngang không cần chân ==")

	var ps := _Placement.new()
	add_child(ps)

	# ── 1. Snap top-face: đặt lên trên slab 20 → min-corner layer 21 ─────────
	var snap_top := ps._snap_to_surface(Vector3(10.42, _layer_top_y(20), 8.73), Vector3.UP)
	_check(snap_top == Vector3(10, _layer_top_y(20), 8),
		"top-face snap → (10, top_y20, 8) được %s" % str(snap_top))
	_check(_BlockData.world_y_to_layer(snap_top.y) == 21,
		"top-face snap: layer đặt = 21 (bên trên block)")

	# ── 2. Snap under-face: đặt dưới đáy slab 20 → layer 19 ───────────────────
	var snap_bot := ps._snap_to_surface(Vector3(10.42, _layer_bottom_y(20), 8.73), Vector3.DOWN)
	_check(snap_bot == Vector3(10, _layer_bottom_y(19), 8),
		"under-face snap → (10, bottom_y19, 8) được %s" % str(snap_bot))

	# ── 3. Snap side-face: trái/phải quanh biên x = 100.0 ─────────────────────
	var hit_side := Vector3(100.0, _layer_center_y(20), 50.5)
	var snap_l := ps._snap_to_surface(hit_side, Vector3(-1, 0, 0))
	var snap_r := ps._snap_to_surface(hit_side, Vector3(1, 0, 0))
	_check(snap_l == Vector3(99, _layer_bottom_y(20), 50),
		"side nhìn từ -x → ô trái (x=99) được %s" % str(snap_l))
	_check(snap_r == Vector3(100, _layer_bottom_y(20), 50),
		"side nhìn từ +x → ô phải (x=100) được %s" % str(snap_r))
	_check(snap_l != snap_r, "trái ≠ phải (bản cũ round 0.5 dính cùng 1 ô)")

	# ── 4. Ghost block: kích thước bằng ô thế giới ────────────────────────────
	ps._item_id = "block_stone"
	ps._make_ghost()
	await get_tree().physics_frame
	var g_full: MeshInstance3D = ps._ghost.get_child(0) as MeshInstance3D
	_check(g_full != null and g_full.mesh is BoxMesh, "ghost full-block có BoxMesh")
	if g_full != null and g_full.mesh is BoxMesh:
		_check((g_full.mesh as BoxMesh).size == Vector3(_Data.VOXEL, SLAB, _Data.VOXEL),
			"ghost full-block size = 1.0×0.5×1.0 được %s" % str((g_full.mesh as BoxMesh).size))
		_check(g_full.position == Vector3(0.5, SLAB * 0.5, 0.5),
			"ghost full-block tâm ô (r=0.5,0.25,0.5) được %s" % str(g_full.position))
	ps._item_id = "block_stone_qtr"
	ps._make_ghost()
	await get_tree().physics_frame
	var g_shp: MeshInstance3D = ps._ghost.get_child(0) as MeshInstance3D
	if g_shp != null and g_shp.mesh is BoxMesh:
		_check((g_shp.mesh as BoxMesh).size == _Data.block_shape(_Data.BlockID.STONE_QTR),
			"ghost shaped size = 0.5×0.5×0.5 được %s" % str((g_shp.mesh as BoxMesh).size))

	# ── 5. Pipeline thật: cột đá ↔ đặt ngang không cần block dưới ─────────────
	var chunk := _Chunk.new()
	chunk.setup(0, 0, CHUNK_SIZE, _Data._Dim.DimensionID.REAL_WORLD, true)
	add_child(chunk)
	chunk.position = Vector3.ZERO
	_check(chunk._built, "chunk sync build xong")

	var cols: int = chunk._cols
	var max_top: int = -1
	for tv in chunk._top_ly_cache:
		max_top = maxi(max_top, tv)
	var ground_ly: int = -1
	var gx: int = 0
	var gz: int = 0
	for ly0 in range(max_top + 1, -1, -1):
		var found := false
		for x in range(8, cols - 8):
			for z in range(8, cols - 8):
				if chunk._top_ly_cache[x * cols + z] != ly0:
					continue
				if chunk._top_ly_cache[(x - 1) * cols + z] == ly0 \
						and chunk._top_ly_cache[(x + 1) * cols + z] == ly0 \
						and chunk._top_ly_cache[x * cols + (z - 1)] == ly0 \
						and chunk._top_ly_cache[x * cols + (z + 1)] == ly0:
					ground_ly = ly0
					gx = x
					gz = z
					found = true
					break
			if found:
				break
		if found:
			break
	_check(ground_ly >= 0, "tìm cột cao nguyên (top_ly=%s at %s,%s)" % [ground_ly, gx, gz])

	var half: float = CHUNK_SIZE * 0.5
	var src_ly: int = ground_ly + 8
	var src_cy := _layer_center_y(src_ly)
	var wx_src: float = -half + (float(gx) + 0.5) * _Data.VOXEL
	var wz_src: float = -half + (float(gz) + 0.5) * _Data.VOXEL
	_check(chunk.place_block_at(wx_src, src_cy, wz_src, _Data.BlockID.STONE),
		"đặt cột nguồn (stone) tại (%s, %s, %s)" % [gx, src_ly, gz])

	# Mặt trái cột nguồn (world min-corner x), nhìn từ -x → đặt sang trái
	var src_min_x: float = -half + float(gx) * _Data.VOXEL
	var snap_on_col := ps._snap_to_surface(Vector3(src_min_x, src_cy, wz_src), Vector3(-1, 0, 0))
	var ok_l: bool = chunk.place_block_at(snap_on_col.x, snap_on_col.y, snap_on_col.z, _Data.BlockID.STONE)
	var lx_cell: int = chunk.world_to_local_block(snap_on_col.x, snap_on_col.y, snap_on_col.z).x
	_check(ok_l, "place ngang (trái) THÀNH CÔNG — không cần block dưới")
	if ok_l:
		_check(lx_cell == gx - 1, "đặt o bên trái cột (cell %s == %s)" % [lx_cell, gx - 1])
		_check(chunk.block_data.get_block(lx_cell, src_ly, gz) == _Data.BlockID.STONE,
			"stone nằm đúng o (%s, %s, %s)" % [lx_cell, src_ly, gz])
		_check(chunk.block_data.get_block(lx_cell, src_ly - 1, gz) == _Data.BlockID.AIR,
			"bên dưới o trái vẫn AIR (không kê chân)")

	# Mặt phải cột nguồn → đặt sang phải
	var snap_rc := ps._snap_to_surface(Vector3(src_min_x + _Data.VOXEL, src_cy, wz_src), Vector3(1, 0, 0))
	var ok_r: bool = chunk.place_block_at(snap_rc.x, snap_rc.y, snap_rc.z, _Data.BlockID.STONE)
	var rx_cell: int = chunk.world_to_local_block(snap_rc.x, snap_rc.y, snap_rc.z).x
	_check(ok_r, "place ngang (phải) THÀNH CÔNG — không cần block dưới")
	if ok_r:
		_check(rx_cell == gx + 1, "đặt o bên phải cột (cell %s == %s)" % [rx_cell, gx + 1])
		_check(chunk.block_data.get_block(rx_cell, src_ly - 1, gz) == _Data.BlockID.AIR,
			"bên dưới o phải vẫn AIR (không kê chân)")

	# ── 6. Pipeline thật: đặt chồng lên trên cùng layer ───────────────────────
	var snap_up := ps._snap_to_surface(Vector3(wx_src, _layer_top_y(src_ly), wz_src), Vector3.UP)
	var ok_up: bool = chunk.place_block_at(snap_up.x, snap_up.y, snap_up.z, _Data.BlockID.STONE)
	var up_ly: int = chunk.world_to_local_block(snap_up.x, snap_up.y, snap_up.z).y
	_check(ok_up, "place chồng lên trên thành công")
	if ok_up:
		_check(up_ly == src_ly + 1, "chồng đúng layer %s == %s" % [up_ly, src_ly + 1])

	ps.queue_free()
	chunk.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)