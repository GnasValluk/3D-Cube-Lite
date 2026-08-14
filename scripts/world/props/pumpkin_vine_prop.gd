class_name PumpkinVineProp
extends GrowingProp

## Cây bí đỏ — dây bò thô mộc (dày hơn dây dưa hấu), phủ rộng ô nông trại,
## theo đặc tả:
## - Thân dây 5 cạnh (pentagonal) uốn lượn bò sát đất, dọc cạnh có gai nhám
##   micro-voxel màu xám ngà; tua cuốn xoắn ốc xanh chuối nõn.
## - Lá to bản hình tim (tim/ chẻ nông chân vịt) vươn cao che mát gốc: mặt
##   trên xanh lục thẫm, gân lá chính xanh lá mạ nhô nổi.
## - Hoa loa đài (kèn) to vượt trội: cánh xếp nếp vàng cam rực rỡ, cột nhụy
##   tròn phủ hạt vàng mộng nước.
## - Quả cầu dẹp nhẹ hai đầu, 8-10 múi khía dọc rãnh sâu: khi non xanh lục
##   sẫm, khi chín cam cháy ấm + vệt xanh chuyển sắc quanh cuống + cuống gỗ
##   5 góc nâu đất pha xanh rêu; chín tỏa hạt sao vàng lấp lánh.
## - 4 giai đoạn: MẦM (2 lá mầm to xanh nõn) → DÂY LEO & HOA (dây bò + lá tim
##   + hoa loa đài vàng cam) → QUẢ NON (hoa tàn, quả xanh sẫm, múi bắt đầu
##   xuất hiện) → THU HOẠCH (quả cam cháy căng mộng, cuống hóa gỗ + lấp lánh).

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _fruit_count: int = 1
var _glow_light: OmniLight3D = null
var _real_fruit_nodes: Array[Node3D] = []

var _sway_phase: float = 0.0
var _sway_freq: float = 0.0
var _sway_amp: float = 0.0

# Đếm voxel theo nhóm — dùng cho test
var _vox_vine: int = 0
var _vox_leaf: int = 0
var _vox_flower: int = 0
var _vox_fruit: int = 0
var _vox_rib: int = 0
var _vox_sparkle: int = 0

func setup() -> void:
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
	_vox_vine = 0; _vox_leaf = 0; _vox_flower = 0
	_vox_fruit = 0; _vox_rib = 0; _vox_sparkle = 0

	if _stage == GrowingProp.Stage.SPROUT:
		_build_sprout()
		_commit_visual(_ordered.size(), 0)
		return

	_build_vines()
	_build_leaves()
	var main_count := _ordered.size()
	if _stage == GrowingProp.Stage.YOUNG:
		_build_flowers()
		_commit_visual(_ordered.size(), 0)
		return
	if _stage == GrowingProp.Stage.RIPE:
		_build_ripe_pumpkins()
		_build_sparkles()
	else:
		_build_pumpkins(true)
	var fruit_count := _ordered.size() - main_count
	_commit_visual(main_count, fruit_count)
	if _stage == GrowingProp.Stage.RIPE:
		_setup_glow()

## Mầm: 2 lá mầm TO xanh nõn nhú thẳng lên từ lòng đất.
func _build_sprout() -> void:
	var col_stem := Color(0.42, 0.60, 0.16)
	var col_leaf := Color(0.50, 0.70, 0.20)
	for vy in range(3):
		_fill(0.0, 0.02 + vy * VOXEL, 0.0, col_stem)
	for side in [-1.0, 1.0]:
		var sx: float = side * 0.06
		_fill(sx, 0.068, 0.01, col_leaf)
		_fill(sx + side * 0.07, 0.056, 0.03, col_leaf)
		_fill(sx + side * 0.12, 0.042, 0.004, col_leaf.lightened(0.05))
		_fill(sx + side * 0.16, 0.030, -0.006, col_leaf.lightened(0.08))
		_vox_leaf += 4

