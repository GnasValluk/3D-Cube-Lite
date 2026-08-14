class_name OrangeTreeProp
extends GrowingProp

enum OrangeSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "plains"
var _size: int = OrangeSize.MEDIUM
var _base_h: float = 3.0

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(variant: String = "plains") -> void:
	_variant = variant
	var r := randf()
	if r < 0.15: _size = OrangeSize.SMALL
	elif r < 0.55: _size = OrangeSize.MEDIUM
	else: _size = OrangeSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
	var is_river: bool = _variant == "river"
	match _size:
		OrangeSize.SMALL:
			return (2.2 + randf() * 0.4) if not is_river else (2.0 + randf() * 0.4)
		OrangeSize.MEDIUM:
			return (2.9 + randf() * 0.5) if not is_river else (2.6 + randf() * 0.5)
		OrangeSize.TALL:
			return (3.6 + randf() * 0.6) if not is_river else (3.2 + randf() * 0.6)
	return 3.0

func _birth_span_days() -> float:
	return 45.0

func _stage_thresholds() -> Array[float]:
	return [8.0, 25.0]

## CÃ¢y cam khÃ´ng cÃ³ giai Ä‘oáº¡n vá»‹ thÃ nh niÃªn â€” máº§m xong lÃ  trÆ°á»Ÿng thÃ nh.
func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.0 + randf() * 0.5
	_sway_amp = deg_to_rad(1.8 + randf() * 0.8)

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
	var seed_def = _ItemDatabase.items_db.get("orange_seed")
	if seed_def:
		_DroppedItem.spawn(world, seed_def, global_position, 1, _spawn_drop_velocity(), global_position.y)
	if randf() < 0.5: return
	var def = _ItemDatabase.items_db.get("orange")
	if def:
		_DroppedItem.spawn(world, def, global_position, randi() % 2 + 1, _spawn_drop_velocity(), global_position.y)

func _process(delta: float) -> void:
	super._process(delta)
	if not _VoxelShared.sway_active(global_position, 60.0):
		return
	var t := _VoxelShared.time_sec()
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
	match _size:
		OrangeSize.SMALL:  r = 0.09
		OrangeSize.MEDIUM: r = 0.11
		OrangeSize.TALL:   r = 0.13
		_: r = 0.11
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

func _get_top_r() -> float:
	var r: float
	match _size:
		OrangeSize.SMALL:  r = 0.030
		OrangeSize.MEDIUM: r = 0.035
		OrangeSize.TALL:   r = 0.045
		_: r = 0.035
	return r

# â”€â”€ GRID helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

var _grid: Dictionary = {}
var _ordered: Array[Vector3] = []

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

func _jitter(col: Color) -> Color:
	var j := (randf() - 0.5) * 0.06
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

# â”€â”€ MAIN BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

var _leaf_cut: int = 0   # index Ä‘áº§u cá»§a nhÃ³m lÃ¡ (lÆ°á»›i 2Ã—VOXEL) â€” scale khÃ¡c thÃ¢n
var _fruit_cut: int = 0  # index Ä‘áº§u cá»§a nhÃ³m trÃ¡i (lÆ°á»›i má»‹n 1Ã—VOXEL)

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
	var branch_tips := _branch_voxels(h)
	_leaf_cut = _ordered.size()
	_canopy_voxels(h, top_r, branch_tips)
	_fruit_cut = _ordered.size()
	if _stage == GrowingProp.Stage.MATURE:
		_fruit_voxels(h)

	_commit_visual()

func _commit_visual() -> void:
	if _ordered.is_empty():
		return
	# TrÃ¡i dÃ¹ng cá»¡ má»‹n FINE_SCALE, lÃ¡ dÃ¹ng TRUNK_SCALE (che khe lÆ°á»›i 0.125),
	# thÃ¢n/cÃ nh dÃ¹ng FINE_SCALE â€” nhÃ¬n ngang khÃ´ng lá»— rá»—ng.
	var positions: Array = []
	var scales_pack: Array = []
	var colors_pack: Array = []
	for i in range(_ordered.size()):
		positions.append(_ordered[i])
		var s: float = _VoxelShared.FINE_SCALE
		if i >= _leaf_cut and i < _fruit_cut:
			s = _VoxelShared.TRUNK_SCALE
		scales_pack.append(s)
		colors_pack.append(_grid[_key(_ordered[i])])
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "OrangeVisual"
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

