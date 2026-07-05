## world/lotus_light_manager.gd
## Quản lý ánh sáng sen thạch anh — chỉ phát sáng về đêm.
##
## Tối ưu cho thiết bị cấu hình thấp (PC lẫn mobile):
## - Cập nhật theo interval, không phải mỗi frame
## - Skip khi night_t không đổi
## - is_instance_valid guard trong update loop

extends Node
class_name LotusLightManager

const MAX_ENERGY:  float = 0.6
const DUSK_START:  float = 17.0
const DUSK_END:    float = 19.0
const DAWN_START:  float = 5.0
const DAWN_END:    float = 7.0

const UPDATE_INTERVAL:  float = 0.12
const CLEANUP_INTERVAL: float = 1.0

var _lights: Array[OmniLight3D] = []

var _update_timer:  float = 0.0
var _cleanup_timer: float = 0.0
var _last_night_t:  float = -1.0

static var _instance: LotusLightManager = null

func _ready() -> void:
	_instance = self

static func register(light: OmniLight3D) -> void:
	if _instance == null:
		return
	if not light in _instance._lights:
		_instance._lights.append(light)

static func unregister(light: OmniLight3D) -> void:
	if _instance == null:
		return
	_instance._lights.erase(light)

func _process(delta: float) -> void:
	_update_timer  += delta
	_cleanup_timer += delta

	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_lights = _lights.filter(func(l): return is_instance_valid(l))

	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	if _lights.is_empty():
		return

	var night_t: float = _night_factor(_get_hour())

	if absf(night_t - _last_night_t) < 0.005:
		return
	_last_night_t = night_t

	var speed: float = UPDATE_INTERVAL * 0.8

	for light in _lights:
		if not is_instance_valid(light):
			continue
		var max_e: float = light.get_meta("max_energy", MAX_ENERGY) if light.has_meta("max_energy") else MAX_ENERGY
		light.light_energy = lerp(light.light_energy, night_t * max_e, speed)

func _get_hour() -> float:
	if TimeSystem:
		return TimeSystem.get_hour()
	return 12.0

func _night_factor(h: float) -> float:
	if h >= DAWN_END and h <= DUSK_START:
		return 0.0
	elif h >= DUSK_END or h < DAWN_START:
		return 1.0
	elif h >= DUSK_START and h < DUSK_END:
		return smoothstep(0.0, 1.0, (h - DUSK_START) / (DUSK_END - DUSK_START))
	else:
		return smoothstep(0.0, 1.0, 1.0 - (h - DAWN_START) / (DAWN_END - DAWN_START))
