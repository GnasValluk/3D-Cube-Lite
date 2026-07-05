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

func _init() -> void:
	show_world_hp_bar = false   # Cá là sinh vật passive — không hiện HP bar

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
const VARIANT_SPEED: Array[float]  = [1.6,        2.0,      1.4,        2.5,        1.8,        2.2]
const VARIANT_SCALE: Array[float]  = [1.0,        0.75,     1.2,        0.55,       0.50,       0.45]

var _fish_mesh: FishMesh
var _fish_anim: FishAnimator

# Personality (randomized per fish)
var _boldness: float = 1.0
var _sociability: float = 1.0
var _speed_mod: float = 1.0

# AI state
var _home: Vector3 = Vector3.ZERO
var _swim_dir: Vector3 = Vector3.FORWARD
var _target_dir: Vector3 = Vector3.FORWARD
var _turn_rate: float = 4.0
var _flee_timer: float = 0.0
var _alert_timer: float = 0.0
var _bob_phase: float = 0.0
var _wall_cooldown: float = 0.0
var _wall_memory: Vector3 = Vector3.ZERO
var _wall_memory_timer: float = 0.0

# Boids
var _neighbors: Array[Node] = []
var _scan_timer: float = 0.0

const HOME_RADIUS: float = 20.0
const FLEE_SPEED_MULT: float = 2.2

# Boids params
const SEP_RADIUS: float = 1.5
const ALIGN_RADIUS: float = 5.0
const COHESION_RADIUS: float = 7.0
const SEP_FORCE: float = 2.5
const ALIGN_FORCE: float = 1.2
const COHESION_FORCE: float = 0.6
const ALERT_RADIUS: float = 6.0

func _build_character() -> void:
	_is_player = false
	character_name = VARIANT_NAMES[fish_variant]

	# Randomize personality
	_boldness = randf_range(0.3, 1.0)
	_sociability = randf_range(0.2, 1.0)
	_speed_mod = randf_range(0.85, 1.15)

	max_hp       = VARIANT_HP[fish_variant]
	hp           = max_hp
	move_speed   = VARIANT_SPEED[fish_variant] * _speed_mod
	sprint_speed = move_speed * FLEE_SPEED_MULT
	defense      = 0
	attack_power = 0
	melee_damage = 0
	jump_height  = 0.3

	var sc: float = VARIANT_SCALE[fish_variant] * fish_scale
	scale = Vector3(sc, sc, sc)

	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.18
	cs.height = 0.40
	col.shape = cs
	col.position = Vector3(0, 0.2, 0)
	add_child(col)

	var colors: Array = VARIANT_COLORS[fish_variant]
	_fish_mesh = FishMesh.new()
	_fish_mesh.color_body  = colors[0] as Color
	_fish_mesh.color_belly = colors[1] as Color
	_fish_mesh.color_fin   = colors[2] as Color
	_fish_mesh.color_tail  = (colors[0] as Color) * 0.8
	_fish_mesh.build(self)
	_rig = _fish_mesh.rig

	_fish_anim = FishAnimator.new()
	_fish_anim.setup(_fish_mesh, self)

