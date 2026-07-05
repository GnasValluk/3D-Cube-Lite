extends WorldEnvironment

const CYCLE_DURATION: float = 600.0
var _lights: Array[Light3D] = []
var _dir_light: DirectionalLight3D

const DAY_BG         := Color(0.42, 0.62, 0.72)
const DAY_AMBIENT    := Color(0.50, 0.62, 0.74)
const DAY_AMB_ENERGY := 1.0

const NIGHT_BG         := Color(0.04, 0.06, 0.10)
const NIGHT_AMBIENT    := Color(0.04, 0.08, 0.10)
const NIGHT_AMB_ENERGY := 0.15

func _ready() -> void:
	var env := Environment.new()

	env.background_mode  = Environment.BG_COLOR
	env.background_color = DAY_BG

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = DAY_AMBIENT
	env.ambient_light_energy = DAY_AMB_ENERGY

	env.glow_enabled       = true
	env.glow_normalized    = true
	env.glow_intensity     = 0.6
	env.glow_strength      = 1.2
	env.glow_bloom         = 0.2
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale     = 1.5
	env.set_glow_level(0, false)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.set_glow_level(3, true)
	env.set_glow_level(4, false)
	env.set_glow_level(5, false)
	env.set_glow_level(6, false)

	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.2

	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.95
	env.adjustment_contrast   = 1.05
	env.adjustment_saturation = 1.3

	environment = env

	await get_tree().process_frame
	_setup_lights()

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
		dir.shadow_enabled = false
		_dir_light = dir
		_lights.append(dir)

	var all := get_parent().find_children("*", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l and l.name != "PlayerLight" and not l in _lights:
			_lights.append(l)

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
