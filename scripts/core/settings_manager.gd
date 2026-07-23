extends Node
class_name SettingsManager

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

enum GraphicsPreset { STANDARD, ENHANCED, REALISTIC }

static var graphics_preset: int = GraphicsPreset.STANDARD
static var locale: String = "en"
static var fullscreen: bool = false
static var vsync: bool = true
static var master_volume: float = 50.0
static var music_volume: float = 50.0
static var sfx_volume: float = 50.0
static var mouse_sensitivity: float = 1.0
static var invert_y: bool = false
static var touch_enabled: bool = false
static var joystick_sensitivity: float = 1.0
static var button_scale: float = 1.0
static var device_mode: int = 0
static var key_bindings: Dictionary = {
	"controls/interact": KEY_F,
	"controls/inventory": KEY_I,
	"controls/build": KEY_B,
	"controls/party": KEY_P,
	"controls/map": KEY_M,
	"controls/debug": KEY_F2,
}

static var _preset_changed_callbacks: Array[Callable] = []

func _ready() -> void:
	_load_translations()
	load_settings()
	_apply_all()

static func _load_translations() -> void:
	var path: String = "res://translations/game.csv"
	if not FileAccess.file_exists(path):
		return
	for locale in ["vi", "en"]:
		var col: int = 1 if locale == "en" else 2
		var t := Translation.new()
		t.locale = locale
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var header: bool = true
			while not f.eof_reached():
				var line = f.get_csv_line()
				if line.is_empty() or line[0].is_empty():
					continue
				if header:
					header = false
					continue
				if line.size() > col:
					t.add_message(line[0], line[col])
			f.close()
		TranslationServer.add_translation(t)

static func on_preset_changed(cb: Callable) -> void:
	_preset_changed_callbacks.append(cb)

static func _notify_preset_changed() -> void:
	for cb in _preset_changed_callbacks:
		cb.call()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	graphics_preset = config.get_value(SECTION, "graphics_preset", GraphicsPreset.STANDARD)
	locale = config.get_value(SECTION, "locale", "en")
	fullscreen = config.get_value(SECTION, "fullscreen", false)
	vsync = config.get_value(SECTION, "vsync", true)
	master_volume = config.get_value(SECTION, "master_volume", 50.0)
	music_volume = config.get_value(SECTION, "music_volume", 50.0)
	sfx_volume = config.get_value(SECTION, "sfx_volume", 50.0)
	mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", 1.0)
	invert_y = config.get_value(SECTION, "invert_y", false)
	touch_enabled = config.get_value(SECTION, "touch_enabled", false)
	joystick_sensitivity = config.get_value(SECTION, "joystick_sensitivity", 1.0)
	button_scale = config.get_value(SECTION, "button_scale", 1.0)
	device_mode = config.get_value(SECTION, "device_mode", 0)
	var saved_keys: Dictionary = config.get_value(SECTION, "key_bindings", {})
	for action in key_bindings:
		if saved_keys.has(action):
			key_bindings[action] = saved_keys[action]

static func _apply_all() -> void:
	TranslationServer.set_locale(locale)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, master_volume / 100.0 * 80.0 - 80.0)
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, music_volume / 100.0 * 80.0 - 80.0)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, sfx_volume / 100.0 * 80.0 - 80.0)
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_modifier", mouse_sensitivity)
	ProjectSettings.set_setting("controls/invert_y", invert_y)
	ProjectSettings.set_setting("mobile/touch_controls_enabled", touch_enabled)
	ProjectSettings.set_setting("mobile/joystick_sensitivity", joystick_sensitivity)
	ProjectSettings.set_setting("mobile/button_scale", button_scale)
	if DeviceManager:
		DeviceManager.set_device(device_mode as DeviceManager.Device)
	for action in key_bindings:
		ProjectSettings.set_setting(action, key_bindings[action])

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "graphics_preset", graphics_preset)
	config.set_value(SECTION, "locale", locale)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "invert_y", invert_y)
	config.set_value(SECTION, "touch_enabled", touch_enabled)
	config.set_value(SECTION, "joystick_sensitivity", joystick_sensitivity)
	config.set_value(SECTION, "button_scale", button_scale)
	config.set_value(SECTION, "device_mode", device_mode)
	config.set_value(SECTION, "key_bindings", key_bindings)
	config.save(SETTINGS_PATH)

static func set_graphics_preset(preset: int) -> void:
	graphics_preset = preset
	if SettingsData:
		SettingsData.save_settings()
	_notify_preset_changed()

static func apply_viewport_settings(viewport: Viewport) -> void:
	match graphics_preset:
		GraphicsPreset.STANDARD:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		GraphicsPreset.ENHANCED:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		GraphicsPreset.REALISTIC:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
