## fish/fish_character.gd
## Sinh vật cá nước ngọt — passive, chỉ bơi trong nước, không tấn công.
## Có nhiều biến thể màu và kích thước để đại diện cho các loài cá khác nhau.

extends CharacterBase
class_name FishCharacter

# Biến thể cá — quyết định màu sắc và kích thước
enum FishVariant {
	CHEP,       # Cá chép — xanh ô liu đậm, lớn
	RO,         # Cá rô — xanh lá đậm, vừa
	TRAM,       # Cá trắm — xám xanh, lớn
	MONG,       # Cá mòng — bạc ánh xanh, nhỏ
	VANG,       # Cá vàng — cam vàng, nhỏ đến vừa
	LINH,       # Cá linh — trắng bạc, nhỏ
}

@export var fish_variant: int = FishVariant.CHEP
@export var fish_scale: float = 1.0

# Màu theo biến thể [body, belly, fin]
const VARIANT_COLORS: Array = [
	# CHEP
	[Color(0.28, 0.42, 0.22), Color(0.78, 0.80, 0.65), Color(0.22, 0.35, 0.18)],
	# RO
	[Color(0.18, 0.38, 0.20), Color(0.72, 0.78, 0.60), Color(0.15, 0.30, 0.16)],
	# TRAM
	[Color(0.32, 0.40, 0.35), Color(0.75, 0.80, 0.72), Color(0.25, 0.35, 0.28)],
	# MONG
	[Color(0.55, 0.65, 0.70), Color(0.85, 0.90, 0.88), Color(0.45, 0.55, 0.62)],
	# VANG
	[Color(0.88, 0.55, 0.12), Color(0.95, 0.88, 0.55), Color(0.75, 0.40, 0.08)],
	# LINH
	[Color(0.70, 0.72, 0.75), Color(0.90, 0.92, 0.90), Color(0.60, 0.62, 0.65)],
]

const VARIANT_NAMES: Array[String] = ["Cá Chép", "Cá Rô", "Cá Trắm", "Cá Mòng", "Cá Vàng", "Cá Linh"]
const VARIANT_HP: Array[int]       = [60,         40,       80,         25,         20,         15]
const VARIANT_SPEED: Array[float]  = [3.5,        4.5,      3.0,        5.5,        4.0,        5.0]
const VARIANT_SCALE: Array[float]  = [1.0,        0.75,     1.2,        0.55,       0.50,       0.45]

var _fish_mesh: FishMesh
var _fish_anim: FishAnimator

# AI riêng cho cá: bơi quanh điểm spawn, bỏ chạy khi bị tấn công
var _home: Vector3 = Vector3.ZERO
var _swim_dir: Vector3 = Vector3.ZERO
var _swim_timer: float = 0.0
var _flee_timer: float = 0.0
const HOME_RADIUS: float = 8.0
const FLEE_SPEED_MULT: float = 2.2

func _build_character() -> void:
	_is_player = false
	character_name = VARIANT_NAMES[fish_variant]

	max_hp       = VARIANT_HP[fish_variant]
	hp           = max_hp
	move_speed   = VARIANT_SPEED[fish_variant]
	sprint_speed = move_speed * FLEE_SPEED_MULT
	defense      = 0
	attack_power = 0
	melee_damage = 0
	jump_height  = 0.3

	# Scale theo loài
	var sc: float = VARIANT_SCALE[fish_variant] * fish_scale
	scale = Vector3(sc, sc, sc)

	# Collision nhỏ gọn
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.18
	cs.height = 0.40
	col.shape = cs
	col.position = Vector3(0, 0.2, 0)
	add_child(col)

	# Mesh
	var colors: Array = VARIANT_COLORS[fish_variant]
	_fish_mesh = FishMesh.new()
	_fish_mesh.color_body  = colors[0] as Color
	_fish_mesh.color_belly = colors[1] as Color
	_fish_mesh.color_fin   = colors[2] as Color
	_fish_mesh.color_tail  = (colors[0] as Color) * 0.8
	_fish_mesh.build(self)
	_rig = _fish_mesh.rig

	# Animator
	_fish_anim = FishAnimator.new()
	_fish_anim.setup(_fish_mesh, self)

func _ready() -> void:
	super._ready()
	_home = global_position
	_pick_swim_dir()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_swim_timer -= delta
	if _flee_timer > 0.0:
		_flee_timer -= delta

	if _swim_timer <= 0.0:
		_pick_swim_dir()

	# Di chuyển ngang như bơi
	var spd: float = sprint_speed if _flee_timer > 0.0 else move_speed
	var target_vel := _swim_dir * spd

	# Giữ ở chiều cao nước — WATER_Y - 0.3
	var water_y: float = 0.5 * 0.5 - 0.3   # WATER_Y = VOXEL*0.5 = 0.5, bơi dưới mặt nước
	var target_y: float = water_y + sin(_swim_timer * 1.2) * 0.08
	var vy: float = (target_y - global_position.y) * 4.0

	velocity = Vector3(target_vel.x, vy, target_vel.z)
	move_and_slide()

	# Quay mặt theo hướng bơi
	if _swim_dir.length_squared() > 0.01:
		var look_target := global_position + Vector3(_swim_dir.x, 0, _swim_dir.z)
		var cur := global_transform.basis.z
		var desired_angle := atan2(_swim_dir.x, _swim_dir.z)
		var cur_angle := atan2(cur.x, cur.z)
		var new_angle := lerp_angle(cur_angle, desired_angle, delta * 6.0)
		rotation.y = new_angle

	# Animation
	if _fish_anim:
		_fish_anim.animate(delta)

func _pick_swim_dir() -> void:
	_swim_timer = randf_range(1.5, 4.0)
	var dist := global_position.distance_to(_home)
	if dist > HOME_RADIUS:
		# Quay về nhà
		var back := (_home - global_position)
		back.y = 0.0
		_swim_dir = back.normalized()
	else:
		# Bơi ngẫu nhiên
		var a := randf_range(0.0, TAU)
		_swim_dir = Vector3(cos(a), 0, sin(a))

func take_damage(dmg: int, attacker: Node3D = null) -> void:
	super.take_damage(dmg, attacker)
	if is_alive:
		# Bỏ chạy khi bị tấn công
		_flee_timer = 3.0
		if attacker:
			var away := global_position - attacker.global_position
			away.y = 0.0
			if away.length_squared() > 0.01:
				_swim_dir = away.normalized()
		_swim_timer = 0.5
