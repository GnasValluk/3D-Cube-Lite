extends RefCounted

const _Data = preload("chunk_data.gd")

static func add_aquatic_plants(st: SurfaceTool, cx: int, cz: int, size: int,
		vx: int, vz: int, pos: Vector3, _h_vox: float, has_silt: bool,
		biome: int, lotus_lights: Array[Vector3] = []) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz

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

	var water_gap: float = _Data.WATER_Y - pos.y

	var is_deep: bool = water_gap >= _Data.VOXEL * 0.5
	var is_shore: bool = not is_deep and water_gap > -_Data.VOXEL * 0.5

	if is_deep:
		_add_tropical_weed(st, wx, wz, pos, r1, r2, r3, r4, h1, h2, water_gap, has_silt, lotus_lights)
		if has_silt:
			_add_lotus_plant(st, wx, wz, pos, r1, r2, r3, r4, h1, lotus_lights)

	if is_shore and (biome == _Data.TileType.SAND or biome == _Data.TileType.MUDDY_SAND):
		_add_taro_plant(st, wx, wz, pos, r1, r2, r3, r4, h1)

# ── Rong nước ngọt nhiệt đới (rong đuôi chó voxel) ──────────────────────────
static func _add_tropical_weed(st: SurfaceTool, _wx: int, _wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int, _h2: int,
		water_gap: float, has_silt: bool, lotus_lights: Array[Vector3]) -> void:

	var chance: float = 0.18 if has_silt else 0.08
	if r1 >= chance: return

	var max_segs: int = clampi(int(water_gap / _Data.VOXEL), 1, 5)
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

	var s: int = h1
	s = s * 16807 + 1; var lean_x: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	s = s * 16807 + 1; var lean_z: float = (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.10
	var cur_x: float = pos.x + (r2 - 0.5) * 0.2
	var cur_z: float = pos.z + (r3 - 0.5) * 0.2
	var cur_y: float = pos.y
	var bx := cur_x; var bz := cur_z; var by := cur_y

	for seg in range(seg_count):
		s = s * 16807 + 1; var dx := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		s = s * 16807 + 1; var dz := (float(s & 0x7FFFFFFF) / 2147483648.0 - 0.5) * 0.07
		var nx := cur_x + lean_x + dx
		var nz := cur_z + lean_z + dz
		var ny := cur_y + _Data.VOXEL
		var mid := Vector3((cur_x + nx) * 0.5, (cur_y + ny) * 0.5, (cur_z + nz) * 0.5)

		# Thân đốt mảnh 4 mặt
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,_Data.VOXEL*0.5,0), Vector3(0,0, 1), col_stem)
		_add_quad(st, mid, Vector3(sw,0,0), Vector3(0,_Data.VOXEL*0.5,0), Vector3(0,0,-1), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,_Data.VOXEL*0.5,0), Vector3( 1,0,0), col_stem)
		_add_quad(st, mid, Vector3(0,0,sw), Vector3(0,_Data.VOXEL*0.5,0), Vector3(-1,0,0), col_stem)

		# Vòng râu 6 cái tỏa tròn quanh đốt
		s = _draw_whorls(st, s, nx, nz, cur_y, sw, col_br1, col_br2, seg)

		# 3 cành phân nhánh 120° (trừ đốt đáy)
		if seg > 0 or seg_count == 1:
			s = _draw_branches(st, s, nx, nz, cur_y, sw, lean_x, lean_z, dx, dz, col_br1, col_br2)

		cur_x = nx; cur_z = nz; cur_y = ny

	# Chùm quả vàng phát sáng — ở gốc cây
	s = _draw_fruit_cluster(st, s, bx, bz, by, lean_x, lean_z, sw, lotus_lights)

