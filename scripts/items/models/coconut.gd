class_name CoconutMesh

const V: float = 0.030

static func whole(parent: Node3D, variant: String = "green") -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3(1.5, 1.5, 1.5)
	parent.add_child(pivot)

	var green: Color = Color(0.18, 0.62, 0.25) if variant == "green" else Color(0.38, 0.25, 0.14)
	var green_light: Color = green.lightened(0.12)
	var green_dark: Color = green.darkened(0.12)
	var brown: Color = Color(0.42, 0.28, 0.15)
	var dark: Color = Color(0.28, 0.18, 0.10)
	var fiber: Color = Color(0.50, 0.35, 0.18)

	var rx: float = 3.2
	var ry: float = 4.0
	var rz: float = 3.2

	for vx in range(-ceili(rx), ceili(rx) + 1):
		for vy in range(-ceili(ry), ceili(ry) + 1):
			for vz in range(-ceili(rz), ceili(rz) + 1):
				var px := float(vx)
				var py := float(vy)
				var pz := float(vz)
				var dx := px / rx
				var dy := py / ry
				var dz := pz / rz
				if dy < 0: dy *= 1.0 + absf(dy) * 0.4
				var d := dx * dx + dy * dy + dz * dz
				if d > 1.0: continue

				var col: Color = green
				if variant == "green":
					if dy > 0.3:
						col = green.lerp(green_light, (dy - 0.3) / 0.7)
					elif dy < -0.2:
						col = green.lerp(brown, absf(dy) * 0.3)
				else:
					if dy > 0.3:
						col = green.lerp(green_light.lightened(0.05), (dy - 0.3) / 0.7)
					elif dy < -0.3:
						col = green.lerp(dark, absf(dy) * 0.4)

				var j := (vx * 374761393 + vy * 668265263 + vz * 1274126177)
				j = (j ^ (j >> 13)) * 1274126177
				j = j ^ (j >> 16)
				var jr := float(j & 0xFF) / 256.0
				col.r = clampf(col.r + (jr - 0.5) * 0.06, 0.0, 1.0)
				col.g = clampf(col.g + (jr - 0.5) * 0.06, 0.0, 1.0)
				col.b = clampf(col.b + (jr - 0.5) * 0.06, 0.0, 1.0)

				ItemMeshShared.add_cube(pivot, vx, vy, vz, 1.0, 1.0, 1.0, col)

	# Stem calyx (ngôi sao 3-4 cánh ở đỉnh)
	var stem_y := ceili(ry) + 1
	for ai in range(4):
		var a := float(ai) * TAU / 4.0
		for si in range(2):
			var sx := cos(a + float(si) * 0.3) * 1.2
			var sz := sin(a + float(si) * 0.3) * 1.2
			ItemMeshShared.add_cube(pivot, sx, stem_y, sz, 0.8, 0.5, 0.8, dark)
	ItemMeshShared.add_cube(pivot, 0, stem_y + 0.5, 0, 0.8, 0.6, 0.8, brown)

	# 3 đường gờ chạy dọc
	for ri in range(3):
		var ra := float(ri) * TAU / 3.0
		for vy2 in range(-ceili(ry) + 1, ceili(ry)):
			var tt := float(vy2 + ceili(ry)) / float(ceili(ry) * 2)
			var inset: float = 0.2 * (1.0 - absf(tt - 0.5) * 1.2)
			var gx := cos(ra) * (rx + inset)
			var gz := sin(ra) * (rz + inset)
			var gc := green_dark if variant == "green" else dark
			ItemMeshShared.add_cube(pivot, gx, vy2, gz, 0.6, 0.7, 0.6, gc)


