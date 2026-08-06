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
		"tractor": StructuresMesh.tractor(parent)
		"palm_wood": MaterialMeshes.palm_wood(parent)
		"eggplant_fruit": _build_eggplant_fruit_icon(parent)
		"eggplant_slice": _build_eggplant_slice_icon(parent)
		"eggplant_seed": _build_eggplant_seed_icon(parent)
		"watermelon": _build_watermelon_icon(parent)
		"watermelon_slice": _build_watermelon_slice_icon(parent)
		"watermelon_seed": _build_watermelon_seed_icon(parent)
		"pumpkin": _build_pumpkin_icon(parent)
		"pumpkin_slice": _build_pumpkin_slice_icon(parent)
		"pumpkin_seed": _build_pumpkin_seed_icon(parent)
		"jack_o_lantern": _build_jack_o_lantern_icon(parent)
		"coconut": CoconutMesh.whole(parent, "green")
		"coconut_half": CoconutMesh.half(parent)
		"coconut_drink": CoconutMesh.drink(parent)
		"raw_pork": CreaturesMesh.meat(parent)
		"water_bucket": _build_water_bucket_icon(parent)
		"taro": _build_taro_icon(parent)
		"tropical_seaweed": _build_seaweed_icon(parent)
		"seagrass": _build_seagrass_icon(parent)
		"coconut_seed": _build_seed_icon(parent, 0)
		"taro_seed": _build_seed_icon(parent, 1)
		"seaweed_seed": _build_seed_icon(parent, 2)
		"seagrass_seed": _build_seed_icon(parent, 3)
		"orange": _build_orange_icon(parent)
		"orange_seed": _build_orange_seed_icon(parent)
		"egg_carp": _build_egg_icon(parent, "egg_carp")
		"egg_perch": _build_egg_icon(parent, "egg_perch")
		"egg_tilapia": _build_egg_icon(parent, "egg_tilapia")
		"egg_snakehead": _build_egg_icon(parent, "egg_snakehead")
		"egg_flowerhorn": _build_egg_icon(parent, "egg_flowerhorn")
		"egg_shrimp": _build_egg_icon(parent, "egg_shrimp")
		"egg_pig": _build_egg_icon(parent, "egg_pig")
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

## Trứng sinh vật — quả trứng 3D theo màu loài (giống visual egg_projectile)
static func _build_egg_icon(p: Node3D, item_id: String) -> void:
	var egg_col: Color = EggProjectile.egg_color(item_id)
	var main := StandardMaterial3D.new()
	main.albedo_color = egg_col
	main.roughness = 0.75
	main.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spot := StandardMaterial3D.new()
	spot.albedo_color = egg_col.lerp(Color(1.0, 1.0, 1.0), 0.55)
	spot.roughness = 0.7
	spot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body := MeshInstance3D.new()
	var egg_mesh := SphereMesh.new()
	egg_mesh.radius = 0.35
	egg_mesh.height = 0.55
	egg_mesh.radial_segments = 10
	egg_mesh.rings = 6
	body.mesh = egg_mesh
	body.material_override = main
	body.scale = Vector3(0.72, 1.0, 0.72)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = Vector3(0, 0.3, 0)
	p.add_child(body)

	var speck := MeshInstance3D.new()
	speck.mesh = egg_mesh
	speck.material_override = spot
	speck.scale = Vector3(0.3, 0.42, 0.3)
	speck.position = Vector3(0.1, 0.46, 0.1)
	speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(speck)

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

