extends Node
class_name SettingsManager

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const PRESET_KEY: String = "graphics_preset"

enum GraphicsPreset { STANDARD, ENHANCED, REALISTIC }

static var graphics_preset: int = GraphicsPreset.STANDARD
static var _preset_changed_callbacks: Array[Callable] = []

func _ready() -> void:
	load_settings()

static func on_preset_changed(cb: Callable) -> void:
	_preset_changed_callbacks.append(cb)

static func _notify_preset_changed() -> void:
	for cb in _preset_changed_callbacks:
		cb.call()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	graphics_preset = config.get_value(SECTION, PRESET_KEY, GraphicsPreset.STANDARD)

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, PRESET_KEY, graphics_preset)
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
