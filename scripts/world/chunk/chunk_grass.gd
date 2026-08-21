extends RefCounted

const GV: float = 0.036
const _GRASS_CONST_INF: int = 999
const BLADE_SEGS := 7

static var _blade_mesh: ArrayMesh = null

## ── LÁ CỎ MỘT KHỐI CONG — theo kiểu LÁC ĐẦM LẦY ─────────────────────────────
## Dải lá DẸT RỘNG võng ra trước (arc bậc 2 về +Z), thon nhọn dần lên ngọn,
## gradient trộn sẵn trong vertex COLOR.rgb; COLOR.a = tỉ lệ cao cho sway.
## Màu ĐẶC TRƯNG từng lá nhân qua INSTANCE color. So với bản cũ: LÁ TO & BỤI
## DÀY HƠN (width scale + blade count tăng ở add_voxel_grass).
static func make_blade_mesh() -> ArrayMesh:
	if _blade_mesh != null:
		return _blade_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var y: float = t * (1.0 - 0.22 * t * t)          # võng nhẹ xuống đầu xa
		var arc: float = 0.62 * t * t                    # võng hẳn ra TRƯỚC (+Z)
		var hw: float = 0.50 * (1.0 - t * 0.72)          # gốc ±0.50 → ngọn ±0.14
		# Gradient: gốc xanh trầm → ngọn sáng vàng lúa
		var col := Color(
			0.40 + t * 0.55,
			0.50 + t * 0.46,
			0.26 + t * 0.24)
		lefts.append(Vector3(-hw, y, arc))
		rights.append(Vector3(hw, y, arc))
		cols.append(Color(col.r, col.g, col.b, t))
	for i in range(segs):
		var l0 := lefts[i]; var r0 := rights[i]
		var l1 := lefts[i + 1]; var r1 := rights[i + 1]
		var c0 := cols[i]; var c1 := cols[i + 1]
		# Mặt trước
		st.set_color(c0); st.add_vertex(l0)
		st.set_color(c0); st.add_vertex(r0)
		st.set_color(c1); st.add_vertex(l1)
		st.set_color(c0); st.add_vertex(r0)
		st.set_color(c1); st.add_vertex(r1)
		st.set_color(c1); st.add_vertex(l1)
		# Mặt sau (qu winding) — nhìn được cả 2 phía
		st.set_color(c0); st.add_vertex(r0)
		st.set_color(c0); st.add_vertex(l0)
		st.set_color(c1); st.add_vertex(r1)
		st.set_color(c0); st.add_vertex(l0)
		st.set_color(c1); st.add_vertex(l1)
		st.set_color(c1); st.add_vertex(r1)
	_blade_mesh = st.commit()
	return _blade_mesh

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

	# BỤI DÀY: nhiều lá hơn bản cũ (~60%) cho từng cụm cỏ lúa
	var blade_count: int = int(8 + (det * 0.5 + 0.5) * 20)
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
		var cv: float = float(ss & 0xFF) / 256.0
		ss = ss * 16807 + 1
		var curve_angle: float = angle + (float(ss & 0x7FFF) / 32768.0 - 0.5) * 1.2
		ss = ss * 16807 + 1
		var h_var: float = 0.78 + float(ss & 0xFF) / 256.0 * 0.45

		# Một lá = một instance cong; cao hơn cỏ lúa (nước 1.25-3.5)
		var hh: float = GV * 6.2 * height_scale * h_var
		var ww: float = hh * (0.26 + cv * 0.14)

		var bx: float = offset.x + cos(angle) * radius
		var bz: float = offset.z + sin(angle) * radius

		# Uốn cong mạnh hơn cỏ lúa — sóng nước đu đưa (xoay hướng cong riêng)
		var b := Basis().rotated(Vector3.UP, curve_angle + 0.6)
		b.x *= ww * 1.10
		b.y *= hh
		b.z *= ww
		out_xforms.append(Transform3D(b, Vector3(bx, offset.y, bz)))

		# Màu vùng nhân vào gradient lưới lá
		var col: Color
		if zone == 0:
			col = Color(0.92 + cv * 0.14, 0.52 + cv * 0.16, 1.22)              # tím biếc
		else:
			col = Color(0.48 + cv * 0.10, 1.10, 1.18)                          # xanh ngọc
		col.a = 1.0
		out_colors.append(col)

static func _add_clump(s: int, offset: Vector3, blade_count: int, spread: float, height_scale: float, out_xforms: Array, out_colors: Array) -> void:
	var ss := s
	for i in range(blade_count):
		ss = ss * 16807 + 1
		var angle: float = float(ss & 0x7FFF) / 32768.0 * TAU
		ss = ss * 16807 + 1
		var radius: float = float(ss & 0x7FFF) / 32768.0 * spread
		ss = ss * 16807 + 1
		var cv: float = float(ss & 0xFF) / 256.0
		ss = ss * 16807 + 1
		var curve_angle: float = angle + (float(ss & 0x7FFF) / 32768.0 - 0.5) * 1.2
		ss = ss * 16807 + 1
		var mature: bool = (ss & 0x1) == 0
		ss = ss * 16807 + 1
		var h_var: float = 0.78 + float(ss & 0xFF) / 256.0 * 0.45

		# Một lá = MỘT instance: CỌNG LÁ DÀY (rộng hơn cũ ~60%) như lác đầm lầy
		var hh: float = GV * 5.2 * height_scale * h_var
		var ww: float = hh * (0.48 + cv * 0.22)

		var bx: float = offset.x + cos(angle) * radius
		var bz: float = offset.z + sin(angle) * radius

		# Xoay hướng võng của lá + scale: y=cao, z=võng ra trước, x=rộng lá
		var b := Basis().rotated(Vector3.UP, curve_angle)
		b.x *= ww * 1.15
		b.y *= hh
		b.z *= ww
		out_xforms.append(Transform3D(b, Vector3(bx, offset.y, bz)))

		# Màu ĐẶC TRƯNG nhân vào gradient có sẵn trong lưới lá
		var col: Color
		if mature:
			col = Color(1.12 + cv * 0.10, 0.94 + cv * 0.08, 0.32 + cv * 0.10)   # vàng chín
		else:
			col = Color(0.34 + cv * 0.26, 1.02 + cv * 0.10, 0.28 + cv * 0.14)   # xanh lúa non
		col.a = 1.0
		out_colors.append(col)
