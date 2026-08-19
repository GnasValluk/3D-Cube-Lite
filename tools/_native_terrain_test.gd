extends SceneTree

const _Terrain = preload("res://scripts/world/chunk/chunk_terrain.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

const COLS := 40
const Y_MIN := -18
const SLAB := 0.5
const CHUNK_H := 69

var _fail := 0

func _init() -> void:
	print("== NATIVE TERRAIN MESH COMPARE ==")
	if not ClassDB.class_exists("WorldTerrain"):
		print("FAIL: WorldTerrain class not loaded")
		quit(1)
		return
	var wt = ClassDB.instantiate("WorldTerrain")
	if wt == null:
		print("FAIL: instantiate WorldTerrain null")
		quit(1)
		return

	var bd := _BlockData.new()
	bd.init(COLS, COLS)
	_build_sample(bd)

	var top_ly_hint := PackedInt32Array()
	top_ly_hint.resize(COLS * COLS)
	for x in range(COLS):
		for z in range(COLS):
			top_ly_hint[x * COLS + z] = _top_ly_of(bd, x, z)

	# ── GDScript reference path (SurfaceTool) ──
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_Terrain.build_terrain_mesh(st, bd, COLS, _Data._Dim.DimensionID.REAL_WORLD, top_ly_hint)
	var ref_mesh: ArrayMesh = st.commit()
	var ref_arrays: Array = ref_mesh.surface_get_arrays(0)
	var ref_verts: PackedVector3Array = ref_arrays[Mesh.ARRAY_VERTEX]
	var ref_norm: PackedVector3Array = ref_arrays[Mesh.ARRAY_NORMAL]
	var ref_col: PackedColorArray = ref_arrays[Mesh.ARRAY_COLOR]

	# ── Native path ──
	var palette := PackedColorArray(_Data.BLOCK_COLORS_RW)
	var t0 := Time.get_ticks_usec()
	var res: Dictionary = wt.build_terrain_mesh(bd._data, COLS, top_ly_hint, false, palette)
	var native_us := Time.get_ticks_usec() - t0
	var n_verts: PackedVector3Array = res["verts"]
	var n_norm: PackedVector3Array = res["normals"]
	var n_col: PackedColorArray = res["colors"]

	# Native arrays -> ArrayMesh (engine nén màu float → 8-bit như SurfaceTool)
	var n_mesh := ArrayMesh.new()
	var n_arrays := []
	n_arrays.resize(Mesh.ARRAY_MAX)
	n_arrays[Mesh.ARRAY_VERTEX] = n_verts
	n_arrays[Mesh.ARRAY_NORMAL] = n_norm
	n_arrays[Mesh.ARRAY_COLOR] = n_col
	n_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, n_arrays)
	var n_read: Array = n_mesh.surface_get_arrays(0)
	var nr_verts: PackedVector3Array = n_read[Mesh.ARRAY_VERTEX]
	var nr_norm: PackedVector3Array = n_read[Mesh.ARRAY_NORMAL]
	var nr_col: PackedColorArray = n_read[Mesh.ARRAY_COLOR]

	print("ref verts=", ref_verts.size(), "  native verts=", nr_verts.size())
	print("ref norm  =", ref_norm.size(), "  native norm  =", nr_norm.size())
	print("ref col   =", ref_col.size(), "  native col   =", nr_col.size())
	print("native build time us=", native_us)

	var ok := true
	_check("vert count", ref_verts.size() == nr_verts.size())
	_check("norm count", ref_norm.size() == nr_norm.size())
	_check("col count", ref_col.size() == nr_col.size())
	if ref_verts.size() != nr_verts.size() or ref_norm.size() != nr_norm.size() or ref_col.size() != nr_col.size():
		ok = false

	if ok and ref_verts.size() == nr_verts.size():
		var bad: int = 0
		for i in range(ref_verts.size()):
			if not ref_verts[i].is_equal_approx(nr_verts[i]):
				bad += 1
				if bad <= 5: print("  vert mismatch at ", i, " ref=", ref_verts[i], " nat=", nr_verts[i])
		_check("vertex values", bad == 0)
		bad = 0
		for i in range(ref_norm.size()):
			if not ref_norm[i].is_equal_approx(nr_norm[i]):
				bad += 1
				if bad <= 5: print("  norm mismatch at ", i, " ref=", ref_norm[i], " nat=", nr_norm[i])
		_check("normal values", bad == 0)
		bad = 0
		for i in range(ref_col.size()):
			if not ref_col[i].is_equal_approx(nr_col[i]):
				bad += 1
				if bad <= 5: print("  col mismatch at ", i, " ref=", ref_col[i], " nat=", nr_col[i])
		_check("color values", bad == 0)

	var gd_us := _time_gd(st, bd, top_ly_hint)
	print("gd build us=", gd_us, "  native us=", native_us,
			"  speedup=", "%.1fx" % (float(gd_us) / maxf(float(native_us), 1.0)))
	print(_summary())
	quit(0 if _fail == 0 else 1)

func _time_gd(_st: SurfaceTool, bd, top_ly_hint: PackedInt32Array) -> int:
	var t0 := Time.get_ticks_usec()
	for _r in range(5):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_Terrain.build_terrain_mesh(st, bd, COLS, _Data._Dim.DimensionID.REAL_WORLD, top_ly_hint)
		st.commit()
	return (Time.get_ticks_usec() - t0) / 5

func _top_ly_of(bd, x: int, z: int) -> int:
	for ly in range(CHUNK_H - 1, -1, -1):
		var b: int = bd.get_block(x, ly, z)
		if b != 0 and b != 6 and b != 24 and b != 25 and b != 26 and b != 27 \
				and b != 28 and b != 29 and b != 30 and b != 31 \
				and b != 34 and b != 35 and b != 36:
			return ly
	return -1

func _build_sample(bd) -> void:
	const B := _Data.BlockID
	for x in range(COLS):
		for z in range(COLS):
			var base: int = 8 + (x * 7 + z * 3) % 18
			var top_grass: bool = (x + z) % 5 != 0
			for ly in range(0, base + 1):
				if ly == base:
					bd.set_block(x, ly, z, B.GRASS_DIRT if top_grass else B.STONE)
				elif ly >= base - 3:
					bd.set_block(x, ly, z, B.DIRT if top_grass else B.STONE)
				elif ly % 17 == 0:
					bd.set_block(x, ly, z, B.COAL_ORE)
				else:
					bd.set_block(x, ly, z, B.STONE if not top_grass else B.DIRT)
			# vài ô nước
			if x == 5 and z % 3 == 0:
				for ly in range(0, base + 1):
					bd.set_block(x, ly, z, B.AIR if ly > base - 6 else B.STONE)
				for ly in range(base - 5, base + 1):
					bd.set_block(x, ly, z, B.WATER_SOURCE if ly <= base - 2 else B.WATER)
			# vài khe hở (block lơ lửng): đào lỗ 2 layer giữa cột
			if x == 12 and z == 12:
				for ly in range(base - 3, base - 1):
					bd.set_block(x, ly, z, B.AIR)
			# shaped block đặt lơ lửng trên mặt
			if x == 20 and z == 20:
				bd.set_block(x, base + 2, z, B.STONE_QTR)
				bd.set_block(x, base + 3, z, B.STONE_THIN)

func _check(label: String, cond: bool) -> void:
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_fail += 1

func _summary() -> String:
	return "RESULT: " + ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail)