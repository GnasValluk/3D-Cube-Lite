class_name PlainsBushProp
extends GrowingProp

## Bụi cây dại đồng bằng — tán lá hình tròn chunky kiểu tán cây sồi (nhiều đùm
## lá dày chồng nhau thành gò thấp), thân là chùm nhánh ngắn vươn ra mọi hướng.
## Khi CHÍN (RIPE) trên mặt tán mọc chùm quả cherry tím mọng — chặt/đập bụi chín
## rụng quả cherry ăn được. Vòng đời: mầm → non → trưởng thành → chín theo
## thời gian game, mọc dại ở đồng cỏ xa nước.

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72
const _CHERRY_SCALE: float = 0.11
const _STEM_SCALE: float = 0.055

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "plains"
var _radius: float = 0.9
var _height: float = 0.8
var _trunk_h: float = 1.1

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

var _tuft_data: Array = []   # { center, pos[], col[], r }
var _grid: Dictionary = {}   # key (int) → Color (thân/nhánh voxel thô)
var _ordered: Array[Vector3] = []
var _berry_seen: Dictionary = {}
var _berry_positions: Array[Vector3] = []
var _berry_scales: Array[float] = []
var _berry_colors: Array[Color] = []

func setup(variant: String = "plains") -> void:
	_variant = variant
	_radius = 0.9 + randf() * 0.35
	_height = _radius * (0.8 + randf() * 0.2)
	_trunk_h = 1.0 + randf() * 0.3

func _birth_span_days() -> float:
	return 60.0

func _stage_thresholds() -> Array[float]:
	return [8.0, 25.0, 45.0]

func _ready() -> void:
	super._ready()
	_build_bush()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.2 + randf() * 0.5
	_sway_amp = deg_to_rad(1.5 + randf() * 0.8)

func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.RIPE:
		return
	var world := _find_world_manager()
	if world == null:
		return
	_ItemDatabase.ensure_db()
	var cherry_def = _ItemDatabase.items_db.get("cherry")
	if cherry_def:
		_DroppedItem.spawn(world, cherry_def, global_position, randi() % 2, _spawn_drop_velocity(), global_position.y)

func _process(delta: float) -> void:
	super._process(delta)
	if not _VoxelShared.sway_active(global_position, 40.0):
		return
	var t := _VoxelShared.time_sec()
	var amp := _sway_amp
	if _stage == GrowingProp.Stage.SPROUT:
		amp *= 0.4
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.6 + _sway_phase * 1.3 + 0.7) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.8 + _sway_phase + 1.0) * 0.7 + cos(t * _sway_freq * 2.1 + _sway_phase + 2.2) * 0.3) * amp * 0.75

## Chỉ rụng quả khi bụi đã CHÍN — chặt non không có gì.
func spawn_drop() -> void:
	if _stage != GrowingProp.Stage.RIPE:
		return
	super.spawn_drop()

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BushCollision"
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	var grow: float = 1.0
	if _stage == GrowingProp.Stage.YOUNG:
		grow = 0.55
	sph.radius = maxf(_radius * 0.95 * grow, 0.30)
	col.shape = sph
	col.position.y = (_trunk_h + _height * 0.5) * grow
	body.add_child(col)
	add_child(body)

## ── GRID helpers ───────────────────────────────────────────────────────────

func _key(v: Vector3) -> int:
	return int(round(v.x / VOXEL)) + int(round(v.y / VOXEL)) * 10000 + int(round(v.z / VOXEL)) * 100000000

func _add_voxel(pos: Vector3, col: Color) -> void:
	var p := Vector3(round(pos.x / VOXEL) * VOXEL, round(pos.y / VOXEL) * VOXEL, round(pos.z / VOXEL) * VOXEL)
	var k := _key(p)
	if _grid.has(k):
		return
	_grid[k] = col
	_ordered.append(p)

func _fill(px: float, py: float, pz: float, col: Color) -> void:
	_add_voxel(Vector3(px, py, pz), col * _DARKEN)

## Nhánh thân trụ voxel hóa giữa 2 điểm — lưới VOXEL (mảnh).
func _stroke(a: Vector3, b: Vector3, col: Color) -> void:
	var dist := a.distance_to(b)
	var steps := maxi(2, ceili(dist / (VOXEL * 1.2)))
	for si in range(steps + 1):
		var t := float(si) / float(steps)
		var p := a.lerp(b, t)
		_fill(p.x, p.y, p.z, col)

## ── MAIN BUILD ─────────────────────────────────────────────────────────────

func _build_bush() -> void:
	_grid.clear()
	_ordered.clear()
	_tuft_data.clear()
	_berry_seen.clear()
	_berry_positions.clear()
	_berry_colors.clear()

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual()
		return

	var grow: float = 1.0
	if _stage == GrowingProp.Stage.YOUNG:
		grow = 0.55
	var r: float = _radius * grow
	var h: float = _height * grow
	var th: float = _trunk_h * grow

	_build_trunk(th)
	if _stage == GrowingProp.Stage.MATURE or _stage == GrowingProp.Stage.RIPE:
		_build_canopy(r, h, th)
		if _stage == GrowingProp.Stage.RIPE:
			_scatter_berries(r, h, th)

	_commit_visual()

