extends Node

## test_diag_side — Block đặt chồng lệch 1 ô (phía trên + cách sang bên) KHÔNG
## được làm mất mặt bên của block dưới cùng chiều (trước đây cột lân cận có
## top cao hơn → mặt bên bị cull → nhìn thấy void). Block lơ lửng phải có mặt
## dưới (game có 2 góc nhìn, không chỉ isometric).
## Chạy qua tools/test_diag_side.tscn (không chạy trực tiếp file .gd).

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

func _layer_top_y(ly: int) -> float:
	return (float(ly + _BlockData.Y_MIN) + 1.0) * SLAB

func _layer_bottom_y(ly: int) -> float:
	return float(ly + _BlockData.Y_MIN) * SLAB

## Vertex mặt bên: `axis` là trục cố định của mặt phẳng tường (0 = x, 2 = z),
## `plane` là tọa độ mặt phẳng; y trong [y_lo, y_hi]; normal trùng hướng.
## Yêu cầu đủ CẢ 2 góc quad (span_lo + span_hi trên trục còn lại) để loại
## nhiễu từ tường cột lân cận — vertex góc chung tại biên 2 cột chỉ đóng góp
## 1 góc (tọa độ các góc quad đều lệch đúng 0.5 so với tâm cột).
func _has_wall_vert(chunk: Node, axis: int, plane: float,
		span_lo: float, span_hi: float,
		y_lo: float, y_hi: float, normal: Vector3) -> bool:
	var mesh: ArrayMesh = chunk._terrain_mesh_instance.mesh
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var span_axis: int = 2 if axis == 0 else 0
		var found_lo := false
		var found_hi := false
		for i in range(verts.size()):
			var v: Vector3 = verts[i]
			if absf(v[axis] - plane) >= 0.01:
				continue
			if v.y <= y_lo - 0.001 or v.y >= y_hi + 0.001:
				continue
			if norms[i].dot(normal) <= 0.9:
				continue
			if absf(v[span_axis] - span_lo) < 0.01:
				found_lo = true
			elif absf(v[span_axis] - span_hi) < 0.01:
				found_hi = true
		if found_lo and found_hi:
			return true
	return false

## Vertex mặt dưới: y chính xác, x/z trong bán kính 0.51 quanh tâm cột, normal
## hướng xuống — phân biệt với mặt top/đáy/đỉnh của block lân cận.
func _has_bottom_vert(chunk: Node, cx: float, y: float, cz: float) -> bool:
	var mesh: ArrayMesh = chunk._terrain_mesh_instance.mesh
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in range(verts.size()):
			var v: Vector3 = verts[i]
			if absf(v.x - cx) <= 0.51 and absf(v.z - cz) <= 0.51 \
					and absf(v.y - y) < 0.01 and norms[i].y < -0.9:
				return true
	return false

