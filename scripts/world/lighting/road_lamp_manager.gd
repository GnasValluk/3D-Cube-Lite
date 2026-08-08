## world/lighting/road_lamp_manager.gd
## Quản lý đèn đường gỗ (WoodLamp) — chỉ sáng ban đêm.
##
## Tối ưu cho thiết bị cấu hình thấp (PC lẫn mobile):
## - Cập nhật theo interval, không phải mỗi frame
## - Skip hoàn toàn khi ban ngày / night_t không đổi
## - Giới hạn số đèn active để tránh overdraw
## - is_instance_valid guard trong update loop

extends Node
class_name RoadLampManager

# ── Ngưỡng năng lượng ─────────────────────────────────────────────────────────
const LIGHT_MAX_ENERGY: float = 2.2
const CRYSTAL_MAX_EMIT: float = 3.5

# ── Mốc thời gian ─────────────────────────────────────────────────────────────
const DUSK_START: float = 17.0
const DUSK_END:   float = 19.0
const DAWN_START: float = 5.0
const DAWN_END:   float = 7.0

# ── Thông số hiệu suất — thống nhất cho mọi platform ─────────────────────────
const MAX_LIGHTS:        int   = 60     # đủ để trải nghiệm tốt, không quá tải
const UPDATE_INTERVAL:   float = 0.12  # ~8 lần/giây, mắt không phân biệt được
const CLEANUP_INTERVAL:  float = 1.0

# ── Danh sách đã đăng ký ─────────────────────────────────────────────────────
var _lights:   Array[OmniLight3D]    = []
var _crystals: Array[MeshInstance3D] = []

var _update_timer:  float = 0.0
var _cleanup_timer: float = 0.0
var _last_night_t:  float = -1.0
var _last_cam_cell: Vector3i = Vector3i(-1, 0, 0)

static var _instance: RoadLampManager = null

func _ready() -> void:
	_instance = self

# ── API đăng ký ───────────────────────────────────────────────────────────────
static func register_light(light: OmniLight3D) -> void:
	if _instance == null:
		return
	if light in _instance._lights:
		return
	_instance._lights.append(light)

static func register_crystal(mesh_instance: MeshInstance3D) -> void:
	if _instance == null:
		return
	if not mesh_instance in _instance._crystals:
		_instance._crystals.append(mesh_instance)

static func unregister_light(light: OmniLight3D) -> void:
	if _instance == null:
		return
	_instance._lights.erase(light)

static func unregister_crystal(mesh_instance: MeshInstance3D) -> void:
	if _instance == null:
		return
	_instance._crystals.erase(mesh_instance)

# ── Cập nhật theo interval ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_timer  += delta
	_cleanup_timer += delta

	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_lights   = _lights.filter(func(l): return is_instance_valid(l))
		_crystals = _crystals.filter(func(m): return is_instance_valid(m))

	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	if _lights.is_empty() and _crystals.is_empty():
		return

	var night_t: float = _night_factor(_get_hour())

	# Skip chỉ khi CẢ hai không đổi: độ sáng đêm lẫn vị trí camera (bộ đèn gần
	# phải đổi theo người chơi, nếu không đèn cố định cứng gây cắt sáng).
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cell: Vector3i = _last_cam_cell
	if cam != null:
		cell = Vector3i(int(cam.global_position.x / 8.0), 0, int(cam.global_position.z / 8.0))
	var night_changed: bool = absf(night_t - _last_night_t) >= 0.003
	if not night_changed and cell == _last_cam_cell:
		return
	_last_night_t = night_t
	_last_cam_cell = cell

	var speed: float = UPDATE_INTERVAL * 0.8

	# Chọn đèn GẦN camera nhất để sáng (bù light budget), đèn xa dần tắt —
	# không treo cứng ở ranh giới chunk: khi camera di chuyển thì bộ đèn gần
	# đổi theo, ánh sáng liền mạch thay vì bị cắt bởi đường biên chunk.
	var ref: Vector3 = Vector3.INF
	if cam != null:
		ref = cam.global_position

	var active: Array = []
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var d2: float = (light.global_position - ref).length_squared() if cam != null else 0.0
		active.append([d2, light])
	if cam != null:
		active.sort_custom(func(a, b): return a[0] < b[0])

	for i in range(active.size()):
		var light: OmniLight3D = active[i][1]
		var lit: bool = i < MAX_LIGHTS
		light.visible = lit
		light.light_energy = lerp(light.light_energy, night_t * LIGHT_MAX_ENERGY if lit else 0.0, speed)

	var crys: Array = []
	for mi in _crystals:
		if not is_instance_valid(mi):
			continue
		var d2: float = (mi.global_position - ref).length_squared() if cam != null else 0.0
		crys.append([d2, mi])
	if cam != null:
		crys.sort_custom(func(a, b): return a[0] < b[0])

	for i in range(crys.size()):
		var mi: MeshInstance3D = crys[i][1]
		var mat := mi.material_override as ShaderMaterial
		if mat == null:
			continue
		var lit: bool = i < MAX_LIGHTS
		var raw = mat.get_shader_parameter("emit_energy")
		var cur_e: float = float(raw) if raw != null else 0.0
		mat.set_shader_parameter("emit_energy",
			lerp(cur_e, night_t * CRYSTAL_MAX_EMIT if lit else 0.0, speed))

# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_hour() -> float:
	if TimeSystem:
		return TimeSystem.get_hour()
	return 12.0

## Trả về 0.0 (tắt hoàn toàn) → 1.0 (sáng tối đa)
## Bật khi: đêm (theo giờ) HOẶC trời mưa (weather_intensity > 0)
func _night_factor(h: float) -> float:
	# ── Phần đêm/ngày ─────────────────────────────────────────────────────────
	var night_t: float
	if h >= DAWN_END and h <= DUSK_START:
		night_t = 0.0                                          # ban ngày hoàn toàn
	elif h >= DUSK_END or h < DAWN_START:
		night_t = 1.0                                          # đêm sâu
	elif h >= DUSK_START and h < DUSK_END:
		night_t = smoothstep(0.0, 1.0, (h - DUSK_START) / (DUSK_END - DUSK_START))
	else:
		night_t = smoothstep(0.0, 1.0, 1.0 - (h - DAWN_START) / (DAWN_END - DAWN_START))

	# ── Phần mưa — đèn bật thêm khi trời tối do mưa ──────────────────────────
	# weather_intensity: 0.0 = nắng, 1.0 = mưa nặng
	# Mưa nhẹ (0.3+) bắt đầu bật đèn, mưa nặng (1.0) = bật như đêm
	var rain_t: float = 0.0
	if TimeSystem:
		var wi: float = TimeSystem.get_weather_intensity()
		rain_t = smoothstep(0.3, 1.0, wi)   # chỉ bật khi mưa đủ nặng

	# Lấy giá trị lớn hơn: đêm hay mưa
	return maxf(night_t, rain_t)
