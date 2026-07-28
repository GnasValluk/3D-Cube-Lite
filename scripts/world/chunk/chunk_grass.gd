extends RefCounted

const GV: float = 0.025

const PATCH_SIZES := [
	Vector2i(20, 20),
	Vector2i(25, 13),
	Vector2i(12, 9),
	Vector2i(4, 6)
]

static func add_voxel_grass(vx: int, vz: int, pos: Vector3, out_xforms: Array, out_colors: Array) -> void:
	var wx := int(round(pos.x))
	var wz := int(round(pos.z))
	var cx := wx / 8
	var cz := wz / 8

	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var gx := cx + dx
			var gz := cz + dz
			var gh := gx * 374761393 + gz * 668265263
			gh = (gh ^ (gh >> 13)) * 1274126177

			if (gh & 0xFF) >= 1:
				continue

			var s := gh
			var idx := (s >> 8) & 0x3
			var pw: int = PATCH_SIZES[idx].x
			var ph: int = PATCH_SIZES[idx].y

			s = s * 16807 + 1
			var ox := s & 0x7
			s = s * 16807 + 1
			var oz := s & 0x7

			var pcx := gx * 8 + ox
			var pcz := gz * 8 + oz
			var hw: int = pw / 2
			var hh: int = ph / 2

			if wx < pcx - hw or wx >= pcx + hw or wz < pcz - hh or wz >= pcz + hh:
				continue

			var th := wx * 16807 + wz * 668265263 + gh
			th = (th ^ (th >> 13)) * 1274126177
			if (th & 0xFF) >= 89:
				return

			var size_class: int = (th >> 8) & 0x3
			var blade_count: int
			var spread_val: float = 0.22
			var height_scale: float = 1.1
			match size_class:
				0:
					blade_count = 30 + (th & 0x7F)
					spread_val = 0.22
					height_scale = 1.1
				1:
					blade_count = 55 + (th & 0xBF)
					spread_val = 0.28
					height_scale = 1.5
				2:
					blade_count = 90 + (th & 0xFF)
					spread_val = 0.34
					height_scale = 1.9
				3:
					blade_count = 140 + (th & 0xFF)
					spread_val = 0.40
					height_scale = 2.4

			var ts := th
			ts = ts * 16807 + 1
			var cx2: float = (float(ts & 0x7FFF) / 32768.0 - 0.5) * 0.4
			ts = ts * 16807 + 1
			var cz2: float = (float(ts & 0x7FFF) / 32768.0 - 0.5) * 0.4
			_add_clump(ts, Vector3(pos.x + cx2, pos.y, pos.z + cz2), blade_count, spread_val, height_scale, out_xforms, out_colors)
			return

static func _add_clump(s: int, offset: Vector3, blade_count: int, spread: float, height_scale: float, out_xforms: Array, out_colors: Array) -> void:
	var ss := s
	for i in range(blade_count):
		ss = ss * 16807 + 1
		var angle: float = float(ss & 0x7FFF) / 32768.0 * TAU
		ss = ss * 16807 + 1
		var radius: float = float(ss & 0x7FFF) / 32768.0 * spread
		ss = ss * 16807 + 1
		var voxel_count: int = 5 + (ss & 0x7)
		ss = ss * 16807 + 1
		var curve_angle: float = angle + (float(ss & 0x7FFF) / 32768.0 - 0.5) * 1.2
		ss = ss * 16807 + 1
		var cv := float(ss & 0xFF) / 256.0
		var base_col := Color(0.06 + cv * 0.12, 0.20 + cv * 0.25, 0.02 + cv * 0.06)

		var bx: float = offset.x + cos(angle) * radius
		var bz: float = offset.z + sin(angle) * radius

		for j in range(voxel_count):
			var t: float = float(j) / float(voxel_count - 1)
			ss = ss * 16807 + 1

			var curve: float = t * t * 0.035 * height_scale
			var cvx: float = cos(curve_angle) * curve
			var cvz: float = sin(curve_angle) * curve

			var vy: float = float(j) * GV * height_scale
			var taper: float = 1.0 - t * 0.35

			var col := base_col.lerp(Color(base_col.r + 0.18, base_col.g + 0.10, base_col.b * 0.7), t)
			var cv2 := float(ss & 0xFF) / 256.0
			col.r = clampf(col.r + (cv2 - 0.5) * 0.04, 0.0, 1.0)
			col.g = clampf(col.g + (cv2 - 0.5) * 0.04, 0.0, 1.0)
			col.b = clampf(col.b + (cv2 - 0.5) * 0.03, 0.0, 1.0)

			var voxel_scale: float = GV * taper * height_scale
			var b := Basis().scaled(Vector3.ONE * voxel_scale)
			out_xforms.append(Transform3D(b, Vector3(bx + cvx, offset.y + vy, bz + cvz)))
			out_colors.append(col)
