class_name EggplantProp
extends GrowingProp

## Cây cà tím — cây trồng 1×1 trên đất tơi xốp, theo đặc tả:
## - Thân thảo bụi nhỏ phân cành thấp, xanh lục sẫm pha tím ở khớp nối,
##   phủ lông tơ xám tro nhạt.
## - Lá to viền lượn sóng xẻ thùy nông, mọc so le, phiến xanh ngọc thẫm,
##   gân lá tím sẫm chạy dọc giữa phiến.
## - Hoa hình sao 5 cánh tím thạch anh xòe rộng, nhị vàng chanh ở trung tâm.
## - Quả thuôn dài cong nhẹ ở đít (hoặc tròn béo) tím hoàng gia mộng nước,
##   vệt highlight trắng xanh dọc thân, đài hoa 4-5 cánh nhọn xanh ngả tím
##   gồ ghề, cuống xanh đậm cong lên; khi chín tỏa hạt lấp lánh.
## - 4 giai đoạn: MẦM (2 lá mầm tím) → CÂY LỚN (bụi lá + nụ hoa) →
##   ĐƠM HOA KẾT QUẢ → CHÍN THU HOẠCH (quả căng mộng + hạt lấp lánh).

enum FruitShape { SLENDER, ROUND }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var _shape: int = FruitShape.SLENDER
var _bush_h: float = 1.0
var _fruit_count: int = 3
var _glow_light: OmniLight3D = null

var _real_fruit_nodes: Array[Node3D] = []

var _sway_phase: float = 0.0
var _sway_freq: float = 0.0
var _sway_amp: float = 0.0

# Đếm voxel theo nhóm — dùng cho test
var _vox_leaf: int = 0
var _vox_bud: int = 0
var _vox_flower: int = 0
var _vox_fruit: int = 0
var _vox_highlight: int = 0
var _vox_sparkle: int = 0

func setup() -> void:
	_shape = FruitShape.ROUND if randf() < 0.40 else FruitShape.SLENDER
	_bush_h = 0.85 + randf() * 0.35
	_fruit_count = 2 + randi() % 3

func _birth_span_days() -> float:
	return 20.0

func _stage_thresholds() -> Array[float]:
	return [3.0, 10.0]

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 0.9 + randf() * 0.6
	_sway_amp = deg_to_rad(2.2 + randf() * 1.2)

func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.10
	var stage_scale: float = 0.55 if _stage == GrowingProp.Stage.YOUNG else 1.0
	return _bush_h * stage_scale

## ── GRID helpers ────────────────────────────────────────────────────────────

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
	var j := (randf() - 0.5) * 0.05
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

## ── MAIN BUILD ──────────────────────────────────────────────────────────────

func _build_tree() -> void:
	_grid.clear()
	_ordered.clear()
	_vox_leaf = 0; _vox_bud = 0; _vox_flower = 0
	_vox_fruit = 0; _vox_highlight = 0; _vox_sparkle = 0

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual(_ordered.size(), 0)
		return

	var h: float = _get_h()
	_build_stem(h)
	_build_leaves(h)
	var main_count := _ordered.size()
	if _stage == GrowingProp.Stage.YOUNG:
		_build_buds(h)
		_commit_visual(_ordered.size(), 0)
		return
	_build_flowers(h)
	var flower_count := _ordered.size() - main_count
	_build_fruits(h)
	var fruit_count := _ordered.size() - main_count - flower_count
	_commit_visual(main_count, fruit_count)
	_setup_glow()

## Mầm: chồi xanh nhỏ + 2 lá mầm tím nhẹ trên mặt đất.
func _build_sprout() -> void:
	var col_stem := Color(0.12, 0.36, 0.14)
	var col_leaf := Color(0.10, 0.34, 0.14)
	var col_tint := Color(0.18, 0.20, 0.28)
	for vy in range(2):
		_fill(0.0, vy * VOXEL, 0.0, col_stem)
	for side in [-1.0, 1.0]:
		var sx: float = side * 0.0625
		_fill(sx, 0.045, 0.012, col_leaf)
		_fill(sx + side * 0.06, 0.032, 0.03, col_leaf)
		_fill(sx + side * 0.10, 0.018, 0.005, col_tint)
		_vox_leaf += 3