# Vòng 6 râu tỏa tròn quanh đốt, mỗi râu chẻ đôi ở đầu
static func _draw_whorls(st: SurfaceTool, s: int, nx: float, nz: float, cur_y: float,
		sw: float, col_br1: Color, col_br2: Color, seg: int) -> int:
	var whorls: int = 6
	var woff: float = float(seg) * (PI / float(whorls))
	var wroot := Vector3(nx, cur_y + _Data.VOXEL * 0.55, nz)
	for wi in range(whorls):
		var wa: float = float(wi) / float(whorls) * TAU + woff
		s = s * 16807 + 1; var wr := float(s & 0x7FFFFFFF) / 2147483648.0
		var wdir := Vector3(cos(wa), 0.12 + wr * 0.10, sin(wa)).normalized()
		var wperp := Vector3(-sin(wa), 0.0, cos(wa)).normalized()
		var wlen: float = 0.16 + wr * 0.08
		var ww: float = sw * 0.55
		_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5,  wperp.cross(wdir).normalized(), col_br1)
		_add_quad(st, wroot + wdir*wlen*0.5, wperp*ww, wdir*wlen*0.5, -wperp.cross(wdir).normalized(), col_br1)
		var wtip: Vector3 = wroot + wdir * wlen
		for fork in [0, 1]:
			s = s * 16807 + 1; var fr := float(s & 0x7FFFFFFF) / 2147483648.0
			var fa: float = wa + (float(fork) - 0.5) * 0.60 + (fr - 0.5) * 0.15
			var fdir := Vector3(cos(fa), 0.18 + fr * 0.10, sin(fa)).normalized()
			var fperp := Vector3(-sin(fa), 0.0, cos(fa)).normalized()
			var flen: float = wlen * 0.50; var fw: float = ww * 0.55
			_add_quad(st, wtip + fdir*flen*0.5, fperp*fw, fdir*flen*0.5,  fperp.cross(fdir).normalized(), col_br2)
			_add_quad(st, wtip + fdir*flen*0.5, fperp*fw, fdir*flen*0.5, -fperp.cross(fdir).normalized(), col_br2)
	return s

# 3 cành phân nhánh đều 120° từ thân, mỗi cành có râu nhỏ + chẻ 2 lần
static func _draw_branches(st: SurfaceTool, s: int, nx: float, nz: float, cur_y: float,
		sw: float, lean_x: float, lean_z: float, dx: float, dz: float,
		col_br1: Color, col_br2: Color) -> int:
	var bbase := Vector3(nx, cur_y + _Data.VOXEL * 0.75, nz)
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

		# Vòng râu nhỏ ở giữa cành (4 râu)
		var branch_mid := bbase + bdir * blen * 0.5
		for wi2 in range(4):
			var wa2: float = float(wi2) / 4.0 * TAU + ba
			s = s * 16807 + 1; var wr2 := float(s & 0x7FFFFFFF) / 2147483648.0
			var wd2 := Vector3(cos(wa2), 0.08 + wr2 * 0.08, sin(wa2)).normalized()
			var wp2 := Vector3(-sin(wa2), 0.0, cos(wa2)).normalized()
			var wl2: float = 0.08 + wr2 * 0.05; var ww3: float = sw * 0.40
			_add_quad(st, branch_mid + wd2*wl2*0.5, wp2*ww3, wd2*wl2*0.5,  wp2.cross(wd2).normalized(), col_br2)
			_add_quad(st, branch_mid + wd2*wl2*0.5, wp2*ww3, wd2*wl2*0.5, -wp2.cross(wd2).normalized(), col_br2)

		# Đầu cành chẻ đôi 2 lần
		var btip := bbase + bdir * blen
		for fork in [0, 1]:
			s = s * 16807 + 1; var fr := float(s & 0x7FFFFFFF) / 2147483648.0
			var fa: float = ba + (float(fork) - 0.5) * 0.55 + (fr - 0.5) * 0.2
			var fdir := Vector3(cos(fa), 0.22 + fr * 0.12, sin(fa)).normalized()
			var fperp2 := Vector3(-sin(fa), 0.0, cos(fa)).normalized()
			var flen: float = blen * 0.52; var fw2: float = bw * 0.55
			_add_quad(st, btip + fdir*flen*0.5, fperp2*fw2, fdir*flen*0.5,  fperp2.cross(fdir).normalized(), col_br2)
			_add_quad(st, btip + fdir*flen*0.5, fperp2*fw2, fdir*flen*0.5, -fperp2.cross(fdir).normalized(), col_br2)
			var ftip := btip + fdir * flen
			for fork2 in [0, 1]:
				s = s * 16807 + 1; var fr2 := float(s & 0x7FFFFFFF) / 2147483648.0
				var fa2: float = fa + (float(fork2) - 0.5) * 0.50 + (fr2 - 0.5) * 0.15
				var f2dir := Vector3(cos(fa2), 0.25 + fr2 * 0.10, sin(fa2)).normalized()
				var f2perp := Vector3(-sin(fa2), 0.0, cos(fa2)).normalized()
				var f2len: float = flen * 0.45; var f2w: float = fw2 * 0.50
				_add_quad(st, ftip + f2dir*f2len*0.5, f2perp*f2w, f2dir*f2len*0.5,  f2perp.cross(f2dir).normalized(), col_br2)
				_add_quad(st, ftip + f2dir*f2len*0.5, f2perp*f2w, f2dir*f2len*0.5, -f2perp.cross(f2dir).normalized(), col_br2)
	return s

