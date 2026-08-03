extends Node

## test_build_float — Block đặt lơ lửng (phía trên cao, bên dưới không có
## block) KHÔNG được tạo "full cột" xuống mặt đất: raycast ngang ở giữa
## khoảng trống phải xuyên qua (bản cũ bị tường ảo chặn). Sau khi kê cột
## xuống đất → tường chặn ray trở lại. Đào block lơ lửng hoạt động bình
## thường; vị trí ảo không có block trong dữ liệu.
## Chạy qua tools/test_build_float.tscn (không chạy trực tiếp file .gd).

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

func _wait_frames(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

## World-Y của đỉnh layer ly (mặt trên slab)
func _layer_top_y(ly: int) -> float:
	return (float(ly + _BlockData.Y_MIN) + 1.0) * SLAB

## World-Y của đáy layer ly (mặt dưới slab)
func _layer_bottom_y(ly: int) -> float:
	return float(ly + _BlockData.Y_MIN) * SLAB

## Y cao nhất của đỉnh mesh trong ô cột (lx, lz).
func _max_vert_y(chunk: Node, lx: int, lz: int) -> float:
	var mesh: ArrayMesh = chunk._terrain_mesh_instance.mesh
	var half: float = CHUNK_SIZE * 0.5
	var cx: float = -half + (float(lx) + 0.5) * _Data.VOXEL
	var cz: float = -half + (float(lz) + 0.5) * _Data.VOXEL
	var best: float = -INF
	for si in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			if absf(v.x - cx) <= 0.55 and absf(v.z - cz) <= 0.55:
				best = maxf(best, v.y)
	return best

## Raycast ngang (trục -x) ở độ cao y, đi qua giữa cột. True nếu có chặn.
func _ray_hits_x(y: float, wx: float, wz: float) -> bool:
	var space := get_tree().root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(wx + 3.0, y, wz), Vector3(wx - 3.0, y, wz))
	var r := space.intersect_ray(q)
	return not r.is_empty()