## Thân chính + cành thấp tạo bụi, khớp nối tím, lông tơ xám tro.
func _build_stem(h: float) -> void:
	var col_stem := Color(0.11, 0.33, 0.12)
	var col_joint := Color(0.26, 0.22, 0.34)
	var col_fuzz := Color(0.62, 0.60, 0.54)
	var col_branch := Color(0.12, 0.34, 0.13)

	var ny: int = ceili(h / VOXEL)
	var lean := (randf() - 0.5) * 0.05
	var cur_x := 0.0
	var cur_z := (randf() - 0.5) * 0.04
	for vy in range(ny):
		var t := float(vy) / float(ny)
		var y := float(vy) * VOXEL
		cur_x = lerpf(0.0, lean * t, 1.0)
		var col := col_stem
		if vy % 4 == 3:
			col = col_joint
		col = _jitter(col)
		_fill(cur_x, y, cur_z, col)
		# Lông tơ xám tro rải rác quanh thân
		if vy > 1 and vy % 2 == 0 and randf() < 0.35:
			var fa: float = randf() * TAU
			_fill(cur_x + cos(fa) * 0.035, y + 0.02, cur_z + sin(fa) * 0.035, col_fuzz)
	# Cành thấp: 2-3 nhánh từ gốc
	var branch_count: int = 2 + randi() % 2
	var seed_a: float = randf() * TAU
	for bi in range(branch_count):
		var ba: float = seed_a + float(bi) / float(branch_count) * TAU + (randf() - 0.5) * 0.5
		var dir := Vector3(cos(ba), 0.30 + randf() * 0.18, sin(ba)).normalized()
		var steps: int = 3 + randi() % 3
		var prev := Vector3(0.0, VOXEL * 1.2, 0.0)
		for si in range(steps):
			var p := prev + dir * VOXEL * 1.4
			var col := col_branch
			if si == 0:
				col = col_joint
			col = _jitter(col)
			_fill(p.x, p.y, p.z, col)
			if randf() < 0.4:
				_fill(p.x + (randf() - 0.5) * 0.05, p.y + 0.02, p.z + (randf() - 0.5) * 0.05, col_fuzz)
			prev = p

## Lá to viền lượn sóng xẻ thùy nông, so le, gân tím sẫm chạy dọc.
func _build_leaves(h: float) -> void:
	var col_leaf := Color(0.08, 0.30, 0.12)
	var col_leaf_dark := Color(0.06, 0.24, 0.10)
	var col_vein := Color(0.24, 0.14, 0.36)
	var is_young := _stage == GrowingProp.Stage.YOUNG

	var leaf_count: int = (5 + randi() % 3) if is_young else (10 + randi() % 3)
	var seed_a: float = randf() * TAU
	var tier: int = 4
	for li in range(leaf_count):
		var la: float = seed_a + float(li) / float(leaf_count) * TAU + (randf() - 0.5) * 0.6
		var dir := Vector3(cos(la), 0.10 + randf() * 0.12, sin(la)).normalized()
		var perp := Vector3(-sin(la), 0.0, cos(la)).normalized()
		var len: int = (6 + randi() % 3) if is_young else (8 + randi() % 3)
		var wid: int = 3 + randi() % 2
		var attach_y: float = h * (0.22 + float(li % tier) * (0.66 / float(tier - 1)))
		var base := Vector3(cos(la) * 0.07, attach_y, sin(la) * 0.07)
		for i in range(1, len):
			for j in range(-wid, wid + 1):
				# Viền lượn sóng: khuyết ô ở mép theo sóng
				var edge: bool = abs(j) == wid
				if edge and (i + j) % 4 == 0:
					continue
				# Xẻ thùy nông ở giữa mép
				if abs(j) == wid - 1 and i % 7 == 3 and j > 0:
					continue
				var p := base + dir * (float(i) * VOXEL * 1.35) + perp * (float(j) * VOXEL * 0.9)
				p.y += sin(float(i) * 0.7) * VOXEL * 0.5 - float(i) * VOXEL * 0.12
				var col := col_leaf
				if j == 0:
					col = col_vein
				elif abs(j) == wid or i % 3 == 0:
					col = col_leaf_dark
				col = _jitter(col)
				_fill(p.x, p.y, p.z, col)
				_vox_leaf += 1

