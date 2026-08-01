class_name ItemMesh

static func build(parent: Node3D, item_id: String) -> void:
	match item_id:
		"carp": _build_fish_icon(parent, "carp")
		"climbing_perch": _build_fish_icon(parent, "climbing_perch")
		"red_tilapia": _build_fish_icon(parent, "red_tilapia")
		"snakehead": _build_fish_icon(parent, "snakehead")
		"flowerhorn": _build_fish_icon(parent, "flowerhorn")
		"shrimp": _build_fish_icon(parent, "shrimp")
		"iron_sword": ToolsMesh.sword_drop(parent)
		"pickaxe": ToolsMesh.cup_drop(parent)
		"shovel": ToolsMesh.shovel_drop(parent)
		"axe": ToolsMesh.axe_drop(parent)
		"hoe": ToolsMesh.hoe_drop(parent)
		"chest": StructuresMesh.chest(parent)
		"crafting_table": StructuresMesh.crafting_table(parent)
		"furnace": StructuresMesh.furnace(parent)
		"fishing_rod": ToolsMesh.fishing_rod_drop(parent)
		"iron_greatsword": ToolsMesh.greatsword_drop(parent)
		"iron_halberd": ToolsMesh.iron_halberd_drop(parent)
		"leather_gloves": ToolsMesh.gauntlet_drop(parent)
		"crossbow": ToolsMesh.no_drop(parent)
		"watermelon_cannon": ToolsMesh.phao_dua_hau_drop(parent)
		"arrow": ToolsMesh.arrow_drop(parent)
		"twilight_gate": StructuresMesh.gate(parent)
		"fishing_boat": StructuresMesh.fishing_boat(parent)
		"palm_wood": MaterialMeshes.palm_wood(parent)
		"pumpkin": FruitMeshes.pumpkin(parent)
		"coconut": CoconutMesh.whole(parent, "green")
		"coconut_half": CoconutMesh.half(parent)
		"coconut_drink": CoconutMesh.drink(parent)
		"raw_pork": CreaturesMesh.meat(parent)
		"water_bucket": _build_water_bucket_icon(parent)
		"taro": _build_taro_icon(parent)
		"tropical_seaweed": _build_seaweed_icon(parent)
		"coconut_seed": _build_seed_icon(parent, 0)
		"taro_seed": _build_seed_icon(parent, 1)
		"seaweed_seed": _build_seed_icon(parent, 2)
		# ── Ores (dùng BlockMeshes.block_cube để texture khớp world) ──
		"copper_ore": BlockMeshes.block_cube(parent, "copper_ore")
		"bauxite_ore": BlockMeshes.block_cube(parent, "bauxite_ore")
		"silver_ore": BlockMeshes.block_cube(parent, "silver_ore")
		"iron_ore": BlockMeshes.block_cube(parent, "iron_ore")
		"gold_ore": BlockMeshes.block_cube(parent, "gold_ore")
		"titan_ore": BlockMeshes.block_cube(parent, "titan_ore")
		"platinum_ore": BlockMeshes.block_cube(parent, "platinum_ore")
		# ── Ingots ────────────────────────────────────────
		"copper_ingot": MaterialMeshes.ingot(parent, Color(0.70, 0.55, 0.15), Color(0.48, 0.27, 0.23))
		"copper_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.85, 0.70, 0.20), Color(0.66, 0.49, 0.37))
		"copper_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.92, 0.78, 0.30), Color(0.72, 0.55, 0.22))
		"aluminium_ingot": MaterialMeshes.ingot(parent, Color(0.65, 0.65, 0.68), Color(0.45, 0.45, 0.48))
		"aluminium_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.80, 0.80, 0.85), Color(0.60, 0.60, 0.65))
		"aluminium_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.90, 0.90, 0.95), Color(0.70, 0.70, 0.75))
		"silver_ingot": MaterialMeshes.ingot(parent, Color(0.75, 0.75, 0.80), Color(0.50, 0.50, 0.55))
		"silver_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.88, 0.88, 0.92), Color(0.65, 0.65, 0.70))
		"silver_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.95, 0.95, 1.00), Color(0.75, 0.75, 0.80))
		"iron_ingot": MaterialMeshes.ingot(parent, Color(0.55, 0.55, 0.60), Color(0.36, 0.36, 0.40))
		"iron_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.72, 0.72, 0.78), Color(0.52, 0.52, 0.58))
		"iron_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.85, 0.85, 0.90), Color(0.65, 0.65, 0.70))
		"gold_ingot": MaterialMeshes.ingot(parent, Color(0.85, 0.65, 0.10), Color(0.60, 0.36, 0.20))
		"gold_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.92, 0.75, 0.15), Color(0.70, 0.50, 0.12))
		"gold_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.97, 0.82, 0.25), Color(0.78, 0.58, 0.15))
		"steel_ingot": MaterialMeshes.ingot(parent, Color(0.50, 0.50, 0.55), Color(0.30, 0.30, 0.35))
		"steel_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.60, 0.60, 0.65), Color(0.40, 0.40, 0.45))
		"steel_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.75, 0.75, 0.82), Color(0.55, 0.55, 0.60))
		"titan_ingot": MaterialMeshes.ingot(parent, Color(0.55, 0.60, 0.70), Color(0.35, 0.40, 0.50))
		"titan_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.70, 0.75, 0.85), Color(0.50, 0.55, 0.65))
		"titan_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.85, 0.88, 0.95), Color(0.65, 0.68, 0.78))
		"platinum_ingot": MaterialMeshes.ingot(parent, Color(0.80, 0.82, 0.88), Color(0.55, 0.56, 0.60))
		"platinum_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.90, 0.92, 0.96), Color(0.68, 0.70, 0.75))
		"platinum_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.97, 0.98, 1.00), Color(0.78, 0.80, 0.85))
		"dark_metal_high_ingot": MaterialMeshes.ingot_high(parent, Color(0.25, 0.25, 0.28), Color(0.12, 0.12, 0.14))
		"dark_metal_purified_ingot": MaterialMeshes.ingot_purified(parent, Color(0.30, 0.20, 0.45), Color(0.15, 0.08, 0.25))
		_:
			if item_id.begins_with("block_"):
				BlockMeshes.block_cube(parent, item_id)
			else:
				FallbackMesh.item_voxel(parent, item_id)

