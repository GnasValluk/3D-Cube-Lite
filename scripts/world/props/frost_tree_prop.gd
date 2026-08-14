class_name FrostTreeProp
extends GrowingProp

## Cây vân sam (thông tuyết) bio băng giá — thân thẳng vuốt nhọn, vài tầng
## tán hình nón xếp chồng, lá xanh lam nhạt phủ tuyết trắng đốm. Vòng đời:
## mầm → trưởng thành (không có giai đoạn vị thành niên). Chặt cho Gỗ Vân Sam.

enum SpruceSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "snow"
var _size: int = SpruceSize.MEDIUM
var _base_h: float = 3.6

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

func setup(variant: String = "snow") -> void:
	_variant = variant
	var r := randf()
	if r < 0.20: _size = SpruceSize.SMALL
	elif r < 0.65: _size = SpruceSize.MEDIUM
	else: _size = SpruceSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
	match _size:
		SpruceSize.SMALL:  return 2.6 + randf() * 0.5
		SpruceSize.MEDIUM: return 3.4 + randf() * 0.6
		SpruceSize.TALL:   return 4.3 + randf() * 0.7
	return 3.6

func _birth_span_days() -> float:
	return 55.0

func _stage_thresholds() -> Array[float]:
	return [10.0, 30.0]

func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 0.8 + randf() * 0.4
	_sway_amp = deg_to_rad(1.2 + randf() * 0.5)

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
	var def = _ItemDatabase.items_db.get("spruce_wood")
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
	shape.radius = br + 0.18
	shape.height = h + 0.4
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

func _get_base_r() -> float:
	var r: float
	match _size:
		SpruceSize.SMALL:  r = 0.20
		SpruceSize.MEDIUM: r = 0.23
		SpruceSize.TALL:   r = 0.26
		_: r = 0.23
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	return r

# ── GRID helpers ────────────────────────────────────────────────────────────

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

## Palette lá vân sam: xanh lam nhạt → ngả tuyết trắng trên ngọn.
const _LEAF_TONES: Array[Color] = [
	Color(0.26, 0.40, 0.38),
	Color(0.34, 0.52, 0.47),
	Color(0.44, 0.64, 0.56),
	Color(0.56, 0.74, 0.66),
	Color(0.72, 0.84, 0.80),
]
const _SNOW_TONE: Color = Color(0.92, 0.95, 0.98)

# ── MAIN BUILD ──────────────────────────────────────────────────────────────

func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual()
		return

	var h: float = _get_h()
	var base_r: float = _get_base_r()

	_trunk_voxels(h, base_r)
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
		scales_pack.append(_VoxelShared.LEAF_SCALE)
		colors_pack.append(_grid[_key(_ordered[i])])
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "FrostVisual"
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

# ── SPROUT ──────────────────────────────────────────────────────────────────

## Mầm vân sam: chồi mập 2 lá mầm tròn xanh tuyết.
func _build_sprout() -> void:
	var col_stem := Color(0.32, 0.24, 0.14)
	var col_leaf := Color(0.44, 0.62, 0.55)
	for fy in range(4):
		_fill(0.0, fy * VOXEL, 0.0, col_stem.lerp(col_leaf, float(fy) / 4.0))
	for side in [1.0, -1.0]:
		var lean := Vector3(side * 0.18, 0.30, 0.0)
		for li in range(3):
			var t := float(li) / 2.0
			_fill(lean.x * t, lean.y + t * 0.10, lean.z, col_leaf.lerp(_SNOW_TONE, t))
	_fill(0.0, 0.34, 0.0, _SNOW_TONE)

# ── TRUNK ───────────────────────────────────────────────────────────────────

func _trunk_voxels(h: float, base_r: float) -> void:
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var col_base := Color(0.40, 0.26, 0.13)
	var col_dark := Color(0.28, 0.17, 0.08)
	var col_light := Color(0.52, 0.38, 0.24)

	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y: float = vy * lv
		var r := lerpf(base_r, base_r * 0.35, t)
		var rv: int = ceili(r / lv)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv
				var dz := vz * lv
				if (dx * dx + dz * dz) <= r * r:
					var rr := randf()
					var col := col_base
					if rr < 0.20:
						col = col_dark
					elif rr < 0.32:
						col = col_light
					_fill(dx, y, dz, col)

# ── CANOPY ──────────────────────────────────────────────────────────────────

## Tán vân sam: vài tầng nón xếp chồng (rộng dưới, thu hẹp lên đỉnh), lá
## xanh lam nhạt → ngả trắng tuyết theo độ cao, đỉnh phủ tuyết trắng.
func _canopy_voxels(h: float) -> void:
	var lv := VOXEL * 2.0
	var tiers: int = 3 + randi() % 2
	var max_r: float = h * 0.30
	var top_y: float = h
	var base_y: float = h * 0.42
	for ti in range(tiers):
		var t0 := float(ti) / float(tiers)
		var t1 := float(ti + 1) / float(tiers)
		var y0 := lerpf(base_y, top_y, t0)
		var y1 := lerpf(base_y, top_y, t1)
		var r0 := lerpf(max_r, 0.0, t0)
		var r1 := lerpf(max_r, 0.0, t1)
		var n: int = maxi(2, ceili((y1 - y0) / lv))
		for k in range(n):
			var kt := float(k) / float(n)
			var y := y0 + (y1 - y0) * kt
			var r := maxf(r0 + (r1 - r0) * kt, lv * 0.6)
			var up := clampf((y - base_y) / maxf(top_y - base_y, 0.001), 0.0, 1.0)
			var tone_i: int = clampi(int(up * float(_LEAF_TONES.size())), 0, _LEAF_TONES.size() - 1)
			_canopy_disc(y, r, lv, tone_i)
	_fill(0.0, top_y + lv * 0.5, 0.0, _SNOW_TONE)

## Đĩa lá (disc) tại độ cao y — pha đốm tuyết, voxel tròn kiểu Minecraft.
func _canopy_disc(y: float, r: float, lv: float, tone_i: int) -> void:
	var rv: int = ceili(maxf(r, 0.0) / lv)
	for vx in range(-rv, rv + 1):
		for vz in range(-rv, rv + 1):
			var dx := vx * lv
			var dz := vz * lv
			if (dx * dx + dz * dz) > r * r:
				continue
			var rn := randf()
			var col: Color = _LEAF_TONES[tone_i]
			if rn < 0.16:
				col = col.darkened(0.22)
			elif rn < 0.34:
				col = col.lightened(0.10)
			elif rn < 0.46:
				col = _SNOW_TONE.lerp(col, 0.5)
			_fill(dx, y, dz, col)

# ── HIT FLASH override (MultiMeshInstance3D) ────────────────────────────────

func _hit_flash() -> void:
	var mmi := find_child("FrostVisual", false, false) as MultiMeshInstance3D
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