## Icon bụi cỏ biển: vòm lá mảnh aqua → xanh biển sâu, rễ nâu ngầm.
static func _build_seagrass_icon(p: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_base := Color(0.05, 0.28, 0.62, 0.9)
	var col_tip  := Color(0.25, 0.62, 0.95, 0.9)
	var VOXEL: float = 0.25
	var cur_dir := Vector3(0.55, 0, 0.25).normalized()
	# Lá kiểu lúa — mảnh, dựng đứng, ngọn nhọn
	for bi in range(7):
		var ba := float(bi) / 7.0 * TAU
		var br: float = 0.22 + float(bi % 3) * 0.10
		var origin := Vector3(cos(ba) * 0.18 * br, 0, sin(ba) * 0.18 * br)
		var blade_h: float = 0.55 + float(bi % 2) * 0.2
		var w: float = VOXEL * 0.40
		var prev := origin
		for seg in range(3):
			var t := float(seg + 1) / 3.0
			var nxt := origin + Vector3(0, blade_h * t, 0) \
				+ cur_dir * blade_h * 0.16 * t * t
			var mid := (prev + nxt) * 0.5
			var dir := (nxt - prev).normalized()
			var perp := Vector3(-dir.z, 0, dir.x).normalized()
			var taper: float = 1.0 - t * 0.8
			var col := col_base.lerp(col_tip, t * 0.9)
			_add_quad(st, mid, perp * w * 0.5 * taper, dir * (nxt - prev).length() * 0.5,
				Vector3(0, 1, 0), col)
			prev = nxt
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

## ── Trái cà tím: tím hoàng gia mộng nước, thuôn cong, đài hoa + cuống ──────
static func _build_eggplant_fruit_icon(p: Node3D) -> void:
	var skin := Color(0.42, 0.14, 0.50)
	var skin_d := Color(0.33, 0.10, 0.40)
	var skin_l := Color(0.52, 0.22, 0.60)
	var hl := Color(0.80, 0.88, 0.98)
	var calix := Color(0.32, 0.50, 0.26)
	var calix_d := Color(0.24, 0.40, 0.20)
	var stalk := Color(0.12, 0.34, 0.10)
	# Thân quả thuôn — đầu nhỏ phình to về đuôi, đít cong nhẹ
	ItemMeshShared.add_cube(p, -0.06, -0.42, 0.05, 0.30, 0.34, 0.30, skin_d)
	ItemMeshShared.add_cube(p, -0.03, 0.08, 0.06, 0.42, 0.42, 0.42, skin)
	ItemMeshShared.add_cube(p, 0.00, -0.02, 0.07, 0.50, 0.44, 0.50, skin)
	ItemMeshShared.add_cube(p, 0.02, -0.30, 0.06, 0.44, 0.40, 0.44, skin_l)
	ItemMeshShared.add_cube(p, 0.00, 0.42, 0.05, 0.34, 0.28, 0.34, skin)
	ItemMeshShared.add_cube(p, -0.02, 0.62, 0.02, 0.26, 0.18, 0.26, skin_d)
	# Vệt highlight trắng xanh chạy dọc thân quả
	ItemMeshShared.add_cube(p, 0.26, -0.16, 0.16, 0.10, 0.66, 0.10, hl)
	ItemMeshShared.add_cube(p, 0.23, -0.30, 0.13, 0.08, 0.18, 0.08, hl)
	# Đài hoa 4-5 cánh nhọn xanh ngả tím
	ItemMeshShared.add_cube(p, 0.00, 0.78, 0.00, 0.40, 0.14, 0.40, calix)
	ItemMeshShared.add_cube(p, 0.22, 0.70, 0.10, 0.12, 0.14, 0.12, calix)
	ItemMeshShared.add_cube(p, -0.20, 0.70, 0.08, 0.12, 0.14, 0.12, calix)
	ItemMeshShared.add_cube(p, 0.10, 0.70, 0.22, 0.12, 0.14, 0.12, calix)
	ItemMeshShared.add_cube(p, 0.08, 0.72, -0.18, 0.12, 0.12, 0.12, calix_d)
	ItemMeshShared.add_cube(p, -0.22, 0.74, -0.10, 0.10, 0.10, 0.10, calix_d)
	# Cuống xanh đậm cong lên
	ItemMeshShared.add_cube(p, -0.04, 0.96, 0.02, 0.10, 0.22, 0.10, stalk)
	ItemMeshShared.add_cube(p, -0.09, 1.08, 0.04, 0.10, 0.10, 0.10, stalk)

## ── Cà tím bổ đôi: vỏ tím + ruột trắng kem + hạt vàng nâu quanh tâm ────────
static func _build_eggplant_slice_icon(p: Node3D) -> void:
	var skin := Color(0.40, 0.13, 0.48)
	var skin_d := Color(0.32, 0.10, 0.38)
	var flesh := Color(0.96, 0.92, 0.82)
	var flesh_d := Color(0.88, 0.82, 0.70)
	var seed_c := Color(0.66, 0.54, 0.30)
	var calix := Color(0.32, 0.50, 0.26)
	var stalk := Color(0.12, 0.34, 0.10)
	# Nửa vỏ tím ôm phía sau (mặt cắt nhìn nghiêng)
	ItemMeshShared.add_cube(p, 0.05, -0.35, -0.10, 0.85, 0.30, 0.30, skin_d)
	ItemMeshShared.add_cube(p, 0.10, 0.15, -0.12, 0.90, 0.40, 0.30, skin_d)
	ItemMeshShared.add_cube(p, 0.05, -0.05, -0.15, 0.95, 0.55, 0.28, skin)
	# Ruột trắng kem sốp
	ItemMeshShared.add_cube(p, 0.05, 0.00, 0.14, 0.82, 0.62, 0.34, flesh)
	ItemMeshShared.add_cube(p, 0.05, 0.18, 0.18, 0.68, 0.26, 0.22, flesh.lightened(0.03))
	ItemMeshShared.add_cube(p, 0.05, -0.24, 0.16, 0.66, 0.20, 0.24, flesh_d)
	# Hạt vàng nâu nhạt quanh tâm
	ItemMeshShared.add_cube(p, 0.12, 0.06, 0.26, 0.10, 0.10, 0.10, seed_c)
	ItemMeshShared.add_cube(p, 0.05, -0.10, 0.28, 0.10, 0.10, 0.10, seed_c)
	ItemMeshShared.add_cube(p, -0.08, -0.02, 0.28, 0.10, 0.10, 0.10, seed_c.darkened(0.08))
	ItemMeshShared.add_cube(p, -0.05, 0.16, 0.26, 0.10, 0.10, 0.10, seed_c.darkened(0.08))
	# Đài hoa + cuống còn trên đầu nửa quả
	ItemMeshShared.add_cube(p, 0.05, 0.52, 0.00, 0.40, 0.14, 0.40, calix)
	ItemMeshShared.add_cube(p, 0.05, 0.70, 0.02, 0.10, 0.22, 0.10, stalk)

## ── Túi hạt giống cà tím: vải đay nâu vàng + dây thừng đỏ + logo quả ────────
static func _build_eggplant_seed_icon(p: Node3D) -> void:
	var kraft := Color(0.64, 0.50, 0.32)
	var kraft_d := Color(0.54, 0.40, 0.24)
	var kraft_l := Color(0.70, 0.56, 0.38)
	var twine := Color(0.78, 0.16, 0.12)
	var logo_purple := Color(0.42, 0.14, 0.50)
	var logo_green := Color(0.32, 0.50, 0.26)
	var seed_c := Color(0.72, 0.60, 0.32)
	# Thân túi vải đay
	ItemMeshShared.add_cube(p, 0, -0.25, 0, 1.5, 1.5, 0.9, kraft)
	ItemMeshShared.add_cube(p, 0, -0.10, 0, 1.34, 1.34, 0.8, kraft_l)
	ItemMeshShared.add_cube(p, 0, -0.42, 0, 1.34, 0.2, 0.8, kraft_d)
	# Miệng túi gập lại
	ItemMeshShared.add_cube(p, 0, 0.62, 0, 1.30, 0.34, 0.8, kraft_d)
	ItemMeshShared.add_cube(p, 0, 0.82, 0, 1.10, 0.18, 0.7, kraft.darkened(0.12))
	# Dải dây thừng đỏ buộc miệng túi
	ItemMeshShared.add_cube(p, 0, 0.50, 0, 1.44, 0.12, 0.16, twine)
	ItemMeshShared.add_cube(p, 0.62, 0.44, 0.06, 0.14, 0.14, 0.14, twine.darkened(0.1))
	# Logo trái cà tím in mặt trước
	ItemMeshShared.add_cube(p, 0, -0.06, 0.46, 0.30, 0.52, 0.12, logo_purple)
	ItemMeshShared.add_cube(p, 0, 0.12, 0.49, 0.22, 0.16, 0.10, logo_purple.lightened(0.08))
	ItemMeshShared.add_cube(p, 0, 0.26, 0.47, 0.26, 0.08, 0.10, logo_green)
	ItemMeshShared.add_cube(p, 0, 0.34, 0.46, 0.08, 0.10, 0.10, logo_green.darkened(0.08))
	# Vài hạt giống vàng rơi vãi quanh túi
	ItemMeshShared.add_cube(p, -0.62, -0.78, 0.30, 0.10, 0.08, 0.10, seed_c)
	ItemMeshShared.add_cube(p, -0.34, -0.86, 0.20, 0.10, 0.08, 0.10, seed_c.darkened(0.08))
	ItemMeshShared.add_cube(p, 0.10, -0.84, 0.34, 0.10, 0.08, 0.10, seed_c.lightened(0.05))
	ItemMeshShared.add_cube(p, 0.52, -0.78, 0.22, 0.10, 0.08, 0.10, seed_c)

## ── Quả dưa hấu nguyên vẹn: cầu căng mọng, vằn zíc-zắc xanh đen, vệt đất ────
static func _build_watermelon_icon(p: Node3D) -> void:
	var jade := Color(0.48, 0.74, 0.40)
	var jade_d := Color(0.36, 0.60, 0.30)
	var stripe := Color(0.08, 0.32, 0.18)
	var stripe_d := Color(0.05, 0.24, 0.13)
	var soil := Color(0.93, 0.84, 0.42)
	var stalk := Color(0.30, 0.38, 0.16)
	# Thân quả bầu dục nghiêng nhẹ
	ItemMeshShared.add_cube(p, 0.00, -0.18, 0.00, 1.00, 0.80, 1.00, jade)
	ItemMeshShared.add_cube(p, 0.00, 0.10, 0.00, 0.92, 0.52, 0.92, jade.lightened(0.04))
	ItemMeshShared.add_cube(p, 0.00, -0.46, 0.00, 0.90, 0.22, 0.90, jade_d)
	ItemMeshShared.add_cube(p, 0.00, 0.38, 0.00, 0.70, 0.18, 0.70, jade)
	ItemMeshShared.add_cube(p, 0.00, 0.52, 0.00, 0.44, 0.10, 0.44, jade_d)
	# Vằn zíc-zắc xanh đen dọc thân
	ItemMeshShared.add_cube(p, 0.30, -0.10, 0.00, 0.14, 0.66, 0.14, stripe)
	ItemMeshShared.add_cube(p, 0.26, -0.28, 0.10, 0.12, 0.20, 0.12, stripe)
	ItemMeshShared.add_cube(p, 0.27, 0.12, -0.12, 0.12, 0.20, 0.12, stripe_d)
	ItemMeshShared.add_cube(p, -0.32, -0.06, 0.04, 0.14, 0.60, 0.14, stripe)
	ItemMeshShared.add_cube(p, -0.27, -0.30, 0.12, 0.12, 0.18, 0.12, stripe_d)
	ItemMeshShared.add_cube(p, -0.28, 0.16, -0.10, 0.12, 0.18, 0.12, stripe)
	ItemMeshShared.add_cube(p, 0.04, -0.32, 0.34, 0.14, 0.56, 0.14, stripe_d)
	ItemMeshShared.add_cube(p, -0.06, -0.30, -0.36, 0.14, 0.52, 0.14, stripe_d)
	# Vệt đất vàng ngà ở đáy quả
	ItemMeshShared.add_cube(p, 0.10, -0.52, 0.10, 0.40, 0.10, 0.40, soil)
	ItemMeshShared.add_cube(p, -0.18, -0.54, -0.08, 0.28, 0.08, 0.28, soil.darkened(0.05))
	# Cuống xoắn nhô lên đỉnh
	ItemMeshShared.add_cube(p, -0.02, 0.62, 0.02, 0.12, 0.14, 0.12, stalk)
	ItemMeshShared.add_cube(p, -0.08, 0.70, 0.06, 0.10, 0.08, 0.10, stalk.darkened(0.08))

## ── Miếng dưa hấu tam giác: vỏ xanh + cùi trắng ngà + ruột đỏ + hạt đen ─────
static func _build_watermelon_slice_icon(p: Node3D) -> void:
	var rind := Color(0.22, 0.52, 0.20)
	var rind_d := Color(0.14, 0.40, 0.14)
	var ivory := Color(0.96, 0.94, 0.84)
	var flesh := Color(0.90, 0.16, 0.20)
	var flesh_d := Color(0.78, 0.12, 0.16)
	var seed_c := Color(0.05, 0.05, 0.06)
	# Lớp vỏ ngoài ôm phía sau
	ItemMeshShared.add_cube(p, 0.00, -0.38, -0.22, 0.86, 0.30, 0.26, rind_d)
	ItemMeshShared.add_cube(p, 0.00, 0.06, -0.24, 0.94, 0.44, 0.24, rind)
	# Cùi trắng ngà 1-2 voxel
	ItemMeshShared.add_cube(p, 0.00, -0.10, 0.02, 0.82, 0.72, 0.16, ivory)
	# Ruột đỏ tươi mộng nước (mặt cắt tam giác)
	ItemMeshShared.add_cube(p, 0.00, -0.02, 0.16, 0.70, 0.60, 0.20, flesh)
	ItemMeshShared.add_cube(p, 0.00, 0.20, 0.20, 0.52, 0.20, 0.14, flesh.lightened(0.05))
	ItemMeshShared.add_cube(p, 0.00, -0.26, 0.18, 0.54, 0.16, 0.14, flesh_d)
	# Hạt đen tuyền hình thoi trong ruột
	ItemMeshShared.add_cube(p, 0.14, 0.04, 0.26, 0.09, 0.13, 0.09, seed_c)
	ItemMeshShared.add_cube(p, -0.16, -0.08, 0.27, 0.09, 0.13, 0.09, seed_c)
	ItemMeshShared.add_cube(p, 0.02, -0.18, 0.27, 0.09, 0.13, 0.09, seed_c.lightened(0.1))
	ItemMeshShared.add_cube(p, -0.06, 0.16, 0.26, 0.08, 0.11, 0.08, seed_c)

## ── Túi hạt giống dưa hấu: kraft + kẹp gỗ + hình miếng dưa in mặt trước ────
static func _build_watermelon_seed_icon(p: Node3D) -> void:
	var kraft := Color(0.64, 0.50, 0.32)
	var kraft_d := Color(0.54, 0.40, 0.24)
	var kraft_l := Color(0.70, 0.56, 0.38)
	var wood_clip := Color(0.48, 0.34, 0.18)
	var logo_red := Color(0.88, 0.16, 0.20)
	var logo_rind := Color(0.22, 0.52, 0.20)
	var logo_seed := Color(0.05, 0.05, 0.06)
	var drop_red := Color(0.92, 0.30, 0.30)
	var spark_green := Color(0.60, 0.90, 0.40)
	# Thân túi giấy kraft vuông vức
	ItemMeshShared.add_cube(p, 0, -0.25, 0, 1.4, 1.4, 0.85, kraft)
	ItemMeshShared.add_cube(p, 0, -0.10, 0, 1.24, 1.24, 0.75, kraft_l)
	ItemMeshShared.add_cube(p, 0, -0.42, 0, 1.24, 0.20, 0.75, kraft_d)
	# Mép trên gấp lại + kẹp gỗ nhỏ
	ItemMeshShared.add_cube(p, 0, 0.56, 0, 1.22, 0.30, 0.75, kraft_d)
	ItemMeshShared.add_cube(p, 0, 0.74, 0, 1.02, 0.16, 0.65, wood_clip)
	ItemMeshShared.add_cube(p, -0.30, 0.76, 0.10, 0.12, 0.20, 0.12, wood_clip.lightened(0.06))
	# Hình miếng dưa hấu voxel in mặt trước
	ItemMeshShared.add_cube(p, 0, -0.06, 0.44, 0.42, 0.34, 0.12, logo_rind)
	ItemMeshShared.add_cube(p, 0, -0.02, 0.48, 0.32, 0.24, 0.10, logo_red)
	ItemMeshShared.add_cube(p, -0.10, 0.10, 0.49, 0.08, 0.08, 0.08, logo_seed)
	ItemMeshShared.add_cube(p, 0.10, 0.02, 0.49, 0.08, 0.08, 0.08, logo_seed)
	ItemMeshShared.add_cube(p, 0, -0.16, 0.46, 0.26, 0.06, 0.08, logo_rind.darkened(0.1))
	# Hạt giọt nước đỏ + vi hạt sáng xanh lá quanh túi
	ItemMeshShared.add_cube(p, -0.66, 0.10, 0.20, 0.08, 0.12, 0.08, drop_red)
	ItemMeshShared.add_cube(p, 0.70, 0.26, 0.14, 0.08, 0.10, 0.08, drop_red.darkened(0.1))
	ItemMeshShared.add_cube(p, 0.60, -0.40, 0.26, 0.08, 0.10, 0.08, drop_red.lightened(0.1))
	ItemMeshShared.add_cube(p, -0.56, -0.42, 0.22, 0.08, 0.08, 0.08, spark_green)
	ItemMeshShared.add_cube(p, 0.16, -0.50, 0.30, 0.06, 0.06, 0.06, spark_green.lightened(0.15))
	ItemMeshShared.add_cube(p, -0.22, 0.42, 0.18, 0.06, 0.06, 0.06, spark_green)
	ItemMeshShared.add_cube(p, 0.38, 0.50, 0.16, 0.06, 0.06, 0.06, spark_green.darkened(0.1))

## ── Trái bí đỏ: cầu dẹp 8-10 múi khía dọc + vệt xanh đỉnh + cuống gỗ 5 góc ─
static func _build_pumpkin_icon(p: Node3D) -> void:
	var orange := Color(0.88, 0.46, 0.10)
	var orange_l := Color(0.95, 0.60, 0.16)
	var groove := Color(0.58, 0.28, 0.06)
	var groove_d := Color(0.46, 0.21, 0.05)
	var top_green := Color(0.34, 0.50, 0.20)
	var stem := Color(0.36, 0.28, 0.13)
	var stem_moss := Color(0.30, 0.34, 0.14)
	# Thân quả cầu dẹp
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.00, 1.10, 0.92, 0.92, orange)
	ItemMeshShared.add_cube(p, 0.00, -0.32, 0.00, 1.00, 0.24, 0.86, groove_d)
	ItemMeshShared.add_cube(p, 0.00, 0.30, 0.00, 1.02, 0.24, 0.88, orange_l)
	ItemMeshShared.add_cube(p, 0.00, 0.48, 0.00, 0.88, 0.16, 0.80, orange_l.lightened(0.05))
	# Vệt xanh lục chuyển sắc quanh cuống
	ItemMeshShared.add_cube(p, 0.00, 0.54, 0.00, 0.66, 0.12, 0.62, top_green)
	# Các rãnh sâu giữa múi (trước/sau/phải/trái)
	ItemMeshShared.add_cube(p, 0.40, 0.00, 0.00, 0.12, 0.86, 0.90, groove)
	ItemMeshShared.add_cube(p, -0.40, 0.00, 0.00, 0.12, 0.86, 0.90, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.40, 0.88, 0.82, 0.12, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, -0.40, 0.88, 0.82, 0.12, groove)
	# Gân múi nhô sáng giữa hai rãnh
	ItemMeshShared.add_cube(p, 0.20, 0.00, 0.00, 0.10, 0.84, 0.86, orange_l.darkened(0.03))
	ItemMeshShared.add_cube(p, -0.20, 0.00, 0.00, 0.10, 0.84, 0.86, orange_l.darkened(0.03))
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.20, 0.84, 0.80, 0.10, orange_l.darkened(0.03))
	ItemMeshShared.add_cube(p, 0.00, 0.00, -0.20, 0.84, 0.80, 0.10, orange_l.darkened(0.03))
	# Cuống gỗ 5 góc hơi uốn cong
	ItemMeshShared.add_cube(p, -0.02, 0.62, 0.00, 0.14, 0.22, 0.14, stem)
	ItemMeshShared.add_cube(p, 0.04, 0.76, -0.02, 0.12, 0.14, 0.12, stem_moss)
	ItemMeshShared.add_cube(p, 0.02, 0.60, 0.02, 0.20, 0.06, 0.20, stem.darkened(0.08))

