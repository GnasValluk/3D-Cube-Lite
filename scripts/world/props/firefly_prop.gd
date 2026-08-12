class_name FireflyProp
extends Node3D

## Đom đóm rừng ngập mặn — ánh chớp vàng-xanh lập lòe trên bãi bùn vào ban
## đêm. Ban ngày ẩn hẳn (tắt light) để tiết kiệm draw/light. Không phá được.

const NIGHT_START_HOUR: float = 18.0
const NIGHT_END_HOUR: float = 5.5

var _light: OmniLight3D = null
var _flicker_phase: float = 0.0
var _drift_phase: float = 0.0

func setup() -> void:
	pass

func _ready() -> void:
	_flicker_phase = randf() * TAU
	_drift_phase = randf() * TAU
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.70, 0.85, 0.20)
	mat.emission_energy_multiplier = 3.0
	mat.vertex_color_use_as_albedo = false
	mat.metallic = 0.0
	mat.roughness = 0.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for li in range(2):
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, 0.05)
		mi.mesh = box
		mi.position = Vector3(0.05 + li * 0.10, (randf() - 0.5) * 0.05, 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_light = OmniLight3D.new()
	_light.omni_range = 2.6
	_light.light_energy = 0.0
	_light.light_specular = 0.0
	_light.omni_attenuation = 0.7
	_light.light_color = Color(0.85, 0.95, 0.30)
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	if _light == null:
		return
	var h: float = TimeSystem.get_hour() if TimeSystem != null else 12.0
	var is_night: bool = h >= NIGHT_START_HOUR or h < NIGHT_END_HOUR
	_light.visible = is_night
	if not is_night:
		_light.light_energy = 0.0
		return
	var t := Time.get_ticks_usec() * 0.000001
	# Chớp lập lòe: chu kỳ nhanh + đốm sáng ngắt quãng
	var flicker: float = (sin(t * 2.2 + _flicker_phase) * 0.5 + 0.5) \
		* (0.45 + sin(t * 1.1 + _flicker_phase * 2.0) * 0.35)
	if sin(t * 0.35 + _flicker_phase) > 0.82:
		flicker = 0.0
	_light.light_energy = 0.30 + flicker * 0.55
	# Trôi lơ lửng nhẹ
	position.x += sin(t * 0.4 + _drift_phase) * delta * 0.02
	position.y += cos(t * 0.5 + _drift_phase * 1.3) * delta * 0.015
	position.z += cos(t * 0.35 + _drift_phase * 0.7) * delta * 0.02
