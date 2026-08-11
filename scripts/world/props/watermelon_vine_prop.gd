class_name WatermelonVineProp
extends GrowingProp

## Cây dưa hấu — dây bò bám mặt đất ô nông trại (1×1), theo đặc tả:
## - Dây leo uốn lượn ngoằn ngoèo bò sát đất, xanh lá mạ pha vàng ở ngọn non,
##   tua cuốn dạng lò xo xoắn ốc xanh chuối nõn, lông tơ xám trắng mờ.
## - Lá to xẻ thùy sâu 3-5 nhánh bo tròn đầu, xanh lục tươi, gân lá xanh nhạt.
## - Hoa sao 5 cánh vàng chanh rực rỡ, nhụy giữa vàng cam mộng nước.
## - Quả cầu tròn béo (hoặc bầu dục) nằm nghiêng trên thảm lá: nền xanh ngọc
##   bích sáng, vằn zíc-zắc xanh đen sẫm nhô cao 1 lớp voxel, vệt đất vàng ngà
##   ở đáy, cuống uốn xoắn; khi chín tỏa hạt sao vàng lấp lánh.
## - 4 giai đoạn: MẦM (2 lá mầm xanh nõn) → DÂY LEO (dây bò + lá xẻ thùy + nụ)
##   → ĐƠM QUẢ NON (hoa tàn, quả nắm tay xanh nhạt chưa vằn) → CHÍN (quả to
##   căng tròn, vằn đậm rõ nét + hạt lấp lánh báo hiệu thu hoạch).

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

var _oval: bool = false
var _fruit_count: int = 1
var _glow_light: OmniLight3D = null
var _real_fruit_nodes: Array[Node3D] = []

var _sway_phase: float = 0.0
var _sway_freq: float = 0.0
var _sway_amp: float = 0.0

# Đếm voxel theo nhóm — dùng cho test
var _vox_vine: int = 0
var _vox_leaf: int = 0
var _vox_bud: int = 0
var _vox_flower: int = 0
var _vox_fruit: int = 0
var _vox_stripe: int = 0
var _vox_sparkle: int = 0

func setup() -> void:
	_oval = randf() < 0.35
	_fruit_count = 1 + randi() % 2

func _birth_span_days() -> float:
	return 20.0

func _stage_thresholds() -> Array[float]:
	return [2.0, 6.0, 13.0]

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.2 + randf() * 0.7
	_sway_amp = deg_to_rad(2.0 + randf() * 1.2)

## Chiều cao tán dây — luôn sát mặt đất, chỉ lớn theo giai đoạn.
func _get_h() -> float:
	if _stage == GrowingProp.Stage.SPROUT:
		return 0.08
	if _stage == GrowingProp.Stage.YOUNG:
		return 0.10
	return 0.14

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
	_vox_vine = 0; _vox_leaf = 0; _vox_bud = 0; _vox_flower = 0
	_vox_fruit = 0; _vox_stripe = 0; _vox_sparkle = 0

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual(_ordered.size(), 0)
		return

	_build_vines()
	_build_leaves()
	var main_count := _ordered.size()
	if _stage == GrowingProp.Stage.YOUNG:
		_build_buds()
		_commit_visual(_ordered.size(), 0)
		return
	_build_flowers()
	var flower_count := _ordered.size() - main_count
	if _stage == GrowingProp.Stage.RIPE:
		_build_ripe_fruits()
	else:
		_build_young_fruits()
	var fruit_count := _ordered.size() - main_count - flower_count
	_commit_visual(main_count, fruit_count)
	if _stage == GrowingProp.Stage.RIPE:
		_setup_glow()

## Mầm: 2 lá mầm nhỏ xanh nõn nhú lên từ đất xốp.
func _build_sprout() -> void:
	var col_stem := Color(0.16, 0.46, 0.20)
	var col_leaf := Color(0.26, 0.62, 0.26)
	for vy in range(2):
		_fill(0.0, 0.03 + vy * VOXEL, 0.0, col_stem)
	for side in [-1.0, 1.0]:
		var sx: float = side * 0.05
		_fill(sx, 0.062, 0.01, col_leaf)
		_fill(sx + side * 0.06, 0.052, 0.03, col_leaf)
		_fill(sx + side * 0.10, 0.040, 0.006, col_leaf.lightened(0.05))
		_vox_leaf += 3

