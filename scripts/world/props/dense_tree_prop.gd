class_name DenseTreeProp
extends GrowingProp

## CÃ¢y rá»«ng ráº­m â€” 6-8 nhÃ¡nh chÃ­nh vÆ°Æ¡n xa + nhÃ¡nh con, tÃ¡n cá»±c um tÃ¹m vá»›i
## gradient nhiá»u sáº¯c xanh lÃ¡ Ä‘áº­m (rá»«ng tháº«m â†’ xanh tÆ°Æ¡i â†’ ngá»n sÃ¡ng). VÃ²ng
## Ä‘á»i: máº§m â†’ trÆ°á»Ÿng thÃ nh (khÃ´ng cÃ³ vá»‹ thÃ nh niÃªn).

enum DenseSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "plains"
var _size: int = DenseSize.MEDIUM
var _base_h: float = 4.0

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(variant: String = "plains") -> void:
	_variant = variant
	var r := randf()
	if r < 0.20: _size = DenseSize.SMALL
	elif r < 0.60: _size = DenseSize.MEDIUM
	else: _size = DenseSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
	match _size:
		DenseSize.SMALL:  return 3.0 + randf() * 0.5
		DenseSize.MEDIUM: return 3.9 + randf() * 0.6
		DenseSize.TALL:   return 4.8 + randf() * 0.7
	return 4.0

func _birth_span_days() -> float:
	return 55.0

func _stage_thresholds() -> Array[float]:
	return [10.0, 30.0]

## CÃ¢y rá»«ng ráº­m khÃ´ng cÃ³ giai Ä‘oáº¡n vá»‹ thÃ nh niÃªn â€” máº§m xong lÃ  trÆ°á»Ÿng thÃ nh.
func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 0.9 + randf() * 0.5
	_sway_amp = deg_to_rad(1.6 + randf() * 0.7)

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
	var def = _ItemDatabase.items_db.get("block_hard_wood")
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
	shape.radius = br + 0.20
	shape.height = h + 0.4
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

func _get_base_r() -> float:
	var r: float
	match _size:
		DenseSize.SMALL:  r = 0.26
		DenseSize.MEDIUM: r = 0.30
		DenseSize.TALL:   r = 0.34
		_: r = 0.30
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

func _get_top_r() -> float:
	var r: float
	match _size:
		DenseSize.SMALL:  r = 0.10
		DenseSize.MEDIUM: r = 0.12
		DenseSize.TALL:   r = 0.14
		_: r = 0.12
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

## Palette gradient xanh lÃ¡ Ä‘áº­m 6 sáº¯c: rá»«ng tháº«m â†’ xanh tÆ°Æ¡i â†’ ngá»n sÃ¡ng.
const _LEAF_TONES: Array[Color] = [
	Color(0.10, 0.26, 0.05),
	Color(0.13, 0.34, 0.07),
	Color(0.16, 0.42, 0.09),
	Color(0.20, 0.51, 0.12),
	Color(0.25, 0.60, 0.14),
	Color(0.33, 0.72, 0.18),
]

# â”€â”€ MAIN BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## TÃ¡ch voxel theo loáº¡i lÆ°á»›i khi build: thÃ¢n/cÃ nh lÆ°á»›i thÃ´, lÃ¡ lÆ°á»›i má»‹n.
var _leaf_cut: int = 0   # sá»‘ voxel Ä‘áº§u tiÃªn thuá»™c nhÃ³m lÃ¡ (sau index nÃ y)

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
	_canopy_voxels(h, branch_tips)

	_commit_visual()

func _commit_visual() -> void:
	if _ordered.is_empty():
		return
	# 1 MultiMesh duy nháº¥t: thÃ¢n/cÃ nh dÃ¹ng TRUNK_SCALE (che khe lÆ°á»›i 0.125),
	# lÃ¡ dÃ¹ng LEAF_SCALE (che khe lÆ°á»›i 0.1875) â€” nhÃ¬n ngang khÃ´ng lá»— rá»—ng.
	var positions: Array = []
	var scales_pack: Array = []
	var colors_pack: Array = []
	for i in range(_ordered.size()):
		positions.append(_ordered[i])
		scales_pack.append(_VoxelShared.LEAF_SCALE if i >= _leaf_cut else _VoxelShared.TRUNK_SCALE)
		colors_pack.append(_grid[_key(_ordered[i])])
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "DenseVisual"
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