func _commit_visual() -> void:
	# Gộp thân/nhánh + đùm lá + quả cherry vào 1 MultiMesh duy nhất.
	var positions: Array = []
	var scales_pack: Array = []
	var colors_pack: Array = []

	for p in _ordered:
		positions.append(p)
		scales_pack.append(_VoxelShared.TRUNK_SCALE)
		colors_pack.append(_grid[_key(p)])
	for t in _tuft_data:
		var pos: Array = t["pos"]
		var col: Array = t["col"]
		for i in range(pos.size()):
			positions.append(t["center"] + pos[i])
			scales_pack.append(_VoxelShared.LEAF_SCALE)
			colors_pack.append(col[i])
	for i in range(_berry_positions.size()):
		positions.append(_berry_positions[i])
		scales_pack.append(_berry_scales[i])
		colors_pack.append(_berry_colors[i])

	if positions.is_empty():
		return
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "BushVisual"
	add_child(mmi)

func _apply_stage(_from: int, _to: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for i in range(get_child_count() - 1, -1, -1):
		var ch := get_child(i)
		if ch is MultiMeshInstance3D or ch is StaticBody3D or ch is CPUParticles3D:
			remove_child(ch)
			ch.queue_free()
	_build_bush()
	_setup_collision()
	_pop_growth()

## Mầm bụi: cọng nhỏ kiểu thân cây + cụm lá xanh trên ngọn.
func _build_sprout() -> void:
	var stem := Color(0.34, 0.28, 0.14)
	var ny: int = 7 + randi() % 3
	for vy in range(ny):
		_fill(0.0, vy * VOXEL, 0.0, stem)
	var tuft: Dictionary = { "center": Vector3(0.0, ny * VOXEL + 0.08, 0.0), "pos": [], "col": [], "r": 0.18 }
	_build_blob(tuft, 0.18)
	_tuft_data.append(tuft)

## Thân bụi: cột vươn cao ~1 mét (gỗ nâu), hơi thon lên trên, có vài nhánh ngắn
## ở ngọn chờm ra — tán lá nằm trên thân.
func _build_trunk(th: float) -> void:
	var stem := Color(0.36, 0.27, 0.15)
	var stem_d := Color(0.28, 0.19, 0.10)
	var lv := VOXEL
	var ny: int = ceili(th / lv)
	var base_r: float = 0.20
	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var r: float = lerpf(base_r, base_r * 0.55, t)
		var wob := sin(vy * 0.9) * 0.02 * (1.0 - t)
		var cx := cos(vy * 0.7) * 0.02 * (1.0 - t)
		var rv: int = ceili(r / lv)
		for vx in range(-rv, rv + 1):
			for vz in range(-rv, rv + 1):
				var dx := vx * lv - cx
				var dz := vz * lv - wob
				if dx * dx + dz * dz > r * r:
					continue
				_fill(dx, vy * lv, dz, stem_d if randf() < 0.25 else stem)
	# Vài nhánh chờm ra ngọn.
	var seed_a: float = randf() * TAU
	for si in range(3):
		var a: float = seed_a + float(si) / 3.0 * TAU + (randf() - 0.5) * 0.8
		var top := Vector3(cos(a) * (base_r * 0.9 + randf() * 0.2), th - lv, sin(a) * (base_r * 0.9 + randf() * 0.2))
		_stroke(Vector3(0.0, th - lv * 2.0, 0.0), top, stem)

## Gò lá dày kiểu tán sồi: 1 đùm chính + vài đùm vệ tinh, nằm TRÊN thân ~1m.
func _build_canopy(r: float, h: float, th: float) -> void:
	var main_c := Vector3(0.0, th + h * 0.5, 0.0)
	var main_r := r * 0.68
	var tuft_main: Dictionary = { "center": main_c, "pos": [], "col": [], "r": main_r }
	_build_blob(tuft_main, main_r)
	_tuft_data.append(tuft_main)
	var n_sat: int = 5 + randi() % 3
	var seed_a: float = randf() * TAU
	for si in range(n_sat):
		var a: float = seed_a + float(si) / float(n_sat) * TAU + (randf() - 0.5) * 0.5
		var off := Vector3(cos(a) * r * 0.62, th + h * (0.15 + randf() * 0.42), sin(a) * r * 0.62)
		var sr := r * (0.42 + randf() * 0.20)
		var tuft: Dictionary = { "center": off, "pos": [], "col": [], "r": sr }
		_build_blob(tuft, sr)
		_tuft_data.append(tuft)

## Đùm lá chunky: elip dẹp trên lưới thô 3×VOXEL (y hệt đùm lá sồi).
func _build_blob(tuft: Dictionary, r: float) -> void:
	var tone := _LEAF_TONES[randi() % _LEAF_TONES.size()]
	var squash := 0.72 + randf() * 0.22
	var edge: float = 0.85 + randf() * 0.15
	var lv := VOXEL * 3.0
	var br: int = ceili(r / lv)
	var r_inv := 1.0 / r
	var ry_inv := 1.0 / (r * 0.6)
	var squash_inv := 1.0 / (r * squash)
	for vx in range(-br, br + 1):
		var sx := (vx * lv) * r_inv
		var sx2 := sx * sx
		for vy in range(-br, br + 1):
			var sy2 := (vy * lv) * ry_inv
			sy2 *= sy2
			var dp2 := sx2 + sy2
			for vz in range(-br, br + 1):
				var sz := (vz * lv) * squash_inv
				var d2 := dp2 + sz * sz
				if d2 > 1.0:
					continue
				var px := vx * lv
				var py := vy * lv
				var pz := vz * lv
				var d := sqrt(d2)
				if d > edge and randf() > 0.45:
					continue
				if d < 0.70 and randf() < 0.04:
					continue
				_add_tuft_voxel_c(tuft, px, py, pz, _leaf_color(tone, d, randf()))

func _add_tuft_voxel_c(tuft: Dictionary, x: float, y: float, z: float, col: Color) -> void:
	var s := VOXEL * 3.0
	(tuft["pos"] as Array).append(Vector3(round(x / s) * s, round(y / s) * s, round(z / s) * s))
	(tuft["col"] as Array).append(col * _DARKEN)

## Bảng tông lá bụi xanh rất tươi (lõi xanh đậm bóng → giữa xanh lá → ngoài
## vàng-xanh sáng đón nắng) — tông "nhiều nước" hơn để bụi nổi bật giữa đồng cỏ.
const _LEAF_TONES: Array[Color] = [
	Color(0.16, 0.55, 0.10),
	Color(0.22, 0.65, 0.13),
	Color(0.28, 0.75, 0.16),
	Color(0.34, 0.84, 0.20),
	Color(0.42, 0.92, 0.26),
]

func _leaf_color(tone: Color, d01: float, rnd: float) -> Color:
	if rnd < 0.10 and d01 > 0.6:
		return tone.lightened(0.30)
	if d01 > 0.72:
		return tone.lightened(0.16)
	if d01 > 0.42:
		return tone
	return tone.darkened(0.18)

## Chùm cherry tím: nhiều trái khum khum trên mặt tán, mỗi trái tựa quả cherry
## thật (2 thùy tim + highlight bóng + lõm đáy + cuống vươn ra ngoài), nhô ra
## khỏi rim lá 1 chút để lộ 2/3 trái.
func _scatter_berries(r: float, h: float, th: float) -> void:
	var main_c := Vector3(0.0, th + h * 0.55, 0.0)
	var blob_r := r * 0.68
	var spots: int = 10 + randi() % 5
	var seed_a: float = randf() * TAU
	for i in range(spots):
		var a: float = seed_a + float(i) / float(spots) * TAU + (randf() - 0.5) * 0.6
		var e: float = -0.15 + randf() * 0.75
		var dir := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)).normalized()
		var base := main_c + dir * (blob_r + 0.30)
		var tan := Vector3(-dir.z, 0.0, dir.x).normalized()
		var n: int = 2 + randi() % 2
		for j in range(n):
			var off := tan * (float(j) - (float(n) - 1.0) * 0.5) * 0.10 \
				+ Vector3(0.0, (randf() - 0.5) * 0.05, 0.0)
			_add_cherry(base + off, dir)

