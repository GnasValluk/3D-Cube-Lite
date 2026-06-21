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


func _ready() -> void:
	_target = get_node_or_null(target_path)

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

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	# Lerp vị trí rig về player (chỉ XZ, giữ Y = 0 để camera không lắc dọc)
	var dest := Vector3(_target.global_position.x, 0.0, _target.global_position.z)
	global_position = global_position.lerp(dest, follow_speed * delta)
