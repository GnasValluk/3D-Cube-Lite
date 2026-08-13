class_name FireflyProp
extends Node3D

## Đom đóm rừng ngập mặn — sinh vật nhỏ (hp=1) bay lơ lửng quanh bãi bùn vào
## ban đêm, ánh chớp vàng-xanh lập lòe. Ban ngày ẩn hẳn (tắt light) để tiết
## kiệm draw/light. Có thể bị giết; chết không rớt ra gì cả.

const NIGHT_START_HOUR: float = 18.0
const NIGHT_END_HOUR: float = 5.5
const MAX_HP: int = 1
const HIT_RADIUS: float = 0.22

## Bán kính vùng bay (quanh điểm sinh) + khoảng bay lên/không trung.
const WANDER_RADIUS: float = 1.6
const WANDER_Y_UP: float = 1.2
const WANDER_SPEED: float = 0.55
const WANDER_PAUSE_MIN: float = 0.4
const WANDER_PAUSE_MAX: float = 1.4

var _light: OmniLight3D = null
var _flicker_phase: float = 0.0
var _drift_phase: float = 0.0
var _mat: StandardMaterial3D = null
var _mesh_root: Node3D = null

var is_alive: bool = true
var hp: int = MAX_HP
var hit_radius: float = HIT_RADIUS

var _home: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _pause_timer: float = 0.0
var _moving: bool = true

func setup() -> void:
	pass

func _ready() -> void:
	add_to_group("firefly")
	_flicker_phase = randf() * TAU
	_drift_phase = randf() * TAU
	_home = global_position
	_pick_new_target(true)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.95, 0.35)
	_mat.emission_enabled = true
	_mat.emission = Color(0.70, 0.85, 0.20)
	_mat.emission_energy_multiplier = 3.0
	_mat.metallic = 0.0
	_mat.roughness = 0.4
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	for li in range(2):
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, 0.05)
		mi.mesh = box
		mi.position = Vector3(0.05 + li * 0.10, (randf() - 0.5) * 0.05, 0.0)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_root.add_child(mi)

	_light = OmniLight3D.new()
	_light.omni_range = 2.6
	_light.light_energy = 0.0
	_light.light_specular = 0.0
	_light.omni_attenuation = 0.7
	_light.light_color = Color(0.85, 0.95, 0.30)
	_light.shadow_enabled = false
	add_child(_light)

## Chọn điểm bay mới quanh _home (thuộc thể tích trụ — không bay xuống đất).
func _pick_new_target(instant: bool = false) -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * WANDER_RADIUS
	var ty := _home.y + randf_range(0.0, WANDER_Y_UP)
	_wander_target = Vector3(
		_home.x + cos(a) * r,
		ty,
		_home.z + sin(a) * r)
	_moving = true
	if instant:
		global_position = _wander_target
	_pause_timer = 0.0

func take_damage(dmg: int, _attacker: Node3D = null, _damage_type: int = 0) -> void:
	if not is_alive:
		return
	hp -= dmg
	if hp <= 0:
		_die()

## Chết — không rớt gì cả, chỉ vụt tắt ánh sáng rồi biến mất.
func _die() -> void:
	is_alive = false
	if _light:
		_light.light_energy = 0.0
	var tween := create_tween()
	tween.tween_property(_mesh_root, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	if not is_alive:
		return
	if _light == null:
		return
	var h: float = TimeSystem.get_hour() if TimeSystem != null else 12.0
	var is_night: bool = h >= NIGHT_START_HOUR or h < NIGHT_END_HOUR
	_light.visible = is_night
	if not is_night:
		_light.light_energy = 0.0
		return
	var t := Time.get_ticks_usec() * 0.000001
	# Chớp lập lòe: chu kỳ nhanh + đốm sáng ngắt quãng
	var flicker: float = (sin(t * 2.2 + _flicker_phase) * 0.5 + 0.5) \
		* (0.45 + sin(t * 1.1 + _flicker_phase * 2.0) * 0.35)
	if sin(t * 0.35 + _flicker_phase) > 0.82:
		flicker = 0.0
	_light.light_energy = 0.30 + flicker * 0.55
	_update_flight(delta)

func _update_flight(delta: float) -> void:
	if not _moving:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_pick_new_target()
		# Lơ lửng tại chỗ với rung nhẹ
		position.y += sin(_drift_phase + _flicker_phase * 3.0) * delta * 0.04
		return
	var to_wp: Vector3 = _wander_target - position
	var dist: float = to_wp.length()
	if dist < 0.06:
		_moving = false
		_pause_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
		return
	var dir := to_wp / dist
	position += dir * minf(WANDER_SPEED * delta, dist)
	# Rung bay lúc di chuyển (đường đi không quá thẳng)
	_drift_phase += delta * 2.4
	position.y += sin(_drift_phase) * delta * 0.05