## Dây leo uốn lượn bò sát đất + tua cuốn lò xo + lông tơ xám trắng.
func _build_vines() -> void:
	var col_vine := Color(0.26, 0.52, 0.22)
	var col_tip := Color(0.55, 0.68, 0.30)
	var col_tendril := Color(0.62, 0.78, 0.30)
	var col_fuzz := Color(0.86, 0.86, 0.82)

	var arm_count: int = 3 + randi() % 2
	var seed_a: float = randf() * TAU
	for ai in range(arm_count):
		var a: float = seed_a + float(ai) / float(arm_count) * TAU * 0.7 + (randf() - 0.5) * 0.7
		var dir := Vector2(cos(a), sin(a))
		var p := Vector2(0.0, 0.0)
		var segs: int = 6 + randi() % 4
		for si in range(segs):
			p += dir * 0.11
			dir = dir.rotated((randf() - 0.5) * 1.1)
			dir = dir.normalized()
			var is_tip := si >= segs - 2
			var col := col_tip if is_tip else col_vine
			col = _jitter(col)
			_fill(p.x, 0.045 + (randf() - 0.5) * 0.02, p.y, col)
			_vox_vine += 1
			# Lông tơ xám trắng điểm xuyết dọc thân dây
			if si % 2 == 0 and randf() < 0.45:
				_fill(p.x + (randf() - 0.5) * 0.05, 0.055, p.y + (randf() - 0.5) * 0.05, col_fuzz)
			# Tua cuốn lò xo xoắn ốc ở nách (gần ngọn)
			if si == segs - 3 or (si == segs - 5 and randf() < 0.5):
				_build_tendril(p, a + randf() * 0.6, col_tendril)

## Tua cuốn: xoắn ốc mảnh gồm 4-5 micro-voxel rủ nhẹ xuống mặt đất.
func _build_tendril(at: Vector2, ang: float, col: Color) -> void:
	var base_y := 0.05
	for ti in range(5):
		var t := float(ti) / 4.0
		var spiral := ang + t * 4.2
		var r: float = 0.012 + t * 0.016
		_fill(at.x + cos(spiral) * r, base_y - t * 0.022, at.y + sin(spiral) * r, col)

## Lá to xẻ thùy sâu 3-5 nhánh bo tròn đầu, xanh lục tươi, gân xanh nhạt.
func _build_leaves() -> void:
	var col_leaf := Color(0.20, 0.50, 0.18)
	var col_leaf_dark := Color(0.14, 0.40, 0.14)
	var col_vein := Color(0.42, 0.66, 0.30)
	var is_young := _stage == GrowingProp.Stage.YOUNG

	var leaf_count: int = (5 + randi() % 3) if is_young else (8 + randi() % 3)
	var seed_a: float = randf() * TAU
	for li in range(leaf_count):
		var la: float = seed_a + float(li) / float(leaf_count) * TAU + (randf() - 0.5) * 0.8
		var dir := Vector2(cos(la), sin(la))
		var perp := Vector2(-sin(la), cos(la))
		var base := Vector2(0.0, 0.0)
		var len: int = (5 + randi() % 2) if is_young else (7 + randi() % 2)
		var lobes: int = 3 + randi() % 3
		var leaf_y: float = 0.062 + randf() * 0.03
		for li2 in range(lobes):
			var lobe_dir := dir.rotated((float(li2) / float(lobes - 1) - 0.5) * 1.5 + (randf() - 0.5) * 0.3)
			var lobe_len: int = len - (0 if li2 in [0, lobes - 1] else 1 + randi() % 2)
			var tip := base + lobe_dir * float(lobe_len) * VOXEL * 1.5
			var step_dir := (tip - base) / float(lobe_len)
			for i in range(1, lobe_len + 1):
				var pv := base + step_dir * float(i)
				var w: float = 0.045 * (1.0 - float(i) / float(lobe_len) * 0.72)
				for j in range(-2, 3):
					var off := perp * (float(j) * VOXEL * 0.55 * (w / 0.045))
					var col := col_leaf
					if j == 0:
						col = col_vein
					elif abs(j) == 2 and i % 3 == 0:
						col = col_leaf_dark
					col = _jitter(col)
					_fill(pv.x + off.x, leaf_y + sin(float(i) * 0.8) * VOXEL * 0.4, pv.y + off.y, col)
					_vox_leaf += 1
				# Đầu nhánh bo tròn
				if i == lobe_len:
					_fill(tip.x + perp.x * 0.02, leaf_y + 0.01, tip.y + perp.y * 0.02, col_leaf.lightened(0.04))
					_vox_leaf += 1