func _ready() -> void:
	super._ready()
	_home = global_position
	_bob_phase = randf_range(0.0, TAU)
	add_to_group("fish")
	var a := randf_range(0.0, TAU)
	_swim_dir = Vector3(cos(a), 0, sin(a))
	_target_dir = _swim_dir

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_bob_phase += delta * randf_range(0.6, 1.4)
	_scan_timer -= delta
	_wall_cooldown -= delta
	_wall_memory_timer = max(0.0, _wall_memory_timer - delta)
	if _flee_timer > 0.0:
		_flee_timer -= delta
	if _alert_timer > 0.0:
		_alert_timer -= delta

	# Scan neighbors periodically
	if _scan_timer <= 0.0:
		_scan_neighbors()

	# Compute boids flocking force
	var boids_dir := _compute_boids()

	# Alert propagation — hoảng loạn lây lan
	if _alert_timer <= 0.0:
		_check_alert()

	# Determine target direction
	if _flee_timer > 0.0:
		pass  # _target_dir already set by take_damage
	elif _alert_timer > 0.0:
		# Hoảng loạn — chạy theo đàn
		_alert_flee()
	else:
		_target_dir = boids_dir

	# Wall avoidance raycast
	if _wall_cooldown <= 0.0:
		_avoid_walls()

	# Smooth steering
	_swim_dir = _swim_dir.slerp(_target_dir, delta * _turn_rate).normalized()

	# Organic perturbation
	var perturb := Vector3(
		sin(_bob_phase * 1.7) * delta * 0.6,
		sin(_bob_phase * 2.3) * delta * 0.3,
		cos(_bob_phase * 1.3) * delta * 0.6
	)
	var move_dir := (_swim_dir + perturb).normalized()

	var spd: float = sprint_speed if _flee_timer > 0.0 else move_speed

	var water_y: float = 0.2
	var y_offset := sin(_bob_phase * 0.9) * 0.15 + cos(_bob_phase * 0.5) * 0.08
	var target_y := water_y + y_offset
	var vy := (target_y - global_position.y) * 3.0

	velocity = Vector3(move_dir.x * spd, vy, move_dir.z * spd)
	move_and_slide()

	# Collision response — slide along walls
	var slide_col: KinematicCollision3D = get_last_slide_collision()
	if slide_col:
		var normal: Vector3 = slide_col.get_normal() * Vector3(1, 0, 1)
		if normal.length_squared() > 0.01:
			normal = normal.normalized()
			if randf() < 0.5:
				_target_dir = Vector3(-normal.z, 0, normal.x)
			else:
				_target_dir = Vector3(normal.z, 0, -normal.x)
			_swim_dir = _target_dir
			_turn_rate = 10.0
			_wall_cooldown = 0.5
			_wall_memory = normal
			_wall_memory_timer = 2.0
		else:
			_target_dir = _swim_dir * Vector3(1, -1, 1)
			_turn_rate = 8.0

	# Smooth face direction
	if _swim_dir.length_squared() > 0.01:
		var cur := global_transform.basis.z
		var desired_angle := atan2(_swim_dir.x, _swim_dir.z)
		var cur_angle := atan2(cur.x, cur.z)
		rotation.y = lerp_angle(cur_angle, desired_angle, delta * 5.0)

	if _fish_anim:
		_fish_anim.animate(delta)

func _scan_neighbors() -> void:
	_scan_timer = randf_range(0.3, 0.8)
	_neighbors = get_tree().get_nodes_in_group("fish")
	# Filter out self and far ones
	_neighbors = _neighbors.filter(func(n):
		return n != self and is_instance_valid(n) and n is FishCharacter \
			and global_position.distance_squared_to(n.global_position) < COHESION_RADIUS * COHESION_RADIUS
	)

