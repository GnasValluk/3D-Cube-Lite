## world/lotus_light_manager.gd
## Quản lý ánh sáng sen thạch anh — chỉ phát sáng về đêm, mượt mà theo giờ.
##
## WorldChunk gọi LotusLightManager.register(light) sau khi tạo OmniLight3D.
## Manager này cập nhật energy mỗi frame theo TimeSystem.get_hour().

extends Node
class_name LotusLightManager

# Energy tối đa ban đêm
const MAX_ENERGY: float  = 0.6
# Không phát sáng ban ngày
const MIN_ENERGY: float  = 0.0

# Giờ bắt đầu tối dần (hoàng hôn) → 17h
const DUSK_START:  float = 17.0
# Giờ tối hoàn toàn → 19h
const DUSK_END:    float = 19.0
# Giờ bắt đầu sáng lên (bình minh) → 5h
const DAWN_START:  float = 5.0
# Giờ sáng hoàn toàn → 7h
const DAWN_END:    float = 7.0

var _lights: Array[OmniLight3D] = []

# Được gọi từ WorldChunk.apply_chunk() sau khi tạo OmniLight3D
static var _instance: LotusLightManager = null

func _ready() -> void:
	_instance = self

static func register(light: OmniLight3D) -> void:
	if _instance == null:
		return
	if not light in _instance._lights:
		_instance._lights.append(light)

func _process(delta: float) -> void:
	# Dọn light đã bị xoá (chunk unload)
	_lights = _lights.filter(func(l): return is_instance_valid(l))

	if _lights.is_empty():
		return

	var h: float = _get_hour()
	var night_t: float = _night_factor(h)

	# Lerp mượt mà — tốc độ chậm để tránh nhấp nháy
	for light in _lights:
		# max_energy riêng từng loại: sen 0.6, rong 0.25
		var max_e: float = light.get_meta("max_energy", MAX_ENERGY) if light.has_meta("max_energy") else MAX_ENERGY
		var target: float = night_t * max_e
		light.light_energy = lerp(light.light_energy, target, delta * 0.8)

func _get_hour() -> float:
	if TimeSystem:
		return TimeSystem.get_hour()
	return 12.0  # fallback: ban ngày

# Trả về 0.0 (ban ngày) → 1.0 (đêm sâu)
# Dùng smoothstep để chuyển mượt
func _night_factor(h: float) -> float:
	if h >= DAWN_END and h <= DUSK_START:
		# Ban ngày hoàn toàn
		return 0.0
	elif h >= DUSK_END or h < DAWN_START:
		# Ban đêm hoàn toàn
		return 1.0
	elif h >= DUSK_START and h < DUSK_END:
		# Hoàng hôn: sáng dần lên
		var t: float = (h - DUSK_START) / (DUSK_END - DUSK_START)
		return smoothstep(0.0, 1.0, t)
	else:
		# Bình minh: tắt dần
		var t: float = (h - DAWN_START) / (DAWN_END - DAWN_START)
		return smoothstep(0.0, 1.0, 1.0 - t)
