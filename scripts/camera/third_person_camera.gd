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
@export var mouse_sens:   float  = 0.20  # Độ nhạy chuột (được nhân với SettingsManager.mouse_sensitivity_h/v)
@export var zoom_min:     float  = 2.0
@export var zoom_max: float = 22.0
@export var zoom_step:    float  = 0.5
@export var aim_zoom:     float  = 1.8  # Khoảng cách khi đang ngắm (góc 3)
@export var aim_offset_right: float = 1.35  # Nhích camera sang PHẢI khi ngắm
# → player nằm BÊN TRÁI màn hình, chừa tâm cho crosshair
@export var aim_offset_up: float = 0.10    # hạ nhẹ camera để vai không che tâm

@onready var _camera: Camera3D = $Camera3D

var _target:      Node3D
var _yaw:         float = 0.0    # Xoay ngang (độ)
var _pitch:       float = -20.0  # Xoay dọc (độ)
var _cur_dist:    float           # Khoảng cách thực tế (smooth zoom)
var _col_dist:    float = 0.0    # Khoảng cách tối đa sau khi va chạm (smooth)
var _is_active: bool = false
var _aiming:      bool = false   # Đang ngắm → zoom gần vào player
var _aim_blend:   float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_target   = get_node_or_null(target_path)
	_cur_dist = distance
	_col_dist = distance
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

## Bật/tắt chế độ ngắm (zoom gần player) — gọi từ vũ khí đang aim.
func set_aim(active: bool) -> void:
	_aiming = active

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	# Khi con trỏ hiển thị (Alt hoặc UI mở) không dùng chuyển động chuột để xoay cam.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		return
	# Xoay camera bằng chuột phải giữ
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# Cam 3: không cần giữ chuột phải — di chuột là xoay camera luôn.
		var s_h: float = SettingsManager.mouse_sensitivity_h if SettingsManager else 1.0
		var s_v: float = SettingsManager.mouse_sensitivity_v if SettingsManager else 0.7
		_yaw   -= mm.relative.x * mouse_sens * s_h
		_pitch += mm.relative.y * mouse_sens * s_v
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
	# Smooth zoom: khi đang ngắm thì kéo gần player, nhả ra thì về khoảng cách chuột.
	_aim_blend += delta * 8.0 if _aiming else -delta * 8.0
	_aim_blend = clamp(_aim_blend, 0.0, 1.0)
	var target_dist: float = lerp(distance, min(aim_zoom, distance), _aim_blend)
	_cur_dist = lerp(_cur_dist, target_dist, delta * 8.0)
	# Lerp rig về player
	var dest := _target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(dest, follow_speed * delta)
	# Va chạm: kéo camera gần lại nếu đường nhìn bị block che — smooth để ko giật.
	var limit := _collision_limit()
	_col_dist = lerp(_col_dist, limit, delta * 10.0)
	_update_camera_position()

func _camera_dir() -> Vector3:
	var yaw_rad   := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)
	return Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	)

## Khoảng cách camera tối đa còn trong thế giới (không bị ẩn vào tường/đất).
func _collision_limit() -> float:
	if _cur_dist <= 0.35:
		return _cur_dist
	var from: Vector3 = global_position
	var dir: Vector3 = _camera_dir()
	var space := get_world_3d().direct_space_state
	if space == null:
		return _cur_dist
	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = from + dir * (_cur_dist + 0.3)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if is_instance_valid(_target):
		q.exclude = [_target]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return _cur_dist
	var d: float = from.distance_to(hit.position) - 0.18
	return max(d, 0.3)

func _update_camera_position() -> void:
	# Smooth distance: dùng khoảng cách va chạm nếu nhỏ hơn người dùng chọn.
	var cam_dist: float = _cur_dist
	if _col_dist > 0.0 and _col_dist < cam_dist:
		cam_dist = _col_dist
	var offset := _camera_dir() * cam_dist
	# Khi đang ngắm: nhích camera sang phải màn hình để người chơi không
	# chắn giữa tầm nhìn — reset về 0 khi nhả ngắm (blend về 0).
	var fwd := -_camera_dir()
	var screen_right := fwd.cross(Vector3.UP).normalized()
	# Vai bắn: camera dịch PHẢI + NHÌN vào điểm lệch phải trước ngực
	# → player bị đẩy sang TRÁI khung hình, chừa tâm cho crosshair
	offset += screen_right * (aim_offset_right * _aim_blend)
	_camera.position = offset + _shake_offset
	var aim_target := global_position \
		+ screen_right * (aim_offset_right * 2.0 * _aim_blend) \
		+ Vector3.UP * (0.10 * _aim_blend) \
		+ _shake_offset * 0.08
	_camera.look_at(aim_target, Vector3.UP)

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