func _ready() -> void:
	seed(20260804)
	print("== test_diag_side: mặt bên + mặt dưới block chồng lệch ==")

	# ── 1. Dựng chunk REAL_WORLD đồng bộ ───────────────────────────────────
	var chunk := _Chunk.new()
	chunk.setup(0, 0, CHUNK_SIZE, _Data._Dim.DimensionID.REAL_WORLD, true)
	add_child(chunk)
	chunk.position = Vector3.ZERO
	_check(chunk._built, "chunk sync build xong")
	_check(chunk._terrain_mesh_instance != null, "chunk có terrain mesh")

	# ── 2. Tìm cột cao nguyên (4 ô lân cận cùng độ cao, không sát biên) ─────
	var cols: int = chunk._cols
	var ground_ly: int = -1
	var gx: int = 0
	var gz: int = 0
	var max_top: int = -1
	for tv in chunk._top_ly_cache:
		max_top = maxi(max_top, tv)
	for ly0 in range(max_top + 1, -1, -1):
		var found := false
		for x in range(4, cols - 5):
			for z in range(4, cols - 5):
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
	_check(ground_ly >= 0, "tìm thấy cột cao nguyên (top_ly=%s at %s,%s)" % [ground_ly, gx, gz])

	var half: float = CHUNK_SIZE * 0.5
	var cx_a: float = -half + (float(gx) + 0.5) * _Data.VOXEL
	var cz: float = -half + (float(gz) + 0.5) * _Data.VOXEL
	var cx_b: float = -half + (float(gx + 1) + 0.5) * _Data.VOXEL

	# ── 3. Block A trên mặt đất; B và E chồng lệch: +1 x/+1 z, +1 layer ─────
	var ly_a: int = ground_ly + 1
	var ly_b: int = ground_ly + 2
	var wy_a: float = (float(ly_a + _BlockData.Y_MIN) + 0.5) * SLAB
	var wy_b: float = (float(ly_b + _BlockData.Y_MIN) + 0.5) * SLAB
	_check(chunk.place_block_at(cx_a, wy_a, cz, _Data.BlockID.GRASS), "đặt block A (mặt đất)")
	_check(chunk.place_block_at(cx_b, wy_b, cz, _Data.BlockID.STONE),
		"đặt block B chồng lệch +1 x, +1 layer")
	_check(chunk.place_block_at(cx_a, wy_b, cz + _Data.VOXEL, _Data.BlockID.STONE),
		"đặt block E chồng lệch +1 z, +1 layer")

	# ── 4. Mặt bên block dưới phải còn (không thấy void) ────────────────────
	var bx: float = cx_a + _Data.VOXEL * 0.5   # mặt phân cách cột A | B
	var bz: float = cz + _Data.VOXEL * 0.5     # mặt phân cách cột A | E
	var span_lo: float = cz - _Data.VOXEL * 0.5
	var span_hi: float = cz + _Data.VOXEL * 0.5
	_check(_has_wall_vert(chunk, 0, bx, span_lo, span_hi,
		_layer_bottom_y(ly_a), _layer_top_y(ly_a), Vector3(1, 0, 0)),
		"mặt bên +x của block A vẫn còn (không thấy void)")
	_check(_has_wall_vert(chunk, 2, bz, span_lo, span_hi,
		_layer_bottom_y(ly_a), _layer_top_y(ly_a), Vector3(0, 0, 1)),
		"mặt bên +z của block A vẫn còn (hướng chéo khác)")
	_check(_has_wall_vert(chunk, 0, bx, span_lo, span_hi,
		_layer_bottom_y(ly_b), _layer_top_y(ly_b), Vector3(-1, 0, 0)),
		"mặt bên -x của block B vẫn còn")
	_check(_has_wall_vert(chunk, 2, bz, span_lo, span_hi,
		_layer_bottom_y(ly_b), _layer_top_y(ly_b), Vector3(0, 0, -1)),
		"mặt bên -z của block E vẫn còn")

	# ── 5. Mặt dưới block lơ lửng (2 góc nhìn) ─────────────────────────────
	_check(_has_bottom_vert(chunk, cx_b, _layer_bottom_y(ly_b), cz),
		"mặt dưới block B được vẽ (không nhìn xuyên từ dưới lên)")
	_check(_has_bottom_vert(chunk, cx_a, _layer_bottom_y(ly_b), cz + _Data.VOXEL),
		"mặt dưới block E được vẽ")
	# Block A nằm trên mặt đất đặc → không được vẽ mặt dưới thừa
	_check(not _has_bottom_vert(chunk, cx_a, _layer_bottom_y(ly_a), cz),
		"mặt dưới block A không vẽ (đất đặc bên dưới)")

	# ── 6. Đào block chồng lệch → mặt lân cận không sập, mặt B biến mất ─────
	_check(chunk.break_block_at(cx_b, wy_b, cz) == _Data.BlockID.STONE, "đào block B")
	_check(_has_wall_vert(chunk, 0, bx, span_lo, span_hi,
		_layer_bottom_y(ly_a), _layer_top_y(ly_a), Vector3(1, 0, 0)),
		"sau đào B: mặt bên +x của block A vẫn còn")
	_check(not _has_wall_vert(chunk, 0, bx, span_lo, span_hi,
		_layer_bottom_y(ly_b), _layer_top_y(ly_b), Vector3(-1, 0, 0)),
		"sau đào B: mặt -x của B biến mất (không còn block)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
