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

var _cycle_time: float = CYCLE_DURATION * 6.0 / 24.0
var _time_scale: float = 1.0

var _weather: int = Weather.CLEAR
var _weather_timer: float = 0.0
var _weather_intensity: float = 0.0
var _weather_check_interval: float = GAME_HOUR

var _month_names: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

func _ready() -> void:
	_cycle_time = CYCLE_DURATION * 6.0 / 24.0
	_weather = Weather.CLEAR
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
		Season.SPRING: return "Spring"
		Season.SUMMER: return "Summer"
		Season.AUTUMN: return "Autumn"
		Season.WINTER: return "Winter"
	return ""

func get_date_string() -> String:
	return "%s %d, Year %d" % [get_month_name(), get_day(), get_year() + 1]

func get_time_string() -> String:
	return "%02d:%02d" % [get_hour_int(), get_minute()]

func get_weather() -> int:
	return _weather

func get_weather_name() -> String:
	match _weather:
		Weather.RAIN: return "Rain"
	return "Clear"

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
		var duration: float = GAME_HOUR * randf_range(0.5, 2.0)
		_weather_timer = duration
		_weather_intensity = randf_range(0.4, 1.0)
	else:
		_weather_timer = _weather_check_interval * randf_range(0.5, 1.5)
	weather_changed.emit(weather)

func get_cycle_progress() -> float:
	return _cycle_time / CYCLE_DURATION

func get_weather_intensity() -> float:
	return _weather_intensity if _weather == Weather.RAIN else 0.0

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

	if get_total_days() != prev_day:
		_emit_time()

func _emit_time() -> void:
	time_changed.emit(get_hour(), get_minute(), get_day(), get_month(), get_year())

func get_cycle_progress_fraction() -> float:
	return fmod(_cycle_time / CYCLE_DURATION, 1.0)