## Dây leo 5 cạnh thô mộc uốn lượn bò sát đất + gai nhám xám ngà dọc cạnh +
## tua cuốn xoắn ốc xanh chuối nõn.
func _build_vines() -> void:
	var col_vine := Color(0.46, 0.60, 0.16)
	var col_tip := Color(0.62, 0.72, 0.22)
	var col_prickle := Color(0.82, 0.82, 0.78)
	var col_tendril := Color(0.68, 0.78, 0.26)

	var arm_count: int = 3 + randi() % 2
	var seed_a: float = randf() * TAU
	for ai in range(arm_count):
		var a: float = seed_a + float(ai) / float(arm_count) * TAU * 0.7 + (randf() - 0.5) * 0.7
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var p := Vector2(0.0, 0.0)
		var segs: int = 6 + randi() % 4
		for si in range(segs):
			p += dir * 0.10
			dir = dir.rotated((randf() - 0.5) * 1.1)
			dir = dir.normalized()
			var is_tip := si >= segs - 2
			var col := col_tip if is_tip else col_vine
			_build_vine_seg(p, dir, col)
			# Gai nhám xám ngà nhô ra dọc cạnh dây
			if randf() < 0.45:
				var ga: float = randf() * TAU
				_fill(p.x + cos(ga) * 0.085, 0.06, p.y + sin(ga) * 0.085, col_prickle)
				_vox_vine += 1
			# Tua cuốn xoắn ốc ở nách (gần ngọn)
			if si == segs - 3 or (si == segs - 5 and randf() < 0.5):
				_build_tendril(p, a + randf() * 0.6, col_tendril)

## Đốt dây: lõi + 5 cạnh hình ngũ giác xoay theo hướng bò (thân 5 cạnh góc cạnh).
func _build_vine_seg(at: Vector2, dir: Vector2, col: Color) -> void:
	var base_a: float = atan2(dir.y, dir.x)
	_fill(at.x, 0.042, at.y, _jitter(col))
	_vox_vine += 1
	for i in range(5):
		var a: float = base_a + PI * 0.5 + float(i) * TAU / 5.0
		_fill(at.x + cos(a) * 0.048, 0.045 + (randf() - 0.5) * 0.012, at.y + sin(a) * 0.048, _jitter(col))
		_vox_vine += 1

## Tua cuốn: xoắn ốc mảnh gồm 5 micro-voxel rủ nhẹ xuống mặt đất.
func _build_tendril(at: Vector2, ang: float, col: Color) -> void:
	var base_y := 0.05
	for ti in range(5):
		var t := float(ti) / 4.0
		var spiral := ang + t * 4.2
		var r: float = 0.012 + t * 0.016
		_fill(at.x + cos(spiral) * r, base_y - t * 0.022, at.y + sin(spiral) * r, col)
		_vox_vine += 1

## Lá to bản hình tim (chân vịt chẻ nông) vươn cao khỏi mặt đất che mát gốc:
## mặt trên xanh lục thẫm, gân chính xanh lá mạ nhô nổi.
func _build_leaves() -> void:
	var col_leaf := Color(0.40, 0.58, 0.14)
	var col_leaf_l := Color(0.54, 0.68, 0.18)
	var col_vein := Color(0.72, 0.78, 0.26)
	var is_young := _stage == GrowingProp.Stage.YOUNG

	var leaf_count: int = (4 + randi() % 2) if is_young else (5 + randi() % 2)
	var seed_a: float = randf() * TAU
	for li in range(leaf_count):
		var la: float = seed_a + float(li) / float(leaf_count) * TAU + (randf() - 0.5) * 0.8
		var scale: float = (0.075 + randf() * 0.02) if is_young else (0.095 + randf() * 0.025)
		var center := Vector3(cos(la) * 0.16, 0.05, sin(la) * 0.16)
		_build_leaf_heart(center, la, scale, col_leaf, col_leaf_l, col_vein)

