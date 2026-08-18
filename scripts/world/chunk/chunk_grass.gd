extends RefCounted

const GV: float = 0.036
const _GRASS_CONST_INF: int = 999

static func _noise(x: float, y: float) -> float:
	return sin(x * 0.0071 + y * 0.0053) * 0.40 \
		+ sin(x * 0.0043 - y * 0.0091 + 1.2) * 0.30 \
		+ sin(x * 0.0017 + y * 0.0037 + 3.8) * 0.20 \
		+ sin(x * 0.0109 + y * 0.0083 + 5.1) * 0.10

static func add_voxel_grass(vx: int, vz: int, pos: Vector3, out_xforms: Array, out_colors: Array, cols: int, wdist: PackedInt32Array, hdist: PackedInt32Array = PackedInt32Array()) -> void:
	var wx: int = int(round(pos.x))
	var wz: int = int(round(pos.z))

	# Cho phép 2 nguồn: gần nước (wdist≤3) hoặc chân núi/đồi (hdist≤2).
	var near_water: bool = wdist[vx * cols + vz] <= 3
	var hill_foot: bool = hdist.size() > 0 \
		and hdist[vx * cols + vz] != _GRASS_CONST_INF and hdist[vx * cols + vz] <= 2
	if not near_water and not hill_foot:
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

	var height_scale: float = 2.0 + (det * 0.5 + 0.5) * 1.8
	var spread_val: float = 0.20 + (det2 * 0.5 + 0.5) * 0.20

	var seed_val: int = wx * 1000 + wz * 371 + 5000
	_add_clump(seed_val, pos, blade_count, spread_val, height_scale, out_xforms, out_colors)

## ── Cỏ biển — copy cấu trúc cỏ lúa (cell 12×12 + clump), 2 loại màu ────────
## Tím và xanh dương mọc riêng từng vùng lớn (hàng trăm block) theo tọa độ
## thế giới — không trộn lẫn. Chỉ mọc ở đáy biển nông (OCEAN_DEEP, gap 1.25-3.5).

static func _sea_zone(wx: float, wz: float) -> int:
	var z: float = sin(wx * 0.0023 + 4.0) * 0.5 \
		+ sin(wz * 0.0027 - 3.0) * 0.5 + 0.5
	return 0 if z < 0.5 else 1  # 0 = vùng tím, 1 = vùng xanh dương

static func add_voxel_seagrass(vx: int, vz: int, pos: Vector3,
		out_xforms: Array, out_colors: Array, cols: int, water_gap: float,
		world_x: float, world_z: float) -> void:
	if water_gap < 1.25 or water_gap > 3.5:
		return
	var wx: int = int(round(pos.x))
	var wz: int = int(round(pos.z))

	var cx := wx / 12
	var cz := wz / 12

	var cell_n := _noise(float(cx * 12 + 6), float(cz * 12 + 6))
	if cell_n < -0.15:
		return

	# Thảm (meadow) theo patch hash 5×5 thế giới — giữ quy tắc cỏ biển cũ
	var ph: int = int(world_x / 5) * 73856093 + int(world_z / 5) * 19349663
	ph = (ph ^ (ph >> 13)) * 1274126177; ph = ph ^ (ph >> 16)
	var pr := float(ph & 0x7FFFFFFF) / 2147483648.0
	var in_meadow: bool = pr < 0.30
	# Ngoài thảm chỉ vài đám lẻ rất hiếm (≈ tỉ lệ cũ 0.006/0.18)
	if not in_meadow and _noise(float(wx) * 0.31, float(wz) * 0.27) > -0.94:
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

	var blade_count: int = int(8 + (det * 0.5 + 0.5) * 10)
	blade_count = int(blade_count * fade)
	if blade_count < 2:
		return

	# Vùng màu theo tọa độ thế giới của ô — cả cụm 1 màu
	var zone: int = _sea_zone(world_x, world_z)
	# Lá cao hơn cỏ lúa (nước 1.25-3.5 → ngọn không vượt mặt nước quá sâu)
	var height_scale: float = (1.6 + (det * 0.5 + 0.5) * 1.4) * 1.5 \
		* clampf(water_gap * 0.45, 0.6, 1.0)
	var spread_val: float = 0.20 + (det2 * 0.5 + 0.5) * 0.20

	var seed_val: int = wx * 1000 + wz * 371 + 5000
	_add_seagrass_clump(seed_val, pos, blade_count, spread_val, height_scale,
		zone, out_xforms, out_colors)

