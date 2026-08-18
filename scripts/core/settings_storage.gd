extends RefCounted

static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

static func set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
	SettingsManager.fullscreen = v
	SettingsManager.save_settings()

static func is_vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

static func set_vsync(v: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
	SettingsManager.vsync = v
	SettingsManager.save_settings()

static func set_framerate(mode: int) -> void:
	SettingsManager.framerate_limit = mode
	match mode:
		0: Engine.max_fps = 60
		1: Engine.max_fps = 120
		2: Engine.max_fps = 0
	SettingsManager.save_settings()

static func get_master_volume() -> float:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0: return 50.0
	return (AudioServer.get_bus_volume_db(idx) + 80.0) / 80.0 * 100.0

static func set_master_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, v / 100.0 * 80.0 - 80.0)
	SettingsManager.master_volume = v
	SettingsManager.save_settings()

static func get_music_volume() -> float:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0: return 50.0
	return (AudioServer.get_bus_volume_db(idx) + 80.0) / 80.0 * 100.0

static func set_music_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, v / 100.0 * 80.0 - 80.0)
	SettingsManager.music_volume = v
	SettingsManager.save_settings()

static func get_sfx_volume() -> float:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0: return 50.0
	return (AudioServer.get_bus_volume_db(idx) + 80.0) / 80.0 * 100.0

static func set_sfx_volume(v: float) -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, v / 100.0 * 80.0 - 80.0)
	SettingsManager.sfx_volume = v
	SettingsManager.save_settings()

static func get_mouse_sensitivity() -> float:
	return ProjectSettings.get_setting("input/pointing/mouse_sensitivity_modifier", 1.0)

static func set_mouse_sensitivity(v: float) -> void:
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_modifier", v)
	SettingsManager.mouse_sensitivity = v
	SettingsManager.mouse_sensitivity_h = v
	SettingsManager.save_settings()

static func get_mouse_sensitivity_h() -> float:
	return ProjectSettings.get_setting("input/pointing/mouse_sensitivity_h", SettingsManager.mouse_sensitivity_h)

static func set_mouse_sensitivity_h(v: float) -> void:
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_h", v)
	SettingsManager.mouse_sensitivity_h = v
	SettingsManager.save_settings()

static func get_mouse_sensitivity_v() -> float:
	return ProjectSettings.get_setting("input/pointing/mouse_sensitivity_v", SettingsManager.mouse_sensitivity_v)

static func set_mouse_sensitivity_v(v: float) -> void:
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_v", v)
	SettingsManager.mouse_sensitivity_v = v
	SettingsManager.save_settings()

static func is_invert_y() -> bool:
	return ProjectSettings.get_setting("controls/invert_y", false)

static func set_invert_y(v: bool) -> void:
	ProjectSettings.set_setting("controls/invert_y", v)
	SettingsManager.invert_y = v
	SettingsManager.save_settings()

static func is_touch_enabled() -> bool:
	return ProjectSettings.get_setting("mobile/touch_controls_enabled", true)

static func set_touch_enabled(v: bool) -> void:
	ProjectSettings.set_setting("mobile/touch_controls_enabled", v)
	SettingsManager.touch_enabled = v
	SettingsManager.save_settings()

static func get_joystick_sensitivity() -> float:
	return ProjectSettings.get_setting("mobile/joystick_sensitivity", 1.0)

static func set_joystick_sensitivity(v: float) -> void:
	ProjectSettings.set_setting("mobile/joystick_sensitivity", v)
	SettingsManager.joystick_sensitivity = v
	SettingsManager.save_settings()

static func get_button_scale() -> float:
	return ProjectSettings.get_setting("mobile/button_scale", 1.0)

static func set_button_scale(v: float) -> void:
	ProjectSettings.set_setting("mobile/button_scale", v)
	SettingsManager.button_scale = v
	SettingsManager.save_settings()

static func get_keybinding(key: String, default_key: int) -> int:
	return SettingsManager.key_bindings.get(key, default_key)

static func set_keybinding(action: String, keycode: int) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)
	SettingsManager.key_bindings[action] = keycode
	SettingsManager.save_settings()

static func reset_keybindings() -> void:
	var defaults := {
		"controls/interact": KEY_F,
		"controls/inventory": KEY_E,
		"controls/build": KEY_B,
		"controls/map": KEY_M,
		"controls/debug": KEY_F2,
	}
	for action in defaults:
		var keycode: int = defaults[action] as int
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action, event)
		SettingsManager.key_bindings[action] = keycode
	SettingsManager.save_settings()

static func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	SettingsManager.locale = locale
	SettingsManager.save_settings()

static func get_chunk_view() -> int:
	return SettingsManager.chunk_view

static func set_chunk_view(v: int) -> void:
	SettingsManager.set_chunk_view(v)

static func is_distant_view() -> bool:
	return true if SettingsManager == null else SettingsManager.distant_view

static func set_distant_view(v: bool) -> void:
	if SettingsManager:
		SettingsManager.set_distant_view(v)

static func is_clouds_enabled() -> bool:
	return true if SettingsManager == null else SettingsManager.clouds_enabled

static func set_clouds_enabled(v: bool) -> void:
	if SettingsManager:
		SettingsManager.set_clouds_enabled(v)
