class_name PlantProp
extends DestroyableProp

const VOXEL: float = 0.25
const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

var plant_type: String = "weed"
var seed_h1: int = 0
var seed_h2: int = 0
var has_silt: bool = false
var water_gap: float = 1.0

func setup(type: String, _h1: int, _h2: int, _has_silt: bool, _water_gap: float) -> void:
	plant_type = type
	seed_h1 = _h1
	seed_h2 = _h2
	has_silt = _has_silt
	water_gap = _water_gap

func _ready() -> void:
	super._ready()
	_build_mesh()

func _build_mesh() -> void:
	if not is_inside_tree():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h1 := seed_h1
	var s := h1 * 16807 + 1

	if plant_type == "weed":
		_build_weed(st, s)
	else:
		_build_taro(st, s)

	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := _make_aquatic_mat()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _build_weed(st: SurfaceTool, s: int) -> void:
	var h1 := seed_h1
	var r1: float = float(h1 & 0x7FFFFFFF) / 2147483648.0
	var h2 := seed_h2
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var h3: int = h1 * 716199923 + seed_h2 * 912334613
	h3 = (h3 ^ (h3 >> 13)) * 974126171; h3 = h3 ^ (h3 >> 16)
	var r3 := float(h3 & 0x7FFFFFFF) / 2147483648.0
	var h4: int = h1 * 374761393 + seed_h2 * 631152931
	h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
	var r4 := float(h4 & 0x7FFFFFFF) / 2147483648.0

	var max_segs: int = clampi(int(maxf(water_gap, 0.0) / VOXEL), 1, 5)
	var seg_count: int
	if   r2 < 0.15: seg_count = 1
	elif r2 < 0.35: seg_count = 2
	elif r2 < 0.60: seg_count = 3
	elif r2 < 0.82: seg_count = 4
	else:            seg_count = 5
	seg_count = mini(seg_count, max_segs)
	if seg_count < 1: seg_count = 1

	var stem_g: float = 0.62 + r3 * 0.22
	var stem_b: float = 0.08 + r3 * 0.10
	var col_stem := Color(0.03, stem_g, stem_b, 1.0)
	var col_br1  := Color(0.04, stem_g * 0.92, stem_b, 1.0)
	var col_br2  := Color(0.05, minf(stem_g * 1.10, 1.0), stem_b * 0.55, 1.0)
	var sw: float = 0.014 + r4 * 0.008

	s = s * 16807 + 1; var lean_x: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	s = s * 16807 + 1; var lean_z: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	var cur_x: float = (r2 - 0.5) * 0.2
	var cur_z: float = (r3 - 0.5) * 0.2
	var cur_y: float = 0.0
	var bx := cur_x; var bz := cur_z; var by := cur_y

	var max_seg: int = mini(seg_count, 3)
	for seg in range(max_seg):
		s = s * 16807 + 1; var dx := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		s = s * 16807 + 1; var dz := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		var nx := cur_x + lean_x + dx
		var nz := cur_z + lean_z + dz
		var ny := cur_y + VOXEL
		var mid := Vector3((cur_x + nx) * 0.5, (cur_y + ny) * 0.5, (cur_z + nz) * 0.5)
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0, 1), col_stem)
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,VOXEL*0.5,0), Vector3(0,0,-1), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,VOXEL*0.5,0), Vector3( 1,0,0), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,VOXEL*0.5,0), Vector3(-1,0,0), col_stem)
		s = _draw_whorls(st, s, nx, nz, cur_y, sw, col_br1, col_br2, seg)
		if seg > 0 or max_seg == 1:
			s = _draw_branches(st, s, nx, nz, cur_y, sw, lean_x, lean_z, dx, dz, col_br1, col_br2)
		cur_x = nx; cur_z = nz; cur_y = ny
	# Fruit cluster at base
	_draw_fruit_cluster(st, s, bx, bz, by, lean_x, lean_z, sw)

