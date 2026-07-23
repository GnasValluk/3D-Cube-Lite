extends Node

signal time_changed(hour: float, minute: int, day: int, month: int, year: int)
signal weather_changed(weather: int)

enum Weather {
	CLEAR = 0,
	RAIN = 1,
}

enum Season {
	SPRING = 0,
	SUMMER = 1,
	AUTUMN = 2,
	WINTER = 3,
}

const CYCLE_DURATION: float = 600.0
const GAME_HOUR: float = CYCLE_DURATION / 24.0
const GAME_MINUTE: float = GAME_HOUR / 60.0

const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12

## Temperature constants per season: { min, max } in °C
const TEMP_RANGES: Dictionary = {
	Season.SPRING: { "min": 12.0, "max": 24.0 },
	Season.SUMMER: { "min": 22.0, "max": 36.0 },
	Season.AUTUMN: { "min": 10.0, "max": 22.0 },
	Season.WINTER: { "min": -2.0, "max": 12.0 },
}
const TEMP_RAIN_PENALTY: float = 6.0    # °C giảm khi mưa
const TEMP_LAPSE_RATE: float = 0.0065    # °C giảm mỗi mét độ cao

var _cycle_time: float = CYCLE_DURATION * 6.0 / 24.0
var _time_scale: float = 1.0

var _weather: int = Weather.CLEAR
var _weather_timer: float = 0.0
var _weather_intensity: float = 0.0
var _weather_intensity_target: float = 0.0
var _weather_check_interval: float = GAME_HOUR

var _month_names: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

func _ready() -> void:
	_cycle_time = CYCLE_DURATION * 6.0 / 24.0
	_weather = Weather.CLEAR
	_weather_intensity = 0.0
	_weather_intensity_target = 0.0
	_weather_timer = _weather_check_interval * randf_range(0.5, 1.5)

func get_hour() -> float:
	return fmod(_cycle_time / CYCLE_DURATION * 24.0, 24.0)

func get_hour_int() -> int:
	return int(get_hour())

func get_minute() -> int:
	return int(fmod(get_hour(), 1.0) * 60.0)

func get_total_days() -> int:
	return int(_cycle_time / CYCLE_DURATION)

func get_day() -> int:
	return (get_total_days() % DAYS_PER_MONTH) + 1

func get_month() -> int:
	return int(float(get_total_days()) / DAYS_PER_MONTH) % MONTHS_PER_YEAR

func get_year() -> int:
	return int(float(get_total_days()) / (DAYS_PER_MONTH * MONTHS_PER_YEAR))

func get_month_name() -> String:
	return _month_names[get_month()]

func get_season() -> int:
	var m: int = get_month()
	match m:
		2, 3, 4: return Season.SPRING
		5, 6, 7: return Season.SUMMER
		8, 9, 10: return Season.AUTUMN
		_: return Season.WINTER

func get_season_name() -> String:
	match get_season():
		Season.SPRING: return tr("SEASON_SPRING")
		Season.SUMMER: return tr("SEASON_SUMMER")
		Season.AUTUMN: return tr("SEASON_AUTUMN")
		Season.WINTER: return tr("SEASON_WINTER")
	return ""

## Nhiệt độ tại vị trí người chơi, dựa trên mùa + giờ + thời tiết + độ cao
func get_temperature(player_y: float = 0.0) -> float:
	var season: int = get_season()
	var hour: float = get_hour()
	var r: Dictionary = TEMP_RANGES.get(season, { "min": 15.0, "max": 25.0 })

	# Biến thiên theo giờ: lạnh nhất 5h, nóng nhất 14h
	var day_curve: float = sin((hour - 5.0) / 24.0 * TAU)
	var t: float = (day_curve + 1.0) * 0.5
	var temp: float = lerp(r["min"], r["max"], t)

	# Mưa làm giảm nhiệt
	temp -= _weather_intensity * TEMP_RAIN_PENALTY

	# Giảm theo độ cao (lapse rate)
	temp -= maxf(player_y, 0.0) * TEMP_LAPSE_RATE

	return temp

func get_temperature_string(player_y: float = 0.0) -> String:
	var temp: float = get_temperature(player_y)
	return tr("TEMP_FORMAT").replace("%d", "%d" % [round(temp)])

func get_date_string() -> String:
	return "%s %d, Year %d" % [get_month_name(), get_day(), get_year() + 1]

func get_time_string() -> String:
	return "%02d:%02d" % [get_hour_int(), get_minute()]

func get_weather() -> int:
	return _weather

func get_weather_name() -> String:
	match _weather:
		Weather.RAIN: return tr("WEATHER_RAIN")
	return tr("WEATHER_CLEAR")

func get_time_scale() -> float:
	return _time_scale

func set_time_scale(scale: float) -> void:
	_time_scale = max(0.0, scale)

func set_hour(target_hour: float) -> void:
	_cycle_time = clamp(target_hour, 0.0, 24.0) / 24.0 * CYCLE_DURATION
	_emit_time()

func force_weather(weather: int) -> void:
	_weather = weather
	if weather == Weather.RAIN:
		_weather_timer = CYCLE_DURATION
		_weather_intensity_target = randf_range(0.4, 1.0)
	else:
		_weather_timer = _weather_check_interval * randf_range(0.8, 1.5)
		_weather_intensity_target = 0.0
	weather_changed.emit(weather)

func get_cycle_progress() -> float:
	return _cycle_time / CYCLE_DURATION

func get_weather_intensity() -> float:
	return _weather_intensity

func _try_change_weather() -> void:
	if _weather == Weather.CLEAR:
		if randf() < 0.10:
			force_weather(Weather.RAIN)
		else:
			_weather_timer = _weather_check_interval * randf_range(0.8, 1.5)
	elif _weather == Weather.RAIN:
		force_weather(Weather.CLEAR)

func _process(delta: float) -> void:
	var prev_day: int = get_total_days()

	_cycle_time += delta * _time_scale

	_weather_timer -= delta * _time_scale
	if _weather_timer <= 0.0:
		_try_change_weather()

	var dt := delta * _time_scale
	_weather_intensity = lerp(_weather_intensity, _weather_intensity_target, dt * 0.5)
	if abs(_weather_intensity - _weather_intensity_target) < 0.001:
		_weather_intensity = _weather_intensity_target

	if get_total_days() != prev_day:
		_emit_time()

func _emit_time() -> void:
	time_changed.emit(get_hour(), get_minute(), get_day(), get_month(), get_year())

func get_cycle_progress_fraction() -> float:
	return fmod(_cycle_time / CYCLE_DURATION, 1.0)
