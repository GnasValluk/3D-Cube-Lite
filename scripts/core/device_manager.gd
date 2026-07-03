## DeviceManager — Autoload quản lý loại thiết bị (PC / Mobile)
## Đọc: DeviceManager.is_mobile()
## Đổi: DeviceManager.set_device(DeviceManager.Device.MOBILE)
extends Node

signal device_changed(is_mobile: bool)

enum Device { AUTO, PC, MOBILE }

const _SETTING_KEY := "device/mode"   # 0=auto, 1=pc, 2=mobile

var _current: Device = Device.AUTO
var _resolved_mobile: bool = false

func _ready() -> void:
	_load()
	_resolve()

## Trả về true nếu đang ở chế độ mobile
func is_mobile() -> bool:
	return _resolved_mobile

## Trả về Device enum hiện tại (AUTO/PC/MOBILE)
func get_device() -> Device:
	return _current

## Đặt thiết bị và lưu setting
func set_device(d: Device) -> void:
	_current = d
	ProjectSettings.set_setting(_SETTING_KEY, int(d))
	_resolve()
	emit_signal("device_changed", _resolved_mobile)

## Detect tự động dựa trên OS
static func _detect_mobile() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

func _resolve() -> void:
	match _current:
		Device.PC:     _resolved_mobile = false
		Device.MOBILE: _resolved_mobile = true
		_:             _resolved_mobile = _detect_mobile()

func _load() -> void:
	var val: int = ProjectSettings.get_setting(_SETTING_KEY, int(Device.AUTO))
	_current = val as Device