# â”€â”€ SPROUT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## Máº§m cam: chá»“i non 2 lÃ¡ máº§m xanh + vÃ i lÃ¡ bÃ©.
func _build_sprout() -> void:
	var col_stem := Color(0.34, 0.60, 0.18)
	var col_leaf := Color(0.30, 0.70, 0.16)
	var col_tip := Color(0.48, 0.86, 0.24)
	for fy in range(4):
		_fill(0.0, fy * VOXEL, 0.0, col_stem.lerp(col_leaf, float(fy) / 4.0))
	_fill(0.0, 0.24, 0.0, col_stem)
	for side in [1.0, -1.0]:
		var lean := Vector3(side * 0.18, 0.30, 0.0)
		for li in range(3):
			var t := float(li) / 2.0
			_fill(lean.x * t, lean.y + t * 0.10, lean.z, col_leaf.lerp(col_tip, t))
	_fill(0.0, 0.34, 0.0, col_tip)

# â”€â”€ TRUNK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _trunk_curve_offset(t: float) -> Vector2:
	var amp: float = 0.08 if _variant != "river" else 0.05
	var cx := sin(t * PI * 0.6) * amp * (1.0 - t * 0.3)
	var cz := cos(t * PI * 0.5) * amp * 0.7 * (1.0 - t * 0.3)
	if t < 0.15:
		var f := t / 0.15
		cx *= f; cz *= f
	return Vector2(cx, cz)

func _trunk_voxels(h: float, base_r: float, top_r: float) -> void:
	var ny: int = ceili(h / VOXEL)
	var is_river: bool = _variant == "river"
	var col_base := Color(0.55, 0.40, 0.20) if not is_river else Color(0.48, 0.30, 0.14)
	var col_dark := Color(0.42, 0.28, 0.13) if not is_river else Color(0.36, 0.22, 0.10)
	var col_light := Color(0.66, 0.50, 0.26) if not is_river else Color(0.58, 0.40, 0.20)

	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * VOXEL

		var off := _trunk_curve_offset(t)
		var curve_x := off.x
		var curve_z := off.y

		var r := lerpf(base_r, top_r, t)
		if t > 0.80:
			r *= 1.0 + (t - 0.80) / 0.20 * 0.15

		var rv: int = ceili(r / VOXEL)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * VOXEL
				var dz := vz * VOXEL
				var d_sq := dx * dx + dz * dz
				if d_sq <= r * r:
					var col := col_base
					var rr := randf()
					if rr < 0.18:
						col = col_dark
					elif rr < 0.30:
						col = col_light
					col = _jitter(col)
					_fill(curve_x + dx, y, curve_z + dz, col)

# â”€â”€ BRANCHES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## NhÃ¡nh thÃ¢n: 5-7 cÃ nh máº£nh (1 voxel) vÆ°Æ¡n tá»« thÃ¢n, cong dáº§n lÃªn.
## Tráº£ vá» máº£ng Ä‘áº§u nhÃ¡nh Ä‘á»ƒ Ä‘áº·t chÃ¹m lÃ¡.
func _branch_voxels(h: float) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	var branch_count: int = 5 + randi() % 3
	var is_river: bool = _variant == "river"
	var col_base := Color(0.52, 0.38, 0.19) if not is_river else Color(0.46, 0.29, 0.13)
	var col_dark := Color(0.40, 0.27, 0.12) if not is_river else Color(0.35, 0.21, 0.09)

	for bi in range(branch_count):
		var a: float = float(bi) / float(branch_count) * TAU + randf() * 0.5
		var t_start: float = 0.48 + randf() * 0.22
		var sy: float = h * t_start
		var s_off := _trunk_curve_offset(t_start)
		var s := Vector3(s_off.x, sy, s_off.y)
		var len: float = (0.42 + randf() * 0.34) * h * 0.30
		var rise: float = 0.30 + randf() * 0.30
		var e := Vector3(s_off.x + cos(a) * len, sy + len * rise, s_off.y + sin(a) * len)
		var ctrl := s + (e - s) * 0.5 + Vector3(0.0, len * 0.18, 0.0)
		var steps := 9
		for si in range(1, steps + 1):
			var tq := float(si) / float(steps)
			var p := s.lerp(ctrl, tq).lerp(ctrl.lerp(e, tq), tq)
			_fill(p.x, p.y, p.z, col_base if si < steps - 2 else col_dark)
		tips.append(e)
	return tips

# â”€â”€ CANOPY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _canopy_pos(h: float) -> Vector3:
	var amp: float = 0.08 if _variant != "river" else 0.05
	return Vector3(sin(PI * 0.6) * amp * 0.5, h, cos(PI * 0.5) * amp * 0.5 * 0.7)

