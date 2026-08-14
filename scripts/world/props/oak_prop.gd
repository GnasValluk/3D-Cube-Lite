class_name OakProp
extends GrowingProp

## CÃ¢y sá»“i kiá»ƒu Minecraft â€” thÃ¢n cá»™t nÃ¢u Ä‘áº­m tháº³ng Ä‘á»©ng (vá» nÃ¢u sáº«m áº¥m, khÃ´ng
## rÃªu/xÃ¡m), tÃ¡n lÃ¡ xanh lÃ¡ chuá»‘i (vÃ ng-xanh sÃ¡ng) dáº¡ng khá»‘i blob chunky lá»›n:
## lÃµi sáº«m, giá»¯a tÆ°Æ¡i, ngoÃ i sÃ¡ng Ä‘Ã³n náº¯ng; nhiá»u cÃ nh nhÃ¡nh vÆ°Æ¡n ra mang chÃ¹m
## lÃ¡ riÃªng, giÃ³ Ä‘u nháº¹ theo chÃ¹m. VÃ²ng Ä‘á»i: máº§m (sapling) â†’ trÆ°á»Ÿng thÃ nh.
## Cháº·t rÃ¬u rÆ¡i khá»‘i gá»— sá»“i.

enum OakSize { SMALL, MEDIUM, TALL }

const VOXEL: float = 0.0625
const _DARKEN: float = 0.72

const _ItemDatabase = preload("res://scripts/items/core/item_database.gd")
const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _VoxelShared = preload("res://scripts/world/props/voxel_shared.gd")

var _variant: String = "plains"
var _size: int = OakSize.MEDIUM
var _base_h: float = 4.4

var _sway_phase: float
var _sway_freq: float
var _sway_amp: float

var _tuft_data: Array = []   # { center, pos[], col[] } â€” chÃ¹m lÃ¡ (local cá»§a chÃ¹m)
var _grid: Dictionary = {}   # key (int) â†’ Color
var _ordered: Array[Vector3] = []

var _canopy_centers: Array[Vector3] = []

func setup(variant: String = "plains") -> void:
	_variant = variant
	# Loáº¡i bá» dáº¡ng Ã­t lÃ¡: cÃ¢y sá»“i luÃ´n chá»‰ cÃ³ cá»¡ vá»«a/lá»›n, tÃ¡n lÃºc nÃ o cÅ©ng um tÃ¹m.
	var r := randf()
	if r < 0.45: _size = OakSize.MEDIUM
	else: _size = OakSize.TALL
	_base_h = _roll_base_h()

func _roll_base_h() -> float:
	match _size:
		OakSize.MEDIUM: return 4.2 + randf() * 0.6
		OakSize.TALL:   return 5.4 + randf() * 0.6
	return 4.4

func _birth_span_days() -> float:
	return 90.0

func _stage_thresholds() -> Array[float]:
	return [15.0, 55.0]

## CÃ¢y sá»“i khÃ´ng cÃ³ giai Ä‘oáº¡n vá»‹ thÃ nh niÃªn â€” máº§m xong lÃ  trÆ°á»Ÿng thÃ nh.
func _has_young_stage() -> bool:
	return false

func _ready() -> void:
	super._ready()
	_build_tree()
	_setup_collision()
	_sway_phase = randf() * TAU
	_sway_freq = 1.0 + randf() * 0.6
	_sway_amp = deg_to_rad(2.0 + randf() * 0.8)

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
	var wood_def = _ItemDatabase.items_db.get("block_oak_wood")
	if wood_def:
		_DroppedItem.spawn(world, wood_def, global_position, randi() % 3 + 2, _spawn_drop_velocity(), global_position.y)

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

