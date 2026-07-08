extends WorldEnvironment

const CYCLE_DURATION: float = 600.0
var _lights: Array[Light3D] = []
var _dir_light: DirectionalLight3D

const DAY_BG         := Color(0.42, 0.62, 0.72)
const DAY_AMBIENT    := Color(0.50, 0.62, 0.74)
const DAY_AMB_ENERGY := 1.0

const NIGHT_BG         := Color(0.10, 0.12, 0.20)
const NIGHT_AMBIENT    := Color(0.10, 0.14, 0.20)
const NIGHT_AMB_ENERGY := 0.35

func _ready() -> void:
	var env := Environment.new()

	env.background_mode  = Environment.BG_COLOR
	env.background_color = DAY_BG

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = DAY_AMBIENT
	env.ambient_light_energy = DAY_AMB_ENERGY

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

	SettingsManager.apply_viewport_settings(get_viewport())

func _setup_lights() -> void:
	var omnis := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for omni in omnis:
		var o := omni as OmniLight3D
		if o == null:
			continue
		o.light_energy = 0.0
		o.omni_range   = 0.1

	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		dir.light_color  = Color(1.0, 0.95, 0.82)
		dir.light_energy = 5.0
		_apply_shadow_settings(dir)
		_dir_light = dir
		_lights.append(dir)

	var all := get_parent().find_children("*", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l and l.name != "PlayerLight" and not l in _lights:
			_lights.append(l)

func _apply_shadow_settings(dir: DirectionalLight3D) -> void:
	var preset: int = SettingsManager.graphics_preset if SettingsManager else 0

	match preset:
		SettingsManager.GraphicsPreset.STANDARD:
			dir.shadow_enabled = false
		SettingsManager.GraphicsPreset.ENHANCED:
			dir.shadow_enabled = true
			dir.shadow_bias = 0.02
			dir.shadow_normal_bias = 0.5
			dir.directional_shadow_max_distance = 40.0
			dir.directional_shadow_split_1 = 0.1
			dir.directional_shadow_split_2 = 0.3
			dir.directional_shadow_split_3 = 0.6
			dir.directional_shadow_blend_splits = false
		SettingsManager.GraphicsPreset.REALISTIC:
			dir.shadow_enabled = true
			dir.shadow_bias = 0.01
			dir.shadow_normal_bias = 0.3
			dir.directional_shadow_max_distance = 80.0
			dir.directional_shadow_split_1 = 0.12
			dir.directional_shadow_split_2 = 0.3
			dir.directional_shadow_split_3 = 0.55
			dir.directional_shadow_blend_splits = true

func _reapply_preset() -> void:
	if environment:
		_apply_graphics_preset(environment)

func _process(delta: float) -> void:
	if _lights.is_empty():
		return

	var raw: float
	if TimeSystem:
		var progress: float = TimeSystem.get_cycle_progress_fraction()
		raw = sin(progress * TAU)
	else:
		raw = 0.5
	var t: float = clamp(raw * 0.5 + 0.5, 0.3, 1.0)

	environment.background_color = DAY_BG.lerp(NIGHT_BG, 1.0 - t)
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, 1.0 - t)
	environment.ambient_light_energy = lerp(DAY_AMB_ENERGY, NIGHT_AMB_ENERGY, 1.0 - t)

	for light in _lights:
		var base_energy: float = 0.6
		if light is OmniLight3D:
			base_energy = 1.5
		light.light_energy = base_energy * t

func get_cycle_progress() -> float:
	if TimeSystem:
		return TimeSystem.get_cycle_progress()
	return 0.0