## Lá hình tim: khuyết ở đỉnh, nhọn dần về cuống (gốc dây) — tả bằng phương
## trình polar r(θ)=1−sin(θ) lưới 36 tia; gân chính + gân phụ nhô nổi mặt trên.
func _build_leaf_heart(center: Vector3, ang: float, scale: float,
		col: Color, col_l: Color, vein: Color) -> void:
	var steps := 36
	for i in range(steps):
		var a := float(i) / float(steps) * TAU
		var r_max: float = (1.0 - sin(a)) * scale
		if r_max < 0.012:
			continue
		var n: int = int(r_max / VOXEL) + 1
		for ri in range(n):
			var rad := (float(ri) + 0.5) * VOXEL
			var lift := 0.052 * (1.0 - rad / r_max)
			var lx := cos(a) * rad
			var lz := sin(a) * rad
			var rot: Vector2 = Vector2(lx * cos(-ang) - lz * sin(-ang), lx * sin(-ang) + lz * cos(-ang))
			var c := col
			if rad > r_max * 0.72:
				c = col_l
			c = _jitter(c)
			_fill(center.x + rot.x, center.y + lift, center.z + rot.y, c)
			_vox_leaf += 1
	# Gân chính: từ đuôi lá (gần cuống) lên tâm lá — nhô cao 1 lớp voxel
	var vein_steps := 4
	for vi in range(vein_steps):
		var t := float(vi) / float(vein_steps - 1)
		var vx: float = lerp(0.0, -scale * 1.5, t)
		var vy := center.y + 0.040 + float(vi) * 0.004
		var rot: Vector2 = Vector2(vx * cos(-ang), vx * sin(-ang))
		_fill(center.x + rot.x, vy, center.z + rot.y, _jitter(vein))
		_vox_leaf += 1
	# Gân phụ xòe sang hai thùy lá
	for side in [-1.0, 1.0]:
		var s1 := Vector2(-scale * 0.7, side * scale * 0.42)
		var r1: Vector2 = Vector2(s1.x * cos(-ang) - s1.y * sin(-ang), s1.x * sin(-ang) + s1.y * cos(-ang))
		_fill(center.x + r1.x, center.y + 0.052, center.z + r1.y, _jitter(vein))
		var s2 := Vector2(-scale * 1.0, side * scale * 0.62)
		var r2: Vector2 = Vector2(s2.x * cos(-ang) - s2.y * sin(-ang), s2.x * sin(-ang) + s2.y * cos(-ang))
		_fill(center.x + r2.x, center.y + 0.048, center.z + r2.y, _jitter(vein.darkened(0.1)))
		_vox_leaf += 2

## Hoa loa đài (kèn) to: ống kèn + vành loa xếp nếp 5 cánh vàng cam rực rỡ,
## cột nhụy tròn phủ hạt vàng mộng nước ở trung tâm.
func _build_flowers() -> void:
	var col_tube := Color(0.92, 0.58, 0.12)
	var col_rim := Color(0.98, 0.72, 0.18)
	var col_stamen := Color(0.96, 0.80, 0.14)
	var flower_count: int = 1 + randi() % 2
	var seed_a: float = randf() * TAU
	for fi in range(flower_count):
		var fa: float = seed_a + float(fi) / float(flower_count) * TAU + (randf() - 0.5) * 0.6
		var r: float = 0.18 + randf() * 0.10
		var center := Vector3(cos(fa) * r, 0.045, sin(fa) * r)
		_build_trumpet(center, fa + PI * 0.5, col_tube, col_rim, col_stamen)

## Ống kèn loa: 5 tầng miệng mở rộng dần + vành loa xếp nếp 5 cánh + cột nhụy.
func _build_trumpet(center: Vector3, tilt_ang: float,
		col_tube: Color, col_rim: Color, col_stamen: Color) -> void:
	var rings := 5
	for ly in range(rings):
		var t := float(ly) / float(rings - 1)
		var rad: float = 0.024 + t * t * 0.058
		var y := float(ly) * VOXEL
		var c := col_tube.lerp(col_rim, t)
		if ly < rings - 1:
			for a in range(14):
				var ang := float(a) / 14.0 * TAU
				_fill(center.x + cos(ang) * rad, center.y + y, center.z + sin(ang) * rad, _jitter(c))
				_vox_flower += 1
		else:
			# Vành loa xếp nếp 5 cánh uốn lượn
			for a in range(26):
				var ang := float(a) / 26.0 * TAU
				var sc := 0.014 * maxf(0.0, sin(ang * 2.5 + 0.5) + 0.6)
				_fill(center.x + cos(ang) * (rad + sc), center.y + y, center.z + sin(ang) * (rad + sc), _jitter(c))
				_vox_flower += 1
	# Cột nhụy tròn + hạt vàng mộng nước
	var st_y := float(rings) * VOXEL
	_fill(center.x, center.y + st_y, center.z, col_stamen)
	_fill(center.x, center.y + st_y + 0.02, center.z, col_stamen.lightened(0.06))
	_vox_flower += 2
	for i in range(6):
		var ga: float = randf() * TAU
		_fill(center.x + cos(ga) * 0.032, center.y + st_y + randf() * 0.03, center.z + sin(ga) * 0.032,
			col_stamen.lightened(0.12))
		_vox_flower += 1

