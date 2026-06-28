## twilight_environment.gd
## Environment + Day/Night cycle
## Ngày: ánh sáng đầy đủ, nền teal sáng, mặt trời trên cao
## Đêm: tắt dần light, nền tối, mặt trăng lên, neon vẫn glow

extends WorldEnvironment

const CYCLE_DURATION: float = 600.0
var _cycle_time: float = 0.0
var _lights: Array[Light3D] = []
var _dir_light: DirectionalLight3D

# ── Day values ──────────────────────────────────────────────────────────────
const DAY_BG         := Color(0.40, 0.60, 0.65)
const DAY_AMBIENT    := Color(0.50, 0.65, 0.70)
const DAY_AMB_ENERGY := 1.0

# ── Night values ────────────────────────────────────────────────────────────
const NIGHT_BG         := Color(0.04, 0.06, 0.10)
const NIGHT_AMBIENT    := Color(0.04, 0.08, 0.10)
const NIGHT_AMB_ENERGY := 0.15


func _ready() -> void:
	var env := Environment.new()

	# ── Nền ──────────────────────────────────────────────────────────────────
	env.background_mode  = Environment.BG_COLOR
	env.background_color = DAY_BG

	# ── Ambient ──────────────────────────────────────────────────────────────
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = DAY_AMBIENT
	env.ambient_light_energy = DAY_AMB_ENERGY

	# ── Bloom ────────────────────────────────────────────────────────────────
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

	# ── Tone mapping ─────────────────────────────────────────────────────────
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.2

	# ── Saturation ───────────────────────────────────────────────────────────
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
		o.light_color  = Color(0.40, 1.0, 0.85)
		o.light_energy = 0.6
		o.omni_range   = 2.0
		_lights.append(o)

	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		dir.light_color  = Color(1.0, 0.90, 0.70)
		dir.light_energy = 5.0
		dir.shadow_enabled = false
		_dir_light = dir
		_lights.append(dir)

	var all := get_parent().find_children("*", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l and not l in _lights:
			_lights.append(l)


func _process(delta: float) -> void:
	if _lights.is_empty():
		return
	_cycle_time += delta
	var raw: float = sin(_cycle_time / CYCLE_DURATION * TAU)
	var t: float = clamp(raw * 0.5 + 0.5, 0.3, 1.0)

	# Environment
	environment.background_color = DAY_BG.lerp(NIGHT_BG, 1.0 - t)
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, 1.0 - t)
	environment.ambient_light_energy = lerp(DAY_AMB_ENERGY, NIGHT_AMB_ENERGY, 1.0 - t)

	# Lights
	for light in _lights:
		var base_energy: float = 0.6
		if light is OmniLight3D:
			base_energy = 1.5
		light.light_energy = base_energy * t


func get_cycle_progress() -> float:
	return _cycle_time / CYCLE_DURATION
