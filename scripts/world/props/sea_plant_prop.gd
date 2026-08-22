class_name SeaPlantProp
extends DestroyableProp

## Cây biển nhiều loài — san hô, san hô não, hải miên ống, tảo bẹ, quạt biển,
## hải quỳ. Mọc dưới đáy biển nông (OCEAN_DEEP), màu sắc rực rỡ, mỗi loài rơi
## item riêng khi chặt. Không có giai đoạn lớn (không phải GrowingProp).

const VOXEL: float = 0.25
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var plant_type: String = "coral"
var seed_h1: int = 0
var seed_h2: int = 0
var water_gap: float = 3.0

var _sway_phase: float = 0.0
var _sway_freq: float = 0.0
var _sway_amp: float = 0.0

func setup(type: String, h1: int, h2: int, wg: float = 3.0) -> void:
	plant_type = type
	seed_h1 = h1
	seed_h2 = h2
	water_gap = wg

func _ready() -> void:
	is_plant = true
	super._ready()
	build(self, plant_type, seed_h1, seed_h2, water_gap)
	if plant_type == "anemone":
		_build_anemone_base()
	# Mỗi cây xoay + to/nhỏ khác nhau — dựa seed thế giới nên ổn định giữa chunk
	var s: int = seed_h1 * 48271 + seed_h2
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	var yaw := (float(s & 0x7FFFFFFF) / 2147483648.0) * TAU
	var sz := 0.82 + (float((s >> 8) & 0x7FFFFFFF) / 2147483648.0) * 0.36
	rotation.y = yaw
	scale = Vector3.ONE * sz
	# Mỗi cây rung lắc riêng — nhịp chậm, biên độ nhỏ (dòng nước nhẹ)
	s = (s >> 3) * 1103515245 + 12345
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	_sway_phase = (float(s & 0x7FFFFFFF) / 2147483648.0) * TAU
	_sway_freq = 0.35 + (float((s >> 5) & 0x7FFFFFFF) / 2147483648.0) * 0.40
	_sway_amp = deg_to_rad(0.6 + (float((s >> 9) & 0x7FFFFFFF) / 2147483648.0) * 0.9)

func _process(delta: float) -> void:
	# Chỉ sway khi gần camera — hàng trăm cây biển mỗi cây tính sin/cos mỗi frame
	# là phí CPU vô ích khi ngoài tầm mắt (dưới nước, sau lưng, xa...).
	if not _VoxelShared.sway_active(global_position, 50.0):
		return
	var t := _VoxelShared.time_sec()
	var amp := _sway_amp
	rotation.x = (sin(t * _sway_freq + _sway_phase) * 0.7 + sin(t * _sway_freq * 2.3 + _sway_phase * 1.3 + 0.7) * 0.3) * amp
	rotation.z = (cos(t * _sway_freq * 0.8 + _sway_phase + 1.0) * 0.7 + cos(t * _sway_freq * 1.7 + _sway_phase + 2.2) * 0.3) * amp * 0.7

## Build mesh cho 1 loài — dùng chung cho prop thế giới và icon drop (router).
static func build(parent: Node3D, plant_type: String, h1: int, h2: int, water_gap: float = 3.0) -> void:
	match plant_type:
		"coral": _build_coral(parent, h1, h2)
		"brain_coral": _build_brain_coral(parent, h1, h2)
		"sponge": _build_sponge(parent, h1, h2)
		"kelp": _build_kelp(parent, h1, h2)
		"kelp_tall": _build_kelp_tall(parent, h1, h2, water_gap)
		"sea_fan": _build_sea_fan(parent, h1, h2)
		"anemone": _build_anemone(parent, h1, h2)
		"sea_bush": _build_sea_bush(parent, h1, h2)
		"grass_carpet": _build_grass_carpet(parent, h1, h2)
		"seaweed": _build_seaweed(parent, h1, h2)