# ── Chùm quả vàng phát sáng (thay thế hoa cũ) ─────────────────────────────
static func _draw_fruit_cluster(st: SurfaceTool, s: int, cur_x: float, cur_z: float, cur_y: float,
		lean_x: float, lean_z: float, sw: float, lotus_lights: Array[Vector3]) -> int:
	s = s * 16807 + 1
	if float(s & 0x7FFFFFFF) / 2147483648.0 >= 0.35:
		return s
	s = s * 16807 + 1; var fc1 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc2 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc3 := float(s & 0x7FFFFFFF) / 2147483648.0
	var fa: float = lean_x + lean_z + fc1 * TAU
	var base_pos := Vector3(cur_x, cur_y + _Data.VOXEL * 0.6, cur_z) + Vector3(cos(fa), 0, sin(fa)) * (sw + 0.05)

	# Chùm 7~12 trái to hơn, màu vàng óng
	var num_berries: int = 7 + (s & 3) + ((s >> 2) & 1) + ((s >> 3) & 1)
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

	# Đăng ký ánh sáng phát quang
	lotus_lights.append(Vector3(base_pos.x + 500.0, base_pos.y, base_pos.z))
	return s

# ── Sen thạch anh ─────────────────────────────────────────────────────────────
static func _add_lotus_plant(st: SurfaceTool, wx: int, wz: int, pos: Vector3,
		_r1: float, _r2: float, _r3: float, _r4: float, _h1: int,
		lotus_lights: Array[Vector3]) -> void:
	var h5: int = wx * 912347189 + wz * 678451237 + 119988771
	h5 = (h5 ^ (h5 >> 13)) * 1174126183; h5 = h5 ^ (h5 >> 16)
	var r5 := float(h5 & 0x7FFFFFFF) / 2147483648.0
	if r5 >= 0.10: return
	var h6: int = wx * 556677889 + wz * 334455667 + 223344556
	h6 = (h6 ^ (h6 >> 13)) * 1074126187; h6 = h6 ^ (h6 >> 16)
	var r6 := float(h6 & 0x7FFFFFFF) / 2147483648.0
	var lily_r: float = 0.22 + r5 * 0.14
	var ox3: float = (r5 - 0.5) * 0.4
	var oz3: float = (r6 - 0.5) * 0.4
	var lily_y: float = _Data.WATER_Y + 0.005
	var col_lily := Color(0.08, 0.38 + r6 * 0.16, 0.10, 1.0)
	_add_quad(st, Vector3(pos.x+ox3, lily_y, pos.z+oz3),
		Vector3(lily_r,0,0), Vector3(0,0,lily_r), Vector3(0,1,0), col_lily)
	var d45: float = lily_r * 0.707
	_add_quad(st, Vector3(pos.x+ox3, lily_y, pos.z+oz3),
		Vector3(d45,0,d45), Vector3(-d45,0,d45), Vector3(0,1,0), col_lily * 0.9)
	if r5 < 0.05:
		var lot_h: float = 0.12 + r6 * 0.08
		var col_lotus := Color(0.90+r6*0.05, 0.65+r5*0.20, 0.68+r6*0.12, 1.0)
		var stem := Vector3(pos.x+ox3, lily_y + lot_h*0.5, pos.z+oz3)
		for ci in range(4):
			var ca: float = float(ci) * PI * 0.5
			_add_quad(st, stem + Vector3(cos(ca)*0.06, 0, sin(ca)*0.06),
				Vector3(cos(ca+PI*0.5)*0.04, 0, sin(ca+PI*0.5)*0.04),
				Vector3(0, lot_h*0.5, 0),
				Vector3(-sin(ca), 0, cos(ca)), col_lotus)
		lotus_lights.append(Vector3(pos.x+ox3, lily_y, pos.z+oz3))

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)