## ── Miếng bí đỏ: vỏ cam mỏng + thịt cam tươi + lõi xơ vàng + hạt bí ngà ─────
static func _build_pumpkin_slice_icon(p: Node3D) -> void:
	var rind := Color(0.80, 0.40, 0.08)
	var rind_d := Color(0.62, 0.28, 0.06)
	var flesh := Color(0.98, 0.66, 0.20)
	var flesh_d := Color(0.88, 0.54, 0.14)
	var hollow := Color(0.70, 0.42, 0.10)
	var fiber := Color(0.96, 0.80, 0.30)
	var seed_c := Color(0.92, 0.88, 0.72)
	# Vỏ ngoài ôm phía sau
	ItemMeshShared.add_cube(p, 0.00, -0.30, -0.24, 0.90, 0.62, 0.20, rind_d)
	ItemMeshShared.add_cube(p, 0.00, 0.04, -0.26, 0.98, 0.60, 0.18, rind)
	# Thịt cam tươi mộng nước (mặt cắt bầu dục)
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.00, 0.86, 0.72, 0.24, flesh)
	ItemMeshShared.add_cube(p, 0.00, 0.24, 0.02, 0.64, 0.16, 0.18, flesh.lightened(0.04))
	ItemMeshShared.add_cube(p, 0.00, -0.30, 0.00, 0.70, 0.14, 0.18, flesh_d)
	# Lõi ruột rỗng giữa tâm
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.16, 0.40, 0.34, 0.12, hollow)
	# Dải xơ bí vàng da cam đan chéo
	ItemMeshShared.add_cube(p, 0.00, 0.12, 0.22, 0.42, 0.06, 0.06, fiber)
	ItemMeshShared.add_cube(p, 0.00, -0.10, 0.22, 0.34, 0.06, 0.06, fiber.darkened(0.08))
	ItemMeshShared.add_cube(p, 0.12, 0.00, 0.23, 0.06, 0.30, 0.05, fiber.darkened(0.06))
	# Hạt bí ngà dẹt bám trong lõi
	ItemMeshShared.add_cube(p, 0.10, 0.04, 0.25, 0.08, 0.05, 0.04, seed_c)
	ItemMeshShared.add_cube(p, -0.10, -0.06, 0.25, 0.08, 0.05, 0.04, seed_c.lightened(0.03))
	ItemMeshShared.add_cube(p, -0.02, 0.14, 0.26, 0.08, 0.05, 0.04, seed_c.darkened(0.04))