static func _build_water_bucket_icon(p: Node3D) -> void:
	var metal := Color(0.55, 0.57, 0.62)
	var metal_d := Color(0.38, 0.40, 0.45)
	var water := Color(0.12, 0.50, 0.72)
	# Bucket body (wider at top)
	ItemMeshShared.add_cube(p, 0, -0.3, 0, 1.6, 0.8, 1.6, metal)
	ItemMeshShared.add_cube(p, 0, -0.8, 0, 1.4, 0.3, 1.4, metal_d)
	# Water inside
	ItemMeshShared.add_cube(p, 0, 0.0, 0, 1.2, 0.3, 1.2, water)
	# Rim
	ItemMeshShared.add_cube(p, 0, 0.3, 0, 1.8, 0.15, 1.8, metal)
	# Handle
	ItemMeshShared.add_cube(p, 0, 1.0, 0.5, 0.15, 0.8, 0.15, metal)
	ItemMeshShared.add_cube(p, 0, 1.0, -0.5, 0.15, 0.8, 0.15, metal)
	ItemMeshShared.add_cube(p, 0.5, 1.0, 0, 0.15, 0.8, 0.15, metal)
	ItemMeshShared.add_cube(p, -0.5, 1.0, 0, 0.15, 0.8, 0.15, metal)
	# Handle top ring
	ItemMeshShared.add_cube(p, 0, 1.4, 0.3, 0.12, 0.12, 0.3, metal.lightened(0.05))
	ItemMeshShared.add_cube(p, 0, 1.4, -0.3, 0.12, 0.12, 0.3, metal.lightened(0.05))
	ItemMeshShared.add_cube(p, 0.3, 1.4, 0, 0.3, 0.12, 0.12, metal.lightened(0.05))
	ItemMeshShared.add_cube(p, -0.3, 1.4, 0, 0.3, 0.12, 0.12, metal.lightened(0.05))

static func _build_fish_icon(p: Node3D, item_id: String) -> void:
	var variant: int = 0
	match item_id:
		"carp": variant = 0
		"climbing_perch": variant = 1
		"red_tilapia": variant = 2
		"snakehead": variant = 3
		"flowerhorn": variant = 4
		"shrimp": variant = 5
	var colors: Array = FishCharacter.VARIANT_COLORS[variant]
	var fm := FishMesh.new()
	fm.color_body = colors[0]
	fm.color_belly = colors[1]
	fm.color_fin = colors[2]
	fm.color_tail = (colors[0] as Color) * 0.8
	fm.color_pattern = FishCharacter.VARIANT_PATTERN[variant]
	fm.body_z_scale = FishCharacter.VARIANT_BODY_Z[variant]
	if variant == 4:
		fm.body_triangular = true
		fm.has_horns = true
	elif variant == 5:
		fm.body_shape = FishMesh.BodyShape.SHRIMP
	var temp := Node3D.new()
	fm.build(temp)
	for child in temp.get_children():
		temp.remove_child(child)
		p.add_child(child)
	temp.queue_free()