## Máº§m cÃ¢y rá»«ng: chá»“i máº­p 2 lÃ¡ máº§m to.
func _build_sprout() -> void:
	var col_stem := Color(0.28, 0.20, 0.10)
	var col_leaf := Color(0.22, 0.54, 0.14)
	var col_tip := Color(0.34, 0.72, 0.18)
	for fy in range(4):
		_fill(0.0, fy * VOXEL, 0.0, col_stem.lerp(col_leaf, float(fy) / 4.0))
	for side in [1.0, -1.0]:
		var lean := Vector3(side * 0.20, 0.30, 0.0)
		for li in range(3):
			var t := float(li) / 2.0
			_fill(lean.x * t, lean.y + t * 0.10, lean.z, col_leaf.lerp(col_tip, t))
	_fill(0.0, 0.34, 0.0, col_tip)

# â”€â”€ TRUNK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _trunk_curve_offset(t: float) -> Vector2:
	var amp: float = 0.07
	var cx := sin(t * PI * 0.6) * amp * (1.0 - t * 0.3)
	var cz := cos(t * PI * 0.5) * amp * 0.7 * (1.0 - t * 0.3)
	if t < 0.15:
		var f := t / 0.15
		cx *= f; cz *= f
	return Vector2(cx, cz)

func _trunk_voxels(h: float, base_r: float, top_r: float) -> void:
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var col_base := Color(0.45, 0.32, 0.16)
	var col_dark := Color(0.34, 0.23, 0.10)
	var col_light := Color(0.56, 0.42, 0.22)

	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * lv
		var off := _trunk_curve_offset(t)

		var r := lerpf(base_r, top_r, t)
		if t > 0.80:
			r *= 1.0 + (t - 0.80) / 0.20 * 0.15

		var rv: int = ceili(r / lv)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv
				var dz := vz * lv
				var d_sq := dx * dx + dz * dz
				if d_sq <= r * r:
					var col := col_base
					var rr := randf()
					if rr < 0.20:
						col = col_dark
					elif rr < 0.32:
						col = col_light
					col = _jitter(col)
					_fill(off.x + dx, y, off.y + dz, col)

# â”€â”€ BRANCHES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## Há»‡ nhÃ¡nh: 6-8 nhÃ¡nh chÃ­nh vÆ°Æ¡n xa, má»—i nhÃ¡nh ráº½ thÃªm 1-2 nhÃ¡nh con â€”
## Ä‘áº§u má»i nhÃ¡nh Ä‘á»u cÃ³ chÃ¹m lÃ¡ â†’ tÃ¡n cá»±c ráº­m.
func _branch_voxels(h: float) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	var count: int = 6 + randi() % 3
	var col_main := Color(0.43, 0.30, 0.14)
	var col_sub := Color(0.36, 0.24, 0.11)

	for bi in range(count):
		var a := float(bi) / float(count) * TAU + randf() * 0.4
		var t_start := 0.35 + randf() * 0.35
		var sy := h * t_start
		var s_off := _trunk_curve_offset(t_start)
		var s := Vector3(s_off.x, sy, s_off.y)
		var len := (0.50 + randf() * 0.35) * h * 0.35
		var rise := 0.35 + randf() * 0.30
		var e := Vector3(s_off.x + cos(a) * len, sy + len * rise, s_off.y + sin(a) * len)
		var ctrl := s + (e - s) * 0.5 + Vector3(0.0, len * 0.20, 0.0)
		_draw_branch(s, ctrl, e, col_main)
		tips.append(e)

		var sub_count: int = 1 + randi() % 2
		for _s in range(sub_count):
			var st := 0.55 + randf() * 0.25
			var sub_start := _bezier(s, ctrl, e, st)
			var sub_ang: float = a + (randf() * 1.2 - 0.6)
			var sub_len := len * (0.35 + randf() * 0.20)
			var sub_rise := 0.5 + randf() * 0.4
			var sub_e := sub_start + Vector3(cos(sub_ang) * sub_len, sub_len * sub_rise, sin(sub_ang) * sub_len)
			var sub_ctrl := sub_start + (sub_e - sub_start) * 0.5 + Vector3(0.0, sub_len * 0.3, 0.0)
			_draw_branch(sub_start, sub_ctrl, sub_e, col_sub)
			tips.append(sub_e)
	return tips