func _ready() -> void:
	seed(20260802)
	print("== test_build_float: block lơ lửng không đổ cột ảo ==")

	# ── 1. Dựng chunk REAL_WORLD đồng bộ ───────────────────────────────────
	var chunk := _Chunk.new()
	chunk.setup(0, 0, CHUNK_SIZE, _Data._Dim.DimensionID.REAL_WORLD, true)
	add_child(chunk)
	chunk.position = Vector3.ZERO
	_check(chunk._built, "chunk sync build xong")
	_check(chunk._terrain_mesh_instance != null, "chunk có terrain mesh")

	# ── 2. Tìm cột cao nguyên (top cao nhất, 4 ô lân cận bằng nhau, không
	#       sát biên chunk) — cột đất không có tường đứng cao ────────────────
	var cols: int = chunk._cols
	var ground_ly: int = -1
	var gx: int = 0
	var gz: int = 0
	var max_top: int = -1
	for tv in chunk._top_ly_cache:
		max_top = maxi(max_top, tv)
	for ly0 in range(max_top + 1, -1, -1):
		var found := false
		for x in range(4, cols - 4):
			for z in range(4, cols - 4):
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
	var wx0: float = -half + (float(gx) + 0.5) * _Data.VOXEL
	var wz0: float = -half + (float(gz) + 0.5) * _Data.VOXEL
	var ground_top_y: float = _layer_top_y(ground_ly)

	# ── 3. Đặt block lơ lửng: 10 slab trên mặt đất, bên dưới là AIR ─────────
	var float_ly: int = ground_ly + 10
	var wy: float = (float(float_ly + _BlockData.Y_MIN) + 0.5) * SLAB
	_check(chunk.place_block_at(wx0, wy, wz0, _Data.BlockID.GRASS), "đặt block lơ lửng thành công")
	_check(chunk.block_data.get_block(gx, float_ly - 1, gz) == _Data.BlockID.AIR,
		"bên dưới block vẫn là AIR (không tự sinh block)")
	var blk := chunk.world_to_local_block(wx0, wy, wz0)
	_check(blk.y == float_ly, "layer đặt đúng (%s == %s)" % [blk.y, float_ly])
	_check(absf(_max_vert_y(chunk, gx, gz) - _layer_top_y(float_ly)) < 0.01,
		"đỉnh mesh = đỉnh block (%s)" % str(_max_vert_y(chunk, gx, gz)))

	# ── 3b. Mặt đất dưới block lơ lửng vẫn còn (không lỗ hổng xuống void) ──
	# Ray thẳng xuống TRONG khe hở (dưới block) phải trúng mặt đất, không rơi
	# xuyên qua — đảm bảo không ngã xuống void khi đứng trong khe.
	await _wait_frames(3)
	var hole_ray := PhysicsRayQueryParameters3D.create(
		Vector3(wx0, ground_top_y + 1.0, wz0), Vector3(wx0, ground_top_y - 3.0, wz0))
	var hole_hit := get_tree().root.get_world_3d().direct_space_state.intersect_ray(hole_ray)
	_check(not hole_hit.is_empty(), "dưới block lơ lửng: ray chạm gì đó (không rơi xuống void)")
	_check(not hole_hit.is_empty() and absf(hole_hit.get("position", Vector3(0, -99, 0)).y - ground_top_y) < 0.01,
		"dưới block lơ lửng: ray trúng mặt đất y=%s" % str(ground_top_y))

	# ── 4. TIA NGANG giữa mặt đất và block: bản cũ bị tường ảo chặn ─────────
	await _wait_frames(3)
	var mid_y: float = ground_top_y + 0.5 + (float_ly - ground_ly) * SLAB * 0.5
	_check(not _ray_hits_x(mid_y, wx0, wz0), "tia ngang xuyên qua khoảng trống (tường ảo đã hết)")

	# ── 5. Vị trí "block ảo" cũ không tồn tại trong dữ liệu ─────────────────
	var phantom_ly: int = ground_ly + 5
	var phantom_wy: float = (float(phantom_ly + _BlockData.Y_MIN) + 0.5) * SLAB
	_check(chunk.break_block_at(wx0, phantom_wy, wz0) == 0,
		"vị trí ảo giữa không đào được gì (air)")

	# ── 6. Chồng thêm block nữa (vẫn lơ lửng, không kê đất) ─────────────────
	var float_ly2: int = float_ly + 1
	var wy2: float = (float(float_ly2 + _BlockData.Y_MIN) + 0.5) * SLAB
	_check(chunk.place_block_at(wx0, wy2, wz0, _Data.BlockID.GRASS), "chồng block thứ 2 (lơ lửng)")
	await _wait_frames(3)
	_check(_ray_hits_x(mid_y, wx0, wz0) == false,
		"chồng 2 block: tia vẫn xuyên qua khoảng trống")
	_check(absf(_max_vert_y(chunk, gx, gz) - _layer_top_y(float_ly2)) < 0.01,
		"chồng 2 block: đỉnh mesh = đỉnh block trên")

	# ── 7. Kê cột xuống đất → tường chặn tia trở lại (cột đặc) ──────────────
	var ok_pillar: bool = true
	for ly in range(ground_ly + 1, float_ly):
		var wyy: float = (float(ly + _BlockData.Y_MIN) + 0.5) * SLAB
		if not chunk.place_block_at(wx0, wyy, wz0, _Data.BlockID.DIRT):
			ok_pillar = false
	_check(ok_pillar, "kê cột đất từ mặt đất lên block")
	await _wait_frames(3)
	_check(_ray_hits_x(mid_y, wx0, wz0) == true,
		"sau khi kê: tia bị tường cột chặn trở lại")

	# ── 8. Đào block trên cùng → đỉnh tụt 1 slab ────────────────────────────
	var broke: int = chunk.break_block_at(wx0, wy2, wz0)
	_check(broke == _Data.BlockID.GRASS, "đào được block lơ lửng (broke=%s)" % str(broke))
	await _wait_frames(3)
	_check(absf(_max_vert_y(chunk, gx, gz) - _layer_top_y(float_ly)) < 0.01,
		"sau đào: đỉnh tụt đúng 1 slab (%s)" % str(_max_vert_y(chunk, gx, gz)))
	_check(chunk.break_block_at(wx0, wy, wz0) == _Data.BlockID.GRASS, "đào được block còn lại")
	await _wait_frames(3)
	_check(_ray_hits_x(mid_y, wx0, wz0) == true,
		"đào sạch 2 block → cột đã kê vẫn đứng (tia vẫn bị chặn)")

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
