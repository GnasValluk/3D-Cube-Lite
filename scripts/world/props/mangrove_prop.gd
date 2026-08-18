class_name MangroveProp
extends GrowingProp

## Cây đước (rừng ngập mặn) — thân ngắn mảnh, rễ chùm (aerial prop roots)
## chống xuống lạch triều, tán lá rậm xanh đậm. Mọc trên bãi bùn ven biển,
## rễ thò xuống nước ngập quanh gốc. Chặt trưởng thành rơi gỗ đước + mầm.

const VOXEL: float = 0.0625
const _DARKEN: float = 0.70

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "coast"
var _base_h: float = 2.6
var _seed_a: float = 0.0

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(variant: String = "coast") -> void:
	_variant = variant
	_base_h = 3.2 + randf() * 1.8
	_seed_a = randf() * TAU

func _birth_span_days() -> float:
	return 60.0

func _stage_thresholds() -> Array[float]:
	return [10.0, 30.0]

func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.0 + randf() * 0.6
	_sway_amp = deg_to_rad(2.2 + randf() * 0.8)

func _process(delta: float) -> void:
	super._process(delta)
	if not _VoxelShared.sway_active(global_position, 60.0):
		return
	var t := _VoxelShared.time_sec()
	var amp := _sway_amp
	if _stage == GrowingProp.Stage.SPROUT:
		amp *= 0.4
	# Rung lắc tự nhiên: harmonic chính + harmonic phụ tần cao (gió giật).
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.7 + _sway_phase * 1.3 + 0.7) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.8 + _sway_phase + 1.0) * 0.7 + cos(t * _sway_freq * 2.1 + _sway_phase + 2.2) * 0.3) * amp * 0.75

func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.55
	return _base_h

func _get_base_r() -> float:
	var r: float = 0.30 if _variant == "coast" else 0.36
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

func _get_top_r() -> float:
	var r: float = 0.12 if _variant == "coast" else 0.15
	return r

func _setup_collision() -> void:
	var h := _get_h()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _get_base_r() + 0.18
	shape.height = h + 0.3
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

# ── GRID helpers ──────────────────────────────────────────────────────────────
var _grid: Dictionary = {}
var _ordered: Array[Vector3] = []
var _scales: Array[float] = []

func _key(v: Vector3) -> int:
	return int(round(v.x / VOXEL)) + int(round(v.y / VOXEL)) * 10000 + int(round(v.z / VOXEL)) * 100000000

func _pos(v: Vector3) -> Vector3:
	return Vector3(round(v.x / VOXEL) * VOXEL, round(v.y / VOXEL) * VOXEL, round(v.z / VOXEL) * VOXEL)

func _add_voxel(pos: Vector3, col: Color, scale: float = _VoxelShared.TRUNK_SCALE) -> void:
	var p := _pos(pos)
	var k := _key(p)
	if _grid.has(k):
		return
	_grid[k] = col
	_ordered.append(p)
	_scales.append(scale)

func _fill(px: float, py: float, pz: float, col: Color, scale: float = _VoxelShared.TRUNK_SCALE) -> void:
	_add_voxel(Vector3(px, py, pz), col * _DARKEN, scale)

func _fill_leaf(px: float, py: float, pz: float, col: Color) -> void:
	_add_voxel(Vector3(px, py, pz), col * _DARKEN, _VoxelShared.LEAF_SCALE)

func _jitter(col: Color) -> Color:
	var j := (randf() - 0.5) * 0.05
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

# ── BUILD ─────────────────────────────────────────────────────────────────────
func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()
	_scales.clear()
	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual()
		return
	var h: float = _get_h()
	_trunk_voxels(h, _get_base_r(), _get_top_r())
	_prop_root_voxels(h)
	_canopy_voxels(h)
	_commit_visual()

func _commit_visual() -> void:
	if _ordered.is_empty():
		return
	var positions: Array = []
	var scales_pack: Array = []
	var colors_pack: Array = []
	for i in range(_ordered.size()):
		positions.append(_ordered[i])
		scales_pack.append(_scales[i])
		colors_pack.append(_grid[_key(_ordered[i])])
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "MangroveVisual"
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