func _draw_whorls(st: SurfaceTool, s: int, nx: float, nz: float, cur_y: float, sw: float, col_br1: Color, col_br2: Color, seg: int) -> int:
	var whorls: int = 4
	var woff: float = float(seg) * (PI / float(whorls))
	var wroot := Vector3(nx, cur_y + VOXEL * 0.55, nz)
	for wi in range(whorls):
		var wa: float = float(wi) / float(whorls) * TAU + woff
		s = s * 16807 + 1; var wr := float(s & 0x7FFFFFFF) / 2147483648.0
		var wdir := Vector3(cos(wa), 0.12 + wr * 0.10, sin(wa)).normalized()
		var wperp := Vector3(-sin(wa), 0.0, cos(wa)).normalized()
		var wlen: float = 0.16 + wr * 0.08
		var ww: float = sw * 0.55
		_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5,  wperp.cross(wdir).normalized(), col_br1)
		_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5, -wperp.cross(wdir).normalized(), col_br1)
	return s

func _draw_branches(st: SurfaceTool, s: int, nx: float, nz: float, cur_y: float, sw: float, lean_x: float, lean_z: float, dx: float, dz: float, col_br1: Color, col_br2: Color) -> int:
	var bbase := Vector3(nx, cur_y + VOXEL * 0.75, nz)
	var base_angle: float = atan2(lean_z + dz, lean_x + dx) + PI * 0.5
	for bi in range(3):
		var ba: float = base_angle + float(bi) * TAU / 3.0
		s = s * 16807 + 1; var br := float(s & 0x7FFFFFFF) / 2147483648.0
		ba += (br - 0.5) * 0.3
		s = s * 16807 + 1; var bup := float(s & 0x7FFFFFFF) / 2147483648.0
		var bdir := Vector3(cos(ba), 0.20 + bup * 0.20, sin(ba)).normalized()
		var bperp := Vector3(-sin(ba), 0.0, cos(ba)).normalized()
		s = s * 16807 + 1; var blen_r := float(s & 0x7FFFFFFF) / 2147483648.0
		var blen: float = 0.22 + blen_r * 0.14; var bw: float = sw * 0.65
		_add_quad(st, bbase + bdir*blen*0.5, bperp*bw, bdir*blen*0.5,  bperp.cross(bdir).normalized(), col_br1)
		_add_quad(st, bbase + bdir*blen*0.5, bperp*bw, bdir*blen*0.5, -bperp.cross(bdir).normalized(), col_br1)
		var branch_mid := bbase + bdir * blen * 0.5
		for wi2 in range(3):
			var wa2: float = float(wi2) / 3.0 * TAU + ba
			s = s * 16807 + 1; var wr2 := float(s & 0x7FFFFFFF) / 2147483648.0
			var wd2 := Vector3(cos(wa2), 0.08 + wr2 * 0.08, sin(wa2)).normalized()
			var wp2 := Vector3(-sin(wa2), 0.0, cos(wa2)).normalized()
			var wl2: float = 0.08 + wr2 * 0.05; var ww3: float = sw * 0.40
			_add_quad(st, branch_mid + wd2*wl2*0.5, wp2*ww3, wd2*wl2*0.5,  wp2.cross(wd2).normalized(), col_br2)
			_add_quad(st, branch_mid + wd2*wl2*0.5, wp2*ww3, wd2*wl2*0.5, -wp2.cross(wd2).normalized(), col_br2)
		var btip := bbase + bdir * blen
		for fork in [0, 1]:
			s = s * 16807 + 1; var fr := float(s & 0x7FFFFFFF) / 2147483648.0
			var fa: float = ba + (float(fork) - 0.5) * 0.55 + (fr - 0.5) * 0.2
			var fdir := Vector3(cos(fa), 0.22 + fr * 0.12, sin(fa)).normalized()
			var fperp2 := Vector3(-sin(fa), 0.0, cos(fa)).normalized()
			var flen: float = blen * 0.52; var fw2: float = bw * 0.55
			_add_quad(st, btip + fdir*flen*0.5, fperp2*fw2, fdir*flen*0.5,  fperp2.cross(fdir).normalized(), col_br2)
			_add_quad(st, btip + fdir*flen*0.5, fperp2*fw2, fdir*flen*0.5, -fperp2.cross(fdir).normalized(), col_br2)
	return s