func _setup_collision() -> void:
	var h := _get_h()
	var body := StaticBody3D.new()
	body.name = "OakCollision"
	# ThÃ¢n cÃ¢y: trá»¥ nhá» khá»›p Ä‘Ãºng pháº§n gá»— tháº­t (bÃ¡n kÃ­nh theo gá»‘c thÃ¢n).
	var trunk := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = _get_base_r() * 0.85 + 0.10
	cyl.height = maxf(h * 0.55, 0.35)
	trunk.shape = cyl
	trunk.position.y = h * 0.5
	body.add_child(trunk)
	# TÃ¡n: 1 quáº£ cáº§u nhá» cho má»—i Ä‘Ã¹m lÃ¡ táº¡i Ä‘Ãºng tÃ¢m Ä‘Ã¹m â€” khá»›p silhouette
	# tháº­t cá»§a cÃ¢y thay vÃ¬ 1 trá»¥ khá»•ng lá»“ phá»§ cáº£ tÃ¡n (trÆ°á»›c Ä‘Ã¢y to hÆ¡n cÃ¢y).
	for t in _tuft_data:
		if not "r" in t:
			continue
		var tc: Vector3 = t["center"]
		var tr2: float = t["r"]
		var slab := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = maxf(tr2 * 0.85, 0.18)
		slab.shape = sph
		slab.position = tc
		body.add_child(slab)
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
	return r

func _get_top_r() -> float:
	var r: float
	match _size:
		OakSize.SMALL:  r = 0.16
		OakSize.MEDIUM: r = 0.19
		OakSize.TALL:   r = 0.22
		_: r = 0.19
	return r

## BÃ¡n kÃ­nh tÃ¡n â€” xÃ²e rá»™ng theo phÆ°Æ¡ng ngang kiá»ƒu Minecraft.
func _canopy_r() -> float:
	var r: float
	match _size:
		OakSize.SMALL:  r = 1.10
		OakSize.MEDIUM: r = 1.55
		OakSize.TALL:   r = 1.90
		_: r = 1.55
	if _variant == "river":
		r *= 1.1
	if _stage == GrowingProp.Stage.SPROUT:
		r *= 0.25
	return r

# â”€â”€ GRID helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

## LÃ¡ dÃ¹ng lÆ°á»›i thÃ´ 0.1875 (3Ã— voxel thÃ¢n) â€” khá»‘i lÃ¡ chunky kiá»ƒu Minecraft.
func _add_tuft_voxel_c(tuft: Dictionary, x: float, y: float, z: float, col: Color) -> void:
	var s := VOXEL * 3.0
	(tuft["pos"] as Array).append(Vector3(round(x / s) * s, round(y / s) * s, round(z / s) * s))
	(tuft["col"] as Array).append(col * _DARKEN)

