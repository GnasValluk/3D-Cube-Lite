## world/lighting/road_lamp_manager.gd
## Quản lý đèn đường gỗ (WoodLamp) — chỉ sáng ban đêm.
##
## WoodLamp tự đăng ký khi _ready() chạy:
##   RoadLampManager.register_light(omni_light)
##   RoadLampManager.register_crystal(mesh_instance)
##
## Manager này cập nhật OmniLight3D energy và ShaderMaterial emit_energy
## mỗi frame theo TimeSystem.get_hour().

extends Node
class_name RoadLampManager

# ── Ngưỡng năng lượng đèn đường ───────────────────────────────────────────────
const LIGHT_MAX_ENERGY:   float = 2.2   # OmniLight3D energy tối đa
const CRYSTAL_MAX_EMIT:   float = 3.5   # ShaderMaterial emit_energy tối đa

# ── Mốc thời gian (dùng chung với LotusLightManager) ─────────────────────────
const DUSK_START:  float = 17.0
const DUSK_END:    float = 19.0
const DAWN_START:  float = 5.0
const DAWN_END:    float = 7.0

# ── Danh sách đã đăng ký ─────────────────────────────────────────────────────
var _lights:   Array[OmniLight3D]      = []
var _crystals: Array[MeshInstance3D]   = []

static var _instance: RoadLampManager = null

func _ready() -> void:
	_instance = self

# ── API đăng ký ───────────────────────────────────────────────────────────────

## Đăng ký OmniLight3D của đèn đường.
static func register_light(light: OmniLight3D) -> void:
	if _instance == null:
		return
	if not light in _instance._lights:
		_instance._lights.append(light)

## Đăng ký MeshInstance3D tinh thể (ShaderMaterial có uniform "emit_energy").
static func register_crystal(mesh_instance: MeshInstance3D) -> void:
	if _instance == null:
		return
	if not mesh_instance in _instance._crystals:
		_instance._crystals.append(mesh_instance)

# ── Cập nhật mỗi frame ────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Dọn instance bị xoá khi chunk unload
	_lights   = _lights.filter(func(l): return is_instance_valid(l))
	_crystals = _crystals.filter(func(m): return is_instance_valid(m))

	if _lights.is_empty() and _crystals.is_empty():
		return

	var night_t: float = _night_factor(_get_hour())
	var speed:   float = delta * 0.8

	# Cập nhật OmniLight3D
	for light in _lights:
		var max_e: float = LIGHT_MAX_ENERGY
		light.light_energy = lerp(light.light_energy, night_t * max_e, speed)

	# Cập nhật emit_energy trên ShaderMaterial tinh thể
	for mi in _crystals:
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
	return 12.0  # fallback: ban ngày

## 0.0 = ban ngày hoàn toàn, 1.0 = đêm sâu
func _night_factor(h: float) -> float:
	if h >= DAWN_END and h <= DUSK_START:
		return 0.0
	elif h >= DUSK_END or h < DAWN_START:
		return 1.0
	elif h >= DUSK_START and h < DUSK_END:
		var t: float = (h - DUSK_START) / (DUSK_END - DUSK_START)
		return smoothstep(0.0, 1.0, t)
	else:
		var t: float = (h - DAWN_START) / (DAWN_END - DAWN_START)
		return smoothstep(0.0, 1.0, 1.0 - t)