## Một trái cherry: 2 thùy bên + highlight bóng trên + lõm tối đáy + cuống nhỏ.
func _add_cherry(base: Vector3, dir: Vector3) -> void:
	var tan := Vector3(-dir.z, 0.0, dir.x).normalized()
	var cherry := Color(0.60, 0.09, 0.52)
	var cherry_l := Color(0.78, 0.28, 0.68)
	var cherry_d := Color(0.34, 0.03, 0.30)
	var stem := Color(0.40, 0.52, 0.15)
	_add_berry_core(base, cherry, _CHERRY_SCALE)
	_add_berry_core(base + tan * 0.05, cherry, _CHERRY_SCALE)
	_add_berry_core(base + Vector3(0.0, 0.04, 0.0) + dir * 0.04, cherry_l, _CHERRY_SCALE * 0.9)
	_add_berry_core(base - dir * 0.04 - Vector3(0.0, 0.03, 0.0), cherry_d, _CHERRY_SCALE * 0.82)
	_add_berry_core(base + dir * 0.07 + Vector3(0.0, 0.06, 0.0), stem, _STEM_SCALE)
	_add_berry_core(base + dir * 0.11 + Vector3(0.0, 0.08, 0.0), stem, _STEM_SCALE)

func _add_berry_core(p: Vector3, col: Color, s: float) -> void:
	var v := Vector3(round(p.x / VOXEL) * VOXEL, round(p.y / VOXEL) * VOXEL, round(p.z / VOXEL) * VOXEL)
	var k := _key(v)
	if _berry_seen.has(k):
		return
	_berry_seen[k] = true
	_berry_positions.append(v)
	_berry_scales.append(s)
	_berry_colors.append(col)

## ── HIT FLASH override (MultiMeshInstance3D, không phải MeshInstance3D) ─────

func _hit_flash() -> void:
	var mmi := find_child("BushVisual", false, false) as MultiMeshInstance3D
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