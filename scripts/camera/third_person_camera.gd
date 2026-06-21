## third_person_camera.gd
## Camera góc nhìn thứ 3 (Third-Person) theo sau nhân vật.
## Dùng chuột để xoay, cuộn chuột để zoom.
##
## Cây Node yêu cầu:
## Node3D  "TPCameraRig"  ← script này (xoay theo yaw/pitch)
## └── Camera3D           ← offset ra sau nhân vật

extends Node3D

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float  = 12.0  # Lerp bám player
@export var distance:     float  = 5.0   # Khoảng cách từ player
@export var height:       float  = 1.8   # Chiều cao nhìn vào player
@export var pitch_min:    float  = -30.0 # Góc pitch thấp nhất (độ)
@export var pitch_max:    float  =  70.0 # Góc pitch cao nhất (độ)
@export var mouse_sens:   float  = 0.20  # Độ nhạy chuột
@export var zoom_min:     float  = 2.0
@export var zoom_max:     float  = 12.0
@export var zoom_step:    float  = 0.5

@onready var _camera: Camera3D = $Camera3D

var _target:      Node3D
var _yaw:         float = 0.0    # Xoay ngang (độ)
var _pitch:       float = -20.0  # Xoay dọc (độ)
var _cur_dist:    float           # Khoảng cách thực tế (smooth zoom)
var _is_active:   bool = false
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_target   = get_node_or_null(target_path)
	_cur_dist = distance
	_rng.randomize()
	_update_camera_position()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov        = 70.0
	_camera.near       = 0.1
	_camera.far        = 500.0

func activate() -> void:
	_is_active = true
	_camera.current = true
	# Kế thừa hướng xoay hiện tại của player để không giật khi chuyển
	if is_instance_valid(_target):
		_yaw = rad_to_deg(_target.rotation.y) + 180.0

func deactivate() -> void:
	_is_active = false
	_camera.current = false

func set_target(node: Node3D) -> void:
	_target = node
	if _is_active:
		_yaw = rad_to_deg(_target.rotation.y) + 180.0

func add_shake(intensity: float, duration: float) -> void:
	if not _is_active:
		return
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(_shake_duration, duration)
	_shake_timer = max(_shake_timer, duration)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	# Xoay camera bằng chuột phải giữ
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_yaw   -= mm.relative.x * mouse_sens
			_pitch -= mm.relative.y * mouse_sens
			_pitch  = clamp(_pitch, pitch_min, pitch_max)
	# Zoom bằng cuộn chuột
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = clamp(distance - zoom_step, zoom_min, zoom_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = clamp(distance + zoom_step, zoom_min, zoom_max)

func _process(delta: float) -> void:
	if not _is_active or not is_instance_valid(_target):
		return
	_update_shake(delta)
	# Smooth zoom
	_cur_dist = lerp(_cur_dist, distance, delta * 8.0)
	# Lerp rig về player
	var dest := _target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(dest, follow_speed * delta)
	_update_camera_position()

func _update_camera_position() -> void:
	# Tính offset dựa vào yaw + pitch
	var yaw_rad   := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)
	var offset := Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	) * _cur_dist
	_camera.position = offset + _shake_offset
	_camera.look_at(global_position + _shake_offset * 0.08, Vector3.UP)

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

## Trả về hướng forward của camera (dùng cho player.gd điều hướng WASD)
func get_camera_basis() -> Basis:
	return _camera.global_transform.basis
