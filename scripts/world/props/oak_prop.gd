class_name OakProp
extends GrowingProp

## Cây sồi kiểu Minecraft — thân cột nâu đậm thẳng đứng (vỏ nâu sẫm ấm, không
## rêu/xám), tán lá xanh um dạng khối blob chunky: lõi xanh rừng thẫm,
## giữa xanh tươi, ngoài xanh sáng đón nắng; nhiều cành nhánh vươn ra
## mang chùm lá riêng, gió đu nhẹ theo chùm. Vòng đời: mầm (sapling)
## → cây non → trưởng thành. Chặt rìu rơi khối gỗ sồi.

enum OakSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var _variant: String = "plains"
var _size: int = OakSize.MEDIUM
var _base_h: float = 4.4

var _tuft_nodes: Array[Node3D] = []
var _tuft_freqs: Array[float] = []
var _tuft_phases: Array[float] = []
var _tuft_amps: Array[float] = []

var _tuft_data: Array = []   # { center, pos[], col[] } — chùm lá (local của chùm)
var _grid: Dictionary = {}   # key (int) → Color
var _ordered: Array[Vector3] = []

var _canopy_centers: Array[Vector3] = []

func setup(variant: String = "plains") -> void:
	_variant = variant
	var r := randf()
	if r < 0.15: _size = OakSize.SMALL
	elif r < 0.45: _size = OakSize.MEDIUM
	else: _size = OakSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
	match _size:
		OakSize.SMALL:  return 3.2 + randf() * 0.4
		OakSize.MEDIUM: return 4.2 + randf() * 0.6
		OakSize.TALL:   return 5.4 + randf() * 0.6
	return 4.4

func _birth_span_days() -> float:
	return 90.0

func _stage_thresholds() -> Array[float]:
	return [15.0, 55.0]

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()

func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.5
	var stage_scale: float = 0.62 if _stage == GrowingProp.Stage.YOUNG else 1.0
	return _base_h * stage_scale

func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.MATURE: return
	var world := _find_world_manager()
	if world == null: return
	_ItemDatabase.ensure_db()
	var wood_def = _ItemDatabase.items_db.get("block_oak_wood")
	if wood_def:
		_DroppedItem.spawn(world, wood_def, global_position, randi() % 3 + 2, _spawn_drop_velocity(), global_position.y)

func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_usec() * 0.000001
	for i in range(_tuft_nodes.size()):
		var tn: Node3D = _tuft_nodes[i]
		if tn == null or not is_instance_valid(tn):
			continue
		tn.rotation.x = sin(t * _tuft_freqs[i] + _tuft_phases[i]) * _tuft_amps[i]
		tn.rotation.z = cos(t * _tuft_freqs[i] * 0.8 + _tuft_phases[i] + 1.0) * _tuft_amps[i] * 0.7

func _setup_collision() -> void:
	var h := _get_h()
	var br := _get_base_r()
	var canopy_r := _canopy_r()
	if _stage == GrowingProp.Stage.YOUNG:
		canopy_r *= 0.6
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(br, canopy_r * 0.6) + 0.2
	shape.height = h + 0.4
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

func _get_base_r() -> float:
	var r: float
	match _size:
		OakSize.SMALL:  r = 0.26
		OakSize.MEDIUM: r = 0.30
		OakSize.TALL:   r = 0.34
		_: r = 0.30
	if _variant == "river":
		r *= 1.1
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.40
	elif _stage == GrowingProp.Stage.YOUNG:
		r *= 0.70
	return r

func _get_top_r() -> float:
	var r: float
	match _size:
		OakSize.SMALL:  r = 0.16
		OakSize.MEDIUM: r = 0.19
		OakSize.TALL:   r = 0.22
		_: r = 0.19
	if _stage == GrowingProp.Stage.YOUNG:
		r *= 0.70
	return r

## Bán kính tán — xòe rộng theo phương ngang kiểu Minecraft.
func _canopy_r() -> float:
	var r: float
	match _size:
		OakSize.SMALL:  r = 1.10
		OakSize.MEDIUM: r = 1.40
		OakSize.TALL:   r = 1.70
		_: r = 1.40
	if _variant == "river":
		r *= 1.1
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.25
	elif _stage == GrowingProp.Stage.YOUNG:
		r *= 0.60
	return r

# ── GRID helpers ────────────────────────────────────────────────────────────

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

func _add_tuft_voxel(tuft: Dictionary, x: float, y: float, z: float, col: Color) -> void:
	(tuft["pos"] as Array).append(Vector3(round(x / VOXEL) * VOXEL, round(y / VOXEL) * VOXEL, round(z / VOXEL) * VOXEL))
	(tuft["col"] as Array).append(col * _DARKEN)

## Lá dùng lưới thô 0.125 (2× voxel thân) — khối lá chunky kiểu Minecraft,
## vẫn đồng bộ 8 sub-cube với lưới chính.
func _add_tuft_voxel_c(tuft: Dictionary, x: float, y: float, z: float, col: Color) -> void:
	var s := VOXEL * 2.0
	(tuft["pos"] as Array).append(Vector3(round(x / s) * s, round(y / s) * s, round(z / s) * s))
	(tuft["col"] as Array).append(col * _DARKEN)