## Nụ hoa vàng nhỏ ở nách lá (giai đoạn DÂY LEO).
func _build_buds() -> void:
	var col_bud := Color(0.85, 0.78, 0.25)
	var col_bud_dark := Color(0.66, 0.58, 0.16)
	var bud_count: int = 3 + randi() % 2
	var seed_a: float = randf() * TAU
	for bi in range(bud_count):
		var ba: float = seed_a + float(bi) / float(bud_count) * TAU + (randf() - 0.5) * 0.5
		var r: float = 0.16 + randf() * 0.10
		var pos := Vector3(cos(ba) * r, 0.06, sin(ba) * r)
		_fill(pos.x, pos.y, pos.z, col_bud)
		_fill(pos.x + 0.02, pos.y + 0.02, pos.z + 0.01, col_bud.lightened(0.06))
		_fill(pos.x - 0.015, pos.y + 0.03, pos.z - 0.02, col_bud_dark)
		_vox_bud += 3

## Hoa sao 5 cánh vàng chanh rực rỡ + nhụy vàng cam mộng nước.
func _build_flowers() -> void:
	var col_petal := Color(0.96, 0.90, 0.26)
	var col_petal_tip := Color(0.98, 0.94, 0.40)
	var col_stamen := Color(0.98, 0.70, 0.14)
	var flower_count: int = 2 + randi() % 2
	var seed_a: float = randf() * TAU
	for fi in range(flower_count):
		var fa: float = seed_a + float(fi) / float(flower_count) * TAU + (randf() - 0.5) * 0.6
		var r: float = 0.16 + randf() * 0.10
		var center := Vector3(cos(fa) * r, 0.075, sin(fa) * r)
		var tilt: float = (randf() - 0.5) * 0.6
		for p in range(5):
			var pa: float = fa + float(p) * TAU / 5.0 + tilt
			for pi in range(2):
				var d := Vector3(cos(pa) * 0.06, 0.015, sin(pa) * 0.06) * float(pi + 1)
				var col := col_petal if pi == 0 else col_petal_tip
				col = _jitter(col)
				_fill(center.x + d.x, center.y + d.y + float(pi) * 0.01, center.z + d.z, col)
				_vox_flower += 1
		_fill(center.x, center.y + 0.045, center.z, col_stamen)
		_vox_flower += 1

## Quả non (nắm tay, xanh nhạt chưa rõ vằn) — giai đoạn ĐƠM QUẢ NON.
func _build_young_fruits() -> void:
	var col_skin := Color(0.52, 0.68, 0.34)
	var col_skin_d := Color(0.40, 0.54, 0.26)
	for fi in range(_fruit_count):
		var fa: float = randf() * TAU
		var r: float = 0.10 + randf() * 0.06
		var center := Vector3(cos(fa) * r, 0.075, sin(fa) * r)
		_build_ball(center, 0.090 + randf() * 0.015, col_skin, col_skin_d, false, 0.0, Color.WHITE)

