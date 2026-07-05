extends WorldEnvironment
class_name RealWorldEnvironment

var _dir_light: DirectionalLight3D

const CYCLE_DURATION: float = 600.0

var _keys: Array[Dictionary] = [
	{ "h": 0.0, "bg": Color(0.03, 0.05, 0.12), "amb": Color(0.04, 0.06, 0.15), "ae": 0.05, "dc": Color(0.60, 0.65, 0.80), "de": 0.3 },
	{ "h": 6.0, "bg": Color(0.70, 0.55, 0.45), "amb": Color(0.65, 0.50, 0.40), "ae": 0.8,  "dc": Color(1.0, 0.85, 0.60), "de": 2.5 },
	{ "h": 8.0, "bg": Color(0.55, 0.78, 0.88), "amb": Color(0.58, 0.60, 0.62), "ae": 1.0, "dc": Color(1.0, 0.95, 0.82), "de": 5.0 },
	{ "h": 14.0,"bg": Color(0.55, 0.78, 0.88), "amb": Color(0.58, 0.60, 0.62), "ae": 1.2, "dc": Color(1.0, 0.95, 0.82), "de": 5.5 },
	{ "h": 15.0,"bg": Color(0.70, 0.60, 0.45), "amb": Color(0.65, 0.55, 0.40), "ae": 1.5, "dc": Color(1.0, 0.80, 0.50), "de": 3.5 },
	{ "h": 18.0,"bg": Color(0.25, 0.18, 0.22), "amb": Color(0.20, 0.15, 0.18), "ae": 0.15,"dc": Color(0.80, 0.55, 0.35), "de": 0.6 },
	{ "h": 24.0,"bg": Color(0.03, 0.05, 0.12), "amb": Color(0.04, 0.06, 0.15), "ae": 0.05,"dc": Color(0.60, 0.65, 0.80), "de": 0.3 },
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

	env.glow_enabled = false

	env.adjustment_enabled = false

	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.0

	environment = env

	await get_tree().process_frame
	_setup_lights()

func _setup_lights() -> void:
	var dir := get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir:
		_dir_light = dir

	var all := get_parent().find_children("PlayerLight", "OmniLight3D", true, false)
	for lt in all:
		var l := lt as OmniLight3D
		if l:
			l.light_energy = 0.0

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
