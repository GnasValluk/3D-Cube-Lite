extends Node

## test_stone_shape — Block đá đa dạng hình dạng: Đá Tư (¼ khối, 0.5×0.5×0.5),
## Đá Vụn (⅛ khối, 0.5×0.25×0.5) và Đá Phiến (tấm 1×0.2×1 thay vì dày 0.5).
## - Dữ liệu: BlockID 34-36, mapping item↔block, độ cứng, cúp, item, recipe.
## - Hành vi: đặt block shape không đổi heightmap/terrain mesh, có collision
##   đúng kích thước, hộp ¼ có khoảng trống bên cạnh, đào bình thường.
## Chạy qua tools/test_stone_shape.tscn (không chạy trực tiếp file .gd).

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Chunk = preload("res://scripts/world/chunk/world_chunk.gd")
const _Terrain = preload("res://scripts/world/chunk/chunk_terrain.gd")
const ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const RecipeDatabase = preload("res://scripts/items/core/recipe_database.gd")

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

## Y cao nhất của đỉnh terrain mesh trong ô cột (lx, lz).
## Lưu ý: greedy strip gộp cả dải phẳng → cột giữa dải KHÔNG có vert;
## chỉ đo được ở cột biên strip (ví dụ sau khi chồng block cao hơn xung quanh).
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

## Ray thẳng đứng từ trên xuống; trả hit đầu tiên (dict rỗng nếu không trúng).
func _ray_down(wx: float, wy: float, wz: float) -> Dictionary:
	var space := get_tree().root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(wx, wy, wz), Vector3(wx, wy - 5.0, wz))
	return space.intersect_ray(q)

## Build terrain mesh (chỉ terrain, không detail) bằng đúng cache hiện tại.
func _build_terrain_ref(chunk: Node, cols: int, st: SurfaceTool) -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, chunk.block_data, cols,
		_Data._Dim.DimensionID.REAL_WORLD, chunk._top_ly_cache)

## Nếu hit vào box shape → trả kích thước hộp, ngược lại Vector3.ZERO.
## Mọi đá shape gộp trong 1 StaticBody3D compound → dùng shape index của hit.
func _hit_box_size(hit: Dictionary) -> Vector3:
	if hit.is_empty():
		return Vector3.ZERO
	var body = hit.get("collider")
	if body is StaticBody3D:
		var si: int = hit.get("shape", -1)
		var children: Array = body.get_children()
		if si >= 0 and si < children.size() and children[si] is CollisionShape3D:
			var cs := children[si] as CollisionShape3D
			if cs.shape is BoxShape3D:
				return (cs.shape as BoxShape3D).size
		for child in children:
			if child is CollisionShape3D and child.shape is BoxShape3D:
				return (child.shape as BoxShape3D).size
	return Vector3.ZERO