static func _build_seaweed_icon(p: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h1 := 12345
	var h2 := 67890
	var s := h1 * 16807 + 1
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var h3: int = h1 * 716199923 + h2 * 912334613
	h3 = (h3 ^ (h3 >> 13)) * 974126171; h3 = h3 ^ (h3 >> 16)
	var r3 := float(h3 & 0x7FFFFFFF) / 2147483648.0
	var h4: int = h1 * 374761393 + h2 * 631152931
	h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
	var r4 := float(h4 & 0x7FFFFFFF) / 2147483648.0
	var stem_g: float = 0.62 + r3 * 0.22
	var stem_b: float = 0.08 + r3 * 0.10
	var col_stem := Color(0.03, stem_g, stem_b, 1.0)
	var col_br1  := Color(0.04, stem_g * 0.92, stem_b, 1.0)
	var sw: float = 0.014 + r4 * 0.008
	var VOXEL: float = 0.25
	s = s * 16807 + 1; var lean_x: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	s = s * 16807 + 1; var lean_z: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	var cur_x: float = (r2 - 0.5) * 0.2
	var cur_z: float = (r3 - 0.5) * 0.2
	var cur_y: float = 0.0
	for seg in range(2):
		s = s * 16807 + 1; var dx := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		s = s * 16807 + 1; var dz := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		var nx := cur_x + lean_x + dx; var nz := cur_z + lean_z + dz; var ny := cur_y + VOXEL
		var mid := Vector3((cur_x + nx) * 0.5, (cur_y + ny) * 0.5, (cur_z + nz) * 0.5)
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0, 1), col_stem)
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0,-1), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,VOXEL*0.5,0), Vector3( 1,0,0), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,VOXEL*0.5,0), Vector3(-1,0,0), col_stem)
		var wroot := Vector3(nx, cur_y + VOXEL * 0.55, nz)
		for wi in range(3):
			var wa: float = float(wi) / 3.0 * TAU + float(seg)
			s = s * 16807 + 1; var wr := float(s & 0x7FFFFFFF) / 2147483648.0
			var wdir := Vector3(cos(wa), 0.12 + wr * 0.10, sin(wa)).normalized()
			var wperp := Vector3(-sin(wa), 0.0, cos(wa)).normalized()
			var wlen: float = 0.16 + wr * 0.08
			var ww: float = sw * 0.55
			_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5, wperp.cross(wdir).normalized(), col_br1)
			_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5, -wperp.cross(wdir).normalized(), col_br1)
		cur_x = nx; cur_z = nz; cur_y = ny
	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		p.add_child(mi)