func _draw_fruit_cluster(st: SurfaceTool, s: int, cur_x: float, cur_z: float, cur_y: float, lean_x: float, lean_z: float, sw: float) -> void:
	s = s * 16807 + 1
	if float(s & 0x7FFFFFFF) / 2147483648.0 >= 0.20: return
	s = s * 16807 + 1; var fc1 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc2 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc3 := float(s & 0x7FFFFFFF) / 2147483648.0
	var fa: float = lean_x + lean_z + fc1 * TAU
	var base_pos := Vector3(cur_x, cur_y + VOXEL * 0.6, cur_z) + Vector3(cos(fa), 0, sin(fa)) * (sw + 0.05)
	var num_berries: int = 3 + (s & 1) + ((s >> 2) & 1)
	var col_fruit := Color(1.0, 0.82, 0.08, 1.0)
	var col_fruit_dark := Color(0.80, 0.65, 0.05, 1.0)
	for bi in range(num_berries):
		s = s * 16807 + 1; var b_r := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1; var b_a := float(s & 0x7FFFFFFF) / 2147483648.0 * TAU
		s = s * 16807 + 1; var b_t := float(s & 0x7FFFFFFF) / 2147483648.0
		var berry_radius: float = 0.022 + b_r * 0.025
		var ox: float = cos(b_a) * (0.03 + b_r * 0.06)
		var oz: float = sin(b_a) * (0.03 + b_r * 0.06)
		var oy: float = -b_t * 0.07
		var berry_pos := base_pos + Vector3(ox, oy, oz)
		var col_berry := col_fruit if b_r > 0.35 else col_fruit_dark
		_add_quad(st, berry_pos, Vector3(berry_radius,0,0), Vector3(0,berry_radius,0), Vector3(0,0,1), col_berry)
		_add_quad(st, berry_pos, Vector3(0,0,berry_radius), Vector3(0,berry_radius,0), Vector3(1,0,0), col_berry)
	var glow := OmniLight3D.new()
	glow.omni_range = 2.5
	glow.light_energy = 0.25
	glow.light_specular = 0.0
	glow.omni_attenuation = 0.6
	glow.shadow_enabled = false
	glow.position = base_pos
	add_child(glow)

func _build_taro(st: SurfaceTool, s: int) -> void:
	var h1 := seed_h1
	var r1: float = float(h1 & 0x7FFFFFFF) / 2147483648.0
	var h2 := seed_h2
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var h3: int = h1 * 716199923 + seed_h2 * 912334613
	h3 = (h3 ^ (h3 >> 13)) * 974126171; h3 = h3 ^ (h3 >> 16)
	var r3 := float(h3 & 0x7FFFFFFF) / 2147483648.0
	var h4: int = h1 * 374761393 + seed_h2 * 631152931
	h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
	var r4 := float(h4 & 0x7FFFFFFF) / 2147483648.0

	var base := Vector3((r2 - 0.5) * 0.4, 0.0, (r3 - 0.5) * 0.4)
	var num_leaves: int = 1 + (s & 2)
	var col_stem := Color(0.26 + r4 * 0.10, 0.46 + r4 * 0.14, 0.10 + r4 * 0.04)
	var col_leaf := Color(0.03 + r4 * 0.06, 0.22 + r4 * 0.16, 0.04 + r4 * 0.03)
	var col_light := Color(0.04 + r4 * 0.04, 0.32 + r4 * 0.14, 0.06 + r4 * 0.03)
	var col_vein := Color(0.06 + r4 * 0.04, 0.40 + r4 * 0.08, 0.08 + r4 * 0.03)
	for i in range(num_leaves):
		s = s * 16807 + 1; var la := float(s & 0x7FFFFFFF) / 2147483648.0 * TAU
		s = s * 16807 + 1; var lb := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1; var lc := float(s & 0x7FFFFFFF) / 2147483648.0
		var lean: float = 0.08 + lb * 0.22
		var pdx: float = cos(la) * lean
		var pdz: float = sin(la) * lean
		var stem_h: float = 0.8 + lb * 0.7
		var leaf_r: float = 0.35 + lb * 0.25
		var stem_top := base + Vector3(pdx, stem_h, pdz)
		var segs: int = 3
		for seg in range(segs):
			var t: float = float(seg + 1) / float(segs)
			var pt: float = float(seg) / float(segs)
			var mid_y: float = base.y + stem_h * (t + pt) * 0.5
			var mid_x: float = base.x + pdx * (t + pt) * 0.5
			var mid_z: float = base.z + pdz * (t + pt) * 0.5
			var sw: float = (0.035 + lb * 0.020) * (1.0 - t * 0.25)
			var seg_mid := Vector3(mid_x, mid_y, mid_z)
			var seg_h: float = stem_h / float(segs) * 0.5
			_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, 1), col_stem)
			_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, -1), col_stem)
			_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(1, 0, 0), col_stem * 0.92)
			_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(-1, 0, 0), col_stem * 0.92)
		_draw_hex_leaf(st, stem_top, leaf_r, la, col_leaf, col_light, col_vein, s)

