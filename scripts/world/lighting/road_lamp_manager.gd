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

static var _instance: RoadLampManager = null

func _ready() -> void:
	_instance = self

# ── API đăng ký ───────────────────────────────────────────────────────────────
static func register_light(light: OmniLight3D) -> void:
	if _instance == null:
		return
	if light in _instance._lights:
		return
	if _instance._lights.size() >= MAX_LIGHTS:
		# Đèn vượt giới hạn: tắt hẳn, không đưa vào update loop
		light.light_energy = 0.0
		light.hide()
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

	if absf(night_t - _last_night_t) < 0.005:
		return
	_last_night_t = night_t

	var speed: float = UPDATE_INTERVAL * 0.8

	for i in range(min(_lights.size(), MAX_LIGHTS)):
		var light: OmniLight3D = _lights[i]
		if not is_instance_valid(light):
			continue
		light.light_energy = lerp(light.light_energy, night_t * LIGHT_MAX_ENERGY, speed)

	for i in range(min(_crystals.size(), MAX_LIGHTS)):
		var mi: MeshInstance3D = _crystals[i]
		if not is_instance_valid(mi):
			continue
		var mat := mi.material_override as ShaderMaterial
		if mat == null:
			continue
		var raw = mat.get_shader_parameter("emit_energy")
		var cur_e: float = float(raw) if raw != null else 0.0
		mat.set_shader_parameter("emit_energy", lerp(cur_e, night_t * CRYSTAL_MAX_EMIT, speed))

# ── Helpers ───────────────────────────────────────────────────────────────────
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
