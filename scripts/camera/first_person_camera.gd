## first_person_camera.gd
## Camera góc nhìn thứ nhất (First-Person) theo sau nhân vật.
## Dùng chuột để xoay ngang/dọc, cuộn chuột để giảm/tăng FOV (zoom).
## Khi kích hoạt sẽ ẩn model của chính người chơi (không thấy đầu/người).
##
## Cây Node yêu cầu:
## Node3D  "CameraRig"  ← script này (bám player ở độ cao mắt + xoay yaw/pitch)
## └── Camera3D         ← camera thật (đồng biến đổi với rig)

extends Node3D

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float  = 20.0  # Lerp bám player
@export var eye_height:   float  = 1.4   # Chiều cao mắt người chơi
@export var pitch_min:    float  = -80.0 # Góc nhìn thấp nhất (độ)
@export var pitch_max:    float  =  80.0 # Góc nhìn cao nhất (độ)
@export var mouse_sens:   float  = 0.20  # Độ nhạy chuột
@export var fov_default:  float  = 70.0
@export var fov_min:      float  = 50.0
@export var fov_max:      float  = 90.0
@export var fov_step:     float  = 4.0

@onready var _camera: Camera3D = $Camera3D

var _target: Node3D
var _yaw:      float = 0.0
var _pitch:    float = 0.0
var _cur_fov:  float = 70.0
var _is_active: bool = false
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _saved_rig_visible: bool = true

func _ready() -> void:
	_target = get_node_or_null(target_path)
	_cur_fov = fov_default
	_rng.randomize()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov        = fov_default
	_camera.near       = 0.05
	_camera.far        = 500.0

func activate() -> void:
	_is_active = true
	_camera.current = true
	_rng.randomize()
	# Kế thừa hướng xoay hiện tại của player để không giật khi chuyển
	if is_instance_valid(_target):
		_yaw = rad_to_deg(_target.rotation.y) + 180.0
		global_position = _target.global_position + Vector3(0, eye_height, 0)
		_apply_camera_pose()
	# Ẩn model chính người chơi (nhìn thứ nhất không thấy đầu mình)
	_saved_rig_visible = true
	if is_instance_valid(_target) and "_rig" in _target and _target._rig != null:
		_saved_rig_visible = _target._rig.visible
		_target._rig.visible = false

func deactivate() -> void:
	_is_active = false
	_camera.current = false
	# Trả lại hiển thị model người chơi
	if is_instance_valid(_target) and "_rig" in _target and _target._rig != null:
		_target._rig.visible = _saved_rig_visible

func set_target(node: Node3D) -> void:
	if is_instance_valid(_target) and "_rig" in _target and _target._rig != null:
		_target._rig.visible = _saved_rig_visible
	_target = node
	if _is_active:
		_yaw = rad_to_deg(_target.rotation.y) + 180.0
		_saved_rig_visible = true
		if is_instance_valid(_target) and "_rig" in _target and _target._rig != null:
			_saved_rig_visible = _target._rig.visible
			_target._rig.visible = false

func add_shake(intensity: float, duration: float) -> void:
	if not _is_active:
		return
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(_shake_duration, duration)
	_shake_timer = max(_shake_timer, duration)

## Bật/tắt chế độ ngắm — FP không đổi khoảng cách (đổi FOV nhẹ để ngắm).
func set_aim(active: bool) -> void:
	if not _is_active:
		return
	_cur_fov = lerp(_cur_fov, fov_default - 8.0 if active else fov_default, 0.35)
	_camera.fov = _cur_fov

## Trả về hướng forward của camera (dùng cho player điều hướng WASD)
func get_camera_basis() -> Basis:
	return _camera.global_transform.basis

func pinch_zoom(factor: float) -> void:
	_cur_fov = clamp(_cur_fov * (1.0 / factor), fov_min, fov_max)
	_camera.fov = _cur_fov

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	# Xoay camera bằng chuột
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_yaw   -= mm.relative.x * mouse_sens
		_pitch += mm.relative.y * mouse_sens
		_pitch  = clamp(_pitch, pitch_min, pitch_max)
	# Zoom bằng cuộn chuột (đổi FOV)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cur_fov = clamp(_cur_fov - fov_step, fov_min, fov_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cur_fov = clamp(_cur_fov + fov_step, fov_min, fov_max)

func _process(delta: float) -> void:
	if not _is_active or not is_instance_valid(_target):
		return
	_update_shake(delta)
	# Lerp rig về mắt player
	var dest := _target.global_position + Vector3(0, eye_height, 0)
	global_position = global_position.lerp(dest, follow_speed * delta)
	_apply_camera_pose()
	_camera.fov = lerp(_camera.fov, _cur_fov, delta * 8.0)

func _apply_camera_pose() -> void:
	global_rotation = Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)
	_camera.position = _shake_offset

func _update_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		_shake_offset = _shake_offset.lerp(Vector3.ZERO, delta * 14.0)
		return
	_shake_timer = max(_shake_timer - delta, 0.0)
	var falloff: float = 0.0
	if _shake_duration > 0.0:
		falloff = _shake_timer / _shake_duration
	var amp: float = _shake_intensity * falloff
	_shake_offset = Vector3(
		_rng.randf_range(-1.0, 1.0) * amp,
		_rng.randf_range(-0.6, 0.6) * amp,
		_rng.randf_range(-1.0, 1.0) * amp
	)
	if _shake_timer <= 0.0:
		_shake_duration = 0.0
		_shake_intensity = 0.0