## TÃ¡n cam: 3 vÃ²ng lÃ¡ cáº§u dáº¹p â€” vÃ²ng dÆ°á»›i rá»™ng xÃ²e, giá»¯a lá»›n nháº¥t, chÃ³p cá»¥m.
## Má»—i Ä‘áº§u nhÃ¡nh cÃ³ thÃªm 1 chÃ¹m lÃ¡ riÃªng â†’ tÃ¡n nhiá»u lá»›p hÆ¡n.
func _canopy_voxels(h: float, _top_r: float, branch_tips: Array[Vector3]) -> void:
	var crown := _canopy_pos(h)
	var is_river: bool = _variant == "river"

	var col_dark := Color(0.18, 0.50, 0.10) if not is_river else Color(0.22, 0.58, 0.12)
	var col_mid := Color(0.28, 0.64, 0.13) if not is_river else Color(0.34, 0.72, 0.16)
	var col_light := Color(0.40, 0.78, 0.17) if not is_river else Color(0.46, 0.86, 0.20)
	var col_tip := Color(0.52, 0.90, 0.24) if not is_river else Color(0.58, 0.95, 0.28)

	var rings: Array = [
		{"r": 0.55, "ry": 0.22, "dy": -0.18, "col": col_dark},
		{"r": 0.62, "ry": 0.26, "dy": 0.02, "col": col_mid},
		{"r": 0.46, "ry": 0.22, "dy": 0.24, "col": col_light},
		{"r": 0.26, "ry": 0.16, "dy": 0.44, "col": col_tip},
	]

	for ring in rings:
		_leaf_ring(crown, ring.r, ring.ry, ring.dy, ring.col)

	for tip in branch_tips:
		var br := 0.16 + randf() * 0.10
		_leaf_ring(tip, br, br * 0.70, 0.0, col_mid if randf() < 0.5 else col_light)

## VÃ²ng lÃ¡ ellipsoid trÃªn lÆ°á»›i voxel thÃ´ 0.125 (2Ã— voxel thÃ¢n) â€” khá»‘i lÃ¡
## chunky kiá»ƒu Minecraft, giáº£m 8Ã— sá»‘ voxel so vá»›i lÆ°á»›i má»‹n cÅ©.
func _leaf_ring(crown: Vector3, rx: float, ry: float, dy: float, col_base: Color) -> void:
	var lv := VOXEL * 2.0
	var br: int = ceili(maxf(rx, ry) / lv)
	var squash: float = 0.75 + randf() * 0.35
	for vx in range(-br, br + 1):
		for vy in range(-br, br + 1):
			for vz in range(-br, br + 1):
				var px := vx * lv
				var py := vy * lv
				var pz := vz * lv
				var dx := px / rx
				var dyq := py / ry
				var dz := pz / (rx * squash)
				if dx * dx + dyq * dyq + dz * dz <= 1.0:
					var rn := randf()
					var col := col_base
					if rn < 0.15:
						col = col_base.darkened(0.18)
					elif rn < 0.30:
						col = col_base.lightened(0.10)
					col = _jitter(col)
					_fill(crown.x + px, crown.y + dy + py, crown.z + pz, col)

# â”€â”€ ORANGES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## Quáº£ cam chÃ­n: 4-6 quáº£ trÃ²n cam rá»±c treo xÃ²e ra ngoÃ i mÃ©p tÃ¡n.
func _fruit_voxels(h: float) -> void:
	var fruit_count: int = 4 + randi() % 3
	var crown := _canopy_pos(h)
	var col_orange := Color(0.95, 0.55, 0.12)
	var col_light := Color(1.00, 0.72, 0.24)
	var col_dark := Color(0.78, 0.38, 0.08)
	var col_stem := Color(0.32, 0.42, 0.14)

	for fi in range(fruit_count):
		var a: float = float(fi) / float(fruit_count) * TAU + randf() * 0.4
		var dist: float = 0.64 + randf() * 0.18
		var off_y: float = -0.12 - randf() * 0.24

		var cx := crown.x + cos(a) * dist
		var cy := crown.y + off_y
		var cz := crown.z + sin(a) * dist

		var rx: float = 0.075 + randf() * 0.02
		var ry: float = 0.085 + randf() * 0.02

		var b := ceili(maxf(rx, ry) / VOXEL)
		for vx in range(-b, b + 1):
			for vy in range(-b, b + 1):
				for vz in range(-b, b + 1):
					var px := vx * VOXEL
					var py := vy * VOXEL
					var pz := vz * VOXEL
					var dx := px / rx
					var dy := py / ry
					var dz := pz / rx
					if dx * dx + dy * dy + dz * dz <= 1.0:
						var col := col_orange
						if dy > 0.4:
							col = col_light
						elif dy < -0.35:
							col = col_dark
						col = _jitter(col)
						_fill(cx + px, cy + py, cz + pz, col)

		# NÃºm quáº£ + vá»‡t lÃµm nhá»
		_fill(cx, cy + ry + VOXEL * 0.8, cz, col_stem)
		if fi % 2 == 0:
			_fill(cx + VOXEL, cy + VOXEL, cz + VOXEL, col_light.lightened(0.10))

# â”€â”€ HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _hit_flash() -> void:
	var mmi := find_child("OrangeVisual", false, false) as MultiMeshInstance3D
	if mmi == null: return
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