static func _add_seagrass_clump(s: int, offset: Vector3, blade_count: int,
		spread: float, height_scale: float, zone: int,
		out_xforms: Array, out_colors: Array) -> void:
	var ss := s
	for i in range(blade_count):
		ss = ss * 16807 + 1
		var angle: float = float(ss & 0x7FFF) / 32768.0 * TAU
		ss = ss * 16807 + 1
		var radius: float = float(ss & 0x7FFF) / 32768.0 * spread
		ss = ss * 16807 + 1
		var voxel_count: int = 5 + (ss & 0x3)
		ss = ss * 16807 + 1
		var curve_angle: float = angle + (float(ss & 0x7FFF) / 32768.0 - 0.5) * 1.2
		ss = ss * 16807 + 1
		var cv := float(ss & 0xFF) / 256.0
		var base_col: Color
		var tip_col: Color
		if zone == 0:
			# Vùng tím — tím biếc, hồng nhạt, tím đậm (nhiều sắc hơn cỏ lúa)
			base_col = Color(0.45 + cv * 0.25, 0.12 + cv * 0.22, 0.62 + cv * 0.28)
			tip_col = Color(0.80, 0.58, 0.95)
		else:
			# Vùng xanh dương — xanh biếc, xanh ngọc, lam (nhiều sắc hơn cỏ lúa)
			base_col = Color(0.06 + cv * 0.16, 0.42 + cv * 0.20, 0.62 + cv * 0.26)
			tip_col = Color(0.45, 0.92, 0.95)

		var bx: float = offset.x + cos(angle) * radius
		var bz: float = offset.z + sin(angle) * radius

		for j in range(voxel_count):
			var t: float = float(j) / float(voxel_count - 1)
			ss = ss * 16807 + 1

			# Uốn cong mạnh hơn cỏ lúa — sóng nước đu đưa
			var curve: float = t * t * 0.045 * height_scale
			var cvx: float = cos(curve_angle) * curve
			var cvz: float = sin(curve_angle) * curve

			var vy: float = float(j) * GV * height_scale
			var taper: float = 1.0 - t * 0.35

			var pos_x := bx + cvx
			var pos_z := bz + cvz
			var pos_y := offset.y + vy

			var col: Color
			if t > 0.60:
				col = base_col.lerp(tip_col, (t - 0.60) / 0.40 * 0.55)
			else:
				col = base_col.lerp(
					Color(minf(base_col.r * 1.4, 1.0), minf(base_col.g * 1.3, 1.0), minf(base_col.b * 1.15, 1.0)),
					t * 0.6)
			var cv2 := float(ss & 0xFF) / 256.0
			col.r = clampf(col.r + (cv2 - 0.5) * 0.05, 0.0, 1.0)
			col.g = clampf(col.g + (cv2 - 0.5) * 0.05, 0.0, 1.0)
			col.b = clampf(col.b + (cv2 - 0.5) * 0.04, 0.0, 1.0)

			var voxel_scale: float = GV * taper * height_scale
			var b := Basis().scaled(Vector3.ONE * voxel_scale)
			out_xforms.append(Transform3D(b, Vector3(pos_x, pos_y, pos_z)))
			var c := col * 0.72
			c.a = t  # chiều cao trong lá (0= gốc, 1= ngọn) → shader sway
			out_colors.append(c)

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
		var base_col := Color(0.03 + cv * 0.12, 0.34 + cv * 0.34, 0.02 + cv * 0.06)
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
				var green := Color(0.08 + cv * 0.12, 0.56 + cv * 0.20, 0.03 + cv * 0.06)
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
			var c := col * 0.88
			c.a = t  # chiều cao trong lá (0= gốc, 1= ngọn) → shader sway
			out_colors.append(c)

		# (Bông lúa sẽ thêm sau)
