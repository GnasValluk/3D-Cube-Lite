## iso_camera.gd
## Camera Isometric Top-Down theo sau nhân vật.
##
## Cây Node yêu cầu:
## Node3D  "CameraRig"   ← script này (chỉ dịch chuyển XZ theo player)
## └── Camera3D          ← offset cứng lên trên & ra sau theo góc isometric

extends Node3D

@export var target_path: NodePath = NodePath("../Player")
@export var follow_speed: float   = 8.0   # Lerp tốc độ bám player
@export var cam_height:   float   = 22.0  # Chiều cao camera so với player
@export var cam_back:     float   = 18.0  # Khoảng lùi ra sau theo trục Z
@export var ortho_size:   float   = 18.0  # Kích thước vùng nhìn Orthographic (tăng = thấy nhiều hơn)

@onready var _camera: Camera3D = $Camera3D

var _target: Node3D
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_target = get_node_or_null(target_path)
	_rng.randomize()

	# Đặt offset camera cố định theo góc isometric (pitch -35.26°, yaw 45°)
	# Góc isometric chuẩn: nhìn từ hướng (+X+Z) xuống dưới
	_camera.position = Vector3(cam_back, cam_height, cam_back)
	# Camera nhìn về gốc tọa độ local của rig (= vị trí player)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	# Orthographic để không có điểm tụ – giữ các cạnh song song
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size       = ortho_size
	_camera.near       = 0.5
	_camera.far        = 300.0

func activate() -> void:
	_camera.current = true

func deactivate() -> void:
	_camera.current = false

func set_target(node: Node3D) -> void:
	_target = node

func add_shake(intensity: float, duration: float) -> void:
	if not _camera.current:
		return
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(_shake_duration, duration)
	_shake_timer = max(_shake_timer, duration)

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	_update_shake(delta)
	# Lerp vị trí rig về player (chỉ XZ, giữ Y = 0 để camera không lắc dọc)
	var dest := Vector3(_target.global_position.x, 0.0, _target.global_position.z)
	global_position = global_position.lerp(dest, follow_speed * delta)
	_camera.position = Vector3(cam_back, cam_height, cam_back) + _shake_offset * 6.0

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
		_rng.randf_range(-0.3, 0.3) * amp,
		_rng.randf_range(-1.0, 1.0) * amp
	)
	if _shake_timer <= 0.0:
		_shake_duration = 0.0
		_shake_intensity = 0.0