## Nụ hoa tím ở nách lá (giai đoạn CÂY LỚN).
func _build_buds(h: float) -> void:
	var col_bud := Color(0.30, 0.18, 0.40)
	var col_bud_dark := Color(0.24, 0.13, 0.33)
	var col_sepal := Color(0.26, 0.44, 0.20)
	var bud_count: int = 3 + randi() % 2
	var seed_a: float = randf() * TAU
	for bi in range(bud_count):
		var ba: float = seed_a + float(bi) / float(bud_count) * TAU + (randf() - 0.5) * 0.4
		var r: float = 0.10 + randf() * 0.06
		var pos := Vector3(cos(ba) * r, h * (0.55 + randf() * 0.25), sin(ba) * r)
		_fill(pos.x, pos.y, pos.z, col_bud)
		_fill(pos.x + 0.03, pos.y + 0.035, pos.z + 0.02, col_bud)
		_fill(pos.x - 0.02, pos.y + 0.05, pos.z - 0.03, col_bud_dark)
		_fill(pos.x, pos.y - 0.04, pos.z, col_sepal)
		_vox_bud += 4

## Hoa sao 5 cánh tím thạch anh + nhị vàng chanh (giai đoạn trưởng thành).
func _build_flowers(h: float) -> void:
	var col_petal := Color(0.44, 0.28, 0.58)
	var col_petal_tip := Color(0.52, 0.34, 0.66)
	var col_stamen := Color(0.96, 0.86, 0.22)
	var flower_count: int = 2 + randi() % 2
	var seed_a: float = randf() * TAU
	for fi in range(flower_count):
		var fa: float = seed_a + float(fi) / float(flower_count) * TAU + (randf() - 0.5) * 0.5
		var r: float = 0.12 + randf() * 0.06
		var center := Vector3(cos(fa) * r, h * (0.62 + randf() * 0.22), sin(fa) * r)
		var tilt: float = (randf() - 0.5) * 0.8
		for p in range(5):
			var pa: float = fa + float(p) * TAU / 5.0 + tilt
			for pi in range(2):
				var d := Vector3(cos(pa) * 0.07, 0.02, sin(pa) * 0.07) * float(pi + 1)
				var col := col_petal if pi == 0 else col_petal_tip
				col = _jitter(col)
				_fill(center.x + d.x, center.y + d.y + float(pi) * 0.012, center.z + d.z, col)
				_vox_flower += 1
		# Nhị vàng chanh
		_fill(center.x, center.y + 0.06, center.z, col_stamen)
		_fill(center.x, center.y + 0.09, center.z, col_stamen.lightened(0.1))
		_vox_flower += 2

## Quả cà tím: model trái thật (item drop) treo lủng lẳng dưới các tầng lá,
## cuống áp vào mặt dưới nhánh, quả rủ xuống — mỗi trái xoay nhẹ khác nhau.
func _build_fruits(h: float) -> void:
	var bounty: int = _fruit_count
	var seed_a: float = randf() * TAU
	for fi in range(bounty):
		var fa: float = seed_a + float(fi) / float(bounty) * TAU + (randf() - 0.5) * 0.6
		var r: float = 0.12 + randf() * 0.08
		var attach_y: float = h * (0.55 + randf() * 0.30) - 0.10
		var target_len: float = 0.34 + randf() * 0.12
		_add_hanging(ItemMesh.add_fruit_hanging(
			self, "eggplant_fruit", target_len,
			Vector3(cos(fa) * r, attach_y, sin(fa) * r), randf() * TAU))
		_build_sparkles(Vector3(cos(fa) * r, attach_y - target_len * 0.5, sin(fa) * r))

## Hạt lấp lánh tỏa quanh quả chín.
func _build_sparkles(center: Vector3) -> void:
	var col := Color(0.95, 0.90, 0.55)
	var n: int = 3 + randi() % 2
	for si in range(n):
		var sa: float = randf() * TAU
		var sr: float = 0.09 + randf() * 0.07
		var sy: float = center.y - 0.06 - randf() * 0.10
		_fill(center.x + cos(sa) * sr, sy, center.z + sin(sa) * sr, col)
		_vox_sparkle += 1

## Ánh sáng tím nhạt báo hiệu quả chín.
func _setup_glow() -> void:
	if _glow_light != null:
		return
	_glow_light = OmniLight3D.new()
	_glow_light.name = "EggplantGlow"
	_glow_light.light_color = Color(0.60, 0.50, 0.85)
	_glow_light.omni_range = 1.3
	_glow_light.light_energy = 0.30
	_glow_light.light_specular = 0.0
	_glow_light.shadow_enabled = false
	_glow_light.position = Vector3(0.0, _get_h() * 0.55, 0.0)
	add_child(_glow_light)

## ── VISUAL ──────────────────────────────────────────────────────────────────

