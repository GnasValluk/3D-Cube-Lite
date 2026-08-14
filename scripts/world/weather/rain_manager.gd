class_name RainManager
extends Node3D

## Quản lý mưa/tuyết theo vùng quanh người chơi.
## - Mưa bình thường: giọt nước rơi nhanh + splash chạm đất.
## - Trong BIO BĂNG GIÁ (FROST): mưa biến thành TUYẾT — hạt tròn trắng, rơi
##   chậm hơn, không có splash.
## - Không còn đám mây tối trên đầu khi mưa (theo yêu cầu: mưa/tuyết → không
##   có mây; bầu trời quang đãng nhờ cloud_cover của sky shader bị tắt khi mưa).

class Zone:
	var center: Vector2
	var radius: float
	var lifetime: float

	func _init(c: Vector2, r: float, lt: float):
		center = c; radius = r; lifetime = lt

static var _instance: RainManager = null
var _local_rain_intensity: float = 0.0
var _local_rain_intensity_smoothed: float = 0.0

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")

## Trả về cường độ mưa cục bộ tại vị trí người chơi (0 = không mưa, >0 = đang trong vùng mưa)
static func get_local_rain_intensity() -> float:
	if _instance == null:
		return 0.0
	return _instance._local_rain_intensity_smoothed

var _zones: Array[Zone] = []
var _drops: GPUParticles3D
var _drop_mat: StandardMaterial3D
var _drop_mesh: BoxMesh
var _drop_pm: ParticleProcessMaterial
var _splash: GPUParticles3D
var _splash_mat: StandardMaterial3D
var _splash_mesh: BoxMesh
var _splash_pm: ParticleProcessMaterial
var _snow: GPUParticles3D
var _snow_mat: StandardMaterial3D
var _snow_mesh: SphereMesh
var _snow_pm: ParticleProcessMaterial
var _last_ortho: float = -1.0

const BASE_ORTHO: float = 20.0

func add_zone(center: Vector2, radius: float, lifetime: float) -> void:
	_zones.append(Zone.new(center, radius, lifetime))

func clear_zones() -> void:
	_zones.clear()

func _ready() -> void:
	_instance = self
	if TimeSystem:
		TimeSystem.weather_changed.connect(_on_weather_changed)
	_setup_drops()
	_setup_splash()
	_setup_snow()

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

## Tuyết: hạt tròn trắng (SphereMesh), rơi CHẬM hơn mưa, có gió nhẹ đẩy ngang,
## không splash. Chỉ hiện khi trời mưa trong bio băng giá.
func _setup_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.name = "SnowFlakes"
	_snow.local_coords = false
	_snow.one_shot = false
	_snow.emitting = false
	_snow.amount = 900
	_snow.lifetime = 7.0
	_snow.fixed_fps = 20
	_snow.interpolate = false

	_snow_pm = ParticleProcessMaterial.new()
	_snow_pm.direction = Vector3.DOWN
	_snow_pm.spread = 30.0
	_snow_pm.gravity = Vector3(0.06, -0.55, 0.06)
	_snow_pm.initial_velocity_min = 0.35
	_snow_pm.initial_velocity_max = 0.7
	_snow_pm.scale_min = 1.0
	_snow_pm.scale_max = 1.6
	_snow_pm.color = Color(1.0, 1.0, 1.0, 0.85)
	_snow_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_snow_pm.emission_box_extents = Vector3(16, 12, 16)
	_snow.process_material = _snow_pm

	_snow_mesh = SphereMesh.new()
	_snow_mesh.radius = 0.025
	_snow_mesh.height = 0.05
	_snow_mesh.radial_segments = 6
	_snow_mesh.rings = 3
	_snow_mat = StandardMaterial3D.new()
	_snow_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_snow_mesh.material = _snow_mat
	_snow.draw_pass_1 = _snow_mesh
	_snow.visibility_aabb = AABB(Vector3(-50, -70, -50), Vector3(100, 90, 100))

	add_child(_snow)

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
	var sr: float = 0.025 * s
	_snow_mesh.radius = sr
	_snow_mesh.height = sr * 2.0
	_snow_pm.emission_box_extents = Vector3(ext, 12 * s, ext)

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
		_snow.emitting = false
		_snow.visible = false
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
		_snow_mesh.radius = 0.025
		_snow_mesh.height = 0.05
		_snow_pm.emission_box_extents = Vector3(16, 12, 16)

	var cpos: Vector3 = cam.global_position
	_drops.global_position = Vector3(cpos.x, cpos.y + 10, cpos.z)
	_splash.global_position = Vector3(cpos.x, 0.5, cpos.z)
	_snow.global_position = Vector3(cpos.x, cpos.y + 10, cpos.z)

	var cam_xz := Vector2(cpos.x, cpos.z)
	var in_rain := false
	var edge_dist: float = INF
	for zone in _zones:
		var d: float = cam_xz.distance_to(zone.center)
		if d < zone.radius:
			in_rain = true
			edge_dist = minf(edge_dist, zone.radius - d)

	# Tuyết thay mưa khi đang trong bio băng giá (FROST).
	var is_frost: bool = WorldChunk.biome_at(cpos.x, cpos.z, _Data._Dim.DimensionID.REAL_WORLD) == _Data.TileType.FROST

	if in_rain:
		var ratio: float = clamp(edge_dist / 20.0, 0.0, 1.0)
		if is_frost:
			_snow.amount_ratio = ratio
			if _snow_pm:
				var sc: Color = _snow_pm.color
				_snow_pm.color = Color(sc.r, sc.g, sc.b, 0.85 * ratio)
			if not _snow.emitting:
				_snow.emitting = true
				_snow.visible = true
				_drops.emitting = false
				_drops.visible = false
				_splash.emitting = false
				_splash.visible = false
		else:
			_drops.amount_ratio = ratio
			_splash.amount_ratio = ratio
			if _drop_mat:
				var c: Color = _drop_mat.albedo_color
				_drop_mat.albedo_color = Color(c.r, c.g, c.b, 0.30 * ratio)
			if _splash_mat:
				var c: Color = _splash_mat.albedo_color
				_splash_mat.albedo_color = Color(c.r, c.g, c.b, 0.25 * ratio)
			if not _drops.emitting:
				_drops.emitting = true
				_drops.visible = true
				_splash.emitting = true
				_splash.visible = true
			if _snow.emitting:
				_snow.emitting = false
				_snow.visible = false
		if TimeSystem:
			_local_rain_intensity = TimeSystem.get_weather_intensity() * ratio
		else:
			_local_rain_intensity = ratio
	else:
		_local_rain_intensity = 0.0
		if _drops.emitting:
			_drops.emitting = false
			_drops.visible = false
			_splash.emitting = false
			_splash.visible = false
		if _snow.emitting:
			_snow.emitting = false
			_snow.visible = false

	_local_rain_intensity_smoothed = lerp(_local_rain_intensity_smoothed, _local_rain_intensity, delta * 4.0)
	if abs(_local_rain_intensity_smoothed - _local_rain_intensity) < 0.001:
		_local_rain_intensity_smoothed = _local_rain_intensity