## ── San hô cành (voxel) — nhiều nhánh cong, đầu chùm sáng ───────────────────
static func _build_coral(parent: Node3D, h1: int, h2: int) -> void:
	var positions: Array = []
	var scales: Array = []
	var colors: Array = []
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var palette: Array[Color] = [
		Color(1.00, 0.34, 0.55), Color(0.98, 0.38, 0.14), Color(0.85, 0.18, 0.26),
		Color(0.66, 0.30, 0.92), Color(1.00, 0.62, 0.16), Color(0.95, 0.26, 0.60),
	]
	var col := palette[int(cr * float(palette.size())) % palette.size()]
	var col_hi := col.lightened(0.32)
	var col_lo := col.darkened(0.24)
	var base := Vector3(0, 0.06, 0)
	var branch_count: int = 4 + (h2 & 3)
	for i in range(branch_count):
		s = s * 16807 + 1
		var ang := float(i) / float(branch_count) * TAU + (float(s & 0x7FFF) / 32768.0 - 0.5) * 0.7
		s = s * 16807 + 1
		var lean := 0.10 + (float(s & 0x7FFF) / 32768.0) * 0.30
		s = s * 16807 + 1
		var blen := 0.34 + (float(s & 0x7FFF) / 32768.0) * 0.40
		var dir := Vector3(cos(ang), 0, sin(ang))
		var steps: int = 4
		for si in range(steps):
			var t := float(si) / float(steps - 1)
			var p := base + dir * (lean + blen * t) + Vector3(0, t * blen * (0.85 + lean), 0)
			positions.append(p)
			scales.append(0.10 - t * 0.035)
			colors.append(col_lo.lerp(col_hi, t))
		var tip := base + dir * (lean + blen) + Vector3(0, blen * (0.85 + lean), 0)
		for ci in 3:
			s = s * 16807 + 1
			var to := (float(s & 0x7FFF) / 32768.0 - 0.5) * 0.10
			s = s * 16807 + 1
			var ta := (float(s & 0x7FFF) / 32768.0) * TAU
			positions.append(tip + Vector3(cos(ta) * 0.05, to, sin(ta) * 0.05))
			scales.append(_VoxelShared.FINE_SCALE)
			colors.append(col_hi.lightened(0.15))
	var mmi := _VoxelShared.build(positions, scales, colors)
	mmi.name = "CoralVisual"
	parent.add_child(mmi)

## ── San hô não — vòm cụm voxel dạng thận, màu teal/tím, sóng lăn ─────────────
static func _build_brain_coral(parent: Node3D, h1: int, h2: int) -> void:
	var positions: Array = []
	var scales: Array = []
	var colors: Array = []
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var palette: Array[Color] = [
		Color(0.35, 0.55, 0.65), Color(0.55, 0.40, 0.75), Color(0.30, 0.70, 0.62), Color(0.62, 0.48, 0.30),
	]
	var col := palette[int(cr * float(palette.size())) % palette.size()]
	var col_hi := col.lightened(0.30)
	var col_lo := col.darkened(0.28)
	var r: float = 0.42 + (h2 & 3) * 0.03
	var cx: float = 0.0
	var cy: float = 0.12
	var cz: float = 0.0
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var px := float(ix) * 0.095
			var pz := float(iz) * 0.095
			var d := sqrt(px * px + pz * pz)
			if d > r * 1.05:
				continue
			var t := d / (r * 1.05)
			var top := sqrt(maxf(0.0, 1.0 - t * t)) * r
			var ridge := 0.5 + 0.5 * sin(px * 9.0 + pz * 6.0 + float(h2 & 7))
			var y: float = cy + top * (0.55 + ridge * 0.45)
			positions.append(Vector3(cx + px, y, cz + pz))
			scales.append(0.115)
			colors.append(col_lo.lerp(col_hi, ridge))
	var mmi := _VoxelShared.build(positions, scales, colors)
	mmi.name = "BrainCoralVisual"
	parent.add_child(mmi)

## ── Hải miên ống — 2-3 ống trụ rỗng, màu vàng/cam/đỏ ─────────────────────────
static func _build_sponge(parent: Node3D, h1: int, h2: int) -> void:
	var positions: Array = []
	var scales: Array = []
	var colors: Array = []
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var palette: Array[Color] = [
		Color(0.98, 0.80, 0.25), Color(0.95, 0.55, 0.15), Color(0.85, 0.30, 0.20), Color(1.00, 0.68, 0.40),
	]
	var col := palette[int(cr * float(palette.size())) % palette.size()]
	var col_hi := col.lightened(0.28)
	var col_lo := col.darkened(0.30)
	var tubes: int = 2 + (h2 & 1)
	for ti in range(tubes):
		s = s * 16807 + 1
		var ta := (float(s & 0x7FFF) / 32768.0) * TAU
		s = s * 16807 + 1
		var tr := 0.12 + (float(s & 0x7FFF) / 32768.0) * 0.10
		var ox: float = cos(ta) * tr
		var oz: float = sin(ta) * tr
		s = s * 16807 + 1
		var th := 0.55 + (float(s & 0x7FFF) / 32768.0) * 0.55
		var steps: int = int(th / 0.11)
		for si in range(steps):
			var t := float(si) / float(steps - 1)
			var taper := 1.0 - t * 0.18
			positions.append(Vector3(ox, 0.06 + t * th, oz))
			scales.append(0.13 * taper)
			colors.append(col_lo.lerp(col_hi, t))
		positions.append(Vector3(ox, 0.06 + th, oz))
		scales.append(0.10)
		colors.append(col_hi)
	var mmi := _VoxelShared.build(positions, scales, colors)
	mmi.name = "SpongeVisual"
	parent.add_child(mmi)