func _draw_hex_leaf(st: SurfaceTool, center: Vector3, r: float, angle: float, col_base: Color, col_light: Color, col_vein: Color, s: int) -> void:
	var cx := center.x; var cy := center.y + 0.02; var cz := center.z
	var d_cup: float = r * 0.10
	var verts: Array[Vector3] = []
	for vi in 6:
		var va := angle + float(vi) * PI / 3.0
		var vx := cx + cos(va) * r * 0.85
		var vz := cz + sin(va) * r * 0.85
		var vy: float = cy - d_cup * (1.0 - abs(cos(va - angle)) * 0.5)
		verts.append(Vector3(vx, vy, vz))
	for ti in 6:
		var ni := (ti + 1) % 6
		var col_t := col_light if (ti + (s & 1)) % 2 == 0 else col_base
		var n := Vector3(0, 1, 0)
		st.set_normal(n); st.set_color(col_t)
		st.add_vertex(Vector3(cx, cy - d_cup * 0.4, cz))
		st.add_vertex(verts[ti])
		st.add_vertex(verts[ni])
	for ei in 6:
		var e0 := verts[ei]
		var e1 := verts[(ei + 1) % 6]
		var em := (e0 + e1) * 0.5
		var e_dir := (e1 - e0).normalized()
		var e_perp := Vector3(-e_dir.z, 0, e_dir.x).normalized()
		var col_edge := col_base * (0.80 + float(ei % 2) * 0.08)
		_add_quad(st, em, e_perp * 0.025, e_dir * e0.distance_to(e1) * 0.5, Vector3(0, 1, 0), col_edge)
	var ba := angle + PI
	var bw: float = r * 0.28
	var bh: float = r * 0.16
	var col_lobe := col_base * 0.80
	var lb := Vector3(cx + cos(ba - 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba - 0.3) * r * 0.45)
	var rb := Vector3(cx + cos(ba + 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba + 0.3) * r * 0.45)
	_add_quad(st, lb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), angle), Vector3(0, 0, bh).rotated(Vector3(0,1,0), angle), Vector3(0, 1, 0), col_lobe)
	_add_quad(st, rb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), angle), Vector3(0, 0, bh).rotated(Vector3(0,1,0), angle), Vector3(0, 1, 0), col_lobe)
	var ve := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, -r * 0.45).rotated(Vector3(0,1,0), angle)
	var vm := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, r * 0.20).rotated(Vector3(0,1,0), angle)
	_add_quad(st, (vm + ve) * 0.5, Vector3(0.018, 0, 0).rotated(Vector3(0,1,0), angle), Vector3(0, 0, vm.distance_to(ve) * 0.5).rotated(Vector3(0,1,0), angle), Vector3(0, 1, 0), col_vein)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)

