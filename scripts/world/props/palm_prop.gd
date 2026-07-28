class_name PalmProp
extends DestroyableProp

enum PalmSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625

var _variant: String = "river"
var _size: int = PalmSize.MEDIUM

func setup(variant: String = "river") -> void:
	_variant = variant
	_size = [PalmSize.SMALL, PalmSize.MEDIUM, PalmSize.TALL].pick_random()

func _ready() -> void:
	super._ready()
	_build_tree()

func _get_h() -> float:
	if _variant == "river":
		match _size:
			PalmSize.SMALL:  return 2.5 + randf() * 0.5
			PalmSize.MEDIUM: return 3.5 + randf() * 0.8
			PalmSize.TALL:   return 5.0 + randf() * 1.0
	else:
		match _size:
			PalmSize.SMALL:  return 1.5 + randf() * 0.3
			PalmSize.MEDIUM: return 2.2 + randf() * 0.5
			PalmSize.TALL:   return 3.0 + randf() * 0.8
	return 2.5

func _get_base_r() -> float:
	if _variant == "river":
		match _size:
			PalmSize.SMALL:  return 0.30
			PalmSize.MEDIUM: return 0.36
			PalmSize.TALL:   return 0.44
		return 0.36
	else:
		match _size:
			PalmSize.SMALL:  return 0.18
			PalmSize.MEDIUM: return 0.22
			PalmSize.TALL:   return 0.26
		return 0.22

func _get_top_r() -> float:
	if _variant == "river":
		match _size:
			PalmSize.SMALL:  return 0.14
			PalmSize.MEDIUM: return 0.16
			PalmSize.TALL:   return 0.20
		return 0.16
	else:
		match _size:
			PalmSize.SMALL:  return 0.08
			PalmSize.MEDIUM: return 0.10
			PalmSize.TALL:   return 0.12
		return 0.10

# ── GRID helpers ────────────────────────────────────────────────────────────

var _grid: Dictionary = {}       # key (int) → Color
var _ordered: Array[Vector3] = []  # insertion order for MultiMesh

func _key(v: Vector3) -> int:
	return int(round(v.x / VOXEL)) + int(round(v.y / VOXEL)) * 10000 + int(round(v.z / VOXEL)) * 100000000

func _pos(v: Vector3) -> Vector3:
	return Vector3(round(v.x / VOXEL) * VOXEL, round(v.y / VOXEL) * VOXEL, round(v.z / VOXEL) * VOXEL)

func _add_voxel(pos: Vector3, col: Color) -> void:
	var p := _pos(pos)
	var k := _key(p)
	if _grid.has(k):
		return
	_grid[k] = col
	_ordered.append(p)

func _fill(px: float, py: float, pz: float, col: Color) -> void:
	_add_voxel(Vector3(px, py, pz), col)

# ── MAIN BUILD ──────────────────────────────────────────────────────────────

func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()

	var h: float = _get_h()
	var base_r: float = _get_base_r()
	var top_r: float = _get_top_r()

	_trunk_voxels(h, base_r, top_r)
	_frond_voxels(h, top_r)
	_coconut_voxels(h, top_r)

	if _ordered.is_empty():
		return

	var cube := BoxMesh.new()
	cube.size = Vector3(VOXEL, VOXEL, VOXEL)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.0
	mat.roughness = 0.85
	cube.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = _ordered.size()

	for i in range(_ordered.size()):
		mm.set_instance_transform(i, Transform3D.IDENTITY.translated(_ordered[i]))
		mm.set_instance_color(i, _grid[_key(_ordered[i])])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "PalmVisual"
	add_child(mmi)

# ── TRUNK ───────────────────────────────────────────────────────────────────

func _trunk_voxels(h: float, base_r: float, top_r: float) -> void:
	var ny: int = ceili(h / VOXEL)
	var is_river: bool = _variant == "river"
	var col_base := Color(0.62, 0.48, 0.28) if not is_river else Color(0.45, 0.28, 0.14)
	var col_dark := Color(0.48, 0.35, 0.18) if not is_river else Color(0.35, 0.20, 0.10)
	var col_scar := Color(0.50, 0.38, 0.20) if not is_river else Color(0.40, 0.25, 0.12)

	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * VOXEL

		var curve_amp: float = 0.20 if not is_river else 0.06
		var curve_x := sin(t * PI * 0.7) * curve_amp * (1.0 - t * 0.4)
		var curve_z := cos(t * PI * 0.6) * curve_amp * 0.8 * (1.0 - t * 0.4)
		if t < 0.15:
			var f := t / 0.15
			curve_x *= f; curve_z *= f

		var r := lerpf(base_r, top_r, t)
		if t > 0.82:
			r *= 1.0 + (t - 0.82) / 0.18 * 0.20

		var is_scar: bool = vy % 3 == 0 and vy % 9 != 0
		var is_ring: bool = vy % 9 == 0
		if is_scar:
			r += VOXEL * 0.4
		if is_ring:
			r += VOXEL * 0.6

		var rv: int = ceili(r / VOXEL)

		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * VOXEL
				var dz := vz * VOXEL
				var d_sq := dx * dx + dz * dz
				if d_sq <= r * r:
					var col := _trunk_color(t, is_scar, is_ring, col_base, col_dark, col_scar)
					_fill(curve_x + dx, y, curve_z + dz, col)

