extends WorldEnvironment
class_name RealWorldEnvironment

var _dir_light: DirectionalLight3D

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

	env.background_mode  = Environment.BG_COLOR
	env.background_color = _keys[0]["bg"]

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = _keys[0]["amb"]
	env.ambient_light_energy = _keys[0]["ae"]

	_apply_graphics_preset(env)

	environment = env

	if SettingsManager:
		SettingsManager.on_preset_changed(_reapply_preset)

	await get_tree().process_frame
	_setup_lights()

func _apply_graphics_preset(env: Environment) -> void:
	var preset: int = SettingsManager.graphics_preset if SettingsManager else 0

	match preset:
		SettingsManager.GraphicsPreset.STANDARD:
			env.glow_enabled = false
			env.adjustment_enabled = false
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
	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		_apply_shadow_settings(dir)
		_dir_light = dir

	var all := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l:
			l.light_energy = 0.0

func _apply_shadow_settings(dir: DirectionalLight3D) -> void:
	var preset: int = SettingsManager.graphics_preset if SettingsManager else 0

	match preset:
		SettingsManager.GraphicsPreset.STANDARD:
			dir.shadow_enabled = false
		SettingsManager.GraphicsPreset.ENHANCED:
			dir.shadow_enabled = true
			dir.shadow_bias = 0.02
			dir.shadow_normal_bias = 0.5
			dir.directional_shadow_max_distance = 50.0
			dir.directional_shadow_split_1 = 0.1
			dir.directional_shadow_split_2 = 0.3
			dir.directional_shadow_split_3 = 0.6
			dir.directional_shadow_blend_splits = false
		SettingsManager.GraphicsPreset.REALISTIC:
			dir.shadow_enabled = true
			dir.shadow_bias = 0.01
			dir.shadow_normal_bias = 0.3
			dir.directional_shadow_max_distance = 100.0
			dir.directional_shadow_split_1 = 0.12
			dir.directional_shadow_split_2 = 0.3
			dir.directional_shadow_split_3 = 0.55
			dir.directional_shadow_blend_splits = true

func _reapply_preset() -> void:
	if environment:
		_apply_graphics_preset(environment)

func _process(delta: float) -> void:
	var h: float = _get_hour()
	var k: Dictionary = _sample_lighting(h)

	var weather_intensity: float = 0.0
	if TimeSystem:
		weather_intensity = TimeSystem.get_weather_intensity()

	var rain_factor: float = 1.0 - weather_intensity * 0.35

	environment.background_color = k["bg"].lerp(Color(0.12, 0.14, 0.18), weather_intensity * 0.5)
	environment.ambient_light_color = k["amb"].lerp(Color(0.08, 0.10, 0.14), weather_intensity * 0.5)
	environment.ambient_light_energy = k["ae"] * rain_factor

	if _dir_light:
		_dir_light.light_color = k["dc"].lerp(Color(0.50, 0.50, 0.55), weather_intensity * 0.4)
		_dir_light.light_energy = k["de"] * rain_factor

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