func _make_aquatic_mat() -> ShaderMaterial:
	return WorldChunk.make_aquatic_mat()

static func build_drop_mesh(parent: Node3D, plant_type: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h1 := rng.randi()
	var h2 := rng.randi()
	var s := h1 * 16807 + 1
	if plant_type == "weed":
		_build_drop_weed_mesh(st, h1, h2, s)
	else:
		_build_drop_taro_mesh(st, h1, h2, s)
	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = WorldChunk.make_aquatic_mat()
		parent.add_child(mi)

static func _build_drop_weed_mesh(st: SurfaceTool, h1: int, h2: int, s: int) -> void:
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
	var col_br2  := Color(0.05, minf(stem_g * 1.10, 1.0), stem_b * 0.55, 1.0)
	var sw: float = 0.014 + r4 * 0.008
	s = s * 16807 + 1; var lean_x: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	s = s * 16807 + 1; var lean_z: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	var cur_x: float = (r2 - 0.5) * 0.2
	var cur_z: float = (r3 - 0.5) * 0.2
	var cur_y: float = 0.0
	for seg in range(2):
		s = s * 16807 + 1; var dx := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		s = s * 16807 + 1; var dz := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		var nx := cur_x + lean_x + dx
		var nz := cur_z + lean_z + dz
		var ny := cur_y + VOXEL
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

static func _build_drop_taro_mesh(st: SurfaceTool, h1: int, h2: int, s: int) -> void:
	var h4: int = h1 * 374761393 + h2 * 631152931
	h4 = (h4 ^ (h4 >> 13)) * 1174126183; h4 = h4 ^ (h4 >> 16)
	var r4f := float(h4 & 0x7FFFFFFF) / 2147483648.0
	var base := Vector3(0, 0.0, 0)
	var col_stem := Color(0.26 + r4f * 0.10, 0.46 + r4f * 0.14, 0.10 + r4f * 0.04)
	var col_leaf := Color(0.03 + r4f * 0.06, 0.22 + r4f * 0.16, 0.04 + r4f * 0.03)
	var col_light := Color(0.04 + r4f * 0.04, 0.32 + r4f * 0.14, 0.06 + r4f * 0.03)
	var col_vein := Color(0.06 + r4f * 0.04, 0.40 + r4f * 0.08, 0.08 + r4f * 0.03)
	s = s * 16807 + 1; var la := float(s & 0x7FFFFFFF) / 2147483648.0 * TAU
	s = s * 16807 + 1; var lb := float(s & 0x7FFFFFFF) / 2147483648.0
	var lean: float = 0.08 + lb * 0.22
	var stem_h: float = 0.8 + lb * 0.7
	var leaf_r: float = 0.35 + lb * 0.25
	var stem_top := base + Vector3(cos(la) * lean, stem_h, sin(la) * lean)
	for seg in range(4):
		var t: float = float(seg + 1) / 4.0
		var pt: float = float(seg) / 4.0
		var mid_y: float = base.y + stem_h * (t + pt) * 0.5
		var sw: float = (0.035 + lb * 0.020) * (1.0 - t * 0.25)
		var seg_mid := Vector3(cos(la) * lean * (t + pt) * 0.5, mid_y, sin(la) * lean * (t + pt) * 0.5)
		var seg_h: float = stem_h / 4.0 * 0.5
		_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, 1), col_stem)
		_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, -1), col_stem)
		_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(1, 0, 0), col_stem * 0.92)
		_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(-1, 0, 0), col_stem * 0.92)
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
		var col_t := col_light if (ti + 0) % 2 == 0 else col_leaf
		st.set_normal(Vector3(0, 1, 0))
		st.set_color(col_t)
		st.add_vertex(Vector3(cx, cy - d_cup * 0.4, cz))
		st.add_vertex(verts[ti])
		st.add_vertex(verts[ni])
