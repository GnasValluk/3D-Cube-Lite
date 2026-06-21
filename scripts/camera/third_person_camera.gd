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

func _ready() -> void:
	_target   = get_node_or_null(target_path)
	_cur_dist = distance
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
	_camera.position = offset
	_camera.look_at(global_position, Vector3.UP)

## Trả về hướng forward của camera (dùng cho player.gd điều hướng WASD)
func get_camera_basis() -> Basis:
	return _camera.global_transform.basis
