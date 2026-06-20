## player.gd
## Nhân vật chính – CharacterBody3D
##
## Cây Node:
## CharacterBody3D  "Player"   ← script này
## ├── CollisionShape3D
## ├── Body      (MeshInstance3D)
## ├── Head      (MeshInstance3D)
## ├── EarLeft   (MeshInstance3D)
## ├── EarRight  (MeshInstance3D)
## ├── LegFL / LegFR / LegBL / LegBR  (MeshInstance3D)

extends CharacterBody3D

# ── Di chuyển ─────────────────────────────────────────────────────────────────
@export var move_speed:    float = 7.0
@export var jump_velocity: float = 7.0

# ── Procedural animation ──────────────────────────────────────────────────────
@export var bob_speed:          float = 9.0
@export var bob_height:         float = 0.07
@export var idle_breathe_speed: float = 1.4
@export var idle_breathe_scale: float = 0.035
@export var ear_swing_amount:   float = 0.20
@export var leg_swing_amount:   float = 0.28

# ── Node con ──────────────────────────────────────────────────────────────────
@onready var _body:   MeshInstance3D = $Body
@onready var _head:   MeshInstance3D = $Head
@onready var _ear_l:  MeshInstance3D = $EarLeft
@onready var _ear_r:  MeshInstance3D = $EarRight
@onready var _leg_fl: MeshInstance3D = $LegFL
@onready var _leg_fr: MeshInstance3D = $LegFR
@onready var _leg_bl: MeshInstance3D = $LegBL
@onready var _leg_br: MeshInstance3D = $LegBR

# ── Hằng & biến nội bộ ────────────────────────────────────────────────────────
## Góc isometric 45° – dùng để xoay input WASD khớp với hướng camera
const ISO_RAD: float = PI / 4.0   # 45 degrees

var _gravity: float  = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _time:    float  = 0.0
var _body_base_pos:   Vector3
var _body_base_scale: Vector3

## Tham chiếu camera để lấy hướng đúng khi di chuyển
var _camera: Camera3D


func _ready() -> void:
	_body_base_pos   = _body.position
	_body_base_scale = _body.scale
	# Lấy camera sau 1 frame để scene đã load xong
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()


func _physics_process(delta: float) -> void:
	_time += delta

	# 1. Trọng lực
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# 2. Nhảy (Space hoặc ui_accept)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# 3. Di chuyển – đọc WASD + Arrow keys rồi xoay 45° cho isometric
	var move_dir := _read_input_isometric()
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		# Xoay nhân vật về hướng đi
		rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z), delta * 12.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

	# 4. Procedural animation
	_animate(delta)


## Đọc input rồi project theo hướng camera xuống mặt phẳng XZ.
## Cách này đúng với mọi góc camera, không cần hardcode góc.
func _read_input_isometric() -> Vector3:
	var raw_x: float = 0.0
	var raw_z: float = 0.0

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		raw_z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		raw_z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		raw_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		raw_x += 1.0

	if raw_x == 0.0 and raw_z == 0.0:
		return Vector3.ZERO

	if _camera == null:
		return Vector3.ZERO

	# Lấy forward và right của camera, flatten xuống XZ (bỏ Y)
	var cam_basis := _camera.global_transform.basis
	var forward := -cam_basis.z        # Camera nhìn theo -Z local
	var right   :=  cam_basis.x

	forward.y = 0.0
	right.y   = 0.0
	forward   = forward.normalized()
	right     = right.normalized()

	# W/S đi theo forward camera, A/D đi theo right camera
	return (forward * -raw_z + right * raw_x)


## Hoạt ảnh procedural bằng sin/cos – không dùng Skeleton3D
func _animate(delta: float) -> void:
	var moving: bool = Vector2(velocity.x, velocity.z).length_squared() > 0.1

	if moving:
		# ── Walk: thân nhấp nhô, tai & chân lắc ──────────────────────────────
		var bob: float      = abs(sin(_time * bob_speed)) * bob_height
		var ear_p: float    = cos(_time * bob_speed)
		var leg_p: float    = sin(_time * bob_speed)

		_body.position.y    = _body_base_pos.y + bob
		_body.scale.y       = _body_base_scale.y + sin(_time * bob_speed) * 0.025

		_ear_l.rotation.x   =  ear_p * ear_swing_amount
		_ear_r.rotation.x   =  ear_p * ear_swing_amount

		_leg_fl.rotation.x  =  leg_p * leg_swing_amount
		_leg_br.rotation.x  =  leg_p * leg_swing_amount
		_leg_fr.rotation.x  = -leg_p * leg_swing_amount
		_leg_bl.rotation.x  = -leg_p * leg_swing_amount
	else:
		# ── Idle: thở nhẹ ─────────────────────────────────────────────────────
		var breathe: float  = sin(_time * idle_breathe_speed)

		_body.scale.y       = _body_base_scale.y + breathe * idle_breathe_scale
		_body.position.y    = _body_base_pos.y   + breathe * idle_breathe_scale * 0.5

		_ear_l.rotation.x   = breathe * ear_swing_amount * 0.25
		_ear_r.rotation.x   = breathe * ear_swing_amount * 0.25

		_leg_fl.rotation.x  = lerp(_leg_fl.rotation.x, 0.0, delta * 6.0)
		_leg_fr.rotation.x  = lerp(_leg_fr.rotation.x, 0.0, delta * 6.0)
		_leg_bl.rotation.x  = lerp(_leg_bl.rotation.x, 0.0, delta * 6.0)
		_leg_br.rotation.x  = lerp(_leg_br.rotation.x, 0.0, delta * 6.0)