## Quả chín: mỗi trái dưa to đặt LỆCH khỏi gốc dây (gần đó) + sợi dây bò nối
## từ gốc đến trái — dưa hấu mọc gần nguồn nước, dây vươn ra đặt trái bên cạnh.
## Trái dùng chính model trái dưa hấu khi cầm/drop (to 1 block).
func _build_ripe_fruits() -> void:
	var col_sparkle := Color(0.80, 0.95, 0.65)
	var col_stripe := Color(0.08, 0.32, 0.18)
	for fi in range(_fruit_count):
		var fa: float = randf() * TAU
		var dist: float = 0.55 + randf() * 0.45
		var fruit_pos := Vector3(cos(fa) * dist, 0.085, sin(fa) * dist)
		_build_fruit_strand(fruit_pos, fa)
		_add_ground(ItemMesh.add_fruit_on_ground(
			self, "watermelon", 0.8,
			Vector3(fruit_pos.x, 0.05, fruit_pos.z), randf() * TAU))
		_build_sparkles(fruit_pos, col_sparkle)
		_build_stalk(fruit_pos, col_stripe.darkened(0.4))

## Sợi dây bò từ gốc ra đến quả — uốn lượn sát mặt đất, khớp đúng 2 đầu.
## Dây nối vẽ LIÊN TỤC (không đứt khúc) + dày 3 micro-voxel + màu sáng
## tương phản để nhìn rõ dây dẫn từ cây ra trái.
func _build_fruit_strand(target: Vector3, ang: float) -> void:
	var col := Color(0.58, 0.70, 0.20)
	var col_edge := Color(0.40, 0.54, 0.14)
	var dist := target.length()
	var steps: int = maxi(6, int(dist / (VOXEL * 1.5)))
	var perp := Vector3(-sin(ang), 0.0, cos(ang))
	var prev := Vector3.ZERO
	for si in range(1, steps + 1):
		var t := float(si) / float(steps)
		var wob := sin(t * 5.0 + ang) * 0.05 * sin(t * PI)
		var cur := target * t + perp * wob
		var mid := (prev + cur) * 0.5
		_fill(mid.x, 0.055, mid.z, col)
		_fill(cur.x, 0.058, cur.z, col)
		_fill(mid.x + perp.x * 0.03, 0.050, mid.z + perp.z * 0.03, col_edge)
		_fill(mid.x - perp.x * 0.03, 0.050, mid.z - perp.z * 0.03, col_edge)
		_vox_vine += 4
		prev = cur

## Khối cầu (bầu dục) vỏ dưa + vằn zíc-zắc nhô cao 1 lớp voxel (bám sát mặt quả).
func _build_ball(center: Vector3, rx: float, skin: Color, skin_d: Color,
		striped: bool, ry_in: float, stripe_col: Color) -> void:
	var ry: float = ry_in if ry_in > 0.0 else rx
	var b := ceili(maxf(rx, ry) / VOXEL)
	var fruit_start := _ordered.size()
	for vx in range(-b, b + 1):
		for vy in range(-b, b + 1):
			for vz in range(-b, b + 1):
				var px := vx * VOXEL; var py := vy * VOXEL; var pz := vz * VOXEL
				var dx := px / rx; var dy := py / ry; var dz := pz / rx
				var d_sq := dx * dx + dy * dy + dz * dz
				if d_sq > 1.0:
					continue
				var on_surface := d_sq > 0.62
				var col := skin
				if py < -ry * 0.6:
					col = skin_d
				if striped and on_surface:
					var phi := atan2(pz, px)
					var t := dy
					if sin(phi * 5.0 + sin(t * 6.0) * 0.35) > 0.72:
						col = stripe_col
				col = _jitter(col)
				_fill(center.x + px, center.y + py, center.z + pz, col)
				_vox_fruit += 1
	# Vằn zíc-zắc nhô cao 1 lớp voxel dọc theo vòng kinh tuyến trên mặt quả
	if striped:
		var ball_end := _ordered.size()
		for i in range(fruit_start, ball_end):
			var v: Vector3 = _ordered[i]
			var dx := v.x - center.x
			var dy := v.y - center.y
			var dz := v.z - center.z
			var phi := atan2(dz, dx)
			var ty := dy / ry
			if sin(phi * 6.0 + sin(ty * 6.0) * 0.35) <= 0.15:
				continue
			var norm := Vector3(dx, dy, dz)
			if norm.length() < 0.01:
				continue
			norm = norm.normalized()
			var raised := _pos(v + norm * VOXEL)
			_add_voxel(raised, stripe_col * _DARKEN)
			_vox_fruit += 1
			_vox_stripe += 1

