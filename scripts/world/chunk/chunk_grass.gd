extends RefCounted

const GV: float = 0.028

static func _noise(x: float, y: float) -> float:
	return sin(x * 0.0071 + y * 0.0053) * 0.40 \
		+ sin(x * 0.0043 - y * 0.0091 + 1.2) * 0.30 \
		+ sin(x * 0.0017 + y * 0.0037 + 3.8) * 0.20 \
		+ sin(x * 0.0109 + y * 0.0083 + 5.1) * 0.10

static func add_voxel_grass(vx: int, vz: int, pos: Vector3, out_xforms: Array, out_colors: Array, cols: int, height_grid: Array) -> void:
	var wx: int = int(round(pos.x))
	var wz: int = int(round(pos.z))

	var near_water: bool = false
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var nx := vx + dx
			var nz := vz + dz
			if nx < 0 or nx >= cols or nz < 0 or nz >= cols:
				continue
			if height_grid[nx][nz] <= 0.5:
				near_water = true
				break
		if near_water:
			break
	if not near_water:
		return

	var cx := wx / 12
	var cz := wz / 12

	var cell_n := _noise(float(cx * 12 + 6), float(cz * 12 + 6))
	if cell_n < -0.15:
		return

	var ox := _noise(float(cx * 50), float(cz * 50 + 999)) * 4.0
	var oz := _noise(float(cx * 50 + 777), float(cz * 50)) * 4.0
	var pcx := cx * 12 + 6 + int(round(ox))
	var pcz := cz * 12 + 6 + int(round(oz))

	var radius: float = 3.0 + (_noise(float(cx * 100 + 333), float(cz * 100 + 666)) * 0.5 + 0.5) * 3.0
	var rad2: float = radius * radius

	var dxb := wx - pcx
	var dzb := wz - pcz
	var dist2 := float(dxb * dxb + dzb * dzb)
	if dist2 >= rad2:
		return

	var edge_t: float = 1.0 - dist2 / rad2
	var fade: float = 1.0
	if edge_t < 0.2:
		fade = edge_t / 0.2
		if fade < 0.05:
			return

	var det := _noise(float(wx), float(wz))
	var det2 := _noise(float(wx + 888), float(wz + 999))

	var blade_count: int = int(5 + (det * 0.5 + 0.5) * 12)
	blade_count = int(blade_count * fade)
	if blade_count < 2:
		return

	var height_scale: float = 1.4 + (det * 0.5 + 0.5) * 1.4
	var spread_val: float = 0.20 + (det2 * 0.5 + 0.5) * 0.20

	var seed_val: int = wx * 1000 + wz * 371 + 5000
	_add_clump(seed_val, pos, blade_count, spread_val, height_scale, out_xforms, out_colors)

static func _add_clump(s: int, offset: Vector3, blade_count: int, spread: float, height_scale: float, out_xforms: Array, out_colors: Array) -> void:
	var ss := s
	for i in range(blade_count):
		ss = ss * 16807 + 1
		var angle: float = float(ss & 0x7FFF) / 32768.0 * TAU
		ss = ss * 16807 + 1
		var radius: float = float(ss & 0x7FFF) / 32768.0 * spread
		ss = ss * 16807 + 1
		var voxel_count: int = 4 + (ss & 0x3)
		ss = ss * 16807 + 1
		var curve_angle: float = angle + (float(ss & 0x7FFF) / 32768.0 - 0.5) * 1.2
		ss = ss * 16807 + 1
		var cv := float(ss & 0xFF) / 256.0
		var base_col := Color(0.06 + cv * 0.12, 0.20 + cv * 0.25, 0.02 + cv * 0.06)
		var mature: bool = (ss & 0x1) == 0

		var bx: float = offset.x + cos(angle) * radius
		var bz: float = offset.z + sin(angle) * radius

		for j in range(voxel_count):
			var t: float = float(j) / float(voxel_count - 1)
			ss = ss * 16807 + 1

			var curve: float = t * t * 0.032 * height_scale
			var cvx: float = cos(curve_angle) * curve
			var cvz: float = sin(curve_angle) * curve

			var vy: float = float(j) * GV * height_scale
			var taper: float = 1.0 - t * 0.35

			var pos_x := bx + cvx
			var pos_z := bz + cvz
			var pos_y := offset.y + vy

			var col: Color
			if mature and t > 0.65:
				var seed_t := (t - 0.65) / 0.35
				var gold := Color(0.85 + cv * 0.10, 0.72 + cv * 0.08, 0.10 + cv * 0.05)
				var green := Color(0.14 + cv * 0.12, 0.45 + cv * 0.15, 0.04 + cv * 0.06)
				col = green.lerp(gold, seed_t)
			else:
				col = base_col.lerp(Color(base_col.r + 0.18, base_col.g + 0.10, base_col.b * 0.7), t)
			var cv2 := float(ss & 0xFF) / 256.0
			col.r = clampf(col.r + (cv2 - 0.5) * 0.04, 0.0, 1.0)
			col.g = clampf(col.g + (cv2 - 0.5) * 0.04, 0.0, 1.0)
			col.b = clampf(col.b + (cv2 - 0.5) * 0.03, 0.0, 1.0)

			var voxel_scale: float = GV * taper * height_scale
			var b := Basis().scaled(Vector3.ONE * voxel_scale)
			out_xforms.append(Transform3D(b, Vector3(pos_x, pos_y, pos_z)))
			out_colors.append(col * 0.72)

		# (Bông lúa sẽ thêm sau)