## Äoáº¡n trá»¥ voxel hÃ³a giá»¯a 2 Ä‘iá»ƒm (thÃ¢n máº£nh cÃ nh) â€” lÆ°á»›i 0.125.
func _stroke(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var lv := VOXEL * 2.0
	var dist := a.distance_to(b)
	var steps := maxi(2, ceili(dist / (lv * 0.8)))
	var rv := maxi(1, ceili(r / lv))
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
				_fill(p.x + vx * lv, p.y, p.z + vz * lv, c2)

# â”€â”€ MAIN BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
	# Gá»™p má»i voxel (thÃ¢n + lÃ¡ cá»§a Má»ŒI chÃ¹m) vÃ o 1 MultiMesh duy nháº¥t.
	# Voxel thÃ¢n dÃ¹ng lÆ°á»›i 0.125 â†’ cube 0.13 (TRUNK_SCALE), lÃ¡ dÃ¹ng lÆ°á»›i
	# 0.1875 â†’ cube 0.20 (LEAF_SCALE) â€” Ä‘Ãºng cá»¡ lÆ°á»›i nÃªn nhÃ¬n ngang khÃ´ng
	# cÃ²n khe rá»—ng giá»¯a cÃ¡c cube. Má»—i cÃ¢y = 1 draw call (trÆ°á»›c: 1+1/cÃ¢y).
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

	if positions.is_empty():
		return
	var mmi := _VoxelShared.build(positions, scales_pack, colors_pack)
	mmi.name = "OakVisual"
	add_child(mmi)

func _apply_stage(_from: int, _to: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for i in range(get_child_count() - 1, -1, -1):
		var ch := get_child(i)
		if ch is MultiMeshInstance3D or ch is StaticBody3D or ch is CPUParticles3D:
			remove_child(ch)
			ch.queue_free()
	_build_tree()
	_setup_collision()
	_pop_growth()

## Máº§m cÃ¢y sá»“i kiá»ƒu sapling: thÃ¢n nhá» nÃ¢u sÃ¡ng + cá»¥m lÃ¡ xanh trÃªn ngá»n.
func _build_sprout() -> void:
	var stem := Color(0.42, 0.30, 0.15)
	var stem_h := 0.22 + randf() * 0.10
	var ny: int = ceili(stem_h / VOXEL)
	for vy in range(ny):
		_fill(0.0, vy * VOXEL, 0.0, stem)
	var br := 0.16 + randf() * 0.06
	var tuft: Dictionary = { "center": Vector3(0.0, stem_h + 0.10, 0.0), "pos": [], "col": [], "r": br }
	_build_blob(tuft, br)
	_tuft_data.append(tuft)

# â”€â”€ TRUNK (thÃ¢n cá»™t nÃ¢u Ä‘áº­m, gáº§n tháº³ng, vá» nÃ¢u sáº«m áº¥m) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _build_trunk(h: float) -> void:
	var base_r := _get_base_r()
	var top_r := _get_top_r()
	var lv := VOXEL * 2.0
	var ny: int = ceili(h / lv)
	var wob := randf() * TAU
	for vy in range(ny):
		var t: float = float(vy) / float(ny)
		var y := vy * lv
		var r := lerpf(base_r, top_r, t)
		r *= 1.0 + sin(vy * 0.7 + wob) * 0.05
		if vy < 2:
			r *= 1.0 + (1.0 - float(vy) / 2.0) * 0.15   # phÃ¬nh nháº¹ chÃ¢n
		var cx := sin(vy * 1.0 + wob) * 0.03 * (1.0 - t)
		var cz := cos(vy * 0.8 + wob * 1.7) * 0.03 * (1.0 - t)
		var rv: int = ceili(r / lv)
		for vx in range(-rv - 1, rv + 2):
			for vz in range(-rv - 1, rv + 2):
				var dx := vx * lv - cx
				var dz := vz * lv - cz
				if dx * dx + dz * dz > r * r:
					continue
				_fill(dx, y, dz, _bark_vary())
		# sáº¹o cÃ nh ngáº¯n ráº£i rÃ¡c trÃªn thÃ¢n (vÃ i cháº¥m sáº«m)
		if vy > ny / 3 and vy % 15 == 3 and randf() < 0.6:
			var sa: float = randf() * TAU
			_fill(cos(sa) * r, y, sin(sa) * r, Color(0.30, 0.19, 0.08))
			_fill(cos(sa + 0.35) * r * 0.8, y + lv * 0.5, sin(sa + 0.35) * r * 0.8, Color(0.30, 0.19, 0.08))

func _bark_vary() -> Color:
	var r := randf()
	if r < 0.12:
		return Color(0.46, 0.31, 0.16)
	if r < 0.24:
		return Color(0.32, 0.20, 0.09)
	return Color(0.39, 0.26, 0.12)

# â”€â”€ BRANCH ARMS (cÃ nh vÆ°Æ¡n lÃªn mang chÃ¹m lÃ¡) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _branch_arms(h: float) -> void:
	var n_arm: int = 3 + randi() % 3
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

# â”€â”€ CANOPY: khá»‘i blob lÃ¡ chunky kiá»ƒu Minecraft â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _build_canopy(h: float) -> void:
	var canopy := _canopy_r()
	# ChÃ¹m trung tÃ¢m trÃªn ngá»n thÃ¢n + chÃ¹m á»Ÿ Ä‘áº§u tá»«ng cÃ nh.
	var centers: Array[Vector3] = [Vector3(0.0, h * 0.96, 0.0)]
	centers.append_array(_canopy_centers)
	# CÃ¢y sá»“i LUÃ”N ráº¥t nhiá»u lÃ¡: má»—i Ä‘iá»ƒm gáº¯n sinh nhiá»u Ä‘Ã¹m lÃ¡ trÃ²n to,
	# lá»‡ch vá»‹ trÃ­ quanh gá»‘c, má»—i Ä‘Ã¹m 1 tÃ´ng mÃ u trong báº£ng palette.
	for c in centers:
		var n_sub: int = 3 if c == centers[0] else 2
		for si in range(n_sub):
			var ang: float = randf() * TAU
			var dist: float = (0.15 + randf() * 0.40) * canopy * 0.8
			var off := Vector3(cos(ang) * dist, (randf() - 0.5) * 0.30, sin(ang) * dist)
			var r: float
			if c == centers[0]:
				r = canopy * (0.62 + randf() * 0.24)
			else:
				r = canopy * (0.46 + randf() * 0.18)
			var tuft: Dictionary = { "center": c + off, "pos": [], "col": [], "r": r }
			_build_blob(tuft, r)
			_tuft_data.append(tuft)

## ÄÃ¹m lÃ¡: elip dáº¹p (giá»‘ng tÃ¡n cÃ¢y cam) trÃªn lÆ°á»›i voxel thÃ´ 0.1875 (3Ã— voxel
## thÃ¢n) â€” khá»‘i chunky kiá»ƒu Minecraft, dÃ y hÆ¡n lÆ°á»›i 0.25 Ä‘á»ƒ lÃ¡ khÃ´ng quÃ¡ thÆ°a.
func _build_blob(tuft: Dictionary, r: float) -> void:
	var tone := _LEAF_TONES[randi() % _LEAF_TONES.size()]
	var squash := 0.70 + randf() * 0.25
	var edge: float = 0.85 + randf() * 0.15
	var lv := VOXEL * 3.0
	var br: int = ceili(r / lv)
	var r_inv := 1.0 / r
	var ry_inv := 1.0 / (r * 0.55)
	var squash_inv := 1.0 / (r * squash)
	var m2 := 1.0
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
				if d2 > m2:
					continue
				var px := vx * lv
				var py := vy * lv
				var pz := vz * lv
				var d := sqrt(d2)
				var d01 := d
				if d01 > edge and randf() > 0.45:
					continue
				if d01 < 0.70 and randf() < 0.04:
					continue
				_add_tuft_voxel_c(tuft, px, py, pz, _leaf_color(tone, d01, randf()))

## Báº£ng tÃ´ng lÃ¡ chuá»‘i (vÃ ng-xanh sÃ¡ng): lÃµi vÃ ng-xanh sáº«m â†’ giá»¯a vÃ ng-xanh
## tÆ°Æ¡i â†’ ngoÃ i vÃ ng-xanh sÃ¡ng Ä‘Ã³n náº¯ng â€” má»—i Ä‘Ã¹m lÃ¡ mang 1 tÃ´ng riÃªng.
const _LEAF_TONES: Array[Color] = [
	Color(0.45, 0.62, 0.12),
	Color(0.52, 0.70, 0.14),
	Color(0.58, 0.76, 0.16),
	Color(0.64, 0.82, 0.18),
	Color(0.70, 0.88, 0.20),
	Color(0.76, 0.92, 0.24),
]

## MÃ u lÃ¡: lÃµi sáº«m hÆ¡n tÃ´ng â†’ giá»¯a báº±ng tÃ´ng â†’ ngoÃ i sÃ¡ng hÆ¡n tÃ´ng Ä‘Ã³n náº¯ng.
func _leaf_color(tone: Color, d01: float, rnd: float) -> Color:
	if rnd < 0.08 and d01 > 0.6:
		return tone.lightened(0.25)
	if d01 > 0.72:
		return tone.lightened(0.12)
	if d01 > 0.42:
		return tone
	return tone.darkened(0.20)

func _jitter(col: Color) -> Color:
	var j := (randf() - 0.5) * 0.06
	col.r = clampf(col.r + j, 0.0, 1.0)
	col.g = clampf(col.g + j, 0.0, 1.0)
	col.b = clampf(col.b + j, 0.0, 1.0)
	return col

# â”€â”€ HIT FLASH override (MultiMeshInstance3D, not MeshInstance3D) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _hit_flash() -> void:
	var mmi := find_child("OakVisual", false, false) as MultiMeshInstance3D
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
