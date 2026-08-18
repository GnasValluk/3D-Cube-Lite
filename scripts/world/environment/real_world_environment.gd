extends WorldEnvironment
class_name RealWorldEnvironment

const _VolumetricClouds := preload("res://scripts/world/environment/volumetric_clouds.gd")

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _clouds: MeshInstance3D = null
var _player: Node3D = null
var _sun_dir := Vector3(0.0, 1.0, 0.0)
var _moon_dir := Vector3(0.0, -1.0, 0.0)

const CYCLE_DURATION: float = 600.0

var _keys: Array[Dictionary] = [
	{ "h": 0.0, "bg": Color(0.12, 0.14, 0.26), "amb": Color(0.16, 0.19, 0.32), "ae": 0.5,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
	{ "h": 6.0, "bg": Color(0.70, 0.55, 0.45), "amb": Color(0.65, 0.50, 0.40), "ae": 0.8,  "dc": Color(1.0, 0.85, 0.60), "de": 2.5 },
	{ "h": 8.0, "bg": Color(0.55, 0.78, 0.88), "amb": Color(0.66, 0.62, 0.54), "ae": 1.0, "dc": Color(1.0, 0.95, 0.82), "de": 5.0 },
	{ "h": 14.0,"bg": Color(0.55, 0.78, 0.88), "amb": Color(0.66, 0.62, 0.54), "ae": 1.2, "dc": Color(1.0, 0.95, 0.82), "de": 5.5 },
	{ "h": 15.0,"bg": Color(0.70, 0.60, 0.45), "amb": Color(0.65, 0.55, 0.40), "ae": 1.5, "dc": Color(1.0, 0.80, 0.50), "de": 3.5 },
	{ "h": 18.0,"bg": Color(0.30, 0.22, 0.28), "amb": Color(0.25, 0.20, 0.25), "ae": 0.35,"dc": Color(0.85, 0.60, 0.40), "de": 1.2 },
	{ "h": 24.0,"bg": Color(0.12, 0.14, 0.26), "amb": Color(0.16, 0.19, 0.32), "ae": 0.5,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
]

func _get_hour() -> float:
	if TimeSystem:
		return TimeSystem.get_hour()
	return 6.0

func _lerp_key(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {
		"bg": a["bg"].lerp(b["bg"], t),
		"amb": a["amb"].lerp(b["amb"], t),
		"ae": lerp(a["ae"], b["ae"], t),
		"dc": a["dc"].lerp(b["dc"], t),
		"de": lerp(a["de"], b["de"], t),
	}

func _sample_lighting(h: float) -> Dictionary:
	var nk: int = _keys.size()
	for i in range(nk - 1):
		if h >= _keys[i]["h"] and h < _keys[i + 1]["h"]:
			var t: float = (h - _keys[i]["h"]) / (_keys[i + 1]["h"] - _keys[i]["h"])
			return _lerp_key(_keys[i], _keys[i + 1], t)
	return _keys[0].duplicate()

func _ready() -> void:
	var env := Environment.new()

	var h: float = _get_hour()
	var k: Dictionary = _sample_lighting(h)

	# Bầu trời procedural theo giờ + thời tiết, không còn nền phẳng xám.
	var sky_data := SkyLight.build_sky()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_data[0]
	_sky_mat = sky_data[1]

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = k["amb"]
	# Fill nhẹ (sky bounce) để bóng không đen tuyệt — directional vẫn là nguồn chính.
	env.ambient_light_energy = 0.25

	env.fog_enabled = true
	env.fog_density = 0.0
	env.fog_height = 2.0
	env.fog_height_density = 0.0
	env.fog_light_color = Color(0.40, 0.42, 0.48)
	# Không để fog tô đè lên bầu trời procedural (tránh nền xám phẳng).
	env.fog_sky_affect = 0.0

	_apply_graphics_preset(env)

	environment = env

	if SettingsManager:
		SettingsManager.on_preset_changed(_reapply_preset)
	if DeviceManager:
		DeviceManager.device_changed.connect(func(_m: bool): _reapply_preset())

	_setup_lights()
	_ensure_sun()
	_setup_clouds()

func _apply_graphics_preset(env: Environment) -> void:
	if not SettingsManager:
		return

	var preset: int = SettingsManager.effective_graphics_preset()

	match preset:
		SettingsManager.GraphicsPreset.STANDARD:
			env.glow_enabled = false
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.04
			env.adjustment_saturation = 1.18
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 1.0

		SettingsManager.GraphicsPreset.ENHANCED:
			env.glow_enabled = true
			env.glow_normalized = true
			env.glow_intensity = 0.4
			env.glow_strength = 0.8
			env.glow_bloom = 0.15
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 1.0
			env.glow_hdr_scale = 1.0
			env.set_glow_level(0, false)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, false)
			env.set_glow_level(4, false)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)

			env.adjustment_enabled = true
			env.adjustment_brightness = 0.98
			env.adjustment_contrast = 1.02
			env.adjustment_saturation = 1.1

			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 1.0

		SettingsManager.GraphicsPreset.REALISTIC:
			env.glow_enabled = true
			env.glow_normalized = true
			env.glow_intensity = 0.6
			env.glow_strength = 1.2
			env.glow_bloom = 0.2
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 0.8
			env.glow_hdr_scale = 1.5
			env.set_glow_level(0, true)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, true)
			env.set_glow_level(4, false)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)

			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.05
			env.adjustment_saturation = 1.2

			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 1.0

			env.ssao_enabled = true
			env.ssao_radius = 0.8
			env.ssao_intensity = 0.5
			env.ssao_power = 1.2
			env.ssao_detail = 0.3

	SettingsManager.apply_viewport_settings(get_viewport())

