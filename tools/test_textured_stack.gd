extends Node

## test_textured_stack — Block có texture (gỗ) khi place chồng nhiều lớp: overlay
## mesh phủ kín CẢ cột (side quad từ đáy lớp dưới tới đỉnh lớp trên), không chỉ
## topmost — block bên dưới không bị mất texture. Chạy qua tools/test_textured_stack.tscn.

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Chunk = preload("res://scripts/world/chunk/world_chunk.gd")

const CHUNK_SIZE: int = 32
const SLAB: float = _BlockData.SLAB_HEIGHT

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _mesh_aabb(mesh: ArrayMesh) -> Array:
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			min_v = Vector3(minf(min_v.x, v.x), minf(min_v.y, v.y), minf(min_v.z, v.z))
			max_v = Vector3(maxf(max_v.x, v.x), maxf(max_v.y, v.y), maxf(max_v.z, v.z))
	return [min_v, max_v]

func _layer_top_y(ly: int) -> float:
	return (float(ly + _BlockData.Y_MIN) + 1.0) * SLAB

func _layer_bottom_y(ly: int) -> float:
	return float(ly + _BlockData.Y_MIN) * SLAB

func _layer_center_y(ly: int) -> float:
	return _BlockData.layer_to_world_y(ly)

func _ready() -> void:
	seed(20260812)
	print("== test_textured_stack: texture phủ kín cột gỗ xếp chồng ==")

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
	var wx: float = -half + (float(gx) + 0.5) * _Data.VOXEL
	var wz: float = -half + (float(gz) + 0.5) * _Data.VOXEL

	# ── 1. 1 block gỗ trên mặt đất → AABB đúng 1 slab ────────────────────────
	var l1: int = ground_ly + 1
	_check(chunk.place_block_at(wx, _layer_center_y(l1), wz, _Data.BlockID.OAK_WOOD), "đặt 1 block gỗ")
	var mi1: MeshInstance3D = chunk._textured_block_mesh_instances.get(_Data.BlockID.OAK_WOOD) as MeshInstance3D
	_check(mi1 != null, "có overlay mesh gỗ")
	if mi1 != null:
		var box1: Array = _mesh_aabb(mi1.mesh)
		_check(absf(box1[0].y - _layer_bottom_y(l1)) < 0.01, "1 block: đáy mesh = đáy block (%.3f)" % box1[0].y)

	# ── 2. Chồng thêm block thứ 2 → mesh kéo dài xuống tận block dưới ────────
	var l2: int = ground_ly + 2
	_check(chunk.place_block_at(wx, _layer_center_y(l2), wz, _Data.BlockID.OAK_WOOD), "chồng block gỗ thứ 2")
	var mi2: MeshInstance3D = chunk._textured_block_mesh_instances.get(_Data.BlockID.OAK_WOOD) as MeshInstance3D
	_check(mi2 != null, "overlay mesh gỗ sau khi chồng")
	if mi2 != null:
		var box2: Array = _mesh_aabb(mi2.mesh)
		_check(absf(box2[0].y - _layer_bottom_y(l1)) < 0.01,
			"2 block: side phủ xuống đáy block dưới (minY %.3f == %s)" % [box2[0].y, _layer_bottom_y(l1)])
		_check(absf(box2[1].y - (_layer_top_y(l2) + 0.01)) < 0.01,
			"2 block: đỉnh = đỉnh block trên (maxY %.3f)" % box2[1].y)
		_check(box2[1].y - box2[0].y > SLAB * 1.5,
			"2 block: chiều cao phủ > 1 slab (cao %.3f)" % (box2[1].y - box2[0].y))

	# ── 3. Chồng thêm block thứ 3 → vẫn phủ kín cả cột 3 ─────────────────────
	var l3: int = ground_ly + 3
	_check(chunk.place_block_at(wx, _layer_center_y(l3), wz, _Data.BlockID.OAK_WOOD), "chồng block gỗ thứ 3")
	var mi3: MeshInstance3D = chunk._textured_block_mesh_instances.get(_Data.BlockID.OAK_WOOD) as MeshInstance3D
	if mi3 != null:
		var box3: Array = _mesh_aabb(mi3.mesh)
		_check(absf(box3[0].y - _layer_bottom_y(l1)) < 0.01,
			"3 block: side phủ xuống đáy block dưới cùng (minY %.3f)" % box3[0].y)
		_check(absf(box3[1].y - (_layer_top_y(l3) + 0.01)) < 0.01,
			"3 block: đỉnh = đỉnh block trên cùng (maxY %.3f)" % box3[1].y)

	# ── 4. Dựng hàng ghép lại → tường gỗ 1×2×1 vẫn phủ kín ───────────────────
	var wx2: float = -half + (float(gx + 2) + 0.5) * _Data.VOXEL
	_check(chunk.place_block_at(wx2, _layer_center_y(l1), wz, _Data.BlockID.OAK_WOOD), "đặt cột gỗ bên cạnh (A)")
	_check(chunk.place_block_at(wx2, _layer_center_y(l2), wz, _Data.BlockID.OAK_WOOD), "đặt cột gỗ bên cạnh (B)")
	var mi4: MeshInstance3D = chunk._textured_block_mesh_instances.get(_Data.BlockID.OAK_WOOD) as MeshInstance3D
	if mi4 != null:
		var box4: Array = _mesh_aabb(mi4.mesh)
		_check(absf(box4[0].y - _layer_bottom_y(l1)) < 0.01,
			"loại mesh giữa (cột A side) không dính vào cột B — minY %.3f" % box4[0].y)

	chunk.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)