## ── Túi vải đay hạt bí đỏ: đay nâu nhạt + dây thừng đay + bí cam in mặt trước ─
static func _build_pumpkin_seed_icon(p: Node3D) -> void:
	var burlap := Color(0.66, 0.54, 0.36)
	var burlap_d := Color(0.56, 0.44, 0.28)
	var burlap_l := Color(0.74, 0.62, 0.42)
	var rope := Color(0.48, 0.36, 0.22)
	var logo_orange := Color(0.88, 0.46, 0.10)
	var logo_groove := Color(0.58, 0.28, 0.06)
	var logo_stem := Color(0.34, 0.30, 0.14)
	var dust_orange := Color(0.98, 0.70, 0.25)
	var spark_fire := Color(0.99, 0.50, 0.15)
	# Thân túi vải đay thô
	ItemMeshShared.add_cube(p, 0, -0.20, 0, 1.40, 1.40, 0.85, burlap)
	ItemMeshShared.add_cube(p, 0, -0.02, 0, 1.26, 1.22, 0.76, burlap_l)
	ItemMeshShared.add_cube(p, 0, -0.48, 0, 1.24, 0.18, 0.76, burlap_d)
	# Mép túi + dây thừng đay buộc góc trên
	ItemMeshShared.add_cube(p, 0, 0.54, 0, 1.20, 0.26, 0.74, burlap_d)
	ItemMeshShared.add_cube(p, 0.38, 0.62, 0.12, 0.14, 0.22, 0.14, rope)
	ItemMeshShared.add_cube(p, 0.34, 0.76, 0.10, 0.26, 0.08, 0.10, rope.darkened(0.1))
	# Biểu tượng trái bí đỏ cam voxel mini in mặt trước
	ItemMeshShared.add_cube(p, 0, -0.08, 0.44, 0.40, 0.34, 0.12, logo_orange)
	ItemMeshShared.add_cube(p, 0, -0.06, 0.49, 0.34, 0.28, 0.08, logo_orange.lightened(0.05))
	ItemMeshShared.add_cube(p, 0.14, -0.08, 0.49, 0.06, 0.30, 0.08, logo_groove)
	ItemMeshShared.add_cube(p, -0.14, -0.08, 0.49, 0.06, 0.30, 0.08, logo_groove)
	ItemMeshShared.add_cube(p, 0, 0.14, 0.49, 0.08, 0.08, 0.08, logo_stem)
	ItemMeshShared.add_cube(p, 0, -0.28, 0.46, 0.24, 0.06, 0.08, logo_groove.darkened(0.1))
	# Hạt bụi sáng cam + đốm lửa nhỏ lơ lửng quanh túi
	ItemMeshShared.add_cube(p, -0.68, 0.18, 0.22, 0.08, 0.08, 0.08, dust_orange)
	ItemMeshShared.add_cube(p, 0.72, 0.30, 0.16, 0.07, 0.07, 0.07, dust_orange.lightened(0.1))
	ItemMeshShared.add_cube(p, 0.58, -0.42, 0.26, 0.08, 0.08, 0.08, dust_orange.darkened(0.08))
	ItemMeshShared.add_cube(p, -0.54, -0.38, 0.24, 0.06, 0.06, 0.06, dust_orange)
	ItemMeshShared.add_cube(p, -0.30, 0.46, 0.16, 0.06, 0.06, 0.06, spark_fire)
	ItemMeshShared.add_cube(p, 0.42, 0.52, 0.14, 0.06, 0.06, 0.06, spark_fire.lightened(0.15))