## Quả bí: cầu dẹp nhẹ hai đầu + 8-10 múi khía dọc rãnh sâu (múi nhô cao,
## rãnh sẫm màu) + cuống gỗ 5 góc; green=true → quả non xanh lục sẫm,
## green=false → quả chín cam cháy + vệt xanh chuyển sắc quanh cuống.
## Quả bí chín: mỗi trái to đặt LỆCH khỏi gốc dây (gần đó) + sợi dây bò nối
## từ gốc đến trái — bí đỏ mọc xa nguồn nước, dây vươn xa đặt trái bên cạnh.
## Trái dùng chính model trái bí đỏ khi cầm/drop (to 1 block).
func _build_ripe_pumpkins() -> void:
	for fi in range(_fruit_count):
		var fa: float = randf() * TAU
		var dist: float = 0.60 + randf() * 0.50
		var fruit_pos := Vector3(cos(fa) * dist, 0.075, sin(fa) * dist)
		_build_fruit_strand(fruit_pos, fa)
		_add_ground(ItemMesh.add_fruit_on_ground(
			self, "pumpkin", 0.8,
			Vector3(fruit_pos.x, 0.05, fruit_pos.z), randf() * TAU))

## Sợi dây bò từ gốc ra đến quả — uốn lượn sát mặt đất, khớp đúng 2 đầu.
## Dây nối vẽ LIÊN TỤC (không đứt khúc) + dày 3 micro-voxel + màu vàng xanh
## tương phản để nhìn rõ dây dẫn từ cây ra trái.
func _build_fruit_strand(target: Vector3, ang: float) -> void:
	var col := Color(0.62, 0.72, 0.20)
	var col_edge := Color(0.44, 0.56, 0.14)
	var dist := target.length()
	var steps: int = maxi(6, int(dist / (VOXEL * 1.5)))
	var perp := Vector3(-sin(ang), 0.0, cos(ang))
	var prev := Vector3.ZERO
	for si in range(1, steps + 1):
		var t := float(si) / float(steps)
		var wob := sin(t * 5.0 + ang) * 0.05 * sin(t * PI)
		var cur := target * t + perp * wob
		var mid := (prev + cur) * 0.5
		# Lõi dây liên tục — mỗi đoạn đều có voxel nên không bị hụt
		_fill(mid.x, 0.055, mid.z, col)
		_fill(cur.x, 0.058, cur.z, col)
		# Hai mép dây sẫm hơn tạo bề dày rõ nét
		_fill(mid.x + perp.x * 0.03, 0.050, mid.z + perp.z * 0.03, col_edge)
		_fill(mid.x - perp.x * 0.03, 0.050, mid.z - perp.z * 0.03, col_edge)
		_vox_vine += 4
		prev = cur

func _build_pumpkins(green: bool) -> void:
	var col_skin := Color(0.20, 0.42, 0.16) if green else Color(0.88, 0.48, 0.12)
	var col_groove := Color(0.13, 0.30, 0.12) if green else Color(0.62, 0.30, 0.07)
	var col_top := Color(0.30, 0.48, 0.20)
	var col_stem := Color(0.36, 0.28, 0.13)
	for fi in range(_fruit_count):
		var fa: float = randf() * TAU
		var r: float = 0.14 + randf() * 0.08
		var center := Vector3(cos(fa) * r, 0.075, sin(fa) * r)
		var rx: float = (0.085 + randf() * 0.02) if green else (0.135 + randf() * 0.025)
		var ry: float = rx * (0.78 + randf() * 0.08)
		_build_pumpkin(center, rx, ry, col_skin, col_groove, col_top, col_stem, green)

