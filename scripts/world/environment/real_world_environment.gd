extends WorldEnvironment
class_name RealWorldEnvironment

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D = null

const CYCLE_DURATION: float = 600.0

var _keys: Array[Dictionary] = [
	{ "h": 0.0, "bg": Color(0.08, 0.10, 0.20), "amb": Color(0.10, 0.12, 0.22), "ae": 0.30,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
	{ "h": 6.0, "bg": Color(0.70, 0.55, 0.45), "amb": Color(0.65, 0.50, 0.40), "ae": 0.8,  "dc": Color(1.0, 0.85, 0.60), "de": 2.5 },
	{ "h": 8.0, "bg": Color(0.55, 0.78, 0.88), "amb": Color(0.58, 0.60, 0.62), "ae": 1.0, "dc": Color(1.0, 0.95, 0.82), "de": 5.0 },
	{ "h": 14.0,"bg": Color(0.55, 0.78, 0.88), "amb": Color(0.58, 0.60, 0.62), "ae": 1.2, "dc": Color(1.0, 0.95, 0.82), "de": 5.5 },
	{ "h": 15.0,"bg": Color(0.70, 0.60, 0.45), "amb": Color(0.65, 0.55, 0.40), "ae": 1.5, "dc": Color(1.0, 0.80, 0.50), "de": 3.5 },
	{ "h": 18.0,"bg": Color(0.30, 0.22, 0.28), "amb": Color(0.25, 0.20, 0.25), "ae": 0.35,"dc": Color(0.85, 0.60, 0.40), "de": 1.2 },
	{ "h": 24.0,"bg": Color(0.08, 0.10, 0.20), "amb": Color(0.10, 0.12, 0.22), "ae": 0.30,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
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
	var up := Vector3.FORWARD if absf(sun_dir.y) > 0.99 else Vector3.UP
	_sun.look_at(_sun.global_position - sun_dir, up)
	# Bình minh (~7h) và hoàng hôn (~17h) ngả vàng cam ấm; buổi trưa giữ
	# trắng-vàng mềm (không chói) cho dễ nhìn.
	var sunrise_t: float = clamp(1.0 - absf(h - 7.0) / 2.0, 0.0, 1.0)
	var sunset_t: float = clamp(1.0 - absf(h - 17.0) / 3.0, 0.0, 1.0)
	var warm: float = maxf(sunrise_t, sunset_t)
	_sun.light_color = Color(1.0, 0.97, 0.90).lerp(Color(1.0, 0.62, 0.30), warm * 0.8)
	# Energy trưa giữ bằng mức lúc ~9h (không tăng tiếp) để không bị gắt/chói.
	var energy_t: float = minf(day_t, 0.725)
	_sun.light_energy = lerp(0.0, 1.6, pow(energy_t, 0.6)) * rain_factor

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
	SkyLight.update_sky(_sky_mat, h, weather_intensity, float(TimeSystem.get_total_days()) if TimeSystem else -1.0)
	environment.ambient_light_color = k["amb"].lerp(Color(0.08, 0.10, 0.14), weather_intensity * 0.7)
	# Fill mềm theo ngày/đêm + mưa để bóng dịu, không đen tuyệt.
	environment.ambient_light_energy = 0.25 * rain_factor * lerp(0.5, 1.0, day_t_real)
	_update_sun(h, rain_factor)

	environment.fog_density = weather_intensity * 0.012
	environment.fog_height_density = weather_intensity * 0.08

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
