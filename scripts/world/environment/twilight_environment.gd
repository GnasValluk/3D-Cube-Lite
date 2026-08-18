extends WorldEnvironment

const CYCLE_DURATION: float = 600.0
var _lights: Array[Light3D] = []
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null

const DAY_BG         := Color(0.42, 0.62, 0.72)
const DAY_AMBIENT    := Color(0.50, 0.62, 0.74)

const NIGHT_BG         := Color(0.10, 0.12, 0.20)
const NIGHT_AMBIENT    := Color(0.10, 0.14, 0.20)

func _ready() -> void:
	var env := Environment.new()

	var sky_data := SkyLight.build_sky()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_data[0]
	_sky_mat = sky_data[1]

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = DAY_AMBIENT
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
	var preset: int = SettingsManager.effective_graphics_preset() if SettingsManager else 0

	match preset:
		SettingsManager.GraphicsPreset.STANDARD:
			env.glow_enabled = true
			env.glow_normalized = true
			env.glow_intensity = 0.6
			env.glow_strength = 1.2
			env.glow_bloom = 0.2
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 0.8
			env.glow_hdr_scale = 1.5
			env.set_glow_level(0, false)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, true)
			env.set_glow_level(4, false)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)

			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 1.2

			env.adjustment_enabled = true
			env.adjustment_brightness = 0.95
			env.adjustment_contrast = 1.05
			env.adjustment_saturation = 1.3

		SettingsManager.GraphicsPreset.ENHANCED:
			env.glow_enabled = true
			env.glow_normalized = true
			env.glow_intensity = 0.8
			env.glow_strength = 1.5
			env.glow_bloom = 0.25
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 0.7
			env.glow_hdr_scale = 2.0
			env.set_glow_level(0, true)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, true)
			env.set_glow_level(4, false)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)

			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 1.0

			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.1
			env.adjustment_saturation = 1.4

		SettingsManager.GraphicsPreset.REALISTIC:
			env.glow_enabled = true
			env.glow_normalized = true
			env.glow_intensity = 1.2
			env.glow_strength = 2.0
			env.glow_bloom = 0.35
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 0.5
			env.glow_hdr_scale = 3.0
			env.set_glow_level(0, true)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, true)
			env.set_glow_level(4, true)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)

			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.2
			env.tonemap_white = 1.0

			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.15
			env.adjustment_saturation = 1.5

			env.ssao_enabled = true
			env.ssao_radius = 1.0
			env.ssao_intensity = 0.6
			env.ssao_power = 1.5
			env.ssao_detail = 0.5

	if SettingsManager:
		SettingsManager.apply_viewport_settings(get_viewport())

func _setup_lights() -> void:
	var omnis := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for omni in omnis:
		var o := omni as OmniLight3D
		if o == null:
			continue
		o.light_energy = 0.0
		o.omni_range   = 0.1

	var all := get_parent().find_children("*", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l and l.name != "PlayerLight" and not l in _lights:
			_lights.append(l)

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

func _get_hour() -> float:
	if TimeSystem:
		return TimeSystem.get_hour()
	return 6.0

func _update_sun(h: float, rain_factor: float) -> void:
	if _sun == null:
		return
	var elev_deg: float = 90.0 * sin((h - 6.0) / 12.0 * PI)
	var day_t: float = clamp((elev_deg + 5.0) / 95.0, 0.0, 1.0)
	var yaw_deg: float = 90.0 - h * 15.0
	var pitch_rad := deg_to_rad(elev_deg)
	var yaw_rad := deg_to_rad(yaw_deg)
	var sun_dir := Vector3(cos(pitch_rad) * cos(yaw_rad), sin(pitch_rad), cos(pitch_rad) * sin(yaw_rad))
	var up := Vector3.FORWARD if absf(sun_dir.y) > 0.99 else Vector3.UP
	_sun.look_at(_sun.global_position - sun_dir, up)
	# Bình minh (~7h) và hoàng hôn (~17h) ngả vàng cam ấm; buổi trưa ngả
	# VÀNG ẤM dịu (không trắng gắt) cho dễ nhìn.
	var sunrise_t: float = clamp(1.0 - absf(h - 7.0) / 2.0, 0.0, 1.0)
	var sunset_t: float = clamp(1.0 - absf(h - 17.0) / 3.0, 0.0, 1.0)
	var warm: float = maxf(sunrise_t, sunset_t)
	_sun.light_color = Color(1.0, 0.94, 0.78).lerp(Color(1.0, 0.62, 0.30), warm * 0.8)
	# Energy trưa giữ bằng mức lúc ~9h (không tăng tiếp) để không bị gắt/chói.
	var energy_t: float = minf(day_t, 0.725)
	_sun.light_energy = lerp(0.0, 1.45, pow(energy_t, 0.6)) * rain_factor

	# ── Ánh trăng: đèn Directional ngược phía mặt trời — ban đêm có trăng sáng ──
	if _moon == null:
		return
	var night_factor: float = 1.0 - day_t
	var moon_scan := fposmod(h + 12.0, 24.0)
	var moon_elev_deg: float = 90.0 * sin(deg_to_rad((moon_scan - 6.0) * 15.0))
	var moon_yaw_deg: float = 90.0 - moon_scan * 15.0 + 22.0
	var mp_rad := deg_to_rad(moon_elev_deg)
	var my_rad := deg_to_rad(moon_yaw_deg)
	var moon_dir := Vector3(cos(mp_rad) * cos(my_rad), sin(mp_rad), cos(mp_rad) * sin(my_rad))
	var moon_up: float = clamp(moon_elev_deg / 40.0, 0.0, 1.0)
	_moon.look_at(_moon.global_position - moon_dir, Vector3.FORWARD if absf(moon_dir.y) > 0.99 else Vector3.UP)
	var days: float = float(TimeSystem.get_total_days()) if TimeSystem else -1.0
	var phase_light: float = 1.0
	if days >= 0.0:
		var phase: float = fposmod(days / SkyLight.SYNODIC_MONTH, 1.0)
		phase_light = lerp(0.55, 1.0, 0.5 * (1.0 - cos(phase * TAU)))
	_moon.visible = moon_up > 0.01 and night_factor > 0.05
	_moon.light_energy = 0.55 * moon_up * night_factor * phase_light * rain_factor

func _reapply_preset() -> void:
	if environment:
		_apply_graphics_preset(environment)
	SettingsManager.apply_viewport_settings(get_viewport())

func _process(delta: float) -> void:
	var hour: float
	if TimeSystem:
		hour = TimeSystem.get_hour()
	else:
		var progress: float = TimeSystem.get_cycle_progress_fraction() if TimeSystem else 0.25
		hour = fmod(progress * 24.0, 24.0)

	# t từ 0 (đêm) đến 1 (trưa) — dùng chung cho ánh sáng khuếch tán.
	var elev := (hour - 6.0) / 12.0 * PI
	var t: float = clamp(90.0 * sin(elev) / 90.0, 0.0, 1.0)

	var wi: float = RainManager.get_local_rain_intensity()
	var rf: float = 1.0 - wi * 0.55

	SkyLight.update_sky(_sky_mat, hour, wi, float(TimeSystem.get_total_days()) if TimeSystem else -1.0, SettingsManager.clouds_enabled if SettingsManager else true)
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, 1.0 - t).lerp(Color(0.08, 0.10, 0.14), wi * 0.7)
	# Fill mềm theo ngày/đêm + mưa để bóng dịu, không đen tuyệt.
	environment.ambient_light_energy = 0.25 * rf * lerp(0.3, 1.0, t)

	for light in _lights:
		var base_energy: float = 5.0
		if light is OmniLight3D:
			base_energy = 1.5
		light.light_energy = base_energy * t * rf

	_update_sun(hour, rf)

	environment.fog_density = wi * 0.012
	environment.fog_height_density = wi * 0.08

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
