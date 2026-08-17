class_name M200IdleVFX
extends Node3D

## VFX idle của M200 DarkVoid — chạy mọi lúc khi súng được cầm / rơi ngoài đất:
## - Các dải neon tím/cyan trên thân nhấp nháy (pulse albedo + emission).
## - Lõi năng lượng tím ở đầu nòng thở phồng + hào quang mờ xoay.
## - 4 hạt neon bay lượn quanh nòng theo quỹ đạo sin.
## - Đèn tím mềm chiếu nhẹ ra môi trường tối.

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

func setup(mats: Array) -> void:
	_pulse_mats = mats
	_base_cols.clear()
	for m in mats:
		_base_cols.append(m.albedo_color if m is StandardMaterial3D else Color.WHITE)
	_build_visuals()
	_active = true

func _build_visuals() -> void:
	_core_mat = _glow_mat(Color(0.72, 0.35, 1.0))
	_core = _glow_sphere(0.018, _core_mat)
	_core.position = Vector3(0, 0.60, -0.012)
	add_child(_core)

	_halo_mat = _glow_mat(Color(0.55, 0.20, 1.0))
	_halo = _glow_sphere(0.036, _halo_mat)
	_halo.position = Vector3(0, 0.60, -0.012)
	add_child(_halo)

	var tints := [Color(0.20, 0.90, 1.0), Color(0.78, 0.40, 1.0)]
	for i in 4:
		var m := _glow_sphere(0.008, _glow_mat(tints[i % 2]))
		m.position = Vector3(0, 0.12 + float(i) * 0.13, -0.012)
		add_child(m)
		_motes.append(m)
		_mote_base.append(m.position)
		_mote_phase.append(float(i) * 1.7)
		_mote_tint.append(tints[i % 2])

	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.30, 1.0)
	_light.light_energy = 0.9
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.30, -0.012)
	add_child(_light)

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
