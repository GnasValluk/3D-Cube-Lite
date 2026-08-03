extends Node3D

## Headless verification: cỏ biển mới (multimesh kiểu cỏ lúa, thay prop cũ) —
## item, hạt giống, cây vòm, model drop mesh, 2 loại (tím/xanh dương) mọc riêng
## vùng, dải nước nông 1.25-3.5, và pipeline thật qua compute_chunk.
## Chạy qua tools/test_seagrass.tscn (không chạy trực tiếp file .gd).

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Grass = preload("res://scripts/world/chunk/chunk_grass.gd")
const _Aquatic = preload("res://scripts/world/chunk/chunk_aquatic.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _Plant = preload("res://scripts/world/props/plant_prop.gd")
const _Growing = preload("res://scripts/world/props/growing_prop.gd")
const _Placement = preload("res://scripts/building/placement_system.gd")

const RW := _Data._Dim.DimensionID.REAL_WORLD
const SIZE := 32

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _has_mesh(node: Node) -> bool:
	for ch in node.get_children():
		if ch is MeshInstance3D:
			return true
	return false

## Tìm ô thế giới thoả: zone theo ý muốn + trong thảm meadow (pr < 0.30) —
## để sinh cỏ biển chắc chắn không bị chặn bởi cổng thảm.
func _find_world_cell(want_zone: int) -> Vector2:
	for wx in [150, 400, 900, -700, -1300, 2200, -2600, 3200]:
		for wz in [300, -500, 1100, -1600, 2100, -2800, 3500]:
			var ph: int = int(wx / 5) * 73856093 + int(wz / 5) * 19349663
			ph = (ph ^ (ph >> 13)) * 1274126177; ph = ph ^ (ph >> 16)
			var pr := float(ph & 0x7FFFFFFF) / 2147483648.0
			if pr >= 0.30:
				continue
			if _Grass._sea_zone(float(wx), float(wz)) != want_zone:
				continue
			return Vector2(wx, wz)
	return Vector2.ZERO

## Tạo cỏ biển tại 1 ô; trả số lá sinh ra.
func _gen_count(pos: Vector3, water_gap: float, world: Vector2,
		out_colors: Array = []) -> int:
	var xforms: Array = []
	var colors: Array = []
	_Grass.add_voxel_seagrass(int(round(pos.x)), int(round(pos.z)), pos,
		xforms, colors, SIZE, water_gap, world.x, world.y)
	if out_colors != null:
		out_colors.assign(colors)
	return xforms.size()

func _ready() -> void:
	seed(20260802)
	print("== test_seagrass: Cỏ biển multimesh (tím/xanh dương theo vùng) ==")

	# ── 1. Item database ──
	ItemDatabase.ensure_db()
	_check(ItemDatabase.items_db.has("seagrass"), "db có item seagrass")
	_check(ItemDatabase.items_db.has("seagrass_seed"), "db có item seagrass_seed")
	_check(_Placement._is_seed_item("seagrass_seed"), "seagrass_seed là seed item")

	# ── 2. Icon mesh không crash ──
	var icon_root := Node3D.new()
	add_child(icon_root)
	ItemMesh.build(icon_root, "seagrass")
	_check(icon_root.get_child_count() > 0, "icon seagrass có mesh")
	var seed_icon := Node3D.new()
	add_child(seed_icon)
	ItemMesh.build(seed_icon, "seagrass_seed")
	_check(seed_icon.get_child_count() > 0, "icon seagrass_seed có mesh")

	# ── 3. Drop mesh không crash ──
	var drop_root := Node3D.new()
	add_child(drop_root)
	_Plant.build_drop_mesh(drop_root, "seagrass")
	_check(drop_root.get_child_count() > 0, "drop mesh seagrass có mesh")

	# ── 4. Cây cỏ biển — vòng đời (prop cũ vẫn chạy được, chỉ hết sinh trong world) ──
	var clump: PlantProp = _Plant.new(50, DestroyableProp.WeaponReq.SWORD, "seagrass")
	clump.name = "SeagrassClump"
	clump.setup("seagrass", 1234, 5678, false, 1.0)
	add_child(clump)
	clump.global_position = Vector3(10, -1.0, 10)
	_check(_has_mesh(clump), "bụi cỏ biển có mesh")

	clump.set_birth_age_days(1.0)
	_check(clump._stage == _Growing.Stage.SPROUT, "cỏ biển 1 ngày = mầm")
	clump.set_birth_age_days(6.0)
	clump._check_growth()
	_check(clump._stage == _Growing.Stage.YOUNG, "cỏ biển 6 ngày = non (ngưỡng 3)")
	clump.set_birth_age_days(12.0)
	clump._check_growth()
	_check(clump._stage == _Growing.Stage.MATURE, "cỏ biển 12 ngày = trưởng thành (ngưỡng 9)")
	_check(_has_mesh(clump), "cỏ biển trưởng thành vẫn có mesh")

	# ── 5. Bụi meadow — dạng thảm nhỏ ──
	var meadow: PlantProp = _Plant.new(50, DestroyableProp.WeaponReq.SWORD, "seagrass")
	meadow.name = "SeagrassMeadow"
	meadow.setup("seagrass", 9999, 1111, false, 0.8, true)
	add_child(meadow)
	meadow.global_position = Vector3(20, -1.0, 10)
	_check(_has_mesh(meadow), "bụi meadow có mesh")

	# ── 6. Sinh cỏ biển ở dải nước nông 1.25-3.5 ──
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	var nd := _W._Noise._noise_for_dim(RW)
	var purple_cell := _find_world_cell(0)
	var blue_cell := _find_world_cell(1)
	_check(purple_cell != Vector2.ZERO, "có vùng cỏ biển tím trong thế giới")
	_check(blue_cell != Vector2.ZERO, "có vùng cỏ biển xanh dương trong thế giới")

	var purple_colors: Array = []
	var purple_count: int = _gen_count(Vector3(6, -1.25, 6), 1.25, purple_cell, purple_colors)
	_check(purple_count > 0, "vùng tím: cỏ biển mọc ở nước nông gap 1.25 (n=%d)" % purple_count)
	var purple_ok: bool = purple_count > 0
	for c in purple_colors:
		var col := c as Color
		if col.r < 0.28 or col.b <= col.g + 0.05:
			purple_ok = false
			break
	_check(purple_ok, "vùng tím: toàn màu tím (r≥0.28, b>g)")

	var blue_colors: Array = []
	var blue_count: int = _gen_count(Vector3(6, -3.0, 6), 3.0, blue_cell, blue_colors)
	_check(blue_count > 0, "vùng xanh dương: cỏ biển mọc ở nước sâu gap 3.0 (n=%d)" % blue_count)
	var blue_ok: bool = blue_count > 0
	for c in blue_colors:
		var col := c as Color
		if col.r >= 0.28 or col.b <= col.g + 0.05:
			blue_ok = false
			break
	_check(blue_ok, "vùng xanh dương: toàn màu xanh dương (r<0.28, b>g)")

	# ── 7. Quá nông — không mọc ──
	_check(_gen_count(Vector3(6, 0.0, 6), 0.5, purple_cell) == 0,
		"sát bờ (gap 0.5) không có cỏ biển")
	_check(_gen_count(Vector3(6, -0.75, 6), 1.0, purple_cell) == 0,
		"quá nông (gap 1.0) không có cỏ biển")

	# ── 8. Quá sâu — không mọc ──
	_check(_gen_count(Vector3(6, -4.5, 6), 5.0, blue_cell) == 0,
		"quá sâu (gap 5.0) không có cỏ biển")

	# ── 9. Vùng phân tách: 2 zone lớn riêng biệt, không trộn lẫn ──
	var zone0 := 0
	var zone1 := 0
	for wx in range(-2000, 2001, 40):
		for wz in range(-2000, 2001, 40):
			var z: int = _Grass._sea_zone(float(wx), float(wz))
			if z == 0: zone0 += 1
			else: zone1 += 1
	_check(zone0 > 0 and zone1 > 0,
		"thế giới có cả 2 vùng (tím %d ô, xanh %d ô)" % [zone0, zone1])
	var flipped := false
	var first_zone: int = _Grass._sea_zone(-2000.0, 0.0)
	for wx in range(-2000, 2001):
		if _Grass._sea_zone(float(wx), 0.0) != first_zone:
			flipped = true
			break
	_check(flipped, "vùng chuyển đổi theo khoảng lớn (không pixel-mix từng ô)")

	# ── 10. Aquatic cũ: không còn sinh prop seagrass (thay bằng multimesh) ──
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lotus_lights: Array[Vector3] = []
	var plant_props: Array[Dictionary] = []
	for vx in range(120):
		_Aquatic.add_aquatic_plants(st, 0, 0, 25, vx, 37,
			Vector3(0, -1.25, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
			lotus_lights, plant_props, false, false)
	_check(plant_props.filter(func(p): return p.get("type", "") == "seagrass").is_empty(),
		"biển không còn sinh prop seagrass cũ")
	_check(lotus_lights.is_empty(), "biển không sinh sen")

	# ── 11. Pipeline thật: chunk biển nông có cỏ biển multimesh ──
	print("-- 11. Pipeline thật: tìm chunk biển nông qua _ocean_mask_at --")
	var ocean_cell := Vector2.ZERO
	for ray_i in range(16):
		var a: float = float(ray_i) / 16.0 * TAU
		var dx := cos(a)
		var dz := sin(a)
		for r in range(200, 5000, 16):
			var wx: float = dx * float(r)
			var wz: float = dz * float(r)
			if _W._ocean_mask_at(nd, wx, wz):
				ocean_cell = Vector2(wx, wz)
				break
		if ocean_cell != Vector2.ZERO:
			break
	_check(ocean_cell != Vector2.ZERO, "tìm thấy ô biển (cách gốc %.0f block)" % ocean_cell.length())

	var found_chunk := Vector2i(-999, -999)
	var found_blades := 0
	var zone_mismatch := 0
	var band_ok := false
	if ocean_cell != Vector2.ZERO:
		var cx0 := int(floor(ocean_cell.x / SIZE))
		var cz0 := int(floor(ocean_cell.y / SIZE))
		var sx := 1 if ocean_cell.x >= 0 else -1
		var sz := 1 if ocean_cell.y >= 0 else -1
		for step_i in range(4):
			var cx := cx0 + sx * step_i
			var cz := cz0 + sz * step_i
			var data := _W.compute_chunk(cx, cz, SIZE, RW)
			var bg: Array = data.get("biome_grid", [])
			var bd = _BD.new()
			bd.from_bytes(data["block_data_bytes"], SIZE, SIZE)
			band_ok = false
			for vx in range(SIZE):
				for vz in range(SIZE):
					if int(bg[vx][vz]) != _Data.TileType.OCEAN_DEEP:
						continue
					# Độ sâu từ block data: lớp nước trên đáy → gap = WATER_Y - đáy
					var top_is_water := false
					var floor_ly := -1
					for ly in range(_BD.CHUNK_H - 1, -1, -1):
						var b: int = bd.get_block(vx, ly, vz)
						if b == _Data.BlockID.AIR:
							continue
						if _Data.is_water(b):
							top_is_water = true
						elif floor_ly == -1:
							floor_ly = ly
						if top_is_water and floor_ly >= 0:
							break
					if not top_is_water or floor_ly < 0:
						continue
					var gap: float = _Data.WATER_Y - _BD.layer_to_world_y(floor_ly)
					if gap >= 1.0 and gap <= 3.5:
						band_ok = true
						break
				if band_ok:
					break
			if band_ok:
				found_chunk = Vector2i(cx, cz)
				break
		if found_chunk.x != -999:
			var data2 := _W.compute_chunk(found_chunk.x, found_chunk.y, SIZE, RW)
			var gbd: Dictionary = data2.get("grass_blade_data", {})
			var gx: Array = gbd.get("xforms", [])
			var gc: Array = gbd.get("colors", [])
			var wox: float = found_chunk.x * SIZE
			var woz: float = found_chunk.y * SIZE
			zone_mismatch = 0
			for i in range(gc.size()):
				var col := gc[i] as Color
				if col.b <= 0.40:
					continue  # không phải cỏ biển (cỏ lúa/rêu xanh)
				found_blades += 1
				var tp := gx[i] as Transform3D
				var zone: int = _Grass._sea_zone(wox + tp.origin.x, woz + tp.origin.z)
				var want_purple: bool = zone == 0
				var is_purple: bool = col.r >= 0.28
				if is_purple != want_purple:
					zone_mismatch += 1
	_check(found_chunk.x != -999,
		"chunk (%d,%d) có dải nước nông OCEAN_DEEP 1.25-3.5" % [found_chunk.x, found_chunk.y])
	_check(band_ok and found_blades > 0,
		"chunk biển có %d lá cỏ biển trong grass_blade_data" % found_blades)
	_check(zone_mismatch == 0,
		"màu cỏ biển khớp vùng phân tách (lệch %d lá)" % zone_mismatch)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
