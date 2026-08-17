class_name WeaponNeonVFX
extends Node3D

## VFX idle neon chung cho vũ khí cyberpunk:
## M200 DarkVoid (tím/cyan) — AK-12 Thunderbolt (vàng + sét).
## - Các dải neon trên thân pulse (albedo brightness + emission).
## - Lõi năng lượng đầu nòng thở phồng + hào quang xoay.
## - Hạt neon bay lượn quanh nòng theo quỹ đạo sin.
## - Đèn màu nhẹ chiếu ra môi trường tối.
## - Tùy chọn tia sét (arc): vài đoạn tia giật ngẫu nhiên giữa các neo trên nòng,
##   nhấp nháy crackle + flash đèn — mặc định tắt, bật qua arc={} cho AK.

var _t: float = 0.0
var _active: bool = false
var _pulse_mats: Array = []
var _base_cols: Array = []

var _core: MeshInstance3D = null
var _core_mat: StandardMaterial3D = null
var _halo: MeshInstance3D = null
var _halo_mat: StandardMaterial3D = null
var _light: OmniLight3D = null

var _motes: Array[MeshInstance3D] = []
var _mote_base: Array[Vector3] = []
var _mote_phase: Array[float] = []
var _mote_tint: Array[Color] = []

var _arcs_enabled := false
var _arc_root: Node3D = null
var _arc_mat: StandardMaterial3D = null
var _strand_a: Array[MeshInstance3D] = []
var _strand_b: Array[MeshInstance3D] = []
var _arc_a_a: Vector3 = Vector3.ZERO
var _arc_a_b: Vector3 = Vector3.ZERO
var _arc_b_a: Vector3 = Vector3.ZERO
var _arc_b_b: Vector3 = Vector3.ZERO
var _arc_hot := false
var _arc_timer := 0.0

const ARC_SEG_LEN := 0.09

## mats: dải neon trên súng sẽ nhấp nháy (StandardMaterial3D, tự dò màu gốc).
## core_col/halo_col: màu lõi năng lượng + hào quang đầu nòng.
## tint_a/tint_b: 2 màu hạt neon bay quanh nòng.
## light_col: màu đèn môi trường nhẹ.
## muzzle: vị trí lõi năng lượng (đầu nòng). mote_start/step: dàn hạt dọc nòng.
## light_pos: vị trí đèn.
## arc: nếu không rỗng thì bật tia sét — {a: đầu nòng, b: thân, c: neo phụ}.
func setup(mats: Array, core_col: Color, halo_col: Color,
		tint_a: Color, tint_b: Color, light_col: Color,
		muzzle: Vector3, mote_start: float, mote_step: float, light_pos: Vector3,
		arc: Dictionary = {}) -> void:
	_pulse_mats = mats
	_base_cols.clear()
	for m in mats:
		_base_cols.append(m.albedo_color if m is StandardMaterial3D else Color.WHITE)
	_build_visuals(core_col, halo_col, tint_a, tint_b, light_col, muzzle, mote_start, mote_step, light_pos)
	if not arc.is_empty():
		_init_arcs(arc)
	_active = true

func _build_visuals(core_col: Color, halo_col: Color, tint_a: Color, tint_b: Color,
		light_col: Color, muzzle: Vector3, mote_start: float, mote_step: float, light_pos: Vector3) -> void:
	_core_mat = _glow_mat(core_col)
	_core = _glow_sphere(0.018, _core_mat)
	_core.position = muzzle
	add_child(_core)

	_halo_mat = _glow_mat(halo_col)
	_halo = _glow_sphere(0.036, _halo_mat)
	_halo.position = muzzle
	add_child(_halo)

	var tints := [tint_a, tint_b]
	var bz: float = muzzle.z
	for i in 4:
		var m := _glow_sphere(0.008, _glow_mat(tints[i % 2]))
		m.position = Vector3(0, mote_start + float(i) * mote_step, bz)
		add_child(m)
		_motes.append(m)
		_mote_base.append(m.position)
		_mote_phase.append(float(i) * 1.7)
		_mote_tint.append(tints[i % 2])

	_light = OmniLight3D.new()
	_light.light_color = light_col
	_light.light_energy = 0.9
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	_light.position = light_pos
	add_child(_light)

