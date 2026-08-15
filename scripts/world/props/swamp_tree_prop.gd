class_name SwampTreeProp
extends GrowingProp

## Cây tràm (rừng đầm lầy) — thân cao mảnh trắng xám (vỏ kiểu giấy), tán lá
## xanh ngả xám thưa như chổi. Mọc trên bùn đầm lầy ngập nước nông, gốc loe
## thành bạnh vè. Chặt trưởng thành rơi gỗ tràm + đôi khi mầm tràm.

const VOXEL: float = 0.0625
const _DARKEN: float = 0.70

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _base_h: float = 3.0
var _seed_a: float = 0.0

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(_variant: String = "marsh") -> void:
	_base_h = 3.4 + randf() * 2.2
	_seed_a = randf() * TAU

func _birth_span_days() -> float:
	return 70.0

func _stage_thresholds() -> Array[float]:
	return [10.0, 30.0]

func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 0.8 + randf() * 0.5
	_sway_amp = deg_to_rad(2.0 + randf() * 0.8)

func _process(delta: float) -> void:
	super._process(delta)
	if not _VoxelShared.sway_active(global_position, 60.0):
		return
	var t := _VoxelShared.time_sec()
	var amp := _sway_amp
	if _stage == GrowingProp.Stage.SPROUT:
		amp *= 0.4
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.6 + _sway_phase * 1.2 + 0.6) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.8 + _sway_phase + 1.1) * 0.7 + cos(t * _sway_freq * 2.0 + _sway_phase + 2.0) * 0.3) * amp * 0.7

func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.6
	return _base_h

func _get_base_r() -> float:
	var r: float = 0.24
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

func _get_top_r() -> float:
	return 0.08

func _setup_collision() -> void:
	var h := _get_h()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _get_base_r() + 0.15
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
	_trunk_voxels(h)
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
	mmi.name = "SwampTreeVisual"
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

## Mầm tràm: chồi nhỏ mảnh, vài lá non xanh tươi.
func _build_sprout() -> void:
	var lv := VOXEL * 2.0
	var col_stem := Color(0.58, 0.56, 0.50)
	var col_leaf := Color(0.16, 0.36, 0.18)
	for vy in range(4):
		var t := float(vy) / 4.0
		_fill(0.0, (float(vy) + 0.5) * lv * 0.5, 0.0, col_stem, _VoxelShared.FINE_SCALE)
	var crown := Vector3(0.0, 0.42, 0.0)
	for li in range(4):
		var a: float = _seed_a + float(li) / 4.0 * TAU
		var tip := crown + Vector3(cos(a) * 0.10, 0.10, sin(a) * 0.10)
		_draw_voxel_segment(crown, tip, col_leaf, 0.4, _VoxelShared.FINE_SCALE)

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

## Thân tràm: thẳng đứng, trắng xám, gốc loe thành bạnh vè trên mặt bùn.
func _trunk_voxels(h: float) -> void:
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var col_bark := Color(0.60, 0.59, 0.54)
	var col_bark_dark := Color(0.52, 0.50, 0.46)
	var col_flare := Color(0.46, 0.42, 0.36)
	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * lv
		var r := lerpf(_get_base_r(), _get_top_r(), t)
		# Bạnh vè ở gốc — loe rộng ngang mặt bùn
		if t < 0.18:
			r = lerpf(_get_base_r() * 1.5, _get_base_r(), t / 0.18)
		var rv: int = ceili(r / lv)
		var col_band: Color = col_bark_dark if vy % 2 == 0 else col_bark
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv
				var dz := vz * lv
				if dx * dx + dz * dz <= r * r:
					_fill(dx, y, dz, _jitter(col_band))

## Tán tràm: chùm chổi thưa xanh ngả xám trên ngọn, vài nhánh vươn đều.
func _canopy_voxels(h: float) -> void:
	var lv := VOXEL * 2.0
	var crown_y: float = h - 0.55
	var canopy_r: float = 1.15 + randf() * 0.6
	var canopy_h: float = 1.4 + randf() * 0.8
	var col_leaf := Color(0.13, 0.30, 0.15)
	var col_leaf_dark := Color(0.10, 0.22, 0.12)
	var col_leaf_gray := Color(0.24, 0.34, 0.20)
	var col_branch := Color(0.56, 0.54, 0.49)
	# Nhánh chính vươn từ thân ra mép tán
	for bi in range(4):
		var a: float = _seed_a + float(bi) / 4.0 * TAU + 0.4
		var from_p := Vector3(sin(a) * 0.10, h - 0.5, cos(a) * 0.10)
		var to_p := Vector3(sin(a) * (canopy_r * 0.7), crown_y + 0.15, cos(a) * (canopy_r * 0.7))
		_draw_voxel_segment(from_p, to_p, col_branch, 0.07)
	# Chùm lá hình chổi, các nhánh con chia nhỏ rìa tán
	var tip_positions: Array[Vector3] = []
	for bi in range(6):
		var a: float = _seed_a + float(bi) / 6.0 * TAU
		var pr: float = canopy_r * (0.55 + randf() * 0.45)
		tip_positions.append(Vector3(cos(a) * pr, crown_y + (randf() - 0.5) * canopy_h * 0.6, sin(a) * pr))
	for tp in tip_positions:
		for li in range(3):
			var a2: float = _seed_a + float(li) / 3.0 * TAU + tp.length() * 0.7
			var ptip := tp + Vector3(cos(a2) * 0.18, 0.28, sin(a2) * 0.18)
			var col: Color = col_leaf
			var r0 := randf()
			if r0 < 0.20:
				col = col_leaf_dark
			elif r0 > 0.80:
				col = col_leaf_gray
			_draw_voxel_segment(tp, ptip, _jitter(col), 0.12, _VoxelShared.LEAF_SCALE)

## Chặt trưởng thành → rơi gỗ tràm + đôi khi mầm tràm để trồng lại.
func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.MATURE:
		return
	var world := _find_world_manager()
	if world == null:
		return
	ItemDatabase.ensure_db()
	if randf() < 0.40:
		var seed_def: ItemDef = ItemDatabase.items_db.get("swamp_seed")
		if seed_def:
			DroppedItem.spawn(world, seed_def, global_position, 1, _spawn_drop_velocity(), global_position.y)
	if randf() < 0.55:
		var def: ItemDef = ItemDatabase.items_db.get("swamp_wood")
		if def:
			DroppedItem.spawn(world, def, global_position, randi() % 2 + 1, _spawn_drop_velocity(), global_position.y)

## Hit flash — MultiMeshInstance3D override như palm.
func _hit_flash() -> void:
	var mmi := find_child("SwampTreeVisual", false, false) as MultiMeshInstance3D
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