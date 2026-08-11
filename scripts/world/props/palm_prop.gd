class_name PalmProp
extends GrowingProp

enum PalmSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _CoconutMesh = preload("res://scripts/items/models/coconut.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "river"
var _size: int = PalmSize.MEDIUM
var _base_h: float = 2.5

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(variant: String = "river") -> void:
	_variant = variant
	var r := randf()
	if r < 0.10: _size = PalmSize.SMALL
	elif r < 0.35: _size = PalmSize.MEDIUM
	else: _size = PalmSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
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

func _birth_span_days() -> float:
	return 45.0

func _stage_thresholds() -> Array[float]:
	return [8.0, 25.0]

## CÃ¢y dá»«a khÃ´ng cÃ³ giai Ä‘oáº¡n vá»‹ thÃ nh niÃªn â€” máº§m xong lÃ  trÆ°á»Ÿng thÃ nh.
func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.1 + randf() * 0.6
	_sway_amp = deg_to_rad(2.4 + randf() * 1.0)

func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.5
	return _base_h

func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.MATURE: return
	var world := _find_world_manager()
	if world == null: return
	_ItemDatabase.ensure_db()
	var seed_def = _ItemDatabase.items_db.get("coconut_seed")
	if seed_def:
		_DroppedItem.spawn(world, seed_def, global_position, 1, _spawn_drop_velocity(), global_position.y)
	if randf() < 0.5: return
	var def = _ItemDatabase.items_db.get("coconut")
	if def:
		_DroppedItem.spawn(world, def, global_position, randi() % 2 + 1, _spawn_drop_velocity(), global_position.y)

func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_usec() * 0.000001
	var amp := _sway_amp
	if _stage == GrowingProp.Stage.SPROUT:
		amp *= 0.4
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.7 + _sway_phase * 1.3 + 0.7) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.7 + _sway_phase + 1.0) * 0.7 + cos(t * _sway_freq * 2.1 + _sway_phase + 2.2) * 0.3) * amp * 0.6

func _setup_collision() -> void:
	var h := _get_h()
	var br := _get_base_r()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = br + 0.15
	shape.height = h + 0.3
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

func _get_base_r() -> float:
	var r: float
	if _variant == "river":
		match _size:
			PalmSize.SMALL:  r = 0.30
			PalmSize.MEDIUM: r = 0.36
			PalmSize.TALL:   r = 0.44
			_: r = 0.36
	else:
		match _size:
			PalmSize.SMALL:  r = 0.18
			PalmSize.MEDIUM: r = 0.22
			PalmSize.TALL:   r = 0.26
			_: r = 0.22
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

func _get_top_r() -> float:
	var r: float
	if _variant == "river":
		match _size:
			PalmSize.SMALL:  r = 0.14
			PalmSize.MEDIUM: r = 0.16
			PalmSize.TALL:   r = 0.20
			_: r = 0.16
	else:
		match _size:
			PalmSize.SMALL:  r = 0.08
			PalmSize.MEDIUM: r = 0.10
			PalmSize.TALL:   r = 0.12
			_: r = 0.10
	return r

# â”€â”€ GRID helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

var _grid: Dictionary = {}       # key (int) â†’ Color
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
	_add_voxel(Vector3(px, py, pz), col * _DARKEN)

# â”€â”€ MAIN BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual()
		return

	var h: float = _get_h()
	var base_r: float = _get_base_r()
	var top_r: float = _get_top_r()

	_trunk_voxels(h, base_r, top_r)
	_frond_voxels(h, top_r)
	_commit_visual()
	if _stage == GrowingProp.Stage.MATURE:
		_commit_coconuts(h, top_r)

