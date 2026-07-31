extends RefCounted

static func update_debug_menu(
	debug_ts_label: Label,
	debug_hour_slider: HSlider,
	debug_speed_slider: HSlider,
	debug_weather_btn: Button
) -> void:
	if not TimeSystem:
		return
	var h: int = TimeSystem.get_hour_int()
	var m: int = TimeSystem.get_minute()
	var day: int = TimeSystem.get_day()
	var month: String = TimeSystem.get_month_name()
	var year: int = TimeSystem.get_year() + 1
	var season: String = TimeSystem.get_season_name()
	var weather: String = TimeSystem.get_weather_name()
	debug_ts_label.text = "%02d:%02d  %s %d, Year %d  |  %s  |  %s" % [h, m, month, day, year, season, weather]
	debug_hour_slider.value = h
	debug_speed_slider.value = TimeSystem.get_time_scale()
	if TimeSystem.get_weather() == TimeSystem.Weather.RAIN:
		debug_weather_btn.text = "Rain"
	else:
		debug_weather_btn.text = "Clear"

static func on_hour_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_hour(value)

static func on_speed_changed(value: float) -> void:
	if TimeSystem:
		TimeSystem.set_time_scale(value)

static func toggle_debug(current_open: bool, panel: Panel) -> bool:
	current_open = not current_open
	panel.visible = current_open
	return current_open

static func on_weather_toggle(debug_weather_btn: Button) -> void:
	if not TimeSystem:
		return
	if TimeSystem.get_weather() == TimeSystem.Weather.CLEAR:
		TimeSystem.force_weather(TimeSystem.Weather.RAIN)
		debug_weather_btn.text = "Rain"
	else:
		TimeSystem.force_weather(TimeSystem.Weather.CLEAR)
		debug_weather_btn.text = "Clear"
