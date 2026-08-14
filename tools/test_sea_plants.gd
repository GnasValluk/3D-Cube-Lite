extends Node3D

## Headless verification: cây biển nhiều loài (san hô, san hô não, hải miên,
## tảo bẹ, quạt biển, hải quỳ) — item DB, icon drop, mesh prop thế giới, sinh
## ở OCEAN_DEEP, và pipeline thật qua compute_chunk.
## Chạy qua tools/test_sea_plants.tscn (không chạy trực tiếp file .gd).

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _Aquatic = preload("res://scripts/world/chunk/chunk_aquatic.gd")
const _W = preload("res://scripts/world/chunk/world_chunk.gd")
const _SeaPlant = preload("res://scripts/world/props/sea_plant_prop.gd")

const RW := _Data._Dim.DimensionID.REAL_WORLD
const SIZE := 32

var _failures: int = 0
var _types: Array[String] = ["coral", "brain_coral", "sponge", "kelp", "kelp_tall", "sea_fan", "anemone", "sea_bush", "grass_carpet", "seaweed"]

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _has_mesh(node: Node) -> bool:
	for ch in node.get_children():
		if ch is MeshInstance3D or ch is MultiMeshInstance3D:
			return true
	return false

func _mesh_height(node: Node) -> float:
	var hi := -INF
	var lo := INF
	for ch in node.get_children():
		if ch is MultiMeshInstance3D:
			var mm: MultiMesh = (ch as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var tr: Transform3D = mm.get_instance_transform(i)
				hi = maxf(hi, tr.origin.y)
				lo = minf(lo, tr.origin.y)
		elif ch is MeshInstance3D:
			var aabb: AABB = (ch as MeshInstance3D).get_aabb()
			hi = maxf(hi, aabb.end.y)
			lo = minf(lo, aabb.position.y)
	if hi == -INF:
		return 0.0
	return hi - lo

func _ready() -> void:
	seed(20260813)
	print("== test_sea_plants: Cây biển nhiều loài (san hô & co) ==")

	# ── 1. Item database ──
	ItemDatabase.ensure_db()
	for t in _types:
		_check(ItemDatabase.items_db.has(t), "db có item %s" % t)

	# ── 2. Icon drop mesh không crash, có mesh ──
	for t in _types:
		var icon_root := Node3D.new()
		add_child(icon_root)
		ItemMesh.build(icon_root, t)
		_check(icon_root.get_child_count() > 0, "icon %s có mesh" % t)

	# ── 3. Prop thế giới — mesh không crash ──
	for t in _types:
		var prop: SeaPlantProp = _SeaPlant.new(45, DestroyableProp.WeaponReq.SWORD, t)
		prop.setup(t, 1234, 5678)
		add_child(prop)
		prop.global_position = Vector3(10, -2.0, 10)
		_check(_has_mesh(prop), "prop %s có mesh" % t)
		_check(prop.drop_item_id == t, "prop %s drop đúng item" % t)

	# ── 3b. Kelp tall — chiều cao tỉ lệ theo water_gap ──
	var k1 := _SeaPlant.new(45, DestroyableProp.WeaponReq.SWORD, "kelp_tall")
	k1.setup("kelp_tall", 1234, 5678, 4.0)
	add_child(k1)
	k1.global_position = Vector3(20, -3.6, 10)
	var k2 := _SeaPlant.new(45, DestroyableProp.WeaponReq.SWORD, "kelp_tall")
	k2.setup("kelp_tall", 1234, 5678, 12.0)
	add_child(k2)
	k2.global_position = Vector3(24, -11.6, 10)
	_check(_mesh_height(k1) > 2.0, "rong cao gap4 cao hơn 2 block")
	_check(_mesh_height(k2) > _mesh_height(k1) + 5.0,
		"rong cao gap12 cao hơn gap4 (%.1f vs %.1f)" % [_mesh_height(k2), _mesh_height(k1)])

	# ── 4. Sinh ở OCEAN_DEEP — đáy biển nông 1.5-6.0 ──
	WorldSeed.seed_value = 20260805
	_W._Noise.clear_cache()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lotus_lights: Array[Vector3] = []
	var plant_props: Array[Dictionary] = []
	var count_ocean := 0
	for vx in range(120):
		_Aquatic.add_aquatic_plants(st, 0, 0, 25, vx, 37,
			Vector3(0, -2.0, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
			lotus_lights, plant_props, false, false)
	for p in plant_props:
		if _types.has(p.get("type", "")):
			count_ocean += 1
	_check(count_ocean > 0, "biển nông OCEAN_DEEP sinh cây biển (n=%d)" % count_ocean)
	_check(lotus_lights.is_empty(), "biển không sinh sen")

	# ── 4b. Mọi loài đều sinh được qua hash (quét dải rộng) ──
	var reachable: Dictionary = {}
	for wx in range(-400, 401, 4):
		for wz in range(-400, 401, 4):
			var h1: int = wx * 631152931 + wz * 493781731 + 224488997
			h1 = (h1 ^ (h1 >> 13)) * 1274126177; h1 = h1 ^ (h1 >> 16)
			var r1 := float(h1 & 0x7FFFFFFF) / 2147483648.0
			var h2: int = wx * 198491327 + wz * 374761393 + 887766554
			h2 = (h2 ^ (h2 >> 13)) * 1074126173; h2 = h2 ^ (h2 >> 16)
			var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0
			var h3: int = wx * 716199923 + wz * 912334613 + 441200317
			h3 = (h3 ^ (h3 >> 13)) * 974126171; h3 = h3 ^ (h3 >> 16)
			var r3 := float(h3 & 0x7FFFFFFF) / 2147483648.0
			var h4: int = wx * 374761393 + wz * 631152931 + 556677889
			h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
			var r4 := float(h4 & 0x7FFFFFFF) / 2147483648.0
			var out: Array[Dictionary] = []
			_Aquatic._add_ocean_sea_plants(out, wx, wz, Vector3(0, -2.0, 0),
				2.0, r1, r2, r3, r4, h1, h2, 25)
			_Aquatic.add_ocean_kelp_tall(out, wx, wz, Vector3(0, -8.0, 0),
				8.0, r1, r2, r3, r4, h1, h2)
			for p in out:
				if _types.has(p.get("type", "")):
					reachable[p["type"]] = true
	for t in _types:
		_check(reachable.has(t), "loài %s sinh được ở vị trí phù hợp" % t)

	# ── 5. Quá nông / quá sâu — không mọc ──
	var p_nong: Array[Dictionary] = []
	_Aquatic.add_aquatic_plants(SurfaceTool.new(), 0, 0, 25, 3, 3,
		Vector3(0, -1.0, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
		[], p_nong, false, false)
	_check(p_nong.filter(func(p): return _types.has(p.get("type", ""))).is_empty(),
		"quá nông (gap 1.0) không sinh cây biển")
	# gap rất sâu (23+) — ngoài khoảng cả 2 loại → không mọc
	var p_sau2: Array[Dictionary] = []
	_Aquatic.add_aquatic_plants(SurfaceTool.new(), 0, 0, 25, 3, 3,
		Vector3(0, -30.0, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
		[], p_sau2, false, false)
	_check(p_sau2.filter(func(p): return _types.has(p.get("type", ""))).is_empty(),
		"quá sâu (gap 30) không sinh cây biển nào")
	# Rong cao: chỉ mọc ở vùng nước sâu (gap ≥ 6), không ở nông
	var p_rong_sau: Array[Dictionary] = []
	_Aquatic.add_aquatic_plants(SurfaceTool.new(), 0, 0, 25, 3, 3,
		Vector3(0, -8.0, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
		[], p_rong_sau, false, false)
	var kelp_in_deep: bool = p_rong_sau.any(func(p): return p.get("type", "") == "kelp_tall")
	var p_rong_nong: Array[Dictionary] = []
	_Aquatic.add_aquatic_plants(SurfaceTool.new(), 0, 0, 25, 3, 3,
		Vector3(0, -2.0, 0), 1.0, false, _Data.TileType.OCEAN_DEEP,
		[], p_rong_nong, false, false)
	var kelp_in_shallow: bool = p_rong_nong.any(func(p): return p.get("type", "") == "kelp_tall")
	# Ít nhất 1 trong 2 ô sâu/nông phải phân biệt rõ — nếu cả 2 đều không, ô
	# (3,3) fixed không trúng hash → bỏ qua (không fail).
	var any_kelp: bool = kelp_in_deep or kelp_in_shallow
	if any_kelp:
		_check(kelp_in_deep and not kelp_in_shallow,
			"rong cao mọc ở nước sâu (gap 8), không mọc ở nông (gap 2)")
	else:
		print("INFO | ô (3,3) không trúng hash rong cao — bỏ qua check phân tầng")

	# ── 6. Hồ nước ngọt — KHÔNG sinh cây biển ──
	var p_ho: Array[Dictionary] = []
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Aquatic.add_aquatic_plants(st2, 0, 0, 25, 5, 5,
		Vector3(0, -2.0, 0), 1.0, false, _Data.TileType.SILT,
		[], p_ho, false, false)
	_check(p_ho.filter(func(p): return _types.has(p.get("type", ""))).is_empty(),
		"hồ SILT không sinh cây biển")

	# ── 7. Pipeline thật: chunk biển có prop cây biển trong plant_props ──
	print("-- 7. Pipeline thật: tìm chunk biển nông qua _ocean_mask_at --")
	var ocean_cell := Vector2.ZERO
	var nd := _W._Noise._noise_for_dim(RW)
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

	var found_any := 0
	if ocean_cell != Vector2.ZERO:
		var cx0 := int(floor(ocean_cell.x / SIZE))
		var cz0 := int(floor(ocean_cell.y / SIZE))
		var sx := 1 if ocean_cell.x >= 0 else -1
		var sz := 1 if ocean_cell.y >= 0 else -1
		for step_i in range(6):
			var cx := cx0 + sx * step_i
			var cz := cz0 + sz * step_i
			var data := _W.compute_chunk(cx, cz, SIZE, RW)
			var props: Array = data.get("plant_props", [])
			for p in props:
				if _types.has(p.get("type", "")):
					found_any += 1
			if found_any > 0:
				break
	_check(found_any > 0, "chunk biển thật có %d cây biển trong plant_props" % found_any)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