func _trunk_color(t: float, is_scar: bool, is_ring: bool, base: Color, dark: Color, scar: Color) -> Color:
	var col := base
	var r := randf()
	if r < 0.20:
		col = dark
	elif r < 0.30:
		col = scar
	elif r < 0.35 and t < 0.3 and randf() < 0.3:
		col = dark.lerp(Color(0.25, 0.50, 0.20), randf())
	if is_scar:
		col = dark.lerp(col, 0.5 + randf() * 0.3)
	if is_ring:
		col = scar.lerp(dark, randf())
	if _variant == "river":
		col = col.darkened(0.25).lerp(Color(0.30, 0.18, 0.08), 0.4)
	else:
		col = col.lerp(Color(0.70, 0.55, 0.30), 0.15)
	col = _jitter(col)
	return col

func _jitter(col: Color) -> Color:
	var j := (randf() - 0.5) * 0.06
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

# ── CROWN ───────────────────────────────────────────────────────────────────

func _crown_pos(h: float) -> Vector3:
	var is_river: bool = _variant == "river"
	var amp: float = 0.20 if not is_river else 0.06
	var curve_x := sin(PI * 0.7) * amp * 0.6
	var curve_z := cos(PI * 0.6) * amp * 0.8 * 0.6
	return Vector3(curve_x, h, curve_z)

# ── FRONDS ──────────────────────────────────────────────────────────────────

func _frond_voxels(h: float, _top_r: float) -> void:
	var is_river: bool = _variant == "river"
	var count: int = (8 + randi() % 4) if not is_river else (14 + randi() % 4)
	var crown := _crown_pos(h)
	var seed_a: float = randf() * TAU

	var young_n: int = maxi(1, count / 4)

	for fi in range(count):
		var is_young: bool = fi < young_n
		var angle_y: float
		if is_young:
			angle_y = seed_a + float(fi) / float(young_n) * TAU * 0.5
		else:
			angle_y = seed_a + float(fi - young_n) / float(count - young_n) * TAU

		var elevation: float
		var frond_len: float
		var col_stem: Color
		var col_leaf: Color
		var col_tip: Color
		var droop: float
		var leaf_width: float = 1.6 if is_river else 0.7

		if is_river:
			if is_young:
				elevation = deg_to_rad(45.0 + randf() * 20.0)
				frond_len = 1.2 + randf() * 0.5
				col_stem = Color(0.12, 0.72, 0.10)
				col_leaf = Color(0.06, 0.55, 0.04)
				col_tip = Color(0.18, 0.65, 0.10)
				droop = 0.08
			elif fi < young_n + int((count - young_n) * 0.65):
				elevation = deg_to_rad(-15.0 + randf() * 20.0)
				frond_len = 1.8 + randf() * 0.5
				col_stem = Color(0.05, 0.48, 0.03)
				col_leaf = Color(0.02, 0.38, 0.02)
				col_tip = Color(0.10, 0.50, 0.06)
				droop = 0.18
			else:
				elevation = deg_to_rad(15.0 + randf() * 20.0)
				frond_len = 1.4 + randf() * 0.4
				col_stem = Color(0.45, 0.32, 0.08)
				col_leaf = Color(0.38, 0.26, 0.06)
				col_tip = Color(0.50, 0.38, 0.10)
				droop = 0.30
		else:
			if is_young:
				elevation = deg_to_rad(60.0 + randf() * 20.0)
				frond_len = 0.6 + randf() * 0.2
				col_stem = Color(0.35, 0.75, 0.15)
				col_leaf = Color(0.28, 0.62, 0.12)
				col_tip = Color(0.45, 0.72, 0.18)
				droop = 0.03
			elif fi < young_n + int((count - young_n) * 0.5):
				elevation = deg_to_rad(-5.0 + randf() * 25.0)
				frond_len = 1.0 + randf() * 0.3
				col_stem = Color(0.20, 0.52, 0.10)
				col_leaf = Color(0.15, 0.42, 0.08)
				col_tip = Color(0.30, 0.55, 0.14)
				droop = 0.10
			else:
				elevation = deg_to_rad(30.0 + randf() * 20.0)
				frond_len = 0.7 + randf() * 0.3
				col_stem = Color(0.55, 0.42, 0.15)
				col_leaf = Color(0.50, 0.38, 0.12)
				col_tip = Color(0.62, 0.48, 0.18)
				droop = 0.22

		var dir := Vector3(sin(angle_y) * cos(elevation), sin(elevation), cos(angle_y) * cos(elevation))
		var right := dir.cross(Vector3.UP).normalized()
		if right.length() < 0.001:
			right = Vector3.RIGHT
		var up_dir := right.cross(dir).normalized()

		var steps: int = maxi(2, ceili(frond_len / VOXEL))
		for si in range(steps + 1):
			var lt: float = float(si) / float(steps)
			var pos := crown + dir * lt * frond_len
			pos.y -= lt * lt * frond_len * droop

			var col := col_stem
			if lt < 0.5:
				col = col_stem.lerp(col_leaf, lt / 0.5)
			else:
				col = col_leaf.lerp(col_tip, (lt - 0.5) / 0.5)
			col = _jitter(col)
			_fill(pos.x, pos.y, pos.z, col)

			if si > 0 and si < steps - 1:
				var leaf_count: int = 2 + randi() % 2
				for side_sign in [1.0, -1.0]:
					var side_f: float = side_sign
					var up_lf: Vector3 = (right * side_f * 0.45 * leaf_width + up_dir * 0.55).normalized()
					var lo_lf: Vector3 = (right * side_f * 0.65 * leaf_width + up_dir * -0.15).normalized()
					for li in range(1, leaf_count + 1):
						var dist: float = li * VOXEL * 2.0 * leaf_width
						var lup: Vector3 = pos + up_lf * dist
						var llo: Vector3 = pos + lo_lf * dist * 0.8
						var base_col := col_leaf
						if lt > 0.5:
							base_col = base_col.lerp(Color(0.55, 0.45, 0.12), (lt - 0.5) / 0.5)
						var col_up := base_col
						var col_lo := base_col.darkened(0.12)
						col_up = _jitter(col_up)
						col_lo = _jitter(col_lo)
						_fill(lup.x, lup.y, lup.z, col_up)
						_fill(llo.x, llo.y, llo.z, col_lo)