## ── Tảo bẹ — lá dài đu đưa theo nước, xanh ô-liu ─────────────────────────────
static func _build_kelp(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	var col_base := Color(0.16, 0.42, 0.14)
	var col_tip := Color(0.38, 0.72, 0.24)
	var blades: int = 3 + (h2 & 1)
	var cur_dir := Vector3(0.4, 0, 0.3).normalized()
	s = s * 16807 + 1
	var lean_ang: float = (float(s & 0x7FFF) / 32768.0) * TAU
	for bi in range(blades):
		var ba: float = lean_ang + float(bi) / float(blades) * TAU * 0.6
		var origin := Vector3(cos(ba) * 0.08, 0, sin(ba) * 0.08)
		var blade_h: float = 0.9 + float((h2 >> (bi * 2)) & 3) * 0.35
		var w: float = VOXEL * 0.5
		var prev := origin
		for seg in range(4):
			var t := float(seg + 1) / 4.0
			var nxt := origin + Vector3(0, blade_h * t, 0) \
				+ cur_dir * blade_h * 0.18 * t * t * (0.5 + float(bi) * 0.3)
			var mid := (prev + nxt) * 0.5
			var dir := (nxt - prev).normalized()
			var perp := Vector3(-dir.z, 0, dir.x).normalized()
			var taper: float = 1.0 - t * 0.8
			var col := col_base.lerp(col_tip, t)
			_add_blade_quad(st, mid, perp * w * 0.5 * taper, dir * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col)
			prev = nxt
	_commit_quad_mesh(parent, st, "KelpVisual")

## ── Rong biển cao (kiểu Minecraft) — mọc thành cột cao, cao hết mức nước ─────
## Chiều cao tỉ lệ với water_gap: thân thẳng đứng, xen kẽ lá ngắn, ngọn mảnh
## đu đưa nhẹ theo dòng nước. Rơi "kelp_tall".
static func _build_kelp_tall(parent: Node3D, h1: int, h2: int, water_gap: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	var col_base := Color(0.15, 0.48, 0.14)
	var col_tip := Color(0.34, 0.74, 0.22)
	# Cột cao tới sát mặt nước (chừa 0.4 block) — như Minecraft kelp
	var max_h: float = maxf(water_gap - 0.4, 0.6)
	var segs: int = clampi(int(max_h / 0.25), 2, 32)
	s = s * 16807 + 1
	var wob := (float(s & 0x7FFF) / 32768.0) * TAU
	# Thân chính — ống 4 mặt dựng đứng, hơi vặn nhẹ
	var leaf_half: float = VOXEL * 0.42
	for seg in range(1, segs + 1):
		var t := float(seg) / float(segs)
		var prev_t := float(seg - 1) / float(segs)
		var y0: float = prev_t * max_h
		var y1: float = t * max_h
		# Vặn nhẹ quanh trục theo múa lượn
		var lean: float = sin(t * 6.0 + wob) * 0.12 * t
		var px0: float = sin(prev_t * 6.0 + wob) * 0.12 * prev_t
		var pz0: float = cos(prev_t * 6.0 + wob) * 0.12 * prev_t
		var px1: float = sin(t * 6.0 + wob) * 0.12 * t
		var pz1: float = cos(t * 6.0 + wob) * 0.12 * t
		var a := Vector3(px0, y0, pz0)
		var b := Vector3(px1, y1, pz1)
		var mid := (a + b) * 0.5
		var d := (b - a).normalized()
		var perp := Vector3(-d.z, 0, d.x).normalized()
		var taper: float = 1.0 - t * 0.55
		var sw: float = VOXEL * 0.30 * taper + 0.02
		var col := col_base.lerp(col_tip, t)
		_add_quad(st, mid, perp * sw, d * (b - a).length() * 0.5, Vector3(0, 0, 1), col * 0.85)
		_add_quad(st, mid, perp * sw, d * (b - a).length() * 0.5, Vector3(0, 0, -1), col * 0.85)
		# Từng cặp lá ngắn mọc đối — quạt ngang một nửa chu vi ở 2 bên
		if seg % 2 == 0:
			for leaf in 2:
				var la: float = (float(leaf) + float(seg % 3)) * PI + wob * 0.5
				var ldir := Vector3(cos(la), 0, sin(la))
				var lperp := Vector3(-sin(la), 0, cos(la))
				var llen: float = 0.16 + (float((s + seg * 7 + leaf) & 0xFF) / 256.0) * 0.12
				var link: Vector3 = mid + d * 0.08
				var scol := col.lerp(col_tip.lightened(0.18), t)
				_add_quad(st, link + ldir * llen * 0.5, lperp * 0.045, ldir * llen * 0.5, Vector3(0, 1, 0), scol)
	_commit_quad_mesh(parent, st, "KelpTallVisual")

## ── Quạt biển (gorgonia) — quạt nan trong mặt phẳng dọc, tím/cam ─────────────
static func _build_sea_fan(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var col := Color(0.70, 0.25, 0.82) if cr < 0.5 else Color(0.95, 0.45, 0.16)
	var col_edge := col.darkened(0.28)
	var fan_r: float = 0.42 + (h2 & 3) * 0.05
	var base := Vector3(0, 0.18, 0)
	var spokes: int = 9
	s = s * 16807 + 1
	var wob := (float(s & 0x7FFF) / 32768.0) * 0.4
	for i in range(spokes + 1):
		var t := float(i) / float(spokes)
		var ang := t * PI
		var rr := fan_r * (1.0 + sin(t * 7.0 + wob) * 0.12)
		var dir := Vector3(sin(ang), cos(ang), 0)
		var tip := base + dir * rr
		var prev := base
		for seg in range(3):
			var st_t := float(seg + 1) / 3.0
			var nxt := base + dir * rr * st_t
			var mid := (prev + nxt) * 0.5
			var d := (nxt - prev).normalized()
			var perp := Vector3(0, 0, 1)
			var col_seg := col.lerp(col_edge, st_t)
			_add_quad(st, mid, perp * 0.035, d * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col_seg)
			prev = nxt
	# Vòng cung nối đầu các nan
	var tip_pts: Array[Vector3] = []
	for i in range(spokes + 1):
		var t := float(i) / float(spokes)
		var ang := t * PI
		var rr := fan_r * (1.0 + sin(t * 7.0 + wob) * 0.12)
		tip_pts.append(base + Vector3(sin(ang), cos(ang), 0) * rr)
	for i in range(spokes):
		var a := tip_pts[i]
		var b := tip_pts[i + 1]
		var mid := (a + b) * 0.5
		var d := (b - a).normalized()
		var perp := Vector3(0, 0, 1)
		_add_quad(st, mid, perp * 0.035, d * a.distance_to(b) * 0.5, Vector3(0, 1, 0), col_edge)
	_commit_quad_mesh(parent, st, "SeaFanVisual")

## ── Hải quỳ — chùm xúc tu cong tỏa quanh, màu neon ───────────────────────────
static func _build_anemone(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var palette: Array[Color] = [
		Color(0.90, 0.20, 0.75), Color(0.20, 0.85, 0.85), Color(0.30, 0.90, 0.35), Color(1.00, 0.35, 0.50),
	]
	var col := palette[int(cr * float(palette.size())) % palette.size()]
	var col_tip := col.lightened(0.40)
	var tentacles: int = 10 + (h2 & 7)
	var base := Vector3(0, 0.10, 0)
	for i in range(tentacles):
		var ang := float(i) / float(tentacles) * TAU
		var origin := base + Vector3(cos(ang) * 0.16, 0, sin(ang) * 0.16)
		var tlen: float = 0.30 + float((h2 >> 1) & 3) * 0.06
		var dir := Vector3(cos(ang), 0.55, sin(ang)).normalized()
		var prev := origin
		for seg in range(3):
			var t := float(seg + 1) / 3.0
			var nxt := origin + dir * tlen * t
			nxt.y += t * t * 0.08
			var mid := (prev + nxt) * 0.5
			var d := (nxt - prev).normalized()
			var perp := Vector3(-d.z, 0, d.x).normalized()
			var taper: float = 1.0 - t * 0.7
			var col_seg := col.lerp(col_tip, t)
			_add_blade_quad(st, mid, perp * 0.035 * taper, d * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col_seg)
			prev = nxt
	_commit_quad_mesh(parent, st, "AnemoneVisual")

## ── Bụi cây biển — cây bụi to, nhiều cành lá dày (voxel), xanh lá/xanh ngọc ──
static func _build_sea_bush(parent: Node3D, h1: int, h2: int) -> void:
	var positions: Array = []
	var scales: Array = []
	var colors: Array = []
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var pal: Array[Color] = [
		Color(0.10, 0.52, 0.18), Color(0.06, 0.55, 0.24), Color(0.08, 0.42, 0.32), Color(0.13, 0.60, 0.14),
	]
	var col := pal[int(cr * float(pal.size())) % pal.size()]
	var col_hi := col.lightened(0.22)
	var col_lo := col.darkened(0.26)
	var bush_r: float = 0.42 + (h2 & 3) * 0.10
	var bush_h: float = 0.8 + (h2 >> 2) * 0.10
	# Đế gốc — vài voxel thân cụt
	for bi in range(4):
		s = s * 16807 + 1
		var ba := (float(s & 0x7FFF) / 32768.0) * TAU
		s = s * 16807 + 1
		var br := 0.10 + (float(s & 0x7FFF) / 32768.0) * 0.12
		positions.append(Vector3(cos(ba) * br, 0.08, sin(ba) * br))
		scales.append(0.12)
		colors.append(col_lo)
	# Bom lá dày — nhiều cụm voxel phủ mặt cầu, độn phồng
	var clumps: int = 14 + (h2 & 3) * 3
	for ci in range(clumps):
		s = s * 16807 + 1
		var ca := (float(s & 0x7FFF) / 32768.0) * TAU
		s = s * 16807 + 1
		var ce := (float(s & 0x7FFF) / 32768.0) * 0.75 + 0.25
		s = s * 16807 + 1
		var crad := (float(s & 0x7FFF) / 32768.0) * bush_r * 0.6
		var px: float = cos(ca) * bush_r * 0.7 * ce
		var pz: float = sin(ca) * bush_r * 0.7 * ce
		var py: float = 0.25 + (float(s & 0x3FFF) / 16384.0) * bush_h * 0.8
		for qi in range(3 + (ci & 1)):
			s = s * 16807 + 1
			var qx := px + (float(s & 0x7FFF) / 32768.0 - 0.5) * 0.22
			s = s * 16807 + 1
			var qy := py + (float(s & 0x7FFF) / 32768.0 - 0.5) * 0.20
			s = s * 16807 + 1
			var qz := pz + (float(s & 0x7FFF) / 32768.0 - 0.5) * 0.22
			positions.append(Vector3(qx, qy, qz))
			scales.append(_VoxelShared.LEAF_SCALE * (0.55 + (float(s & 0x7FFF) / 32768.0) * 0.5))
			colors.append(col_lo.lerp(col_hi, float(s & 0x7FFF) / 32768.0))
	# Ngọn nổi vài cụm sáng hơn
	for ti in range(3):
		s = s * 16807 + 1
		var ta := (float(s & 0x7FFF) / 32768.0) * TAU
		var tr := bush_r * 0.4
		positions.append(Vector3(cos(ta) * tr, bush_h * (0.8 + (float(s & 0x7FFF) / 32768.0) * 0.2), sin(ta) * tr))
		scales.append(_VoxelShared.LEAF_SCALE)
		colors.append(col_hi)
	var mmi := _VoxelShared.build(positions, scales, colors)
	mmi.name = "SeaBushVisual"
	parent.add_child(mmi)

## ── Thảm cỏ xanh biển — lá mảnh thấp rủ sát đáy tạo thảm xanh dày ────────────
static func _build_grass_carpet(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	var col_base := Color(0.05, 0.48, 0.14)
	var col_tip := Color(0.16, 0.68, 0.22)
	var blades: int = 18 + (h2 & 7) * 2
	var cur_dir := Vector3(0.3, 0, 0.2).normalized()
	s = s * 16807 + 1
	var seed_a := (float(s & 0x7FFF) / 32768.0) * TAU
	for bi in range(blades):
		var ba: float = seed_a + float(bi) / float(blades) * TAU
		var r: float = 0.30 + float(bi % 5) * 0.07 + (float(s & 0xFF) / 256.0) * 0.05
		var origin := Vector3(cos(ba) * r, 0, sin(ba) * r)
		var blade_h: float = 0.28 + (float((h2 >> (bi % 4)) & 3) / 3.0) * 0.25
		var w: float = VOXEL * 0.55
		var prev := origin
		for seg in range(3):
			var t := float(seg + 1) / 3.0
			var nxt := origin + Vector3(0, blade_h * t, 0) \
				+ cur_dir * blade_h * 0.30 * t * t * (0.4 + float(bi % 3) * 0.2)
			var mid := (prev + nxt) * 0.5
			var d := (nxt - prev).normalized()
			var perp := Vector3(-d.z, 0, d.x).normalized()
			var taper: float = 1.0 - t * 0.8
			var col := col_base.lerp(col_tip, t)
			_add_blade_quad(st, mid, perp * w * 0.5 * taper, d * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col)
			prev = nxt
	# Cỏ nền dọc thân thảm — vài lá nằm ngang phủ đáy
	for bi in range(8):
		s = s * 16807 + 1
		var ba2 := (float(s & 0x7FFF) / 32768.0) * TAU
		s = s * 16807 + 1
		var len: float = 0.20 + (float(s & 0x7FFF) / 32768.0) * 0.22
		var px: float = cos(ba2) * 0.22
		var pz: float = sin(ba2) * 0.22
		_add_blade_quad(st, Vector3(px, 0.03, pz),
			Vector3(-sin(ba2) * 0.02, 0, cos(ba2) * 0.02),
			Vector3(cos(ba2) * len * 0.5, 0, sin(ba2) * len * 0.5),
			Vector3(0, 1, 0), col_base)
	_commit_quad_mesh(parent, st, "GrassCarpetVisual")

## ── Tảo biển (rockweed) — lá dày to bản, xếp tầng từ gốc, xanh ô-liu ──────────
static func _build_seaweed(parent: Node3D, h1: int, h2: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var col_base := Color(0.16, 0.34, 0.10).lerp(Color(0.22, 0.42, 0.14), cr)
	var col_tip := Color(0.34, 0.55, 0.18).lerp(Color(0.42, 0.62, 0.20), cr)
	var cur_dir := Vector3(0.5, 0, 0.3).normalized()
	s = s * 16807 + 1
	var seed_a := (float(s & 0x7FFF) / 32768.0) * TAU
	var fronds: int = 5 + (h2 & 1) * 2
	for fi in range(fronds):
		var ba: float = seed_a + float(fi) / float(fronds) * TAU
		var origin := Vector3(cos(ba) * 0.12, 0, sin(ba) * 0.12)
		var frond_h: float = 0.9 + float((h2 >> 1) & 3) * 0.30
		var w: float = VOXEL * 0.9
		var prev := origin
		for seg in range(4):
			var t := float(seg + 1) / 4.0
			var nxt := origin + Vector3(0, frond_h * t, 0) \
				+ cur_dir * frond_h * 0.22 * t * t
			var mid := (prev + nxt) * 0.5
			var d := (nxt - prev).normalized()
			var perp := Vector3(-d.z, 0, d.x).normalized()
			var taper: float = 1.0 - t * 0.55
			var col := col_base.lerp(col_tip, t)
			_add_blade_quad(st, mid, perp * w * 0.5 * taper, d * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col)
			prev = nxt
	_commit_quad_mesh(parent, st, "SeaweedVisual")

## ── Đĩa gốc hải quỳ — miếng dẹt dưới chân (chỉ gắn vào prop thế giới) ────────
func _build_anemone_base() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = seed_h1 * 16807 + 1
	s = s * 16807 + 1
	var cr := float(s & 0x7FFFFFFF) / 2147483648.0
	var col := Color(0.90, 0.20, 0.75)
	if cr < 0.33:
		col = Color(0.20, 0.85, 0.85)
	elif cr < 0.66:
		col = Color(0.30, 0.90, 0.35)
	_add_quad(st, Vector3(0, 0.03, 0), Vector3(0.20, 0, 0), Vector3(0, 0, 0.20), Vector3(0, 1, 0), col.darkened(0.35))
	_commit_quad_mesh(self, st, "AnemoneBase")

static func _commit_quad_mesh(parent: Node3D, st: SurfaceTool, name: String) -> void:
	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = mesh
		mi.material_override = WorldChunk.make_aquatic_mat()
		parent.add_child(mi)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)

static func _add_blade_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	_add_quad(st, center, u, v, n, col)
	var u2 := Vector3(u.z, 0.0, -u.x)
	if u2.length() < 0.0001:
		u2 = Vector3(-u.z, 0.0, u.x)
	_add_quad(st, center, u2, v, n, col)