## Vệt đất vàng ngà ở đáy quả tiếp xúc mặt đất.
func _build_soil_spot(center: Vector3, rx: float, col: Color) -> void:
	for sx in range(-2, 3):
		for sz in range(-2, 3):
			var d := sqrt(float(sx * sx + sz * sz))
			if d > 2.0:
				continue
			var px := center.x + float(sx) * VOXEL * 1.4
			var pz := center.z + float(sz) * VOXEL * 1.4
			_fill(px, center.y - rx * 0.9, pz, col)

## Cuống nhỏ uốn xoắn màu xanh nâu khô nhô lên đỉnh quả.
func _build_stalk(center: Vector3, col: Color) -> void:
	var ang := randf() * TAU
	var prev := Vector3(center.x, center.y + 0.10, center.z)
	for si in range(3):
		var na := ang + float(si) * 0.9
		var nx := prev.x + cos(na) * 0.02
		var nz := prev.z + sin(na) * 0.02
		var ny := prev.y + 0.028
		_fill(nx, ny, nz, col)
		prev = Vector3(nx, ny, nz)

## Hạt sao vàng lấp lánh tỏa quanh quả chín.
func _build_sparkles(center: Vector3, col: Color) -> void:
	var n: int = 3 + randi() % 2
	for si in range(n):
		var sa: float = randf() * TAU
		var sr: float = 0.16 + randf() * 0.10
		var sy: float = 0.10 + randf() * 0.10
		_fill(center.x + cos(sa) * sr, sy, center.z + sin(sa) * sr, col)
		_vox_sparkle += 1

## Ánh sáng vàng dịu báo hiệu quả chín.
func _setup_glow() -> void:
	if _glow_light != null:
		return
	_glow_light = OmniLight3D.new()
	_glow_light.name = "WatermelonGlow"
	_glow_light.light_color = Color(0.90, 0.85, 0.45)
	_glow_light.omni_range = 1.3
	_glow_light.light_energy = 0.30
	_glow_light.light_specular = 0.0
	_glow_light.shadow_enabled = false
	_glow_light.position = Vector3(0.0, 0.25, 0.0)
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
		mmi.name = "WatermelonVineVisual"
		add_child(mmi)

	if fruit_count > 0:
		var fruit_cube := BoxMesh.new()
		fruit_cube.size = Vector3(VOXEL, VOXEL, VOXEL)
		var fruit_mat := StandardMaterial3D.new()
		fruit_mat.vertex_color_use_as_albedo = true
		fruit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fruit_mat.metallic = 0.0
		fruit_mat.roughness = 0.30
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
		fruit_mmi.name = "WatermelonFruitVisual"
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

## Chỉ chặt khi CHÍN mới rơi trái — chặt non không được mùa.
func spawn_drop() -> void:
	if _stage != GrowingProp.Stage.RIPE:
		return
	super.spawn_drop()

func _on_destroy() -> void:
	super._on_destroy()
	if _stage != GrowingProp.Stage.RIPE:
		return
	var world := _find_world_manager()
	if world == null:
		return
	_ItemDatabase.ensure_db()
	var fruit_def: ItemDef = _ItemDatabase.items_db.get("watermelon")
	if fruit_def:
		_DroppedItem.spawn(world, fruit_def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)
	var seed_def: ItemDef = _ItemDatabase.items_db.get("watermelon_seed")
	if seed_def:
		_DroppedItem.spawn(world, seed_def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)

## ── SWAY ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_usec() * 0.000001
	# Dây leo rung lắc theo 2 harmonic cho sinh động hơn.
	rotation.y = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.6 + _sway_phase * 1.3 + 0.9) * 0.3) * _sway_amp

## ── COLLISION ───────────────────────────────────────────────────────────────

func _setup_collision() -> void:
	var h := _get_h()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.52
	shape.height = maxf(h, 0.10) + 0.12
	col.shape = shape
	col.position.y = shape.height * 0.5
	body.add_child(col)
	add_child(body)

## ── HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) ───────────

func _hit_flash() -> void:
	for name in ["WatermelonVineVisual", "WatermelonFruitVisual"]:
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

func _add_ground(n: Node3D) -> void:
	if n != null:
		_real_fruit_nodes.append(n)
