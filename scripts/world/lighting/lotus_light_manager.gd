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

## Forward Mobile: mỗi OmniLight active là 1 pass riêng cho từng bề mặt trong
## phạm vi — hàng trăm đèn sen cùng sáng là thủ phạm chính làm avg frame ~25ms
## (profile test_profile_src: 890 OmniLight, 613 từ world_chunk). Áp ngưỡng như
## RoadLampManager: chỉ giữ N đèn GẦN camera nhất, còn lại tắt visible → GPU
## chỉ tính đèn trong tầm mắt. Đèn sen/xác rêu cũng nhỏ (range ≤12m) nên đủ.
const MAX_LIGHTS: int = 40

var _lights: Array[OmniLight3D] = []

var _update_timer:  float = 0.0
var _cleanup_timer: float = 0.0
# Khởi đầu coi là "đang đêm" để lần đầu vào ngày phải tắt visible hết đèn.
var _last_night_t:  float = 1.0
var _last_cam_cell: Vector3i = Vector3i(-1, 0, 0)

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

	# Ban ngày hoàn toàn: tắt visible hết (đèn còn energy gần 0 vẫn khiến Godot
	# tính pass cho từng light). Ngắt sớm — không phải sort/duyệt danh sách.
	if night_t <= 0.01:
		if _last_night_t > 0.01:
			for light in _lights:
				if is_instance_valid(light):
					light.visible = false
		_last_night_t = night_t
		return

	# Bật đèn mỗi khi night_t đổi HOẶC camera đi sang ô 8m mới (bộ đèn gần đổi
	# theo người chơi). Nếu bỏ, đèn cố định theo vị trí cũ → cắt sáng khi di chuyển.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cell: Vector3i = _last_cam_cell
	if cam != null:
		cell = Vector3i(int(cam.global_position.x / 8.0), 0, int(cam.global_position.z / 8.0))
	var night_changed: bool = absf(night_t - _last_night_t) >= 0.003
	if not night_changed and cell == _last_cam_cell:
		return
	_last_night_t = night_t
	_last_cam_cell = cell

	# Chỉ bật đèn GẦN camera nhất (budget), đèn xa tắt visible — thay vì bật
	# toàn bộ sen/xác rêu quanh thế giới như trước (GPU tính cả nghìn đèn).
	var ref: Vector3 = Vector3.INF
	if cam != null:
		ref = cam.global_position
	var active: Array = []
	for light in _lights:
		if not is_instance_valid(light):
			continue
		if cam != null:
			active.append([(light.global_position - ref).length_squared(), light])
		else:
			active.append([0.0, light])
	active.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(active.size()):
		var light: OmniLight3D = active[i][1]
		var lit: bool = i < MAX_LIGHTS
		light.visible = lit
		var max_e: float = light.get_meta("max_energy", MAX_ENERGY) if light.has_meta("max_energy") else MAX_ENERGY
		light.light_energy = lerp(light.light_energy, night_t * max_e if lit else 0.0, UPDATE_INTERVAL * 0.8)

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