static func _build_taro_icon(p: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Fixed colors matching world taro
	var col_stem := Color(0.35, 0.56, 0.14)
	var col_leaf := Color(0.06, 0.30, 0.06)
	var col_light := Color(0.08, 0.38, 0.08)
	var col_vein := Color(0.10, 0.44, 0.10)
	var la: float = 0.0
	var lean: float = 0.15
	var stem_h: float = 1.1
	var leaf_r: float = 0.45
	var base := Vector3(0, 0, 0)
	var stem_top := base + Vector3(cos(la) * lean, stem_h, sin(la) * lean)
	# Stem segments
	var segs: int = 4
	for seg in range(segs):
		var t: float = float(seg + 1) / float(segs)
		var pt: float = float(seg) / float(segs)
		var mid_y: float = base.y + stem_h * (t + pt) * 0.5
		var sw: float = 0.045 * (1.0 - t * 0.25)
		var seg_mid := Vector3(cos(la) * lean * (t + pt) * 0.5, mid_y, sin(la) * lean * (t + pt) * 0.5)
		var seg_h: float = stem_h / float(segs) * 0.5
		_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, 1), col_stem)
		_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, -1), col_stem)
		_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(1, 0, 0), col_stem * 0.92)
		_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(-1, 0, 0), col_stem * 0.92)
	# Hex leaf
	var r: float = leaf_r
	var cx := stem_top.x; var cy := stem_top.y + 0.02; var cz := stem_top.z
	var d_cup: float = r * 0.10
	var verts: Array[Vector3] = []
	for vi in 6:
		var va := la + float(vi) * PI / 3.0
		var vx := cx + cos(va) * r * 0.85
		var vz := cz + sin(va) * r * 0.85
		var vy: float = cy - d_cup * (1.0 - abs(cos(va - la)) * 0.5)
		verts.append(Vector3(vx, vy, vz))
	for ti in 6:
		var ni := (ti + 1) % 6
		var col_t := col_light if ti % 2 == 0 else col_leaf
		var n := Vector3(0, 1, 0)
		st.set_normal(n); st.set_color(col_t)
		st.add_vertex(Vector3(cx, cy - d_cup * 0.4, cz))
		st.add_vertex(verts[ti])
		st.add_vertex(verts[ni])
	for ei in 6:
		var e0 := verts[ei]; var e1 := verts[(ei + 1) % 6]
		var em := (e0 + e1) * 0.5
		var e_dir := (e1 - e0).normalized()
		var e_perp := Vector3(-e_dir.z, 0, e_dir.x).normalized()
		var col_edge := col_leaf * (0.80 + float(ei % 2) * 0.08)
		_add_quad(st, em, e_perp * 0.025, e_dir * e0.distance_to(e1) * 0.5, Vector3(0, 1, 0), col_edge)
	var ba := la + PI
	var bw: float = r * 0.28; var bh: float = r * 0.16
	var col_lobe := col_leaf * 0.80
	var lb := Vector3(cx + cos(ba - 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba - 0.3) * r * 0.45)
	var rb := Vector3(cx + cos(ba + 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba + 0.3) * r * 0.45)
	_add_quad(st, lb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), la), Vector3(0, 0, bh).rotated(Vector3(0,1,0), la), Vector3(0, 1, 0), col_lobe)
	_add_quad(st, rb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), la), Vector3(0, 0, bh).rotated(Vector3(0,1,0), la), Vector3(0, 1, 0), col_lobe)
	var ve := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, -r * 0.45).rotated(Vector3(0,1,0), la)
	var vm := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, r * 0.20).rotated(Vector3(0,1,0), la)
	_add_quad(st, (vm + ve) * 0.5, Vector3(0.018, 0, 0).rotated(Vector3(0,1,0), la), Vector3(0, 0, vm.distance_to(ve) * 0.5).rotated(Vector3(0,1,0), la), Vector3(0, 1, 0), col_vein)
	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		p.add_child(mi)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)

## ── Mầm cây: hạt + chồi non ─────────────────────────────────────────────────
## variant 0 = dừa (xanh sáng), 1 = môn (xanh đậm), 2 = rong (xanh ngọc)
static func _build_seed_icon(p: Node3D, variant: int) -> void:
	var seed_c := Color(0.38, 0.26, 0.14)
	var stem_c: Color
	var leaf_c: Color
	var leaf2_c: Color
	match variant:
		1:
			stem_c = Color(0.32, 0.55, 0.14)
			leaf_c = Color(0.10, 0.34, 0.08)
			leaf2_c = Color(0.14, 0.44, 0.10)
		2:
			stem_c = Color(0.10, 0.60, 0.35)
			leaf_c = Color(0.06, 0.48, 0.26)
			leaf2_c = Color(0.10, 0.62, 0.34)
		_:
			stem_c = Color(0.42, 0.68, 0.18)
			leaf_c = Color(0.24, 0.58, 0.12)
			leaf2_c = Color(0.34, 0.68, 0.16)
	# Hạt
	ItemMeshShared.add_cube(p, 0, -0.45, 0, 0.9, 0.7, 0.9, seed_c)
	ItemMeshShared.add_cube(p, 0, -0.6, 0, 0.7, 0.3, 0.7, seed_c.darkened(0.15))
	# Chồi non
	ItemMeshShared.add_cube(p, 0, -0.05, 0, 0.22, 0.8, 0.22, stem_c)
	ItemMeshShared.add_cube(p, 0.22, 0.35, 0, 0.5, 0.14, 0.26, leaf_c)
	ItemMeshShared.add_cube(p, -0.22, 0.35, 0, 0.5, 0.14, 0.26, leaf2_c)
	ItemMeshShared.add_cube(p, 0, 0.68, 0, 0.12, 0.18, 0.12, stem_c.lightened(0.1))