## Khối cầu dẹp: vẽ mặt quả + múi khía nhô cao (rãnh sâu) + gradient đỉnh +
## cuống gỗ 5 góc hơi uốn cong.
func _build_pumpkin(center: Vector3, rx: float, ry: float,
		skin: Color, groove: Color, col_top: Color, col_stem: Color, green: bool) -> void:
	var b := ceili(rx / VOXEL)
	var ribs: int = 9 + randi() % 3
	var fruit_start := _ordered.size()
	for vx in range(-b, b + 1):
		for vy in range(-b, b + 1):
			for vz in range(-b, b + 1):
				var px := vx * VOXEL; var py := vy * VOXEL; var pz := vz * VOXEL
				var dx := px / rx; var dy := py / ry; var dz := pz / rx
				var d_sq := dx * dx + dy * dy + dz * dz
				if d_sq > 1.0:
					continue
				var on_surface := d_sq > 0.55
				var col := skin
				if on_surface:
					var phi := atan2(dz, dx)
					var frac := fposmod(phi * float(ribs) / TAU, 1.0)
					# Rãnh giữa hai múi — sẫm màu
					if frac < 0.10 or frac > 0.90:
						col = groove
					# Đỉnh quả: vệt xanh lục chuyển sắc (quả chín)
					if not green and py > ry * 0.42:
						var g: float = clampf((py - ry * 0.42) / (ry * 0.5), 0.0, 1.0)
						col = col.lerp(col_top, g * 0.65)
				col = _jitter(col)
				_fill(center.x + px, center.y + py, center.z + pz, col)
				_vox_fruit += 1
				# Múi khía nhô cao 1 lớp voxel — rãnh sâu rõ nét
				if on_surface:
					var phi := atan2(pz, px)
					var frac := fposmod(phi * float(ribs) / TAU, 1.0)
					var in_rib := frac > 0.10 and frac < 0.90
					if green:
						in_rib = frac > 0.25 and frac < 0.75 and randf() < 0.5
					if in_rib:
						var norm := Vector3(dx, dy, dz)
						if norm.length() < 0.01:
							continue
						norm = norm.normalized()
						var raised := _pos(Vector3(center.x + px, center.y + py, center.z + pz) + norm * VOXEL)
						_add_voxel(raised, col * 0.88)
						_vox_fruit += 1
						_vox_rib += 1
	# Cuống gỗ 5 góc hơi uốn cong cắm vào đỉnh quả (quả chín)
	if not green:
		var stem_base := Vector3(center.x, center.y + ry * 0.92, center.z)
		var prev := stem_base
		for si in range(3):
			var a: float = float(si) * 0.5 + 0.2
			var nx := prev.x + cos(a) * 0.018
			var nz := prev.z + sin(a) * 0.018
			var ny := prev.y + 0.030
			for i in range(5):
				var sa: float = a + float(i) * TAU / 5.0
				var col_s := col_stem if si > 0 else col_stem.lightened(0.06)
				_fill(nx + cos(sa) * 0.034, ny, nz + sin(sa) * 0.034, _jitter(col_s))
				_vox_fruit += 1
			_fill(nx, ny, nz, col_stem.darkened(0.08))
			_vox_fruit += 1
			prev = Vector3(nx, ny, nz)

## Hạt sao vàng lấp lánh tỏa quanh quả chín.
func _build_sparkles() -> void:
	var col := Color(0.98, 0.85, 0.35)
	var n: int = 3 + randi() % 2
	for si in range(n):
		var sa: float = randf() * TAU
		var sr: float = 0.18 + randf() * 0.12
		var sy: float = 0.10 + randf() * 0.10
		_fill(cos(sa) * sr, sy, sin(sa) * sr, col)
		_vox_sparkle += 1

## Ánh sáng vàng ấm báo hiệu quả chín.
func _setup_glow() -> void:
	if _glow_light != null:
		return
	_glow_light = OmniLight3D.new()
	_glow_light.name = "PumpkinGlow"
	_glow_light.light_color = Color(0.95, 0.75, 0.30)
	_glow_light.omni_range = 1.3
	_glow_light.light_energy = 0.35
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
		mmi.name = "PumpkinVineVisual"
		add_child(mmi)

	if fruit_count > 0:
		var fruit_cube := BoxMesh.new()
		fruit_cube.size = Vector3(VOXEL, VOXEL, VOXEL)
		var fruit_mat := StandardMaterial3D.new()
		fruit_mat.vertex_color_use_as_albedo = true
		fruit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fruit_mat.metallic = 0.0
		fruit_mat.roughness = 0.40
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
		fruit_mmi.name = "PumpkinFruitVisual"
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

## Chỉ chặt khi THU HOẠCH (chín) mới rơi trái — chặt non không được mùa.
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
	var fruit_def: ItemDef = _ItemDatabase.items_db.get("pumpkin")
	if fruit_def:
		_DroppedItem.spawn(world, fruit_def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)
	var seed_def: ItemDef = _ItemDatabase.items_db.get("pumpkin_seed")
	if seed_def:
		_DroppedItem.spawn(world, seed_def, global_position, 1,
			_spawn_drop_velocity(), global_position.y)

## ── SWAY ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not _VoxelShared.sway_active(global_position, 40.0):
		return
	var t := _VoxelShared.time_sec()
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
	for name in ["PumpkinVineVisual", "PumpkinFruitVisual"]:
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
