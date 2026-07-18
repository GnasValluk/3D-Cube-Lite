extends RefCounted

static func add_grass_cluster(st: SurfaceTool, cx: int, cz: int, size: int, vx: int, vz: int, pos: Vector3, h_vox: float) -> void:
	var wx: int = cx * size + vx
	var wz: int = cz * size + vz

	var pcx: int = (wx / 5) | 0
	var pcz: int = (wz / 5) | 0
	var ph: int = pcx * 374761393 + pcz * 668265263
	if ((ph ^ (ph >> 13)) * 1274126177) & 0xFF > 63:
		return

	var h: int = wx * 374761393 + wz * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	if ((h & 0x7F)) < 38:
		return

	var s: int = h
	var count: int = 1
	if (h & 0x7FFFFFFF) < 1073741824:
		count = 2

	for i in range(count):
		s = s * 16807 + 1
		var rx := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rz := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rt := float(s & 0x7FFFFFFF) / 2147483648.0
		s = s * 16807 + 1
		var rs := float(s & 0x7FFFFFFF) / 2147483648.0

		var ox: float = (rx - 0.5) * 0.7
		var oz: float = (rz - 0.5) * 0.7
		var leaf_count: int = 4 if rt > 0.65 else 3
		var stem_h: float = rs * 0.06 + 0.12
		var leaf_r: float = rs * 0.06 + 0.10
		var cv: float = rs * 0.10
		var col_stem := Color(0.10 + cv * 0.5, 0.38 + cv, 0.06 + cv * 0.3, 1.0)
		var col_leaf := Color(0.22 + cv, 0.58 + cv, 0.12 + cv * 0.5, 1.0)
		var col_light := Color(0.28 + cv, 0.68 + cv, 0.16 + cv * 0.5, 1.0)

		var cx_pos: float = pos.x + ox
		var cz_pos: float = pos.z + oz
		var cy_pos: float = pos.y + h_vox

		_add_quad(st, Vector3(cx_pos, cy_pos + stem_h * 0.5, cz_pos),
			Vector3(0.008, 0, 0), Vector3(0, stem_h * 0.5, 0), Vector3(0, 0, 1), col_stem)
		_add_quad(st, Vector3(cx_pos, cy_pos + stem_h * 0.5, cz_pos),
			Vector3(0, 0, 0.008), Vector3(0, stem_h * 0.5, 0), Vector3(1, 0, 0), col_stem)

		var top_y: float = cy_pos + stem_h
		var ba: float = rs * 0.5
		for li in range(leaf_count):
			var la: float = float(li) / float(leaf_count) * TAU + ba
			var lh_half: float = leaf_r * 0.40
			var lw: float = leaf_r * 0.22
			var lc: Vector3 = Vector3(cx_pos + cos(la) * leaf_r * 0.25, top_y, cz_pos + sin(la) * leaf_r * 0.25)
			_add_quad(st, lc, Vector3(cos(la) * lw, lh_half * 0.3, sin(la) * lw),
				Vector3(-sin(la) * lw * 0.5, lh_half * 0.7, cos(la) * lw * 0.5),
				Vector3(-sin(la) * 0.3, 1.0, cos(la) * 0.3).normalized(), col_light)
			_add_quad(st, lc, Vector3(cos(la) * lw, lh_half * 0.3, sin(la) * lw),
				Vector3(-sin(la) * lw * 0.5, -lh_half * 0.7, cos(la) * lw * 0.5),
				Vector3(sin(la) * 0.3, -1.0, -cos(la) * 0.3).normalized(), col_leaf)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)
