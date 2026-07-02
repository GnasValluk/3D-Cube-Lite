extends RefCounted

static func add_sand_gravel(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 374761393 + wz * 668265263 + 123456789
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 5915587277 + wz * 4276112413 + 987654321
	h2 = (h2 ^ (h2 >> 13)) * 104395303
	h2 = h2 ^ (h2 >> 16)
	var g := float(h2 & 0x7FFFFFFF) / 2147483648.0
	var mult: float = 2.0 if g > 0.55 else 1.0

	var base_chance: float = 0.10 * mult
	var base_chance2: float = 0.04 * mult
	var count: int = 0
	if r < base_chance: count = 1
	elif r < base_chance + base_chance2: count = 2
	var s: int = h
	for i in range(count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		var ox: float = (rx - 0.5) * 0.6
		var oz: float = (rz - 0.5) * 0.6
		var psize: float = rs * 0.06 + 0.03
		var col: Color = Color(0.50 + rs * 0.15, 0.48 + rs * 0.12, 0.45 + rs * 0.10, 1.0)
		var pc := pos + Vector3(ox, h_vox + 0.015, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func add_silt_detail(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 481652729 + wz * 924652741 + 556789123
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 312018923 + wz * 719234571 + 112233445
	h2 = (h2 ^ (h2 >> 13)) * 1074126173
	h2 = h2 ^ (h2 >> 16)
	var g := float(h2 & 0x7FFFFFFF) / 2147483648.0

	var count: int = 2
	if r < 0.45: count = 3
	elif r < 0.15: count = 4

	var s: int = h
	for i in range(count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		var ox: float = (rx - 0.5) * 0.75
		var oz: float = (rz - 0.5) * 0.75
		var br: float = 0.30 + rs * 0.12 + g * 0.08
		var bg_val: float = 0.22 + rs * 0.10 + g * 0.06
		var bb: float = 0.10 + rs * 0.06
		var col: Color = Color(br, bg_val, bb, 1.0)
		var psize: float = rs * 0.10 + 0.05
		var pc := pos + Vector3(ox, h_vox + 0.01, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func add_trail_detail(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 274761391 + wz * 568265261 + 345678901
	h = (h ^ (h >> 13)) * 1174126177
	h = h ^ (h >> 16)
	var r := float(h & 0x7FFFFFFF) / 2147483648.0

	var count: int = 0
	if r < 0.30: count = 1
	elif r < 0.50: count = 2
	elif r < 0.62: count = 3

	var h2: int = wx * 441761393 + wz * 778265263 + 234567891
	h2 = (h2 ^ (h2 >> 13)) * 1474126177
	h2 = h2 ^ (h2 >> 16)
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0

	var extra: int = 0
	if r2 < 0.15: extra = 1

	var s: int = h
	for i in range(count + extra):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rt := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.55
		var oz: float = (rz - 0.5) * 0.55
		var psize: float
		var dh: float
		var col: Color

		if rt < 0.40:
			psize = rs * 0.07 + 0.03
			dh = rs * 0.03 + 0.008
			var b: float = rs * 0.12 - 0.06
			col = Color(0.68 + b, 0.52 + b, 0.26 + b * 0.5, 1.0)
		elif rt < 0.70:
			psize = rs * 0.05 + 0.025
			dh = rs * 0.02 + 0.005
			col = Color(0.55 + rs * 0.15, 0.48 + rs * 0.12, 0.38 + rs * 0.08, 1.0)
		else:
			psize = rs * 0.10 + 0.05
			dh = rs * 0.025 + 0.005
			col = Color(0.60 + rs * 0.12, 0.50 + rs * 0.10, 0.30 + rs * 0.08, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.005 + dh, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func add_dirt_mounds(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz
	var h: int = wx * 874761391 + wz * 968265261 + 456789012
	h = (h ^ (h >> 13)) * 1374126177
	h = h ^ (h >> 16)
	var r1 := float(h & 0x7FFFFFFF) / 2147483648.0

	var h2: int = wx * 674761391 + wz * 868265261 + 556789012
	h2 = (h2 ^ (h2 >> 13)) * 1274126177
	h2 = h2 ^ (h2 >> 16)
	var r2 := float(h2 & 0x7FFFFFFF) / 2147483648.0

	var mound_count: int = 0
	if r1 < 0.04: mound_count = 1
	elif r1 < 0.06: mound_count = 2

	var gravel_count: int = 0
	if r2 < 0.08: gravel_count = 1

	var s: int = h
	for i in range(mound_count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rh := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.5
		var oz: float = (rz - 0.5) * 0.5
		var mound_size: float = rs * 0.10 + 0.06
		var dh: float = rh * 0.04 + 0.02
		var col: Color = Color(0.36 + rs * 0.12, 0.22 + rs * 0.10, 0.10 + rs * 0.06, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.005, oz)
		_add_quad(st, pc + Vector3(0, dh, 0), Vector3(mound_size, 0, 0), Vector3(0, 0, mound_size), Vector3(0, 1, 0), col)

	s = h2
	for i in range(gravel_count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.6
		var oz: float = (rz - 0.5) * 0.6
		var psize: float = rs * 0.05 + 0.025
		var col: Color = Color(0.45 + rs * 0.15, 0.42 + rs * 0.12, 0.38 + rs * 0.10, 1.0)

		var pc := pos + Vector3(ox, h_vox + 0.015, oz)
		_add_quad(st, pc, Vector3(psize, 0, 0), Vector3(0, 0, psize), Vector3(0, 1, 0), col)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