func _setup_lights() -> void:
	var all := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l:
			l.light_energy = 0.0

func _ensure_sun() -> void:
	if _sun != null:
		return
	_sun = DirectionalLight3D.new()
	_sun.name = "SunLight"
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.shadow_enabled = true
	_sun.shadow_blur = 4.0
	add_child(_sun)

	_moon = DirectionalLight3D.new()
	_moon.name = "MoonLight"
	_moon.light_color = Color(0.74, 0.84, 1.0)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = true
	_moon.shadow_blur = 6.0
	_moon.visible = false
	add_child(_moon)

func _update_sun(h: float, rain_factor: float) -> void:
	if _sun == null:
		return
	# Hướng nắng ăn khớp mặt trời trên sky shader (SkyLight): 6h chân trời đông,
	# 12h đỉnh đầu, 18h tây.
	var elev_deg: float = 90.0 * sin((h - 6.0) / 12.0 * PI)
	var day_t: float = clamp((elev_deg + 5.0) / 95.0, 0.0, 1.0)
	var yaw_deg: float = 90.0 - h * 15.0
	var pitch_rad := deg_to_rad(elev_deg)
	var yaw_rad := deg_to_rad(yaw_deg)
	var sun_dir := Vector3(cos(pitch_rad) * cos(yaw_rad), sin(pitch_rad), cos(pitch_rad) * sin(yaw_rad))
	_sun_dir = sun_dir
	var up := Vector3.FORWARD if absf(sun_dir.y) > 0.99 else Vector3.UP
	_sun.look_at(_sun.global_position - sun_dir, up)
	# Bình minh (~7h) và hoàng hôn (~17h) ngả vàng cam ấm; buổi trưa ngả
	# VÀNG ẤM dịu (không trắng gắt) cho dễ nhìn — trưa là khoảng thường xuyên
	# nên cần cảm giác êm ái nhất có thể.
	var sunrise_t: float = clamp(1.0 - absf(h - 7.0) / 2.0, 0.0, 1.0)
	var sunset_t: float = clamp(1.0 - absf(h - 17.0) / 3.0, 0.0, 1.0)
	var warm: float = maxf(sunrise_t, sunset_t)
	_sun.light_color = Color(1.0, 0.94, 0.78).lerp(Color(1.0, 0.62, 0.30), warm * 0.8)
	# Energy trưa giữ bằng mức lúc ~9h (không tăng tiếp) + hạ nhẹ so với
	# trước (1.6→1.45) để trưa dịu, không chói gắt.
	var energy_t: float = minf(day_t, 0.725)
	_sun.light_energy = lerp(0.0, 1.45, pow(energy_t, 0.6)) * rain_factor

	# ── Ánh trăng: đèn Directional ngược phía mặt trời — ban đêm có trăng sáng thật ──
	if _moon == null:
		return
	# Quỹ đạo trăng khớp sky shader (SkyLight): mọc ~18h, đỉnh nửa đêm, lặn ~6h.
	var night_factor: float = 1.0 - day_t
	var moon_scan := fposmod(h + 12.0, 24.0)
	var moon_elev_deg: float = 90.0 * sin(deg_to_rad((moon_scan - 6.0) * 15.0))
	var moon_yaw_deg: float = 90.0 - moon_scan * 15.0 + 22.0
	var mp_rad := deg_to_rad(moon_elev_deg)
	var my_rad := deg_to_rad(moon_yaw_deg)
	var moon_dir := Vector3(cos(mp_rad) * cos(my_rad), sin(mp_rad), cos(mp_rad) * sin(my_rad))
	_moon_dir = moon_dir
	var moon_up: float = clamp(moon_elev_deg / 40.0, 0.0, 1.0)
	_moon.look_at(_moon.global_position - moon_dir, Vector3.FORWARD if absf(moon_dir.y) > 0.99 else Vector3.UP)
	# Sáng đầy đủ khi trăng tròn, nhạt khi trăng mảnh.
	var days: float = float(TimeSystem.get_total_days()) if TimeSystem else -1.0
	var phase_light: float = 1.0
	if days >= 0.0:
		var phase: float = fposmod(days / SkyLight.SYNODIC_MONTH, 1.0)
		phase_light = lerp(0.55, 1.0, 0.5 * (1.0 - cos(phase * TAU)))
	_moon.visible = moon_up > 0.01 and night_factor > 0.05
	_moon.light_energy = 0.45 * moon_up * night_factor * phase_light * rain_factor

