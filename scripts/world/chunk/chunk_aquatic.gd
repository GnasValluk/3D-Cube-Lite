extends RefCounted

const _Data = preload("chunk_data.gd")

static func add_aquatic_plants(st: SurfaceTool, cx: int, cz: int, size: int,
		vx: int, vz: int, pos: Vector3, h_vox: float, has_silt: bool,
		lotus_lights: Array[Vector3] = []) -> void:
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

	_add_tropical_weed(st, wx, wz, pos, r1, r2, r3, r4, h1, h2, water_gap, has_silt, lotus_lights)

	if has_silt:
		_add_lotus_plant(st, wx, wz, pos, r1, r2, r3, r4, h1, lotus_lights)

# ── Rong nước ngọt nhiệt đới (rong đuôi chó voxel) ──────────────────────────
static func _add_tropical_weed(st: SurfaceTool, wx: int, wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int, h2: int,
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

		# Hoa bên hông 25% mỗi đốt trừ đốt đáy
		if seg > 0:
			s = _draw_flower(st, s, cur_x, cur_z, cur_y, lean_x, lean_z, sw, lotus_lights)

		cur_x = nx; cur_z = nz; cur_y = ny

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

# Hoa nhỏ mọc bên hông đốt — 25% xác suất, nhiều màu nhiệt đới
static func _draw_flower(st: SurfaceTool, s: int, cur_x: float, cur_z: float, cur_y: float,
		lean_x: float, lean_z: float, sw: float, lotus_lights: Array[Vector3]) -> int:
	s = s * 16807 + 1
	if float(s & 0x7FFFFFFF) / 2147483648.0 >= 0.25:
		return s
	s = s * 16807 + 1; var fc1 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc2 := float(s & 0x7FFFFFFF) / 2147483648.0
	s = s * 16807 + 1; var fc3 := float(s & 0x7FFFFFFF) / 2147483648.0
	var fa: float = lean_x + lean_z + fc1 * TAU
	var fpos := Vector3(cur_x, cur_y + _Data.VOXEL * 0.6, cur_z) + Vector3(cos(fa), 0, sin(fa)) * (sw + 0.07)
	var col_f: Color
	if   fc2 < 0.17: col_f = Color(1.0,  0.20 + fc3*0.35, 0.08, 1.0)
	elif fc2 < 0.33: col_f = Color(1.0,  0.82 + fc3*0.12, 0.10, 1.0)
	elif fc2 < 0.50: col_f = Color(0.15, 0.88 + fc3*0.10, 0.28, 1.0)
	elif fc2 < 0.65: col_f = Color(0.08, 0.55 + fc3*0.25, 1.00, 1.0)
	elif fc2 < 0.80: col_f = Color(0.72 + fc3*0.22, 0.08, 1.00, 1.0)
	else:             col_f = Color(1.0,  0.28 + fc3*0.28, 0.68 + fc2*0.18, 1.0)
	var fp: float = 0.035 + fc3 * 0.022
	for fi in range(4):
		var faa: float = fa + float(fi) * PI * 0.5
		var fd := Vector3(cos(faa), 0, sin(faa))
		var fpperp := Vector3(-sin(faa), 0, cos(faa))
		_add_quad(st, fpos + fd*fp*0.5, fpperp*fp*0.45, Vector3(0,fp*0.65,0),  fd, col_f)
		_add_quad(st, fpos + fd*fp*0.5, fpperp*fp*0.45, Vector3(0,fp*0.65,0), -fd, col_f)
	var col_st := Color(1.0, 0.95, 0.15, 1.0)
	_add_quad(st, fpos + Vector3(0,fp*0.4,0), Vector3(fp*0.18,0,0), Vector3(0,fp*0.18,0), Vector3(0,0,1), col_st)
	_add_quad(st, fpos + Vector3(0,fp*0.4,0), Vector3(0,0,fp*0.18), Vector3(0,fp*0.18,0), Vector3(1,0,0), col_st)
	lotus_lights.append(Vector3(fpos.x + 500.0, fpos.y, fpos.z))
	return s

# ── Sen thạch anh ─────────────────────────────────────────────────────────────
static func _add_lotus_plant(st: SurfaceTool, wx: int, wz: int, pos: Vector3,
		r1: float, r2: float, r3: float, r4: float, h1: int,
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
	var lily_y: float = _Data.WATER_Y - 0.02
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