## Đoạn trụ voxel hóa giữa 2 điểm (thân mảnh cành).
func _stroke(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var dist := a.distance_to(b)
	var steps := maxi(2, ceili(dist / (VOXEL * 0.8)))
	var rv := maxi(1, ceili(r / VOXEL))
	for si in range(steps + 1):
		var t := float(si) / float(steps)
		var p := a.lerp(b, t)
		if rv <= 1:
			_fill(p.x, p.y, p.z, col)
			continue
		for vx in range(-rv, rv + 1):
			for vz in range(-rv, rv + 1):
				if vx * vx + vz * vz > rv * rv:
					continue
				var c2: Color = col
				if randf() < 0.15:
					c2 = col.darkened(0.10)
				_fill(p.x + vx * VOXEL, p.y, p.z + vz * VOXEL, c2)

# ── MAIN BUILD ──────────────────────────────────────────────────────────────

func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()
	_tuft_data.clear()
	_canopy_centers.clear()

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual()
		return

	var h: float = _get_h()
	_build_trunk(h)
	_branch_arms(h)
	_build_canopy(h)

	_commit_visual()

func _commit_visual() -> void:
	var total := _ordered.size()
	for t in _tuft_data:
		total += (t["pos"] as Array).size()
	if total == 0:
		return

	var cube := BoxMesh.new()
	cube.size = Vector3(VOXEL, VOXEL, VOXEL)
	var cube_mat := StandardMaterial3D.new()
	cube_mat.vertex_color_use_as_albedo = true
	cube_mat.metallic = 0.0
	cube_mat.roughness = 0.85
	cube.material = cube_mat

	if not _ordered.is_empty():
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
		mmi.name = "OakVisual"
		add_child(mmi)

	for ti in range(_tuft_data.size()):
		var tuft: Dictionary = _tuft_data[ti]
		var pos: Array = tuft["pos"]
		if pos.is_empty():
			continue
		var col: Array = tuft["col"]
		var tn := Node3D.new()
		tn.name = "Tuft%d" % ti
		tn.position = tuft["center"]
		add_child(tn)
		var tmm := MultiMesh.new()
		tmm.transform_format = MultiMesh.TRANSFORM_3D
		tmm.use_colors = true
		tmm.mesh = cube
		tmm.instance_count = pos.size()
		for i in range(pos.size()):
			tmm.set_instance_transform(i, Transform3D.IDENTITY.translated(pos[i]))
			tmm.set_instance_color(i, col[i])
		var tmi := MultiMeshInstance3D.new()
		tmi.multimesh = tmm
		tmi.name = "TuftVisual"
		tn.add_child(tmi)
		_tuft_nodes.append(tn)
		_tuft_freqs.append(0.5 + randf() * 0.3)
		_tuft_phases.append(randf() * TAU)
		_tuft_amps.append(deg_to_rad(1.0 + randf() * 1.0))

func _apply_stage(_from: int, _to: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for i in range(get_child_count() - 1, -1, -1):
		var ch := get_child(i)
		if ch is MultiMeshInstance3D or ch is StaticBody3D or ch is CPUParticles3D:
			remove_child(ch)
			ch.queue_free()
		elif ch is Node3D and ch.name.begins_with("Tuft"):
			remove_child(ch)
			ch.queue_free()
	_tuft_nodes.clear()
	_tuft_freqs.clear()
	_tuft_phases.clear()
	_tuft_amps.clear()
	_build_tree()
	_setup_collision()
	_pop_growth()

## Mầm cây sồi kiểu sapling: thân nhỏ nâu sáng + cụm lá xanh trên ngọn.
func _build_sprout() -> void:
	var stem := Color(0.42, 0.30, 0.15)
	var stem_h := 0.22 + randf() * 0.10
	var ny: int = ceili(stem_h / VOXEL)
	for vy in range(ny):
		_fill(0.0, vy * VOXEL, 0.0, stem)
	var tuft: Dictionary = { "center": Vector3(0.0, stem_h + 0.10, 0.0), "pos": [], "col": [] }
	_build_blob(tuft, Vector3.ZERO, 0.16 + randf() * 0.06)
	_tuft_data.append(tuft)

# ── TRUNK (thân cột nâu đậm, gần thẳng, vỏ nâu sẫm ấm) ─────────────────────

func _build_trunk(h: float) -> void:
	var base_r := _get_base_r()
	var top_r := _get_top_r()
	var ny: int = ceili(h / VOXEL)
	var wob := randf() * TAU
	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y := vy * VOXEL
		var r := lerpf(base_r, top_r, t)
		r *= 1.0 + sin(vy * 0.35 + wob) * 0.05
		if vy < 4:
			r *= 1.0 + (1.0 - float(vy) / 4.0) * 0.15   # phình nhẹ chân
		var cx := sin(vy * 0.5 + wob) * 0.03 * (1.0 - t)
		var cz := cos(vy * 0.4 + wob * 1.7) * 0.03 * (1.0 - t)
		var rv: int = ceili(r / VOXEL)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * VOXEL - cx
				var dz := vz * VOXEL - cz
				if dx * dx + dz * dz > r * r:
					continue
				_fill(dx, y, dz, _bark_vary())
		# sẹo cành ngắn rải rác trên thân (vài chấm sẫm)
		if vy > ny / 3 and vy % 29 == 7 and randf() < 0.6:
			var sa: float = randf() * TAU
			_fill(cos(sa) * r, y, sin(sa) * r, Color(0.30, 0.19, 0.08))
			_fill(cos(sa + 0.35) * r * 0.8, y + VOXEL * 0.5, sin(sa + 0.35) * r * 0.8, Color(0.30, 0.19, 0.08))

func _bark_vary() -> Color:
	var r := randf()
	if r < 0.12:
		return Color(0.46, 0.31, 0.16)
	if r < 0.24:
		return Color(0.32, 0.20, 0.09)
	return Color(0.39, 0.26, 0.12)

# ── BRANCH ARMS (cành vươn lên mang chùm lá) ───────────────────────────────

func _branch_arms(h: float) -> void:
	var is_young: bool = _stage == GrowingProp.Stage.YOUNG
	var n_arm: int = 2 if is_young else (3 + randi() % 3)
	var base_r := _get_base_r()
	_canopy_centers.clear()
	var seed_a: float = randf() * TAU
	for ai in range(n_arm):
		var a: float = seed_a + float(ai) / float(n_arm) * TAU + (randf() - 0.5) * 0.7
		var start_h := h * (0.55 + randf() * 0.20)
		var len_out := 0.9 + randf() * 0.5
		var tip_y := h * (0.82 + randf() * 0.14)
		var end := Vector3(cos(a) * len_out, tip_y, sin(a) * len_out)
		var start := Vector3(cos(a) * base_r * 0.85, start_h, sin(a) * base_r * 0.85)
		_stroke(start, end, lerpf(base_r * 0.55, base_r * 0.30, randf()), _jitter(Color(0.39, 0.26, 0.12)))
		_canopy_centers.append(end + Vector3(0, 0.15, 0))

# ── CANOPY: khối blob lá chunky kiểu Minecraft ─────────────────────────────

func _build_canopy(h: float) -> void:
	var is_young: bool = _stage == GrowingProp.Stage.YOUNG
	var canopy := _canopy_r()
	# Chùm trung tâm trên ngọn thân
	var centers: Array[Vector3] = [Vector3(0.0, h * 0.96, 0.0)]
	centers.append_array(_canopy_centers)
	var max_blobs: int = 1 if is_young else centers.size()
	var made := 0
	for c in centers:
		if made >= max_blobs:
			break
		var r: float = canopy * (0.78 if made == 0 else (0.46 + randf() * 0.12))
		if is_young:
			r = canopy * (0.55 if made == 0 else 0.38)
		var tuft: Dictionary = { "center": c, "pos": [], "col": [] }
		_build_blob(tuft, Vector3.ZERO, r)
		_tuft_data.append(tuft)
		made += 1

func _build_blob(tuft: Dictionary, center: Vector3, r: float) -> void:
	var s := VOXEL * 2.0
	var rv: int = ceili(r / s)
	for vx in range(-rv - 1, rv + 2):
		for vy in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * s
				var dy := vy * s
				var dz := vz * s
				var d := sqrt(dx * dx + dy * dy + dz * dz)
				if d > r:
					continue
				var d01 := clampf(d / maxf(r, 0.001), 0.0, 1.0)
				var edge: float = 0.82 + randf() * 0.18
				if d01 > edge and randf() > 0.45:
					continue
				if d01 < 0.75 and randf() < 0.06:
					continue
				_add_tuft_voxel_c(tuft, dx, dy, dz, _leaf_color(d01, randf()))

## Màu lá: lõi xanh rừng thẫm → giữa xanh tươi → ngoài xanh sáng đón nắng.
func _leaf_color(d01: float, rnd: float) -> Color:
	if rnd < 0.10 and d01 > 0.6:
		return Color(0.32, 0.80, 0.22)
	if d01 > 0.72:
		return Color(0.24, 0.70, 0.16)
	if d01 > 0.42:
		return Color(0.18, 0.60, 0.12)
	return Color(0.11, 0.48, 0.09)

func _jitter(col: Color) -> Color:
	var j := (randf() - 0.5) * 0.06
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

# ── HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) ───────────

func _hit_flash() -> void:
	var all: Array[MultiMeshInstance3D] = []
	var mmi := find_child("OakVisual", false, false) as MultiMeshInstance3D
	if mmi != null:
		all.append(mmi)
	for tn in _tuft_nodes:
		if tn == null or not is_instance_valid(tn):
			continue
		var tmi: MultiMeshInstance3D = tn.find_child("TuftVisual", false, false)
		if tmi != null:
			all.append(tmi)
	for mi in all:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var orig := mi.material_override
		mi.material_override = mat
		var tween := create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(func():
			if is_instance_valid(mi):
				mi.material_override = orig
		)

func _get_mesh_instances() -> Array[MeshInstance3D]:
	return []