## Mầm đước: chồi nhỏ đứng — 2 lá mầm trụ + mầm nhọn dài (hypocotyl).
func _build_sprout() -> void:
	var lv := VOXEL * 2.0
	var col_stem := Color(0.30, 0.45, 0.18)
	var col_leaf := Color(0.06, 0.32, 0.12)
	var lean := 0.05 + randf() * 0.10
	var dir_x := cos(_seed_a) * lean
	var dir_z := sin(_seed_a) * lean
	var top_h: float = 0.45
	for vy in range(3):
		var t := float(vy) / 3.0
		var mid := Vector3(dir_x * t, (float(vy) + 0.5) * lv * 0.5, dir_z * t)
		_fill(mid.x, mid.y, mid.z, col_stem, _VoxelShared.FINE_SCALE)
	var crown := Vector3(dir_x, top_h, dir_z)
	for li in range(3):
		var a: float = _seed_a + float(li) / 3.0 * TAU
		var tip := crown + Vector3(cos(a) * 0.10, 0.12, sin(a) * 0.10)
		_draw_voxel_segment(crown, tip, col_leaf, 0.5, _VoxelShared.FINE_SCALE)

func _draw_voxel_segment(a: Vector3, b: Vector3, col: Color, r: float, scale: float = _VoxelShared.TRUNK_SCALE) -> void:
	var lv := VOXEL * 2.0
	var n := (b - a).length()
	var steps: int = maxi(2, ceili(n / lv))
	for si in range(steps + 1):
		var t := float(si) / float(steps)
		var p := a.lerp(b, t)
		var rr: float = r * (1.0 - t * 0.7)
		var rv: int = maxi(1, ceili(rr / lv))
		for vx in range(-rv, rv + 1):
			for vz in range(-rv, rv + 1):
				var dx := vx * lv
				var dz := vz * lv
				if dx * dx + dz * dz <= rr * rr:
					_fill(p.x + dx, p.y, p.z + dz, col, scale)

## Thân đước: hơi cong nhẹ, nhỏ dần, nâu sẫm. Rễ chùm chống từ gốc.
func _trunk_voxels(h: float, base_r: float, top_r: float) -> void:
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var col_base := Color(0.34, 0.22, 0.15)
	var col_dark := Color(0.24, 0.15, 0.10)
	var col_knob := Color(0.40, 0.28, 0.18)
	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * lv
		var curve_x := sin(t * PI * 0.5) * 0.10 * (1.0 - t * 0.5)
		var curve_z := cos(t * PI * 0.45) * 0.08 * (1.0 - t * 0.5)
		var r := lerpf(base_r, top_r, t)
		if t > 0.85:
			r *= 1.0 + (t - 0.85) / 0.15 * 0.15
		var is_knob: bool = vy % 3 == 1
		if is_knob:
			r += lv * 0.35
		var rv: int = ceili(r / lv)
		var col_band: Color = col_knob if is_knob else (col_dark if vy % 2 == 0 else col_base)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv
				var dz := vz * lv
				if dx * dx + dz * dz <= r * r:
					_fill(curve_x + dx, y, curve_z + dz, _jitter(col_band))

## Rễ chùm — 5-7 cọc chống từ gốc lan xuống dưới/nước, tạo "chân kiềng".
func _prop_root_voxels(h: float) -> void:
	var lv := VOXEL * 2.0
	var root_count: int = 5 + randi() % 3
	var col_root := Color(0.30, 0.24, 0.18)
	var col_root_dark := Color(0.22, 0.17, 0.12)
	for ri in range(root_count):
		var a: float = _seed_a + float(ri) / float(root_count) * TAU + (randf() - 0.5) * 0.25
		var reach: float = 0.75 + randf() * 0.65
		var drop: float = 1.1 + randf() * 1.5
		var base_p := Vector3(sin(a) * 0.18, 0.15 + randf() * 0.10, cos(a) * 0.18)
		var tip_p := Vector3(sin(a) * reach, -drop, cos(a) * reach)
		var ctrl := base_p.lerp(tip_p, 0.45) + Vector3.UP * 0.18
		var steps: int = maxi(4, ceili(drop * 2.0 / lv))
		for si in range(steps + 1):
			var t := float(si) / float(steps)
			var p: Vector3 = _quad_bezier(base_p, ctrl, tip_p, t)
			var rr: float = lerpf(0.10, 0.045, t)
			var rv: int = maxi(1, ceili(rr / lv))
			var col := col_root if si % 2 == 0 else col_root_dark
			for vx in range(-rv, rv + 1):
				for vz in range(-rv, rv + 1):
					var dx := vx * lv
					var dz := vz * lv
					if dx * dx + dz * dz <= rr * rr:
						_fill(p.x + dx, p.y, p.z + dz, col)