func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)

func _draw_branch(p0: Vector3, p1: Vector3, p2: Vector3, col: Color) -> void:
	var steps := 10
	for si in range(1, steps + 1):
		var t := float(si) / float(steps)
		var p := _bezier(p0, p1, p2, t)
		_fill(p.x, p.y, p.z, col)
		if si == 1:
			for off in [[VOXEL, 0.0], [-VOXEL, 0.0], [0.0, VOXEL], [0.0, -VOXEL]]:
				_fill(p.x + off[0], p.y, p.z + off[1], col)

# â”€â”€ CANOPY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## TÃ¡n um tÃ¹m: 5-6 vÃ²ng cáº§u dáº¹p quanh chÃ³p vá»›i gradient nhiá»u sáº¯c xanh lÃ¡ Ä‘áº­m
## + chÃ¹m lÃ¡ to á»Ÿ Ä‘áº§u má»i nhÃ¡nh.
func _canopy_voxels(h: float, branch_tips: Array[Vector3]) -> void:
	var crown_off := _trunk_curve_offset(1.0)
	var crown := Vector3(crown_off.x, h, crown_off.y)

	# Gradient xanh lÃ¡ Ä‘áº­m: rá»«ng tháº«m dÆ°á»›i â†’ xanh tÆ°Æ¡i giá»¯a â†’ ngá»n sÃ¡ng.
	var rings: Array = [
		{"r": 0.95, "ry": 0.36, "dy": -0.40, "col": _LEAF_TONES[0]},
		{"r": 1.10, "ry": 0.40, "dy": -0.10, "col": _LEAF_TONES[1]},
		{"r": 0.98, "ry": 0.36, "dy": 0.22,  "col": _LEAF_TONES[2]},
		{"r": 0.72, "ry": 0.28, "dy": 0.55,  "col": _LEAF_TONES[3]},
		{"r": 0.48, "ry": 0.22, "dy": 0.80,  "col": _LEAF_TONES[4]},
	]

	for ring in rings:
		_leaf_ring(crown, ring.r, ring.ry, ring.dy, ring.col)

	for tip in branch_tips:
		var br := 0.32 + randf() * 0.16
		var bry := br * 0.72
		_leaf_ring(tip, br, bry, 0.0, _LEAF_TONES[2 + randi() % 3])

## VÃ²ng lÃ¡ ellipsoid trÃªn lÆ°á»›i voxel thÃ´ 0.1875 (3Ã— voxel thÃ¢n) â€” khá»‘i lÃ¡
## chunky kiá»ƒu Minecraft, dÃ y hÆ¡n lÆ°á»›i 0.25 Ä‘á»ƒ lÃ¡ khÃ´ng quÃ¡ thÆ°a.
func _leaf_ring(crown: Vector3, rx: float, ry: float, dy: float, col_base: Color) -> void:
	var lv := VOXEL * 3.0
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
					if rn < 0.14:
						col = col_base.darkened(0.22)
					elif rn < 0.34:
						col = col_base.lightened(0.10)
					elif rn < 0.55:
						col = _LEAF_TONES[randi() % _LEAF_TONES.size()]
					else:
						col = col_base.lerp(_LEAF_TONES[randi() % _LEAF_TONES.size()], 0.6)
					col = _jitter(col)
					_fill(crown.x + px, crown.y + dy + py, crown.z + pz, col)

# â”€â”€ HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _hit_flash() -> void:
	var mmi := find_child("DenseVisual", false, false) as MultiMeshInstance3D
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
