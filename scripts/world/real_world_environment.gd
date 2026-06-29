extends WorldEnvironment
class_name RealWorldEnvironment

const CYCLE_DURATION: float = 600.0
var _cycle_time: float = 0.0
var _dir_light: DirectionalLight3D

const DAY_BG         := Color(0.50, 0.65, 0.80)
const DAY_AMBIENT    := Color(0.40, 0.55, 0.65)
const DAY_AMB_ENERGY := 2.5

const NIGHT_BG         := Color(0.02, 0.03, 0.05)
const NIGHT_AMBIENT    := Color(0.03, 0.04, 0.06)
const NIGHT_AMB_ENERGY := 0.10

func _ready() -> void:
	var env := Environment.new()

	env.background_mode  = Environment.BG_COLOR
	env.background_color = DAY_BG

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = DAY_AMBIENT
	env.ambient_light_energy = DAY_AMB_ENERGY

	env.glow_enabled = false

	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.0

	environment = env

	await get_tree().process_frame
	_setup_lights()

func _setup_lights() -> void:
	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		dir.light_color  = Color(1.0, 0.95, 0.85)
		dir.light_energy = 12.0
		dir.shadow_enabled = false
		_dir_light = dir

	var all := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l:
			l.light_energy = 0.0

func _process(delta: float) -> void:
	_cycle_time += delta
	var raw: float = sin(_cycle_time / CYCLE_DURATION * TAU)
	var t: float = clamp(raw * 0.5 + 0.5, 0.0, 1.0)

	environment.background_color = DAY_BG.lerp(NIGHT_BG, 1.0 - t)
	environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, 1.0 - t)
	environment.ambient_light_energy = lerp(DAY_AMB_ENERGY, NIGHT_AMB_ENERGY, 1.0 - t)

	if _dir_light:
		_dir_light.light_energy = 12.0 * t

func get_cycle_progress() -> float:
	return _cycle_time / CYCLE_DURATION