## ── Đèn lồng bí đỏ: mắt/mũi/miệng tam giác zíc-zắc + nến voxel + ánh lửa ────
static func _build_jack_o_lantern_icon(p: Node3D) -> void:
	var orange := Color(0.90, 0.50, 0.12)
	var orange_l := Color(0.97, 0.62, 0.18)
	var groove := Color(0.60, 0.30, 0.06)
	var cut := Color(0.06, 0.04, 0.02)
	var candle := Color(0.99, 0.90, 0.55)
	var flame := Color(1.00, 0.62, 0.20)
	# Thân bí cầu dẹp
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.00, 1.14, 0.96, 0.96, orange)
	ItemMeshShared.add_cube(p, 0.00, -0.34, 0.00, 1.04, 0.24, 0.90, orange.darkened(0.12))
	ItemMeshShared.add_cube(p, 0.00, 0.32, 0.00, 1.06, 0.24, 0.92, orange_l)
	ItemMeshShared.add_cube(p, 0.38, 0.00, 0.00, 0.12, 0.90, 0.94, groove)
	ItemMeshShared.add_cube(p, -0.38, 0.00, 0.00, 0.12, 0.90, 0.94, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.38, 0.92, 0.86, 0.12, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, -0.38, 0.92, 0.86, 0.12, groove)
	# Cuống gỗ
	ItemMeshShared.add_cube(p, 0.00, 0.62, 0.00, 0.14, 0.24, 0.14, Color(0.34, 0.28, 0.12))
	# Mắt tam giác
	ItemMeshShared.add_cube(p, -0.22, 0.18, 0.50, 0.22, 0.26, 0.06, cut)
	ItemMeshShared.add_cube(p, 0.22, 0.18, 0.50, 0.22, 0.26, 0.06, cut)
	# Mũi tam giác
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.50, 0.16, 0.20, 0.06, cut)
	# Miệng zíc-zắc 3 răng
	ItemMeshShared.add_cube(p, -0.26, -0.24, 0.50, 0.16, 0.12, 0.06, cut)
	ItemMeshShared.add_cube(p, 0.26, -0.24, 0.50, 0.16, 0.12, 0.06, cut)
	ItemMeshShared.add_cube(p, -0.24, -0.34, 0.50, 0.48, 0.12, 0.06, cut)
	# Nến voxel bên trong + ánh lửa vàng đỏ
	ItemMeshShared.add_cube(p, 0.00, -0.14, 0.50, 0.10, 0.20, 0.05, candle)
	ItemMeshShared.add_cube(p, 0.00, -0.02, 0.52, 0.07, 0.10, 0.05, flame)
	ItemMeshShared.add_cube_shaded(p, 0.00, 0.02, 0.52, 0.10, 0.10, 0.06, flame, 0.0, 1.0, Color(1.0, 0.6, 0.15))
	var light := OmniLight3D.new()
	light.light_color = Color(1.00, 0.62, 0.25)
	light.omni_range = 1.6
	light.light_energy = 0.8
	light.light_specular = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.05, 0.55)
	p.add_child(light)