## ── Môn ngọt — bờ hồ, lá lục giác to, cuống 3D ─────────────────────────────
static func _add_taro_plant(st: SurfaceTool, _wx: int, _wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int) -> void:
	if r1 >= 0.12: return
	var s: int = h1
	var water_surf: float = _Data.WATER_Y
	var root_y: float = water_surf - _Data.VOXEL * 0.5
	var base := Vector3(pos.x + (r2 - 0.5) * 0.4, root_y, pos.z + (r3 - 0.5) * 0.4)
	var num_leaves: int = 1 + (s & 2)
	var col_stem := Color(0.26 + r4 * 0.10, 0.46 + r4 * 0.14, 0.10 + r4 * 0.04)
	var col_leaf := Color(0.03 + r4 * 0.06, 0.22 + r4 * 0.16, 0.04 + r4 * 0.03)
	var col_light := Color(0.04 + r4 * 0.04, 0.32 + r4 * 0.14, 0.06 + r4 * 0.03)
	var col_vein := Color(0.06 + r4 * 0.04, 0.40 + r4 * 0.08, 0.08 + r4 * 0.03)
	for i in range(num_leaves):
		s = s * 16807 + 1; var la := float(s & 0x7FFFFFFF) / 2147483648.0 * TAU
		s = s * 16807 + 1; var lb := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1; var lc := float(s & 0x7FFFFFFF) / 2147483648.0
		# Cuống 3D — 4 mặt dạng hộp, cao
		var lean: float = 0.08 + lb * 0.22
		var pdx: float = cos(la) * lean
		var pdz: float = sin(la) * lean
		var stem_h: float = (_Data.VOXEL * 1.0) + lb * (_Data.VOXEL * 0.8)
		var stem_top := base + Vector3(pdx, stem_h, pdz)
		var segs: int = 4
		for seg in range(segs):
			var t: float = float(seg + 1) / float(segs)
			var pt: float = float(seg) / float(segs)
			var mid_y: float = base.y + stem_h * (t + pt) * 0.5
			var mid_x: float = base.x + pdx * (t + pt) * 0.5
			var mid_z: float = base.z + pdz * (t + pt) * 0.5
			var sw: float = (0.035 + lc * 0.020) * (1.0 - t * 0.25)
			var seg_mid := Vector3(mid_x, mid_y, mid_z)
			var seg_h: float = stem_h / float(segs) * 0.5
			_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, 1), col_stem)
			_add_quad(st, seg_mid, Vector3(sw, 0, 0), Vector3(0, seg_h, 0), Vector3(0, 0, -1), col_stem)
			_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(1, 0, 0), col_stem * 0.92)
			_add_quad(st, seg_mid, Vector3(0, 0, sw), Vector3(0, seg_h, 0), Vector3(-1, 0, 0), col_stem * 0.92)

		# Lá lục giác — 6 tam giác dạng quạt, không chồng chéo
		var r: float = 0.35 + lc * 0.25
		var lc2 := _draw_hex_leaf(st, stem_top, r, la, col_leaf, col_light, col_vein, s)
		s = lc2