func _compute_boids() -> Vector3:
	var sep := Vector3.ZERO
	var align := Vector3.ZERO
	var cohesion := Vector3.ZERO
	var sep_count := 0
	var align_count := 0
	var coh_count := 0

	for n in _neighbors:
		if not is_instance_valid(n):
			continue
		var other := n as FishCharacter
		var to_other := other.global_position - global_position
		var dist_sq := to_other.length_squared()

		# Separation — đẩy xa nếu quá gần
		if dist_sq < SEP_RADIUS * SEP_RADIUS and dist_sq > 0.001:
			var repel := -to_other.normalized() / sqrt(dist_sq)
			sep += repel
			sep_count += 1

		# Alignment — cùng hướng với đàn
		if dist_sq < ALIGN_RADIUS * ALIGN_RADIUS:
			align += other._swim_dir
			align_count += 1

		# Cohesion — bơi về tâm đàn
		if dist_sq < COHESION_RADIUS * COHESION_RADIUS:
			cohesion += to_other
			coh_count += 1

	if sep_count > 0:
		sep = sep.normalized() * SEP_FORCE * (1.0 + _boldness * 0.5)
	if align_count > 0:
		align = align.normalized() * ALIGN_FORCE * _sociability
	if coh_count > 0:
		cohesion = cohesion.normalized() * COHESION_FORCE * _sociability

	# Cá nhút nhát dựa vào đàn nhiều hơn
	var shyness: float = 1.0 - _boldness
	var result := (sep * 0.4 + align * (0.3 + shyness * 0.3) + cohesion * (0.2 + shyness * 0.3))
	if result.length_squared() < 0.001:
		# Không có bạn — bơi tự do với thiên hướng về home
		var to_home := _home - global_position
		to_home.y = 0.0
		if to_home.length_squared() > 0.01:
			result = to_home.normalized() * 0.5
		else:
			result = _swim_dir
		# Thêm nhiễu
		var a := randf_range(0.0, TAU) + sin(_bob_phase) * 0.5
		result += Vector3(cos(a), 0, sin(a)) * 0.5

	return result.normalized()

func _check_alert() -> void:
	for n in _neighbors:
		if not is_instance_valid(n):
			continue
		var other := n as FishCharacter
		if other._alert_timer > 0.0 or other._flee_timer > 0.0:
			var dist := global_position.distance_to(other.global_position)
			if dist < ALERT_RADIUS:
				_alert_timer = randf_range(1.5, 3.5)
				_turn_rate = 10.0
				break

func _alert_flee() -> void:
	# Chạy theo hướng trung bình của đàn + tránh xa vị trí cũ
	var flee_dir := Vector3.ZERO
	var count := 0
	for n in _neighbors:
		if not is_instance_valid(n):
			continue
		var other := n as FishCharacter
		if other._alert_timer > 0.0 or other._flee_timer > 0.0:
			flee_dir += other._swim_dir
			count += 1

	if count > 0:
		_target_dir = flee_dir.normalized()
	else:
		var a := randf_range(0.0, TAU)
		_target_dir = Vector3(cos(a), 0, sin(a))
	_turn_rate = 8.0

func _avoid_walls() -> void:
	_wall_cooldown = randf_range(0.2, 0.5)
	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var dir_3d := _target_dir.normalized()
	if dir_3d.length_squared() < 0.01:
		return
	var origin := global_position + Vector3(0, 0.05, 0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir_3d * 1.2))
	hit = hit if hit else space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir_3d * 0.6))

	if hit:
		var normal: Vector3 = (hit.normal as Vector3) * Vector3(1, 0, 1)
		if normal.length_squared() > 0.1:
			normal = normal.normalized()
			# Chọn ngẫu nhiên trái/phải dọc tường
			if randf() < 0.5:
				_target_dir = Vector3(-normal.z, 0, normal.x)
			else:
				_target_dir = Vector3(normal.z, 0, -normal.x)
			_turn_rate = 12.0
			_target_dir *= _boldness + 0.5  # Cá bạo dạn rẽ mạnh hơn
		else:
			_target_dir = _swim_dir * Vector3(1, -1, 1)
			_turn_rate = 10.0

	# Biên mềm về home — chỉ khi đi quá xa
	if global_position.distance_to(_home) > HOME_RADIUS:
		var back := _home - global_position
		back.y = 0.0
		if back.length_squared() > 0.01 and _flee_timer <= 0.0 and _alert_timer <= 0.0:
			_target_dir = _target_dir.lerp(back.normalized(), 0.3).normalized()

func take_damage(dmg: int, attacker: Node3D = null) -> void:
	super.take_damage(dmg, attacker)
	if is_alive:
		_flee_timer = randf_range(2.5, 4.5)
		_alert_timer = _flee_timer
		if attacker:
			var away := global_position - attacker.global_position
			away.y = 0.0
			if away.length_squared() > 0.01:
				_target_dir = away.normalized()
				_swim_dir = _target_dir
				_turn_rate = 12.0