func _ready() -> void:
	seed(20260803)
	print("== test_stone_shape: block đá đa dạng hình dạng ==")
	ItemDatabase.ensure_db()
	RecipeDatabase.ensure()

	# ── 1. Dữ liệu: BlockID + kích thước shape ─────────────────────────────
	_check(_Data.BlockID.STONE_QTR == 34 and _Data.BlockID.STONE_EIGHTH == 35 \
		and _Data.BlockID.STONE_THIN == 36, "BlockID 34/35/36 cho 3 variant đá")
	_check(_Data.is_shaped_block(_Data.BlockID.STONE_QTR) \
		and _Data.is_shaped_block(_Data.BlockID.STONE_EIGHTH) \
		and _Data.is_shaped_block(_Data.BlockID.STONE_THIN), "3 block shape đúng nhận diện")
	_check(not _Data.is_shaped_block(_Data.BlockID.STONE), "đá thường không phải shape")
	_check(_Data.block_shape(_Data.BlockID.STONE_QTR) == Vector3(0.5, 0.5, 0.5),
		"đá tư = ¼ khối (0.5×0.5×0.5)")
	_check(_Data.block_shape(_Data.BlockID.STONE_EIGHTH) == Vector3(0.5, 0.25, 0.5),
		"đá vụn = ⅛ khối (0.5×0.25×0.5)")
	_check(_Data.block_shape(_Data.BlockID.STONE_THIN) == Vector3(1.0, 0.2, 1.0),
		"đá phiến mỏng 0.2 (thay vì 0.5)")
	_check(_Data.block_shape(_Data.BlockID.STONE) == Vector3.ZERO, "đá thường không có shape")

	# ── 2. Mapping item ↔ block + hardness + cúp ───────────────────────────
	_check(_Data.ITEM_TO_BLOCK.get("block_stone_qtr") == _Data.BlockID.STONE_QTR \
		and _Data.ITEM_TO_BLOCK.get("block_stone_eighth") == _Data.BlockID.STONE_EIGHTH \
		and _Data.ITEM_TO_BLOCK.get("block_stone_thin") == _Data.BlockID.STONE_THIN,
		"ITEM_TO_BLOCK đủ 3 item đá variant")
	_check(_Data.BLOCK_TO_ITEM.get(_Data.BlockID.STONE_QTR) == "block_stone_qtr" \
		and _Data.BLOCK_TO_ITEM.get(_Data.BlockID.STONE_EIGHTH) == "block_stone_eighth" \
		and _Data.BLOCK_TO_ITEM.get(_Data.BlockID.STONE_THIN) == "block_stone_thin",
		"BLOCK_TO_ITEM đủ 3 block shape")
	for bid in [_Data.BlockID.STONE_QTR, _Data.BlockID.STONE_EIGHTH, _Data.BlockID.STONE_THIN]:
		_check(_Data.get_block_hardness(bid) > 0.0, "block %d có độ cứng > 0" % bid)
	_check(_Data.is_pickaxable(_Data.BlockID.STONE_QTR) \
		and _Data.is_pickaxable(_Data.BlockID.STONE_EIGHTH) \
		and _Data.is_pickaxable(_Data.BlockID.STONE_THIN), "3 block shape đào được bằng cúp")

	# ── 3. Item + recipe ────────────────────────────────────────────────────
	for item_id in ["block_stone_qtr", "block_stone_eighth", "block_stone_thin"]:
		var def: ItemDef = ItemDatabase.items_db.get(item_id)
		_check(def != null and def.type == ItemDef.Type.BLOCK,
			"item %s tồn tại (BLOCK)" % item_id)
	var r1 := RecipeDatabase.match_counts({ "block_stone": 1 })
	_check(r1.get("id") == "block_stone_qtr" and r1.get("count") == 4,
		"recipe: 1 đá → 4 đá tư")

	# ── 4. Dựng chunk REAL_WORLD đồng bộ ───────────────────────────────────
	var chunk := _Chunk.new()
	chunk.setup(0, 0, CHUNK_SIZE, _Data._Dim.DimensionID.REAL_WORLD, true)
	add_child(chunk)
	chunk.position = Vector3.ZERO
	_check(chunk._built, "chunk sync build xong")
	_check(chunk._shaped_block_instances.is_empty() and chunk._shaped_collider == null,
		"chunk mới chưa có block shape")

	# Tìm cột cao nguyên (4 ô lân cận cùng độ cao, không sát biên chunk)
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

	# ── 5. Đặt đá phiến mỏng ngay trên mặt đất ─────────────────────────────
	# Terrain-mesh tham chiếu (chỉ terrain, không detail): build lại bằng đúng
	# cache — đặt block shape KHÔNG được làm đổi terrain mesh.
	var st_ref := SurfaceTool.new()
	_build_terrain_ref(chunk, cols, st_ref)
	var ref_arrays: Array = st_ref.commit().surface_get_arrays(0)
	_check((ref_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0,
		"mesh terrain chuẩn có đỉnh")
	var wy1: float = ground_top_y + SLAB * 0.5
	_check(chunk.place_block_at(wx0, wy1, wz0, _Data.BlockID.STONE_THIN), "đặt đá phiến 0.2")
	_check(chunk.block_data.get_block(gx, ground_ly + 1, gz) == _Data.BlockID.STONE_THIN,
		"ô chứa đá phiến")
	_check(chunk._top_ly_cache[gx * cols + gz] == ground_ly,
		"heightmap không đổi (đá phiến không tính là đỉnh cột)")
	var st_after := SurfaceTool.new()
	_build_terrain_ref(chunk, cols, st_after)
	var after_arrays: Array = st_after.commit().surface_get_arrays(0)
	_check(after_arrays[Mesh.ARRAY_VERTEX] == ref_arrays[Mesh.ARRAY_VERTEX] \
		and after_arrays[Mesh.ARRAY_INDEX] == ref_arrays[Mesh.ARRAY_INDEX],
		"đặt đá phiến không đổi terrain mesh")
	await _wait_frames(3)
	var hit := _ray_down(wx0, ground_top_y + 2.0, wz0)
	_check(not hit.is_empty(), "ray trúng gì đó phía trên mặt đất")
	_check(_hit_box_size(hit) == Vector3(1.0, 0.2, 1.0), "collision đá phiến = 1×0.2×1")
	_check(absf(hit.get("position", Vector3(-9, -9, -9)).y - (ground_top_y + 0.2)) < 0.01,
		"đỉnh đá phiến ở y = mặt đất + 0.2")

	# ── 6. Đặt đá thường chồng lên đá phiến ────────────────────────────────
	var wy2: float = ground_top_y + SLAB + SLAB * 0.5
	_check(chunk.place_block_at(wx0, wy2, wz0, _Data.BlockID.STONE), "đặt đá thường chồng lên đá phiến")
	_check(chunk._top_ly_cache[gx * cols + gz] == ground_ly + 2, "đá thường trở thành đỉnh cột")
	await _wait_frames(3)
	_check(absf(_max_vert_y(chunk, gx, gz) - _layer_top_y(ground_ly + 2)) < 0.01,
		"đỉnh mesh = đỉnh đá thường")

	# ── 7. Đào đá phiến bên dưới ───────────────────────────────────────────
	_check(chunk.break_block_at(wx0, wy1, wz0) == _Data.BlockID.STONE_THIN, "đào được đá phiến")
	_check(chunk._top_ly_cache[gx * cols + gz] == ground_ly + 2, "đỉnh cột vẫn là đá thường")
	await _wait_frames(3)
	_check(absf(_max_vert_y(chunk, gx, gz) - _layer_top_y(ground_ly + 2)) < 0.01,
		"đá thường vẫn đứng sau khi đào đá phiến")
	_check(not _ray_down(wx0, ground_top_y + 2.0, wz0).is_empty(), "đá thường vẫn chặn ray")

	# ── 8. Đá tư (¼): hộp 0.5 — có khoảng trống bên cạnh ───────────────────
	var wy3: float = _layer_top_y(ground_ly + 2) + SLAB * 0.5
	_check(chunk.place_block_at(wx0, wy3, wz0, _Data.BlockID.STONE_QTR), "đặt đá tư")
	await _wait_frames(3)
	var hit3 := _ray_down(wx0, _layer_top_y(ground_ly + 2) + 2.0, wz0)
	_check(_hit_box_size(hit3) == Vector3(0.5, 0.5, 0.5), "collision đá tư = 0.5×0.5×0.5")
	var hit4 := _ray_down(wx0 + 0.4, _layer_top_y(ground_ly + 2) + 2.0, wz0)
	_check(_hit_box_size(hit4) == Vector3.ZERO,
		"lệch 0.4 → ray không trúng hộp đá tư (khoảng trống bên cạnh)")
	_check(absf(hit4.get("position", Vector3(-9, -9, -9)).y - _layer_top_y(ground_ly + 2)) < 0.01,
		"lệch 0.4 → ray trúng đỉnh đá thường bên dưới")

	# ── 9. Đá vụn (⅛): hộp cao 0.25 ────────────────────────────────────────
	var wy4: float = _layer_top_y(ground_ly + 2) + SLAB + SLAB * 0.5
	_check(chunk.place_block_at(wx0, wy4, wz0, _Data.BlockID.STONE_EIGHTH), "đặt đá vụn")
	await _wait_frames(3)
	var hit6 := _ray_down(wx0, _layer_top_y(ground_ly + 2) + SLAB + 2.0, wz0)
	_check(_hit_box_size(hit6) == Vector3(0.5, 0.25, 0.5), "collision đá vụn = 0.5×0.25×0.5")
	_check(absf(hit6.get("position", Vector3(-9, -9, -9)).y \
		- (_layer_top_y(ground_ly + 2) + SLAB + 0.25)) < 0.01,
		"đỉnh đá vụn ở +0.25 so với đáy ô")

	# ── 10. Đào sạch → không còn mesh/collision shape ──────────────────────
	_check(chunk.break_block_at(wx0, wy4, wz0) == _Data.BlockID.STONE_EIGHTH, "đào đá vụn")
	_check(chunk.break_block_at(wx0, wy3, wz0) == _Data.BlockID.STONE_QTR, "đào đá tư")
	_check(chunk.break_block_at(wx0, wy2, wz0) == _Data.BlockID.STONE, "đào đá thường")
	await _wait_frames(3)
	_check(chunk._shaped_block_instances.is_empty() and chunk._shaped_collider == null,
		"đào sạch → không còn mesh/collision shape")
	_check(chunk._top_ly_cache[gx * cols + gz] == ground_ly, "heightmap về mặt đất ban đầu")
	await _wait_frames(3)
	var hit_final := _ray_down(wx0, ground_top_y + 2.0, wz0)
	_check(_hit_box_size(hit_final) == Vector3.ZERO \
		and absf(hit_final.get("position", Vector3(-9, -9, -9)).y - ground_top_y) < 0.01,
		"đào sạch → mặt đất nguyên vẹn ở y=%s" % str(ground_top_y))

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