## Lá lục giác — 6 tam giác quạt, viền + gân + thuỳ
static func _draw_hex_leaf(st: SurfaceTool, center: Vector3, r: float,
		angle: float, col_base: Color, col_light: Color, col_vein: Color, s: int) -> int:
	var cx := center.x; var cy := center.y + 0.02; var cz := center.z
	var d_cup: float = r * 0.10

	# 6 đỉnh lục giác
	var verts: Array[Vector3] = []
	for vi in 6:
		var va := angle + float(vi) * PI / 3.0
		var vx := cx + cos(va) * r * 0.85
		var vz := cz + sin(va) * r * 0.85
		var vy: float = cy - d_cup * (1.0 - abs(cos(va - angle)) * 0.5)
		verts.append(Vector3(vx, vy, vz))

	# 6 tam giác từ tâm ra từng cặp đỉnh — không chồng lấn
	for ti in 6:
		var ni := (ti + 1) % 6
		var col_t := col_light if (ti + (s & 1)) % 2 == 0 else col_base
		var n := Vector3(0, 1, 0)
		st.set_normal(n); st.set_color(col_t)
		st.add_vertex(Vector3(cx, cy - d_cup * 0.4, cz))
		st.add_vertex(verts[ti])
		st.add_vertex(verts[ni])

	# Viền lá — 6 quads nhỏ nối giữa các đỉnh lục giác
	for ei in 6:
		var e0 := verts[ei]
		var e1 := verts[(ei + 1) % 6]
		var em := (e0 + e1) * 0.5
		var e_dir := (e1 - e0).normalized()
		var e_perp := Vector3(-e_dir.z, 0, e_dir.x).normalized()
		var col_edge := col_base * (0.80 + float(ei % 2) * 0.08)
		_add_quad(st, em, e_perp * 0.025, e_dir * e0.distance_to(e1) * 0.5, Vector3(0, 1, 0), col_edge)

	# Thuỳ đáy — 2 quads ở phía gốc cuống (mặt sau)
	var ba := angle + PI
	var bw: float = r * 0.28
	var bh: float = r * 0.16
	var col_lobe := col_base * 0.80
	var lb := Vector3(cx + cos(ba - 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba - 0.3) * r * 0.45)
	var rb := Vector3(cx + cos(ba + 0.3) * r * 0.45, cy - d_cup * 0.5, cz + sin(ba + 0.3) * r * 0.45)
	_add_quad(st, lb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), angle), Vector3(0, 0, bh).rotated(Vector3(0,1,0), angle), Vector3(0, 1, 0), col_lobe)
	_add_quad(st, rb, Vector3(bw, 0, 0).rotated(Vector3(0,1,0), angle), Vector3(0, 0, bh).rotated(Vector3(0,1,0), angle), Vector3(0, 1, 0), col_lobe)

	# Gân chính — dày, rõ
	var ve := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, -r * 0.45).rotated(Vector3(0,1,0), angle)
	var vm := Vector3(cx, cy + 0.008, cz) + Vector3(0, 0, r * 0.20).rotated(Vector3(0,1,0), angle)
	_add_quad(st, (vm + ve) * 0.5, Vector3(0.018, 0, 0).rotated(Vector3(0,1,0), angle),
		Vector3(0, 0, vm.distance_to(ve) * 0.5).rotated(Vector3(0,1,0), angle),
		Vector3(0, 1, 0), col_vein)

	# Gân phụ — 4 nhánh
	s = s * 16807 + 1; var sr := float(s & 0x7FFFFFFF) / 2147483648.0
	for si in 4:
		var ga := angle + float(si) * PI / 4.0 + 0.3 + sr * 0.15
		var gv := Vector3(cx + cos(ga) * r * 0.18, cy + 0.005, cz + sin(ga) * r * 0.18)
		var ge := Vector3(cx + cos(ga) * r * 0.55, cy + 0.003, cz + sin(ga) * r * 0.55)
		_add_quad(st, (gv + ge) * 0.5, Vector3(0.006, 0, 0).rotated(Vector3(0,1,0), ga),
			Vector3(gv.distance_to(ge) * 0.5, 0, 0).rotated(Vector3(0,1,0), ga),
			Vector3(0, 1, 0), col_vein * 0.85)
	return s
