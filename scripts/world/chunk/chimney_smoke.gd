extends Node3D

## ── VFX khói ống khói quán rượu (giống khói lò nung) ─────────────────────────
## GPUParticles3D với ParticleProcessMaterial + SphereMesh, khói bốc lên và loang
## dần. Bật lúc chiều tối (17h) và tắt sau 2 giờ sáng theo TimeSystem.

var _particles: GPUParticles3D
var _prev_active: bool = false

func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 20
	_particles.lifetime = 3.2
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.5
	_particles.position = Vector3(0, 0.3, 0)
	_particles.visible = false

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 16.0
	pm.gravity = Vector3(0, 0.8, 0)
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.85
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.7))
	sc.add_point(Vector2(0.5, 1.4))
	sc.add_point(Vector2(1, 2.9))
	var sc_tex := CurveTexture.new()
	sc_tex.curve = sc
	pm.scale_curve = sc_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(0.50, 0.50, 0.52, 0.55))
	grad.set_color(0.6, Color(0.42, 0.42, 0.44, 0.30))
	grad.set_color(1, Color(0.30, 0.30, 0.30, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	_particles.process_material = pm

	var sph := SphereMesh.new()
	sph.radius = 0.35
	sph.height = 0.7
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = sm
	_particles.draw_pass_1 = sph

	add_child(_particles)
	_prev_active = _hour_active(TimeSystem.get_hour())

func _process(_delta: float) -> void:
	var active := _hour_active(TimeSystem.get_hour())
	if active == _prev_active:
		return
	_prev_active = active
	_particles.emitting = active
	_particles.visible = active

## Khói hoạt động lúc chiều (17h) cho đến hết đêm, tắt sau 2h sáng.
static func _hour_active(hour: float) -> bool:
	return hour >= 17.0 or hour < 2.0