## ── Mầm cây: hạt + chồi non ─────────────────────────────────────────────────
## variant 0 = dừa (xanh sáng), 1 = môn (xanh đậm), 2 = rong (xanh ngọc),
## 3 = cỏ biển (aqua biển)
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
		3:
			seed_c = Color(0.45, 0.38, 0.20)
			stem_c = Color(0.08, 0.62, 0.40)
			leaf_c = Color(0.05, 0.50, 0.30)
			leaf2_c = Color(0.10, 0.70, 0.46)
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

## ── Quả cam chín: cầu cam rực vân lõm + núm xanh, vệt sáng bóng ────────────
static func _build_orange_icon(p: Node3D) -> void:
	var orange := Color(0.95, 0.55, 0.12)
	var orange_l := Color(1.00, 0.70, 0.22)
	var orange_d := Color(0.78, 0.38, 0.08)
	var groove := Color(0.88, 0.46, 0.08)
	var hl := Color(1.00, 0.90, 0.60)
	var stem := Color(0.30, 0.42, 0.14)
	# Thân quả cầu
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.00, 1.10, 1.06, 1.06, orange)
	ItemMeshShared.add_cube(p, 0.00, 0.26, 0.00, 0.96, 0.24, 0.94, orange_l)
	ItemMeshShared.add_cube(p, 0.00, -0.34, 0.00, 0.98, 0.22, 0.98, orange_d)
	# Vân lõm nhẹ chạy dọc
	ItemMeshShared.add_cube(p, 0.34, 0.00, 0.00, 0.10, 0.92, 1.00, groove)
	ItemMeshShared.add_cube(p, -0.34, 0.00, 0.00, 0.10, 0.92, 1.00, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, 0.36, 0.98, 0.88, 0.10, groove)
	ItemMeshShared.add_cube(p, 0.00, 0.00, -0.36, 0.98, 0.88, 0.10, groove)
	ItemMeshShared.add_cube(p, 0.17, 0.00, 0.00, 0.08, 0.90, 0.92, orange_l.darkened(0.03))
	ItemMeshShared.add_cube(p, -0.17, 0.00, 0.00, 0.08, 0.90, 0.92, orange_l.darkened(0.03))
	# Vệt sáng bóng
	ItemMeshShared.add_cube(p, 0.30, 0.18, 0.32, 0.12, 0.22, 0.10, hl)
	ItemMeshShared.add_cube(p, 0.26, -0.02, 0.30, 0.10, 0.12, 0.08, hl.darkened(0.05))
	# Núm quả + vệt đất ở đáy
	ItemMeshShared.add_cube(p, 0.00, 0.58, 0.00, 0.16, 0.12, 0.16, stem)
	ItemMeshShared.add_cube(p, -0.02, 0.68, 0.02, 0.10, 0.08, 0.10, stem.darkened(0.08))
	ItemMeshShared.add_cube(p, 0.10, -0.54, 0.10, 0.30, 0.06, 0.30, orange_d.darkened(0.10))