## Tán lá đước — cụm cầu dẹt rậm, xanh đậm bóng; vài cành nhỏ dưới tán.
func _canopy_voxels(h: float) -> void:
	var lv := VOXEL * 2.0
	var crown_y: float = h - 0.32
	var canopy_r: float = 1.45 + randf() * 0.85
	var canopy_h: float = 1.1 + randf() * 0.6
	var col_leaf := Color(0.05, 0.26, 0.10)
	var col_leaf_dark := Color(0.035, 0.19, 0.075)
	var col_leaf_light := Color(0.10, 0.34, 0.13)
	var col_branch := Color(0.30, 0.22, 0.15)
	# Cành nhỏ nối thân lên tán
	for bi in range(3):
		var a: float = _seed_a + float(bi) / 3.0 * TAU + 0.5
		var from_p := Vector3(sin(a) * 0.12, h - 0.35, cos(a) * 0.12)
		var to_p := Vector3(sin(a) * (canopy_r * 0.5), crown_y + 0.1, cos(a) * (canopy_r * 0.5))
		_draw_voxel_segment(from_p, to_p, col_branch, 0.09)
	# Cụm lá dẹt (elipsoid) nhiều lớp
	var n_seed: int = 6
	var rng := randf()
	var step_v := lv
	var vmax: int = ceili(canopy_h / step_v)
	for vy in range(-vmax, vmax + 1):
		var t: float = abs(float(vy) * step_v / canopy_h)
		var t2: float = clamp(1.0 - t * t, 0.0, 1.0)
		var rr: float = canopy_r * (0.55 + t2 * 0.45)
		var yr: float = crown_y + float(vy) * step_v * 0.6
		var rings: int = int(TAU / 0.35)
		for wi in range(rings):
			var a: float = float(wi) / float(rings) * TAU + _seed_a * 0.3
			var pr: float = rr * (0.5 + float((wi + (vy * 7)) % 3) / 3.0 * 0.55)
			var px := cos(a) * pr
			var pz := sin(a) * pr
			var col: Color = col_leaf
			var r0 := randf()
			if r0 < 0.18:
				col = col_leaf_dark
			elif r0 > 0.78:
				col = col_leaf_light
			_fill_leaf(px, yr, pz, _jitter(col))
	# Mầm đước (propagule) — quả mầm nhọn treo rìa tán
	if _stage == GrowingProp.Stage.MATURE and rng < 0.5:
		var pod_count: int = 3 + randi() % 3
		for pi in range(pod_count):
			var a: float = _seed_a + float(pi) / float(pod_count) * TAU
			var attach := Vector3(cos(a) * canopy_r * 0.60, crown_y - 0.05, sin(a) * canopy_r * 0.60)
			var tip := attach + Vector3(0, -0.75, 0)
			_draw_voxel_segment(attach, tip, Color(0.28, 0.35, 0.16), 0.07)

func _quad_bezier(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var it := 1.0 - t
	return a * (it * it) + c * (2.0 * it * t) + b * (t * t)

## Chặt trưởng thành → rơi gỗ đước + đôi khi mầm đước để trồng lại.
func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.MATURE:
		return
	var world := _find_world_manager()
	if world == null:
		return
	ItemDatabase.ensure_db()
	var seed_def: ItemDef = ItemDatabase.items_db.get("mangrove_seed")
	if seed_def:
		DroppedItem.spawn(world, seed_def, global_position, 1, _spawn_drop_velocity(), global_position.y)
	if randf() < 0.45:
		var def: ItemDef = ItemDatabase.items_db.get("log_mangrove")
		if def:
			DroppedItem.spawn(world, def, global_position, randi() % 2 + 1, _spawn_drop_velocity(), global_position.y)

## Hit flash — MultiMeshInstance3D override như palm.
func _hit_flash() -> void:
	var mmi := find_child("MangroveVisual", false, false) as MultiMeshInstance3D
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