func _init_arcs(arc: Dictionary) -> void:
	_arcs_enabled = true
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arc_mat.albedo_color = Color(1.0, 0.96, 0.75, 0.95)
	_arc_mat.emission_enabled = true
	_arc_mat.emission = Color(1.0, 0.92, 0.60, 1.0)
	_arc_mat.emission_energy_multiplier = 3.0
	_arc_root = Node3D.new()
	_arc_root.name = "ArcRoot"
	_arc_root.visible = false
	add_child(_arc_root)
	_arc_a_a = arc.get("a", Vector3(0, 0.37, -0.010))
	_arc_a_b = arc.get("b", Vector3(0, 0.12, 0.030))
	_arc_b_a = arc.get("c", Vector3(0, 0.30, -0.045))
	_arc_b_b = arc.get("d", Vector3(0, -0.02, 0.050))
	_strand_a = _make_strand(6)
	_strand_b = _make_strand(4)
	_arc_timer = 0.3

func _make_strand(count: int) -> Array[MeshInstance3D]:
	var strand: Array[MeshInstance3D] = []
	for i in count:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.0045, 0.0045, ARC_SEG_LEN)
		mi.mesh = bm
		mi.material_override = _arc_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc_root.add_child(mi)
		strand.append(mi)
	return strand

func _zap() -> void:
	_arc_hot = true
	_arc_root.visible = true
	_redraw_strand(_strand_a, _arc_a_a, _arc_a_b, 0.055, 0.024)
	_redraw_strand(_strand_b, _arc_b_a, _arc_b_b, 0.040, 0.018)
	_arc_mat.albedo_color = Color(1.0, 0.96, 0.75, randf_range(0.75, 1.0))
	_arc_timer = randf_range(0.06, 0.10)

func _redraw_strand(strand: Array[MeshInstance3D], a: Vector3, b: Vector3, jx: float, jy: float) -> void:
	var n: int = strand.size()
	var pts: Array[Vector3] = []
	pts.append(a)
	for i in range(1, n):
		var t: float = float(i) / float(n)
		var base: Vector3 = a.lerp(b, t)
		pts.append(base + Vector3(randf_range(-jx, jx), randf_range(-jy, jy), randf_range(-jx, jx)))
	pts.append(b)
	for i in n:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var d: Vector3 = p1 - p0
		var mid: Vector3 = (p0 + p1) * 0.5
		strand[i].position = mid
		strand[i].scale = Vector3(1, 1, maxf(0.01, d.length()) / ARC_SEG_LEN)
		if d.length_squared() > 0.0000001:
			strand[i].look_at_from_position(mid, p1, Vector3.RIGHT)

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	for i in _pulse_mats.size():
		var mat: Variant = _pulse_mats[i]
		if not (mat is StandardMaterial3D):
			continue
		var b: Color = _base_cols[i]
		var k: float = 0.62 + 0.38 * pulse
		mat.albedo_color = Color(b.r * k, b.g * k, b.b * k, b.a)
		if mat.emission_enabled:
			mat.emission_energy_multiplier = 0.8 + 1.8 * pulse

	var cs: float = 1.0 + 0.25 * sin(_t * 5.0)
	_core.scale = Vector3.ONE * cs
	_halo.scale = Vector3.ONE * (1.0 + 0.35 * sin(_t * 5.0 + 1.3))
	_core_mat.albedo_color.a = 0.80 + 0.20 * sin(_t * 5.0)
	_halo_mat.albedo_color.a = 0.42 + 0.28 * sin(_t * 4.0)
	_halo.rotation.y = _t * 0.6

	for i in _motes.size():
		var ph: float = _mote_phase[i] + _t * 1.4
		var r: float = 0.045 + 0.02 * sin(_t * 1.7 + float(i))
		_motes[i].position = _mote_base[i] + Vector3(
			cos(ph) * r,
			sin(_t * 2.0 + float(i) * 1.3) * 0.03,
			sin(ph) * r * 0.6)
		_motes[i].scale = Vector3.ONE * (1.0 + 0.35 * sin(_t * 6.0 + float(i)))

	if _light:
		_light.light_energy = 0.7 + 0.5 * pulse

	# ── Tia sét giật (crackle): chu kỳ zap ngẫu nhiên, nháy nhanh + flash đèn ──
	if _arcs_enabled:
		_arc_timer -= delta
		if _arc_hot:
			if _arc_timer <= 0.0:
				if randf() < 0.35:
					_zap()
				else:
					_arc_hot = false
					_arc_root.visible = false
					_arc_timer = randf_range(0.2, 0.6)
			else:
				_arc_mat.albedo_color.a = randf_range(0.55, 1.0)
		elif _arc_timer <= 0.0:
			_zap()
		if _arc_hot:
			_light.light_energy = 1.2 + 0.8 * (0.5 + 0.5 * sin(_t * 45.0))

static func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 1.0)
	m.emission_energy_multiplier = 2.0
	m.roughness = 0.6
	m.metallic_specular = 0.1
	return m

static func _glow_sphere(radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi