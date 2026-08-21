extends WorldEnvironment
class_name RealWorldEnvironment

var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _sun_dir := Vector3(0.0, 1.0, 0.0)
var _moon_dir := Vector3(0.0, -1.0, 0.0)
## TẦNG MÂY KHỐI ở y=25: các MẢNG KHỐI box dày (kiểu voxel) trôi chậm,
## wrap vô tận quanh người chơi theo chu kỳ SPAN.
var _cloud_holder: Node3D = null
var _cloud_mm_res: MultiMesh = null
var _cloud_smat: StandardMaterial3D = null
var _cloud_pos := PackedVector3Array()
var _cloud_scale: Array[Vector3] = []
var _cloud_wind := Vector3.ZERO
const CLOUD_SPAN: float = 2200.0
const CLOUD_Y: float = 25.0

const CYCLE_DURATION: float = 600.0

var _keys: Array[Dictionary] = [
	{ "h": 0.0, "bg": Color(0.12, 0.14, 0.26), "amb": Color(0.10, 0.12, 0.20), "ae": 0.35,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
	{ "h": 6.0, "bg": Color(0.70, 0.55, 0.45), "amb": Color(0.65, 0.50, 0.40), "ae": 0.8,  "dc": Color(1.0, 0.85, 0.60), "de": 2.5 },
	{ "h": 8.0, "bg": Color(0.55, 0.78, 0.88), "amb": Color(0.66, 0.62, 0.54), "ae": 1.0, "dc": Color(1.0, 0.95, 0.82), "de": 5.0 },
	{ "h": 14.0,"bg": Color(0.55, 0.78, 0.88), "amb": Color(0.66, 0.62, 0.54), "ae": 1.2, "dc": Color(1.0, 0.95, 0.82), "de": 5.5 },
	{ "h": 15.0,"bg": Color(0.70, 0.60, 0.45), "amb": Color(0.65, 0.55, 0.40), "ae": 1.5, "dc": Color(1.0, 0.80, 0.50), "de": 3.5 },
	{ "h": 18.0,"bg": Color(0.30, 0.22, 0.28), "amb": Color(0.25, 0.20, 0.25), "ae": 0.35,"dc": Color(0.85, 0.60, 0.40), "de": 1.2 },
	{ "h": 24.0,"bg": Color(0.12, 0.14, 0.26), "amb": Color(0.10, 0.12, 0.20), "ae": 0.35,"dc": Color(0.65, 0.70, 0.85), "de": 0.8 },
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

	_setup_clouds()

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
			# SSAO nhẹ hơn — bớt nhiễu hạt trong góc tối
			env.ssao_radius = 0.8
			env.ssao_intensity = 0.32
			env.ssao_power = 1.1
			env.ssao_detail = 0.15

	SettingsManager.apply_viewport_settings(get_viewport())

func _setup_lights() -> void:
	var all := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l:
			l.light_energy = 0.0

## ── TẦNG MÂY KHỐI y=25 — các MẢNG KHỐI box dày kiểu voxel ────────────────────
## ~52 cụm, mỗi cụm 2-4 slab box chồng lệch (rộng 9-38m, dày ~3-5m) trải trên
## diện 1500×1500. Mỗi frame: wrap vị trí quanh người chơi theo chu kỳ SPAN
## (trường mây vô tận) + trôi chậm theo gió. Màu tint theo giờ qua albedo.
func _setup_clouds() -> void:
	if _cloud_holder != null:
		return
	_cloud_holder = Node3D.new()
	_cloud_holder.name = "CloudLayer"
	_cloud_holder.position.y = CLOUD_Y
	add_child(_cloud_holder)

	_cloud_smat = StandardMaterial3D.new()
	_cloud_smat.vertex_color_use_as_albedo = true
	_cloud_smat.roughness = 1.0
	_cloud_smat.metallic = 0.0

	var rng := RandomNumberGenerator.new()
	rng.seed = 20240613
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 14
	puff.rings = 8
	var xf: Array = []
	var cls: Array = []
	for ci in range(46):
		var cx: float = rng.randf_range(-CLOUD_SPAN, CLOUD_SPAN) * 0.5
		var cz: float = rng.randf_range(-CLOUD_SPAN, CLOUD_SPAN) * 0.5
		var puffs: int = 3 + rng.randi_range(0, 2)
		var cw: float = rng.randf_range(26.0, 60.0)    # MẢNG MÂY TO hơn trước gấp đôi
		var cd: float = rng.randf_range(18.0, 44.0)
		for si in range(puffs):
			var w: float = cw * rng.randf_range(0.45, 1.05)
			var d: float = cd * rng.randf_range(0.45, 1.05)
			var hgt: float = rng.randf_range(6.5, 12.0)   # bồng bềnh dày như khói
			var ox: float = rng.randf_range(-cw * 0.30, cw * 0.30)
			var oz: float = rng.randf_range(-cd * 0.30, cd * 0.30)
			var oy: float = rng.randf_range(-1.2, 2.4)
			var sc := Vector3(w, hgt, d)
			xf.append(Transform3D(Basis().scaled(sc), Vector3(cx + ox, oy, cz + oz)))
			var shade: float = rng.randf_range(0.88, 1.08)
			cls.append(Color(shade, shade, shade * 1.02))

	_cloud_mm_res = MultiMesh.new()
	_cloud_mm_res.transform_format = MultiMesh.TRANSFORM_3D
	_cloud_mm_res.use_colors = true
	_cloud_mm_res.mesh = puff
	_cloud_mm_res.instance_count = xf.size()
	_cloud_pos.resize(xf.size())
	for i in range(xf.size()):
		var tf: Transform3D = xf[i]
		_cloud_mm_res.set_instance_transform(i, tf)
		_cloud_mm_res.set_instance_color(i, cls[i])
		_cloud_pos[i] = tf.origin
		_cloud_scale.append(tf.basis.get_scale())

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _cloud_mm_res
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_holder.add_child(mmi)

## Mỗi frame: trôi theo gió + wrap quanh camera; tint màu theo giờ.
func _update_clouds(delta: float, h: float, day_t: float, weather: float) -> void:
	if _cloud_holder == null or _cloud_mm_res == null or _cloud_mm_res.instance_count == 0:
		return
	_cloud_wind += Vector3(2.2, 0.0, -0.8) * delta   # TRÔI CHẬM — mây bồng bềnh
	var cam := get_viewport().get_camera_3d()
	var px: float = cam.global_position.x if cam != null else 0.0
	var pz: float = cam.global_position.z if cam != null else 0.0
	var half := CLOUD_SPAN * 0.5
	for i in range(_cloud_pos.size()):
		var raw := _cloud_pos[i] + _cloud_wind
		raw.x = px + fposmod(raw.x - px + half, CLOUD_SPAN) - half
		raw.z = pz + fposmod(raw.z - pz + half, CLOUD_SPAN) - half
		raw.y = CLOUD_Y
		var sc := _cloud_scale[i]
		_cloud_mm_res.set_instance_transform(i, Transform3D(
			Basis(Vector3(sc.x, 0, 0), Vector3(0, sc.y, 0), Vector3(0, 0, sc.z)), raw))
	# Tint: ngày trắng, chiều vàng cam, đêm xám tối; mưa xám đục
	var warm: float = clampf(1.0 - absf(h - 17.0) / 2.6, 0.0, 1.0)
	var c := Color(0.12, 0.14, 0.24).lerp(Color(0.99, 0.99, 1.0), day_t)
	c = c.lerp(Color(0.95, 0.62, 0.34), warm * clampf(day_t + 0.12, 0.0, 1.0) * 0.9)
	if weather > 0.0:
		c = c.lerp(Color(0.45, 0.47, 0.52), weather * 0.6)
	_cloud_smat.albedo_color = c

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
	# Tông ấm buổi sáng kéo tới ~13h: trưa sáng dịu như 8–9h, không bạc gắt.
	var morning_w: float = clamp(1.0 - absf(h - 8.5) / 5.0, 0.0, 1.0)
	_sun.light_color = _sun.light_color.lerp(Color(1.00, 0.90, 0.72), morning_w * 0.30)
	# Energy trưa GIỮA MỨC (1.22) — đủ sáng mà mặt đất không cháy trắng.
	var energy_t: float = minf(day_t, 0.725)
	_sun.light_energy = lerp(0.0, 1.22, pow(energy_t, 0.6)) * rain_factor

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
	# Trăng rọi sáng vừa phải — đêm phải thật tối, trăng chỉ tông nhẹ để thấy đường.
	_moon.light_energy = 0.13 * moon_up * night_factor * phase_light * rain_factor

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
	environment.ambient_light_energy = 0.28 * rain_factor * lerp(0.72, 1.0, day_t_real)
	_update_sun(h, rain_factor)

	environment.fog_density = weather_intensity * 0.012
	environment.fog_height_density = weather_intensity * 0.08

	# ── MÂY KHỐI: tint màu theo giờ + trôi/wrap quanh người chơi ────────────
	_update_clouds(delta, h, day_t_real, weather_intensity)

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