## ── Túi hạt giống cam: kraft + logo quả cam in mặt trước + hạt cam vãi ──────
static func _build_orange_seed_icon(p: Node3D) -> void:
	var kraft := Color(0.64, 0.50, 0.32)
	var kraft_d := Color(0.54, 0.40, 0.24)
	var kraft_l := Color(0.70, 0.56, 0.38)
	var rope := Color(0.78, 0.16, 0.12)
	var logo_orange := Color(0.95, 0.55, 0.12)
	var logo_groove := Color(0.80, 0.42, 0.08)
	var logo_stem := Color(0.30, 0.42, 0.14)
	var seed_c := Color(0.92, 0.66, 0.30)
	# Thân túi vải đay
	ItemMeshShared.add_cube(p, 0, -0.25, 0, 1.5, 1.5, 0.9, kraft)
	ItemMeshShared.add_cube(p, 0, -0.10, 0, 1.34, 1.34, 0.8, kraft_l)
	ItemMeshShared.add_cube(p, 0, -0.42, 0, 1.34, 0.2, 0.8, kraft_d)
	# Miệng túi gập lại + dây thừng đỏ
	ItemMeshShared.add_cube(p, 0, 0.62, 0, 1.30, 0.34, 0.8, kraft_d)
	ItemMeshShared.add_cube(p, 0, 0.82, 0, 1.10, 0.18, 0.7, kraft.darkened(0.12))
	ItemMeshShared.add_cube(p, 0, 0.50, 0, 1.44, 0.12, 0.16, rope)
	# Logo quả cam in mặt trước
	ItemMeshShared.add_cube(p, 0, -0.06, 0.46, 0.34, 0.36, 0.12, logo_orange)
	ItemMeshShared.add_cube(p, 0, 0.08, 0.49, 0.26, 0.10, 0.08, logo_orange.lightened(0.08))
	ItemMeshShared.add_cube(p, 0.12, -0.06, 0.49, 0.05, 0.30, 0.08, logo_groove)
	ItemMeshShared.add_cube(p, -0.12, -0.06, 0.49, 0.05, 0.30, 0.08, logo_groove)
	ItemMeshShared.add_cube(p, 0, 0.20, 0.48, 0.08, 0.08, 0.08, logo_stem)
	# Hạt cam vãi quanh túi
	ItemMeshShared.add_cube(p, -0.64, -0.76, 0.30, 0.10, 0.08, 0.10, seed_c)
	ItemMeshShared.add_cube(p, -0.32, -0.84, 0.18, 0.10, 0.08, 0.10, seed_c.darkened(0.08))
	ItemMeshShared.add_cube(p, 0.12, -0.82, 0.34, 0.10, 0.08, 0.10, seed_c.lightened(0.06))
	ItemMeshShared.add_cube(p, 0.54, -0.76, 0.24, 0.10, 0.08, 0.10, seed_c.darkened(0.05))