func _commit_visual() -> void:
	if _ordered.is_empty():
		return
	# 1 MultiMesh duy nháº¥t cho cáº£ cÃ¢y (thÃ¢n + tÃ u lÃ¡), scale khá»›p lÆ°á»›i 0.125 â€”
	# nhÃ¬n ngang khÃ´ng cÃ²n khe rá»—ng giá»¯a cÃ¡c cube. Máº§m dÃ¹ng cá»¡ má»‹n FINE_SCALE.
	var positions: Array = []
	var scales_pack: Array = []
	var colors_pack: Array = []
	var s := _VoxelShared.TRUNK_SCALE
	if _stage == GrowingProp.Stage.SPROUT:
		s = _VoxelShared.FINE_SCALE
	for i in range(_ordered.size()):
		positions.append(_ordered[i])
		scales_pack.append(s)
		colors_pack.append(_grid[_key(_ordered[i])])
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "PalmVisual"
	add_child(mmi)

func _apply_stage(_from: int, _to: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for i in range(get_child_count() - 1, -1, -1):
		var ch := get_child(i)
		if ch is MultiMeshInstance3D or ch is StaticBody3D:
			remove_child(ch)
			ch.queue_free()
	_build_tree()
	_setup_collision()
	_pop_growth()

## CÃ¢y dá»«a máº§m: chá»“i non nhá» vá»›i cÃ¡c lÃ¡ dáº¡ng lÆ°á»¡i kiáº¿m dá»±ng Ä‘á»©ng, chÆ°a cÃ³ thÃ¢n.
func _build_sprout() -> void:
	var is_river: bool = _variant == "river"
	var count: int = 6 + randi() % 2
	var crown := Vector3(0.0, 0.22, 0.0)
	var seed_a: float = randf() * TAU
	var col_stem := Color(0.35, 0.72, 0.15) if is_river else Color(0.42, 0.78, 0.18)
	var col_leaf := Color(0.30, 0.78, 0.16) if is_river else Color(0.38, 0.82, 0.20)
	var col_tip := Color(0.50, 0.88, 0.26) if is_river else Color(0.58, 0.90, 0.30)
	for fi in range(count):
		var angle_y: float = seed_a + float(fi) / float(count) * TAU
		var elevation: float = deg_to_rad(55.0 + randf() * 25.0)
		var frond_len: float = 0.38 + randf() * 0.30
		var droop: float = 0.06 + randf() * 0.06
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
				var up_pos := pos + up_dir * VOXEL * 1.6
				var lo_pos := pos + right * VOXEL * 1.2 - up_dir * VOXEL * 0.4
				_fill(up_pos.x, up_pos.y, up_pos.z, col_leaf)
				_fill(lo_pos.x, lo_pos.y, lo_pos.z, col_leaf.darkened(0.12))

# â”€â”€ TRUNK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _trunk_voxels(h: float, base_r: float, top_r: float) -> void:
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var is_river: bool = _variant == "river"
	var col_base := Color(0.62, 0.48, 0.28) if not is_river else Color(0.45, 0.28, 0.14)
	var col_dark := Color(0.48, 0.35, 0.18) if not is_river else Color(0.35, 0.20, 0.10)
	var col_scar := Color(0.50, 0.38, 0.20) if not is_river else Color(0.40, 0.25, 0.12)

	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * lv

		var curve_amp: float = 0.20 if not is_river else 0.06
		var curve_x := sin(t * PI * 0.7) * curve_amp * (1.0 - t * 0.4)
		var curve_z := cos(t * PI * 0.6) * curve_amp * 0.8 * (1.0 - t * 0.4)
		if t < 0.15:
			var f := t / 0.15
			curve_x *= f; curve_z *= f

		var r := lerpf(base_r, top_r, t)
		if t > 0.82:
			r *= 1.0 + (t - 0.82) / 0.18 * 0.20

		var is_scar: bool = vy % 2 == 0 and vy % 4 != 0
		var is_ring: bool = vy % 4 == 0
		if is_scar:
			r += lv * 0.3
		if is_ring:
			r += lv * 0.5

		var rv: int = ceili(r / lv)

		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv
				var dz := vz * lv
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

# â”€â”€ CROWN â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _crown_pos(h: float) -> Vector3:
	var is_river: bool = _variant == "river"
	var amp: float = 0.20 if not is_river else 0.06
	var curve_x := sin(PI * 0.7) * amp * 0.6
	var curve_z := cos(PI * 0.6) * amp * 0.8 * 0.6
	return Vector3(curve_x, h, curve_z)

# â”€â”€ FRONDS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _frond_voxels(h: float, _top_r: float) -> void:
	var is_river: bool = _variant == "river"
	var count: int = (8 + randi() % 4) if not is_river else (14 + randi() % 4)
	var crown := _crown_pos(h)
	var seed_a: float = randf() * TAU

	# NhÃ³m lÃ¡ non trong tÃ¡n trÆ°á»Ÿng thÃ nh: vÃ i lÃ¡ ngáº¯n dá»±ng cao, cÃ²n láº¡i lÃ 
	# lÃ¡ giÃ  dÃ i trÄ©u xuá»‘ng â€” tÃ¡n dá»«a lÃºc nÃ o cÅ©ng ráº­m Ä‘á»§ lá»›p.
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
				col_stem = Color(0.15, 0.82, 0.12)
				col_leaf = Color(0.08, 0.70, 0.06)
				col_tip = Color(0.22, 0.85, 0.14)
				droop = 0.08
			elif fi < young_n + int((count - young_n) * 0.65):
				elevation = deg_to_rad(-15.0 + randf() * 20.0)
				frond_len = 1.8 + randf() * 0.5
				col_stem = Color(0.08, 0.65, 0.05)
				col_leaf = Color(0.05, 0.58, 0.04)
				col_tip = Color(0.14, 0.72, 0.08)
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
				col_stem = Color(0.38, 0.82, 0.18)
				col_leaf = Color(0.30, 0.72, 0.15)
				col_tip = Color(0.45, 0.85, 0.22)
				droop = 0.03
			elif fi < young_n + int((count - young_n) * 0.5):
				elevation = deg_to_rad(-5.0 + randf() * 25.0)
				frond_len = 1.0 + randf() * 0.3
				col_stem = Color(0.22, 0.68, 0.12)
				col_leaf = Color(0.16, 0.58, 0.10)
				col_tip = Color(0.30, 0.74, 0.16)
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

		var steps: int = maxi(2, ceili(frond_len / (VOXEL * 2.0)))
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

# â”€â”€ COCONUTS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## Gáº¯n model quáº£ dá»«a chuáº©n (CoconutMesh.whole_data â€” elip + Ä‘Ã i hoa + 3 gá»)
## vÃ o chÃ²m lÃ¡ ngá»n: 2-4 quáº£ treo quanh tÃ¡n, phÃ¡t sÃ¡ng nháº¹. Má»™t MultiMesh
## duy nháº¥t cho má»i quáº£ (1 draw call), mÃ u vertex giá»¯ nguyÃªn chi tiáº¿t model.
func _commit_coconuts(h: float, top_r: float) -> void:
	var data: Array = _CoconutMesh.whole_data("green")
	if data.is_empty():
		return
	var positions: Array[Vector3] = []
	var crown := _crown_pos(h)
	var nut_count: int = 2 + randi() % 2
	for ni in range(nut_count):
		var a: float = float(ni) / float(nut_count) * TAU + randf() * 0.3
		var dist: float = top_r * 0.6 + randf() * 0.25
		var off_y: float = -0.10 - randf() * 0.15
		positions.append(crown + Vector3(cos(a) * dist, off_y, sin(a) * dist))

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.0
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(0.30, 0.65, 0.26) * 0.55
	mat.emission_energy_multiplier = 1.0
	cube.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = data.size() * positions.size()
	var pi := 0
	for p in positions:
		for d in data:
			var dp: Vector3 = d["pos"]
			var ds: Vector3 = d["size"]
			var scale := _CoconutMesh.V * 1.5
			var t := Transform3D(Basis.from_scale(ds * scale), dp * scale + p)
			mm.set_instance_transform(pi, t)
			mm.set_instance_color(pi, d["color"])
			pi += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "CoconutVisual"
	add_child(mmi)

# â”€â”€ HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _hit_flash() -> void:
	for name in ["PalmVisual", "CoconutVisual"]:
		var mmi := find_child(name, false, false) as MultiMeshInstance3D
		if mmi == null: continue
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