static func half(parent: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3(1.5, 1.5, 1.5)
	parent.add_child(pivot)

	var outer_green := Color(0.18, 0.62, 0.25)
	var fiber_col := Color(0.55, 0.40, 0.22)
	var meat := Color(0.92, 0.88, 0.78)
	var meat_dark := Color(0.85, 0.78, 0.65)
	var hollow := Color(0.20, 0.12, 0.06)

	var rx: float = 3.2
	var ry: float = 2.0
	var rz: float = 3.2

	# Vỏ ngoài + xơ + cơm dừa
	for vx in range(-ceili(rx), ceili(rx) + 1):
		for vy in range(0, ceili(ry) + 1):
			for vz in range(-ceili(rz), ceili(rz) + 1):
				var px := float(vx)
				var py := float(vy)
				var pz := float(vz)
				var dx := px / rx
				var dy := py / ry
				var dz := pz / rz
				var d := dx * dx + dy * dy + dz * dz
				if d > 1.0: continue

				var col: Color
				var edge_dist := 1.0 - sqrt(d)
				if edge_dist < 0.15:
					col = outer_green.lerp(fiber_col, 1.0 - edge_dist / 0.15)
				elif edge_dist < 0.30:
					col = fiber_col.lerp(meat, (edge_dist - 0.15) / 0.15)
				elif edge_dist < 0.45:
					col = meat
				else:
					col = hollow

				var j := (vx * 374761393 + vy * 668265263 + vz * 1274126177)
				j = (j ^ (j >> 13)) * 1274126177
				j = j ^ (j >> 16)
				var jr := float(j & 0xFF) / 256.0
				col.r = clampf(col.r + (jr - 0.5) * 0.04, 0.0, 1.0)
				col.g = clampf(col.g + (jr - 0.5) * 0.04, 0.0, 1.0)
				col.b = clampf(col.b + (jr - 0.5) * 0.04, 0.0, 1.0)

				ItemMeshShared.add_cube(pivot, vx, vy, vz, 1.0, 1.0, 1.0, col)

	# Mép cắt — vụn cơm dừa
	for _s in range(6):
		var s := _s * 374761393 + 12345
		s = (s ^ (s >> 13)) * 1274126177
		var sr := float(s & 0xFF) / 256.0
		var sx := (sr - 0.5) * rx * 0.7
		s = s * 16807 + 1; var sz := (float(s & 0xFF) / 256.0 - 0.5) * rz * 0.7
		s = s * 16807 + 1; var sy := float(s & 0xFF) / 256.0 * 0.5
		ItemMeshShared.add_cube(pivot, sx, sy, sz, 0.5, 0.4, 0.5, meat_dark)

	# Vụn vỏ xanh
	for _s2 in range(4):
		var s2 := _s2 * 668265263 + 54321
		s2 = (s2 ^ (s2 >> 13)) * 1274126177
		var sr2 := float(s2 & 0xFF) / 256.0
		var sx2 := (sr2 - 0.5) * rx * 1.0
		s2 = s2 * 16807 + 1; var sz2 := (float(s2 & 0xFF) / 256.0 - 0.5) * rz * 1.0
		s2 = s2 * 16807 + 1; var sy2 := float(s2 & 0xFF) / 256.0 * 0.3
		ItemMeshShared.add_cube(pivot, sx2, sy2, sz2, 0.4, 0.3, 0.4, outer_green.darkened(0.15))


static func drink(parent: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.scale = Vector3(1.5, 1.5, 1.5)
	parent.add_child(pivot)

	var green := Color(0.18, 0.62, 0.25)
	var green_light := Color(0.30, 0.72, 0.32)
	var meat_col := Color(0.92, 0.88, 0.78)
	var water := Color(0.65, 0.82, 0.85, 0.70)
	var straw_red := Color(0.85, 0.15, 0.15)
	var straw_white := Color(0.92, 0.92, 0.92)
	var lemon := Color(0.95, 0.85, 0.10)
	var umbrella := Color(0.90, 0.30, 0.35)
	var umbrella_light := Color(0.95, 0.50, 0.55)

	var rx: float = 3.2
	var ry: float = 3.5
	var rz: float = 3.2

	# Thân dừa (cắt bỏ phần đỉnh)
	for vx in range(-ceili(rx), ceili(rx) + 1):
		for vy in range(-2, ceili(ry) - 1):
			for vz in range(-ceili(rz), ceili(rz) + 1):
				var px := float(vx)
				var py := float(vy)
				var pz := float(vz)
				var dx := px / rx
				var dy := py / ry
				var dz := pz / rz
				if dy < 0: dy *= 1.0 + absf(dy) * 0.4
				var d := dx * dx + dy * dy + dz * dz
				if d > 1.0: continue

				var col: Color = green
				if dy > 0.3:
					col = green.lerp(green_light, (dy - 0.3) / 0.7)
				elif dy < -0.2:
					col = col.lerp(Color(0.42, 0.28, 0.15), absf(dy) * 0.3)

				var j := (vx * 374761393 + vy * 668265263 + vz * 1274126177)
				j = (j ^ (j >> 13)) * 1274126177
				j = j ^ (j >> 16)
				var jr := float(j & 0xFF) / 256.0
				col.r = clampf(col.r + (jr - 0.5) * 0.06, 0.0, 1.0)
				col.g = clampf(col.g + (jr - 0.5) * 0.06, 0.0, 1.0)
				col.b = clampf(col.b + (jr - 0.5) * 0.06, 0.0, 1.0)

				ItemMeshShared.add_cube(pivot, vx, vy, vz, 1.0, 1.0, 1.0, col)

	# Phần đỉnh gọt — hình chóp nón 4 cạnh
	var top_y := ceili(ry) - 1
	for vx in range(-2, 3):
		for vz in range(-2, 3):
			var dist := maxf(absf(vx), absf(vz))
			if dist > 2: continue
			var h := 3 - dist
			for vy2 in range(h):
				ItemMeshShared.add_cube(pivot, vx, top_y + vy2, vz, 1.0, 1.0, 1.0, meat_col)

	# Viền cắt
	for vx in range(-3, 4):
		for vz in range(-3, 4):
			var dist := maxf(absf(vx), absf(vz))
			if dist > 2 and dist < 4:
				ItemMeshShared.add_cube(pivot, vx, top_y, vz, 1.0, 0.5, 1.0, green)

	# Lỗ tròn + nước dừa
	var hole_y := top_y + 3
	for vx in range(-1, 2):
		for vz in range(-1, 2):
			if absf(vx) == 1 and absf(vz) == 1: continue
			ItemMeshShared.add_cube(pivot, vx, hole_y, vz, 1.0, 0.4, 1.0, water)
			ItemMeshShared.add_cube(pivot, vx, hole_y + 0.5, vz, 0.6, 0.3, 0.6, water)

	# Ống hút sọc đỏ-trắng
	for sy2 in range(7):
		var sy_pos := hole_y + 0.5 + float(sy2) * 0.8
		var sc: Color = straw_red if sy2 % 2 == 0 else straw_white
		for sx2 in range(-1, 2):
			ItemMeshShared.add_cube(pivot, 1.0 + float(sx2) * 0.3, sy_pos, 1.0, 0.4, 0.6, 0.4, sc)
	for sy3 in range(5):
		var sy_pos2 := hole_y + 0.5 + float(sy3) * 0.8
		var sc2: Color = straw_red if sy3 % 2 == 0 else straw_white
		for sz2 in range(-1, 2):
			ItemMeshShared.add_cube(pivot, 1.0, sy_pos2, 1.0 + float(sz2) * 0.3, 0.4, 0.6, 0.4, sc2)

	# Ống hút nghiêng — đốt ống chéo
	var straw_dir := Vector3(0.8, 1.0, 0.8).normalized()
	var straw_len := 5.0
	for si in range(8):
		var t := float(si) / 8.0
		var sp := Vector3(1.0, hole_y + 0.5, 1.0) + straw_dir * t * straw_len
		var sc3: Color = straw_red if si % 2 == 0 else straw_white
		ItemMeshShared.add_cube(pivot, sp.x, sp.y, sp.z, 0.5, 0.8, 0.5, sc3)

	# Ô giấy nhỏ
	var umb_pos := Vector3(-2.5, hole_y + 2.0, -2.0)
	var umb_r := 2.0
	for ux in range(-ceili(umb_r), ceili(umb_r) + 1):
		for uz in range(-ceili(umb_r), ceili(umb_r) + 1):
			var ud := float(ux * ux + uz * uz)
			if ud > umb_r * umb_r: continue
			var uh := sqrt(umb_r * umb_r - ud) * 0.8
			var uc: Color = umbrella if (int(floor(ux + umb_r)) + int(floor(uz + umb_r))) % 2 == 0 else umbrella_light
			ItemMeshShared.add_cube(pivot, umb_pos.x + ux, umb_pos.y + uh, umb_pos.z + uz, 0.8, 0.8, 0.8, uc)

	# Lát chanh
	for lx in range(-3, 4):
		for ly in range(-1, 2):
			for lz in range(-3, 4):
				var ld := float(lx * lx + lz * lz)
				if ld > 9.0 or ld < 4.0: continue
				var lcol := Color(0.95, 0.85, 0.10) if absf(ly) < 1 else Color(0.90, 0.75, 0.08)
				var lpos := Vector3(-1.5, top_y + 1, -1.5)
				ItemMeshShared.add_cube(pivot, lpos.x + lx, lpos.y + ly, lpos.z + lz, 0.8, 0.6, 0.8, lcol)
