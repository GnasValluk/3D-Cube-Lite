extends Node
class_name SettingsManager

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

enum GraphicsPreset { STANDARD, ENHANCED, REALISTIC }
enum FramerateLimit { FPS_60, FPS_120, UNLIMITED }

static var graphics_preset: int = GraphicsPreset.STANDARD
static var framerate_limit: int = FramerateLimit.FPS_60
static var locale: String = "en"
static var fullscreen: bool = false
static var vsync: bool = true
static var master_volume: float = 50.0
static var music_volume: float = 50.0
static var sfx_volume: float = 50.0
static var mouse_sensitivity: float = 1.0   # legacy (backward compat)
static var mouse_sensitivity_h: float = 1.0   # horizontal sensitivity (mouse X)
static var mouse_sensitivity_v: float = 0.7   # vertical sensitivity (mouse Y — thấp hơn horizontal để điều khiển mượt)
static var invert_y: bool = false
static var touch_enabled: bool = false
static var joystick_sensitivity: float = 1.0
static var button_scale: float = 1.0
static var device_mode: int = 0
static var player_skin: String = "cora"
static var chunk_view: int = 3
static var key_bindings: Dictionary = {
	"controls/interact": KEY_F,
	"controls/inventory": KEY_E,
	"controls/build": KEY_B,
	"controls/map": KEY_M,
	"controls/debug": KEY_F2,
	}

static var _preset_changed_callbacks: Array[Callable] = []
static var _chunk_view_changed_callbacks: Array[Callable] = []

func _ready() -> void:
	_load_translations()
	load_settings()
	# Luôn set inventory key = E (bất kể setting cũ có bị đổi)
	key_bindings["controls/inventory"] = KEY_E
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

static func on_chunk_view_changed(cb: Callable) -> void:
	_chunk_view_changed_callbacks.append(cb)

static func _notify_chunk_view_changed() -> void:
	for cb in _chunk_view_changed_callbacks:
		cb.call()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	graphics_preset = config.get_value(SECTION, "graphics_preset", GraphicsPreset.STANDARD)
	framerate_limit = config.get_value(SECTION, "framerate_limit", FramerateLimit.FPS_60)
	locale = config.get_value(SECTION, "locale", "en")
	fullscreen = config.get_value(SECTION, "fullscreen", false)
	vsync = config.get_value(SECTION, "vsync", true)
	master_volume = config.get_value(SECTION, "master_volume", 50.0)
	music_volume = config.get_value(SECTION, "music_volume", 50.0)
	sfx_volume = config.get_value(SECTION, "sfx_volume", 50.0)
	mouse_sensitivity = config.get_value(SECTION, "mouse_sensitivity", 1.0)
	mouse_sensitivity_h = config.get_value(SECTION, "mouse_sensitivity_h", mouse_sensitivity)
	mouse_sensitivity_v = config.get_value(SECTION, "mouse_sensitivity_v", 0.7)
	invert_y = config.get_value(SECTION, "invert_y", false)
	touch_enabled = config.get_value(SECTION, "touch_enabled", false)
	joystick_sensitivity = config.get_value(SECTION, "joystick_sensitivity", 1.0)
	button_scale = config.get_value(SECTION, "button_scale", 1.0)
	device_mode = config.get_value(SECTION, "device_mode", 0)
	player_skin = config.get_value(SECTION, "player_skin", "cora")
	chunk_view = config.get_value(SECTION, "chunk_view", 3)
	var saved_keys: Dictionary = config.get_value(SECTION, "key_bindings", {})
	for action in key_bindings:
		if saved_keys.has(action):
			key_bindings[action] = saved_keys[action]

static func _apply_all() -> void:
	TranslationServer.set_locale(locale)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match framerate_limit:
		FramerateLimit.FPS_60: Engine.max_fps = 60
		FramerateLimit.FPS_120: Engine.max_fps = 120
		FramerateLimit.UNLIMITED: Engine.max_fps = 0
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
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_h", mouse_sensitivity_h)
	ProjectSettings.set_setting("input/pointing/mouse_sensitivity_v", mouse_sensitivity_v)
	ProjectSettings.set_setting("controls/invert_y", invert_y)
	ProjectSettings.set_setting("mobile/touch_controls_enabled", touch_enabled)
	ProjectSettings.set_setting("mobile/joystick_sensitivity", joystick_sensitivity)
	ProjectSettings.set_setting("mobile/button_scale", button_scale)
	if DeviceManager:
		DeviceManager.set_device(device_mode as DeviceManager.Device)
	_apply_key_bindings()

## Đồng bộ key_bindings đã lưu (nếu có rebind) vào InputMap trước khi vào game
static func _apply_key_bindings() -> void:
	for action in key_bindings:
		var code: int = key_bindings[action] as int
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			var ev := InputEventKey.new()
			ev.keycode = code
			InputMap.action_add_event(action, ev)

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "graphics_preset", graphics_preset)
	config.set_value(SECTION, "framerate_limit", framerate_limit)
	config.set_value(SECTION, "locale", locale)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "mouse_sensitivity_h", mouse_sensitivity_h)
	config.set_value(SECTION, "mouse_sensitivity_v", mouse_sensitivity_v)
	config.set_value(SECTION, "invert_y", invert_y)
	config.set_value(SECTION, "touch_enabled", touch_enabled)
	config.set_value(SECTION, "joystick_sensitivity", joystick_sensitivity)
	config.set_value(SECTION, "button_scale", button_scale)
	config.set_value(SECTION, "device_mode", device_mode)
	config.set_value(SECTION, "player_skin", player_skin)
	config.set_value(SECTION, "chunk_view", chunk_view)
	config.set_value(SECTION, "key_bindings", key_bindings)
	config.save(SETTINGS_PATH)

static func set_graphics_preset(preset: int) -> void:
	graphics_preset = preset
	if SettingsData:
		SettingsData.save_settings()
	_notify_preset_changed()

## Preset thực tế đang áp dụng: trên mobile luôn ép STANDARD để đảm bảo hiệu năng
static func effective_graphics_preset() -> int:
	if DeviceManager != null and DeviceManager.is_mobile():
		return GraphicsPreset.STANDARD
	return graphics_preset

static func set_chunk_view(value: int) -> void:
	chunk_view = clampi(value, 2, 8)
	if SettingsData:
		SettingsData.save_settings()
	_notify_chunk_view_changed()

static func apply_viewport_settings(viewport: Viewport) -> void:
	var is_mob: bool = DeviceManager != null and DeviceManager.is_mobile()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 0.75 if is_mob else 1.0
	match effective_graphics_preset():
		GraphicsPreset.STANDARD:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		GraphicsPreset.ENHANCED:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		GraphicsPreset.REALISTIC:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