func _commit_visual(main_count: int, fruit_count: int) -> void:
	if _ordered.is_empty():
		return
	var cube := BoxMesh.new()
	cube.size = Vector3(VOXEL, VOXEL, VOXEL)
	var cube_mat := StandardMaterial3D.new()
	cube_mat.vertex_color_use_as_albedo = true
	cube_mat.metallic = 0.0
	cube_mat.roughness = 0.85
	cube.material = cube_mat

	if main_count > 0:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cube
		mm.instance_count = main_count
		for i in range(main_count):
			mm.set_instance_transform(i, Transform3D.IDENTITY.translated(_ordered[i]))
			mm.set_instance_color(i, _grid[_key(_ordered[i])])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "EggplantVisual"
		add_child(mmi)

	if fruit_count > 0:
		var fruit_cube := BoxMesh.new()
		fruit_cube.size = Vector3(VOXEL, VOXEL, VOXEL)
		var fruit_mat := StandardMaterial3D.new()
		fruit_mat.vertex_color_use_as_albedo = true
		fruit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fruit_mat.metallic = 0.0
		fruit_mat.roughness = 0.15
		fruit_cube.material = fruit_mat
		var fruit_mm := MultiMesh.new()
		fruit_mm.transform_format = MultiMesh.TRANSFORM_3D
		fruit_mm.use_colors = true
		fruit_mm.mesh = fruit_cube
		fruit_mm.instance_count = fruit_count
		for i in range(fruit_count):
			var idx := main_count + i
			fruit_mm.set_instance_transform(i, Transform3D.IDENTITY.translated(_ordered[idx]))
			fruit_mm.set_instance_color(i, _grid[_key(_ordered[idx])])
		var fruit_mmi := MultiMeshInstance3D.new()
		fruit_mmi.multimesh = fruit_mm
		fruit_mmi.name = "EggplantFruitVisual"
		add_child(fruit_mmi)

func _apply_stage(_from: int, _to: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for rf in _real_fruit_nodes:
		if is_instance_valid(rf):
			remove_child(rf)
			rf.queue_free()
	_real_fruit_nodes.clear()
	for i in range(get_child_count() - 1, -1, -1):
		var ch := get_child(i)
		if ch is MultiMeshInstance3D or ch is StaticBody3D or ch is OmniLight3D:
			remove_child(ch)
			ch.queue_free()
	_glow_light = null
	_build_tree()
	_setup_collision()
	_pop_growth()

## ── DROP ────────────────────────────────────────────────────────────────────

## Chỉ chặt cây TRƯỞNG THÀNH mới rơi trái — mầm/cây non không rơi.
func spawn_drop() -> void:
	if _stage != GrowingProp.Stage.MATURE:
		return
	super.spawn_drop()

func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.MATURE:
		return
	var world := _find_world_manager()
	if world == null:
		return
	_ItemDatabase.ensure_db()
	var fruit_def: ItemDef = _ItemDatabase.items_db.get("eggplant_fruit")
	if fruit_def:
		var fruit_n: int = 1 + (1 if randf() < 0.5 else 0)
		_DroppedItem.spawn(world, fruit_def, global_position, fruit_n,
			_spawn_drop_velocity(), global_position.y)
	var seed_def: ItemDef = _ItemDatabase.items_db.get("eggplant_seed")
	if seed_def:
		_DroppedItem.spawn(world, seed_def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)

## ── SWAY ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_usec() * 0.000001
	var amp := _sway_amp
	if _stage == GrowingProp.Stage.SPROUT:
		amp *= 0.4
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.7 + _sway_phase * 1.3 + 0.7) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.7 + _sway_phase + 1.0) * 0.7 + cos(t * _sway_freq * 2.1 + _sway_phase + 2.2) * 0.3) * amp * 0.6

## ── COLLISION ───────────────────────────────────────────────────────────────

func _setup_collision() -> void:
	var h := _get_h()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _bush_h * 0.24 + 0.10
	shape.height = h + 0.15
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	add_child(body)

## ── HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) ───────────

func _hit_flash() -> void:
	for name in ["EggplantVisual", "EggplantFruitVisual"]:
		var mmi := find_child(name, false, false) as MultiMeshInstance3D
		if mmi == null:
			continue
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
	super._hit_flash()

func _get_mesh_instances() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for rf in _real_fruit_nodes:
		if is_instance_valid(rf):
			_collect_mi(rf, result)
	return result

func _add_hanging(n: Node3D) -> void:
	if n != null:
		_real_fruit_nodes.append(n)