# ── COCONUTS ────────────────────────────────────────────────────────────────

func _coconut_voxels(h: float, top_r: float) -> void:
	var nut_count: int = 2 + randi() % 2
	var crown := _crown_pos(h)
	var col_green := Color(0.25, 0.55, 0.20)
	var col_light := Color(0.40, 0.70, 0.30)
	var col_brown := Color(0.40, 0.28, 0.15)
	var col_fiber := Color(0.50, 0.35, 0.18)

	for ni in range(nut_count):
		var a: float = float(ni) / float(nut_count) * TAU + randf() * 0.3
		var dist: float = top_r * 0.6 + randf() * 0.25
		var off_y: float = -0.1 - randf() * 0.15

		var cx := crown.x + cos(a) * dist
		var cy := crown.y + off_y
		var cz := crown.z + sin(a) * dist

		var rx: float = 0.07 + randf() * 0.02
		var ry: float = 0.09 + randf() * 0.03
		var rz: float = 0.07 + randf() * 0.02

		var b := ceili(maxf(rx, maxf(ry, rz)) / VOXEL)
		for vx in range(-b, b + 1):
			for vy in range(-b, b + 1):
				for vz in range(-b, b + 1):
					var px := vx * VOXEL
					var py := vy * VOXEL
					var pz := vz * VOXEL
					var dx := px / rx
					var dy := py / ry
					var dz := pz / rz
					if dy < 0:
						dy *= 1.0 + absf(dy) * 0.6
					if dx * dx + dy * dy + dz * dz <= 1.0:
						var col := col_green
						if dy > 0.5:
							col = col_green.lerp(col_light, (dy - 0.5) * 2.0)
						elif dy < -0.3:
							col = col_green.lerp(col_brown, absf(dy) * 0.5)
						col = _jitter(col)
						_fill(cx + px, cy + py, cz + pz, col)

		# Coir fibres (mo dừa)
		var fiber_count: int = 3 + randi() % 4
		for _fi in range(fiber_count):
			var fa: float = randf() * TAU
			var fd: float = 0.10 + randf() * 0.08
			var fy: float = -0.04 + randf() * 0.08
			var col := col_fiber
			if randf() < 0.3:
				col = col_fiber.darkened(0.3)
			col = _jitter(col)
			_fill(cx + cos(fa) * fd, cy + fy, cz + sin(fa) * fd, col)

# ── HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) ───────────

func _hit_flash() -> void:
	var mmi := find_child("PalmVisual", false, false) as MultiMeshInstance3D
	if mmi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var orig := mmi.material_override
	mmi.material_override = mat
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func():
		if is_instance_valid(mmi):
			mmi.material_override = orig
	)

func _get_mesh_instances() -> Array[MeshInstance3D]:
	return []
