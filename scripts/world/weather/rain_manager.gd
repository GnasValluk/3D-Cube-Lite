class_name RainManager
extends Node3D

class Zone:
	var center: Vector2
	var radius: float
	var lifetime: float

	func _init(c: Vector2, r: float, lt: float):
		center = c; radius = r; lifetime = lt

var _zones: Array[Zone] = []
var _drops: GPUParticles3D
var _drop_mat: StandardMaterial3D
var _drop_mesh: BoxMesh
var _drop_pm: ParticleProcessMaterial
var _splash: GPUParticles3D
var _splash_mat: StandardMaterial3D
var _splash_mesh: BoxMesh
var _splash_pm: ParticleProcessMaterial
var _clouds: GPUParticles3D
var _cloud_mat: StandardMaterial3D
var _cloud_pm: ParticleProcessMaterial
var _last_ortho: float = -1.0
var _cloud_alpha: float = 0.0
var _cloud_alpha_target: float = 0.0
var _cloud_ortho_alpha: float = 0.95

const BASE_ORTHO: float = 20.0

func add_zone(center: Vector2, radius: float, lifetime: float) -> void:
	_zones.append(Zone.new(center, radius, lifetime))

func clear_zones() -> void:
	_zones.clear()

func _ready() -> void:
	if TimeSystem:
		TimeSystem.weather_changed.connect(_on_weather_changed)
	_setup_drops()
	_setup_splash()
	_setup_clouds()

func _on_weather_changed(weather: int) -> void:
	if weather == TimeSystem.Weather.RAIN:
		var cx := randf_range(-150.0, 150.0)
		var cz := randf_range(-150.0, 150.0)
		add_zone(Vector2(cx, cz), randf_range(60.0, 120.0), TimeSystem.CYCLE_DURATION)
	else:
		clear_zones()

func _setup_drops() -> void:
	_drops = GPUParticles3D.new()
	_drops.name = "RainDrops"
	_drops.local_coords = false
	_drops.one_shot = false
	_drops.emitting = false
	_drops.amount = 1500
	_drops.lifetime = 2.0
	_drops.fixed_fps = 30
	_drops.interpolate = false

	_drop_pm = ParticleProcessMaterial.new()
	_drop_pm.direction = Vector3.DOWN
	_drop_pm.spread = 15.0
	_drop_pm.gravity = Vector3(3.0, -18, 1.5)
	_drop_pm.initial_velocity_min = 12.0
	_drop_pm.initial_velocity_max = 16.0
	_drop_pm.scale_min = 0.8
	_drop_pm.scale_max = 1.2
	_drop_pm.color = Color(0.70, 0.75, 0.85, 0.35)
	_drop_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_drop_pm.emission_box_extents = Vector3(16, 12, 16)
	_drops.process_material = _drop_pm

	_drop_mesh = BoxMesh.new()
	_drop_mesh.size = Vector3(0.012, 0.20, 0.012)
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.albedo_color = Color(0.75, 0.80, 0.90, 0.30)
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_drop_mesh.material = _drop_mat
	_drops.draw_pass_1 = _drop_mesh
	_drops.visibility_aabb = AABB(Vector3(-50, -70, -50), Vector3(100, 90, 100))

	add_child(_drops)

func _setup_splash() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "RainSplash"
	_splash.local_coords = false
	_splash.one_shot = false
	_splash.emitting = false
	_splash.amount = 800
	_splash.lifetime = 0.4
	_splash.fixed_fps = 20
	_splash.interpolate = false

	_splash_pm = ParticleProcessMaterial.new()
	_splash_pm.direction = Vector3.UP
	_splash_pm.spread = 70.0
	_splash_pm.gravity = Vector3(0, -12, 0)
	_splash_pm.initial_velocity_min = 2.0
	_splash_pm.initial_velocity_max = 4.0
	_splash_pm.scale_min = 0.4
	_splash_pm.scale_max = 0.8
	_splash_pm.color = Color(0.75, 0.80, 0.90, 0.25)
	_splash_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_splash_pm.emission_box_extents = Vector3(18, 0.5, 18)
	_splash.process_material = _splash_pm

	_splash_mesh = BoxMesh.new()
	_splash_mesh.size = Vector3(0.030, 0.030, 0.030)
	_splash_mat = StandardMaterial3D.new()
	_splash_mat.albedo_color = Color(0.85, 0.88, 0.95, 0.25)
	_splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_splash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_splash_mesh.material = _splash_mat
	_splash.draw_pass_1 = _splash_mesh
	_splash.visibility_aabb = AABB(Vector3(-30, -1, -30), Vector3(60, 8, 60))

	add_child(_splash)