func _setup_clouds() -> void:
	_clouds = _VolumetricClouds.new()
	_clouds.name = "VolumetricClouds"
	get_parent().call_deferred("add_child", _clouds)

func _find_cloud_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var world := tree.current_scene
	if world == null:
		return
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()
	else:
		_player = world.get_node_or_null("Player")

# Đẩy màu/hướng sáng + vị trí cho đám mây thể tích mỗi frame.
func _update_clouds(h: float, weather: float, day_t: float) -> void:
	if _clouds == null:
		return
	var night: float = 1.0 - day_t
	var light_dir: Vector3 = _sun_dir.lerp(_moon_dir, night * 0.85)
	if light_dir.length_squared() < 0.001:
		light_dir = Vector3(0.0, 1.0, 0.0)
	light_dir = light_dir.normalized()
	var sun_low: float = clamp(1.0 - absf(_sun_dir.y) * 2.2, 0.0, 1.0)
	var col := Color(1.04, 1.03, 0.99)
	col = col.lerp(Color(1.28, 1.06, 0.80), sun_low * 0.55)
	col = col.lerp(Color(0.30, 0.34, 0.48), night * 0.9)
	col = col.lerp(Color(0.56, 0.57, 0.60), weather * 0.9)
	var bright: float = (1.0 - night * 0.62) * (1.0 - weather * 0.2) * (0.9 + 0.32 * day_t)
	var threshold: float = 0.46 + night * 0.05 + weather * 0.03
	_clouds.update_clouds(light_dir, col, bright, threshold)
	_clouds.visible = SettingsManager.clouds_enabled if SettingsManager else true
	if _player == null or not is_instance_valid(_player):
		_find_cloud_player()
		if _player == null:
			return
	_clouds.follow(_player.global_position)

func _reapply_preset() -> void:
	if environment:
		_apply_graphics_preset(environment)
	SettingsManager.apply_viewport_settings(get_viewport())

func _process(delta: float) -> void:
	var h: float = _get_hour()
	var k: Dictionary = _sample_lighting(h)

	var weather_intensity: float = RainManager.get_local_rain_intensity()

	var rain_factor: float = 1.0 - weather_intensity * 0.55

	var day_t_real: float = clamp((90.0 * sin((h - 6.0) / 12.0 * PI) + 5.0) / 95.0, 0.0, 1.0)
	SkyLight.update_sky(_sky_mat, h, weather_intensity, float(TimeSystem.get_total_days()) if TimeSystem else -1.0, SettingsManager.clouds_enabled if SettingsManager else true)
	environment.ambient_light_color = k["amb"].lerp(Color(0.08, 0.10, 0.14), weather_intensity * 0.7)
	# Fill mềm theo ngày/đêm + mưa để bóng dịu, không đen tuyệt.
	environment.ambient_light_energy = 0.28 * rain_factor * lerp(0.72, 1.0, day_t_real)
	_update_sun(h, rain_factor)
	# Mây thể tích thật thay mây vẽ trên sky shader (tránh trùng hai lớp).
	_sky_mat.set_shader_parameter("cloud_cover", 0.0)
	_update_clouds(h, weather_intensity, day_t_real)

	environment.fog_density = weather_intensity * 0.012
	environment.fog_height_density = weather_intensity * 0.08

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
