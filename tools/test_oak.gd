extends Node

## Headless verification: block gỗ sồi (BlockID 37, texture WOOD nâu sáng ấm)
## + cây sồi kiểu Minecraft (OakProp — thân cột nâu sáng thẳng, tán blob lá
## xanh um dày, nhiều cành vươn chùm lá, gió theo chùm; KHÔNG còn quả sồi/
## tổ chim/lá rơi) + xác nhận cây tre & quả sồi đã bị loại bỏ.
## Chạy qua tools/test_oak.tscn (không chạy trực tiếp file .gd).

const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _D = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _OreTex = preload("res://scripts/items/models/ore_texture.gd")
const _BlockMeshes = preload("res://scripts/items/models/block_mesh.gd")
const _OakProp = preload("res://scripts/world/props/oak_prop.gd")

const SIZE := 32
const COLS := 32
const RW := _D._Dim.DimensionID.REAL_WORLD

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _ready() -> void:
	seed(20260805)
	ItemDatabase.ensure_db()

	# ── 1. Dữ liệu block gỗ sồi ───────────────────────────────────────────
	_check(_D.BlockID.OAK_WOOD == 37, "OAK_WOOD = 37")
	_check(_D.ITEM_TO_BLOCK.get("block_oak_wood", 0) == _D.BlockID.OAK_WOOD,
		"ITEM_TO_BLOCK[block_oak_wood] → 37 (đặt được)")
	_check(_D.BLOCK_TO_ITEM.get(_D.BlockID.OAK_WOOD, "") == "block_oak_wood",
		"BLOCK_TO_ITEM[37] → block_oak_wood (đào rớt khối gỗ)")
	_check(_D.get_block_hardness(_D.BlockID.OAK_WOOD) == 1.4, "gỗ sồi 1.4s (rìu sắt)")
	_check(_D.is_axable(_D.BlockID.OAK_WOOD), "rìu đào được gỗ sồi")
	_check(not _D.is_pickaxable(_D.BlockID.OAK_WOOD), "cúp KHÔNG đào được gỗ sồi")
	_check(not _D.is_shovelable(_D.BlockID.OAK_WOOD), "xẻng KHÔNG đào được gỗ sồi")
	_check(_D.BLOCK_COLORS_RW[_D.BlockID.OAK_WOOD] != Color.BLACK, "BLOCK_COLORS_RW[37] có màu")

	# ── 2. Items ────────────────────────────────────────────────────────────
	var wood_item: ItemDef = ItemDatabase.items_db.get("block_oak_wood") as ItemDef
	_check(wood_item != null and wood_item.type == ItemDef.Type.BLOCK,
		"item block_oak_wood tồn tại, loại BLOCK")
	_check(wood_item != null and wood_item.icon_color.r > wood_item.icon_color.b,
		"item gỗ sồi màu nâu ấm (r > b)")
	_check(not ItemDatabase.items_db.has("acorn"), "item acorn đã bị loại bỏ")
	_check(not ItemDatabase.items_db.has("bamboo_stick"), "item bamboo_stick đã bị loại bỏ")

	# ── 3. Texture vân gỗ riêng (WOOD) — nâu sáng ấm, không xám ────────────
	var mat37: Material = _OreTex.get_material(_D.BlockID.OAK_WOOD)
	_check(mat37 != null, "OreTex.get_material(37) có material")
	var img := _OreTex.make_image(_D.BlockID.OAK_WOOD)
	var colors: Dictionary = {}
	var avg_r := 0.0
	var avg_g := 0.0
	var avg_b := 0.0
	for y in range(8):
		for x in range(8):
			var c := img.get_pixel(x, y)
			colors[c.to_html()] = true
			avg_r += c.r; avg_g += c.g; avg_b += c.b
	avg_r /= 64.0; avg_g /= 64.0; avg_b /= 64.0
	_check(colors.size() >= 6, "vân gỗ có ≥6 màu khác nhau (không trơn)")
	_check(avg_r > avg_g and avg_g > avg_b and avg_r > 0.5,
		"vân gỗ nâu sáng ấm (r>g>b, r=%.2f)" % avg_r)

	# ── 4. Item mesh ───────────────────────────────────────────────────────
	var p_item := Node3D.new()
	add_child(p_item)
	_BlockMeshes.block_cube(p_item, "block_oak_wood")
	var any_mi := false
	var has_tex := false
	for ch in p_item.get_children():
		if ch is MeshInstance3D:
			any_mi = true
			var mi_c := ch as MeshInstance3D
			if mi_c.material_override != null or (mi_c.mesh != null and mi_c.mesh.material != null):
				has_tex = true
	_check(any_mi, "item gỗ sồi có mesh 3D")
	_check(has_tex, "item gỗ sồi có material texture")
	p_item.queue_free()

	# ── 5. Chunk: đặt block → overlay textured; phá → xóa overlay ──────────
	var chunk := _W.new()
	chunk.name = "OakChunk"
	add_child(chunk)
	chunk.setup(0, 0, SIZE, RW, true)
	_check(chunk.block_data != null, "chunk setup sync ok")
	if chunk.block_data != null:
		var dig_x := -1
		var dig_z := -1
		var dig_top := -1
		for x in range(COLS):
			for z in range(COLS):
				var t := chunk._top_ly_cache[x * COLS + z]
				if t >= 0:
					dig_x = x; dig_z = z; dig_top = t
					break
			if dig_x >= 0:
				break
		_check(dig_x >= 0, "tìm được cột bề mặt (%d,%d)" % [dig_x, dig_z])
		if dig_x >= 0:
			var half_sz := SIZE * 0.5
			var wx := chunk.global_position.x - half_sz + (dig_x + 0.5) * _D.VOXEL
			var wz := chunk.global_position.z - half_sz + (dig_z + 0.5) * _D.VOXEL
			var wy := _BD.layer_to_world_y(dig_top + 1)
			var placed: bool = chunk.place_block_at(wx, wy, wz, _D.BlockID.OAK_WOOD)
			_check(placed, "đặt gỗ sồi ok")
			_check(chunk.block_data.get_block(dig_x, dig_top + 1, dig_z) == _D.BlockID.OAK_WOOD,
				"block data lưu gỗ sồi")
			var mi := chunk._textured_block_mesh_instances.get(_D.BlockID.OAK_WOOD) as MeshInstance3D
			_check(mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0,
				"overlay gỗ sồi có geometry")
			_check(mi != null and mi.material_override != null, "overlay gỗ sồi có material")
			var old_bid: int = chunk.break_block_at(wx, wy, wz)
			_check(old_bid == _D.BlockID.OAK_WOOD, "phá gỗ sồi trả về 37")
			_check(not chunk._textured_block_mesh_instances.has(_D.BlockID.OAK_WOOD),
				"phá gỗ sồi → overlay bị xóa")

	# ── 6. Cây sồi kiểu Minecraft ─────────────────────────────────────────
	var oak := _OakProp.new(250, DestroyableProp.WeaponReq.AXE, "block_oak_wood")
	oak.setup("plains")
	oak.position = Vector3(2.5, 0.5, 2.5)
	add_child(oak)
	_check(oak.get_child_count() > 0, "cây sồi dựng xong (có visual/collision)")
	_check(oak.find_child("OakVisual", false, false) != null, "có thân/cành chính (OakVisual)")

	# Trưởng thành: thân nâu sáng + tán nhiều chùm blob lá xanh um
	oak.set_birth_age_days(80.0)
	var mature_tufts: int = oak._tuft_data.size()
	_check(mature_tufts >= 3 and mature_tufts <= 8,
		"trưởng thành có 3-8 chùm lá (có %d)" % mature_tufts)
	var trunk_voxels: int = oak._ordered.size()
	_check(trunk_voxels >= 2000, "thân có ≥2000 voxel (có %d)" % trunk_voxels)
	var trunk_avg := _avg_color(oak._grid)
	_check(trunk_avg.r > trunk_avg.g and trunk_avg.g > trunk_avg.b and trunk_avg.r > 0.22,
		"thân nâu đậm ấm, không xám (r=%.2f g=%.2f b=%.2f)" % [trunk_avg.r, trunk_avg.g, trunk_avg.b])
	var leaf_avg := _avg_tuft_color(oak._tuft_data)
	_check(leaf_avg.g > leaf_avg.r and leaf_avg.g > leaf_avg.b and leaf_avg.g > 0.35,
		"tán lá xanh tươi (r=%.2f g=%.2f b=%.2f)" % [leaf_avg.r, leaf_avg.g, leaf_avg.b])
	_check(oak.find_child("FallingLeaves", false, false) == null, "không còn hiệu ứng lá rơi")
	_check(oak.find_child("FallingAcorns", false, false) == null, "không còn hiệu ứng sồi rơi")
	var tuft0: Node3D = oak.find_child("Tuft0", false, false)
	_check(tuft0 != null, "chùm lá nằm trong container riêng (gió theo chùm)")
	if tuft0 != null:
		var tmi: MultiMeshInstance3D = tuft0.find_child("TuftVisual", false, false)
		_check(tmi != null and tmi.multimesh != null and tmi.multimesh.instance_count > 0,
			"chùm lá Tuft0 có voxel lá")
		_check(tmi != null and tmi.multimesh.instance_count >= 50,
			"chùm lá chính dày đặc (≥50 voxel, có %d)" % (tmi.multimesh.instance_count if tmi != null else 0))

	# Non: chỉ 1 blob tán trung tâm, thân nhỏ hơn
	oak.set_birth_age_days(30.0)
	var young_tufts: int = oak._tuft_data.size()
	_check(young_tufts == 1, "cây non có 1 chùm tán trung tâm (có %d)" % young_tufts)
	_check(oak._ordered.size() < trunk_voxels, "cây non ít voxel thân hơn cây trưởng thành")

	# Mầm: sapling — thân nhỏ nâu + cụm lá nhỏ trên ngọn
	oak.set_birth_age_days(3.0)
	_check(oak._ordered.size() > 0, "mầm có thân nhỏ")
	_check(oak._tuft_data.size() == 1, "mầm có cụm lá nhỏ trên ngọn")
	_check(oak.find_child("Tuft0", false, false) != null, "mầm có container chùm")
	var sapling_avg := _avg_color(oak._grid)
	_check(sapling_avg.r > sapling_avg.g and sapling_avg.g > sapling_avg.b,
		"thân mầm nâu đậm (r=%.2f g=%.2f b=%.2f)" % [sapling_avg.r, sapling_avg.g, sapling_avg.b])

	# Gió: quay container chùm lá theo thời gian
	oak.set_birth_age_days(80.0)
	tuft0 = oak.find_child("Tuft0", false, false)
	var rot_before: float = tuft0.rotation.x if tuft0 != null else 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var rot_after: float = tuft0.rotation.x if tuft0 != null else 0.0
	_check(absf(rot_after - rot_before) > 0.0001 or tuft0 == null,
		"container chùm đung đưa theo thời gian (gió)")

	oak.queue_free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

func _avg_color(grid: Dictionary) -> Color:
	if grid.is_empty():
		return Color.BLACK
	var r := 0.0; var g := 0.0; var b := 0.0
	for c in grid.values():
		r += (c as Color).r; g += (c as Color).g; b += (c as Color).b
	var n := float(grid.size())
	return Color(r / n, g / n, b / n)

func _avg_tuft_color(tufts: Array) -> Color:
	var r := 0.0; var g := 0.0; var b := 0.0
	var n := 0
	for t in tufts:
		for c in (t["col"] as Array):
			r += (c as Color).r; g += (c as Color).g; b += (c as Color).b
			n += 1
	if n == 0:
		return Color.BLACK
	return Color(r / n, g / n, b / n)