func _setup_clouds() -> void:
	_clouds = GPUParticles3D.new()
	_clouds.name = "RainClouds"
	_clouds.local_coords = false
	_clouds.one_shot = false
	_clouds.emitting = false
	_clouds.amount = 8
	_clouds.lifetime = 25.0
	_clouds.fixed_fps = 0
	_clouds.interpolate = false

	_cloud_pm = ParticleProcessMaterial.new()
	_cloud_pm.direction = Vector3(0.02, 0, -0.01)
	_cloud_pm.spread = 8.0
	_cloud_pm.gravity = Vector3.ZERO
	_cloud_pm.initial_velocity_min = 0.1
	_cloud_pm.initial_velocity_max = 0.4
	_cloud_pm.scale_min = 8.0
	_cloud_pm.scale_max = 18.0
	_cloud_pm.color = Color(0.92, 0.92, 0.95, 0.75)
	_cloud_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_cloud_pm.emission_box_extents = Vector3(42, 0.4, 42)
	_cloud_pm.angle_min = 0.0
	_cloud_pm.angle_max = 360.0
	_clouds.process_material = _cloud_pm

	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.albedo_color = Color(0.90, 0.90, 0.93, 0.75)
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud_mat.render_priority = 127

	var m1 := BoxMesh.new()
	m1.size = Vector3(2.5, 0.04, 1.5)
	m1.material = _cloud_mat
	var m2 := BoxMesh.new()
	m2.size = Vector3(1.5, 0.05, 2.0)
	m2.material = _cloud_mat
	var m3 := BoxMesh.new()
	m3.size = Vector3(3.0, 0.03, 1.0)
	m3.material = _cloud_mat
	var m4 := BoxMesh.new()
	m4.size = Vector3(1.0, 0.06, 1.8)
	m4.material = _cloud_mat

	_clouds.draw_passes = 4
	_clouds.draw_pass_1 = m1
	_clouds.draw_pass_2 = m2
	_clouds.draw_pass_3 = m3
	_clouds.draw_pass_4 = m4
	_clouds.visibility_aabb = AABB(Vector3(-200, -1, -200), Vector3(400, 3, 400))

	add_child(_clouds)

func _update_ortho_scale(ortho: float) -> void:
	var s: float = ortho / BASE_ORTHO
	var drops_w: float = 0.012 * s
	var drops_h: float = 0.20 * s
	var ext: float = maxf(ortho * 0.8, 16.0)
	_drop_mesh.size = Vector3(drops_w, drops_h, drops_w)
	_drop_pm.emission_box_extents = Vector3(ext, 12 * s, ext)
	var sb: float = 0.030 * s
	_splash_mesh.size = Vector3(sb, sb, sb)
	var sext: float = maxf(ortho * 0.9, 18.0)
	_splash_pm.emission_box_extents = Vector3(sext, 0.5, sext)
	var cext: float = maxf((ortho - 6.0) * 3.0, 8.0)
	_cloud_pm.emission_box_extents = Vector3(cext, 0.4, cext)
	_cloud_pm.scale_min = 8.0
	_cloud_pm.scale_max = 18.0
	var zoom_norm: float = (ortho - 45.0) / (55.0 - 45.0)
	_cloud_ortho_alpha = clamp(zoom_norm, 0.0, 1.0) * 0.95

func _process(delta: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		_zones[i].lifetime -= delta
		if _zones[i].lifetime <= 0:
			_zones.remove_at(i)

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	if not cam:
		_drops.emitting = false
		_drops.visible = false
		_splash.emitting = false
		_splash.visible = false
		_clouds.emitting = false
		_clouds.visible = false
		return

	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var o: float = cam.size
		if abs(o - _last_ortho) > 0.5:
			_last_ortho = o
			_update_ortho_scale(o)
	elif _last_ortho >= 0.0:
		_last_ortho = -1.0
		_drop_mesh.size = Vector3(0.012, 0.20, 0.012)
		_drop_pm.emission_box_extents = Vector3(16, 12, 16)
		_splash_mesh.size = Vector3(0.030, 0.030, 0.030)
		_splash_pm.emission_box_extents = Vector3(18, 0.5, 18)
		_cloud_pm.emission_box_extents = Vector3(42, 0.4, 42)
		_cloud_pm.scale_min = 8.0
		_cloud_pm.scale_max = 18.0

	var cpos: Vector3 = cam.global_position
	_drops.global_position = Vector3(cpos.x, cpos.y + 10, cpos.z)
	_splash.global_position = Vector3(cpos.x, 0.5, cpos.z)
	_clouds.global_position = Vector3(cpos.x, 15.0, cpos.z)

	var cam_xz := Vector2(cpos.x, cpos.z)
	var in_rain := false
	var edge_dist: float = INF
	for zone in _zones:
		var d: float = cam_xz.distance_to(zone.center)
		if d < zone.radius:
			in_rain = true
			edge_dist = minf(edge_dist, zone.radius - d)

	if in_rain:
		var ratio: float = clamp(edge_dist / 20.0, 0.0, 1.0)
		_drops.amount_ratio = ratio
		_splash.amount_ratio = ratio
		if _drop_mat:
			var c: Color = _drop_mat.albedo_color
			_drop_mat.albedo_color = Color(c.r, c.g, c.b, 0.30 * ratio)
		if _splash_mat:
			var c: Color = _splash_mat.albedo_color
			_splash_mat.albedo_color = Color(c.r, c.g, c.b, 0.25 * ratio)
			_clouds.amount_ratio = minf(ratio + 0.3, 1.0)
		_cloud_alpha_target = _cloud_ortho_alpha * ratio
		if not _drops.emitting:
			_drops.emitting = true
			_drops.visible = true
			_splash.emitting = true
			_splash.visible = true
	else:
		_cloud_alpha_target = 0.0
		if _drops.emitting:
			_drops.emitting = false
			_drops.visible = false
			_splash.emitting = false
			_splash.visible = false

	_cloud_alpha = lerp(_cloud_alpha, _cloud_alpha_target, delta * 2.0)
	if _cloud_mat:
		var c: Color = _cloud_mat.albedo_color
		_cloud_mat.albedo_color = Color(c.r, c.g, c.b, _cloud_alpha)
	if _cloud_pm:
		var c2: Color = _cloud_pm.color
		_cloud_pm.color = Color(c2.r, c2.g, c2.b, _cloud_alpha)

	if _cloud_alpha < 0.01 and _clouds.emitting:
		_clouds.emitting = false
		_clouds.visible = false
	elif _cloud_alpha >= 0.01 and not _clouds.emitting:
		_clouds.emitting = true
		_clouds.visible = true
