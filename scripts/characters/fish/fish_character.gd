## fish/fish_character.gd
## Sinh vật cá nước ngọt — passive, chỉ bơi trong nước, không tấn công.
## Có nhiều biến thể màu và kích thước để đại diện cho các loài cá khác nhau.

extends CharacterBase
class_name FishCharacter

# Biến thể cá — quyết định màu sắc và kích thước
enum FishVariant {
	CARP,       # Cá chép cảnh (Koi) — cam vàng nổi bật, vảy khoang
	PERCH,      # Cá rô (Climbing Perch) — xám đen, vừa
	TILAPIA,    # Cá điêu hồng (Red Tilapia) — hồng đỏ, vừa
	SNAKEHEAD,  # Cá lóc (Snakehead) — nâu đen, dài
	FLOWERHORN, # Cá la hán (Flowerhorn) — đỏ rực, săn mồi
	SHRIMP,     # Tôm nước ngọt — nâu xám, đáy
}

@export var fish_variant: int = FishVariant.CARP
@export var fish_scale: float = 1.0

func _init() -> void:
	show_world_hp_bar = false   # Cá là sinh vật passive — không hiện HP bar

# Màu theo biến thể [body, belly, fin]
const VARIANT_COLORS: Array = [
	# CARP (Koi — cam vàng nổi bật + vảy đen)
	[Color(0.95, 0.70, 0.10), Color(0.98, 0.95, 0.80), Color(0.85, 0.55, 0.05)],
	# PERCH (Climbing Perch — xám đen)
	[Color(0.30, 0.30, 0.30), Color(0.65, 0.65, 0.65), Color(0.20, 0.20, 0.20)],
	# TILAPIA (Red Tilapia — hồng đỏ)
	[Color(0.88, 0.55, 0.45), Color(0.95, 0.80, 0.70), Color(0.85, 0.40, 0.30)],
	# SNAKEHEAD (Cá lóc — nâu đen, thân dài)
	[Color(0.30, 0.25, 0.15), Color(0.65, 0.60, 0.50), Color(0.20, 0.18, 0.10)],
	# FLOWERHORN (Cá la hán — đỏ rực, chấm đen)
	[Color(0.92, 0.25, 0.15), Color(0.90, 0.55, 0.45), Color(0.75, 0.15, 0.10)],
	# SHRIMP (Tôm nước ngọt — cam đỏ)
	[Color(0.85, 0.35, 0.20), Color(0.92, 0.55, 0.35), Color(0.75, 0.25, 0.15)],
]

# Màu pattern dọc thân [alpha=0 → không pattern]
const VARIANT_PATTERN: Array[Color] = [
	Color(0.15, 0.10, 0.05),  # CARP: vảy đen
	Color(0, 0, 0, 0),        # PERCH: không pattern
	Color(0, 0, 0, 0),        # TILAPIA: không pattern
	Color(0, 0, 0, 0),        # SNAKEHEAD: không pattern
	Color(0.15, 0.10, 0.08),  # FLOWERHORN: chấm đen
	Color(0, 0, 0, 0),        # SHRIMP: không pattern
]

# Tỉ lệ dài thân (body_z_scale)
const VARIANT_BODY_Z: Array[float] = [1.0, 1.0, 1.0, 1.8, 1.0, 1.0]

const VARIANT_NAMES: Array[String] = ["Carp", "Climbing Perch", "Red Tilapia", "Snakehead", "Flowerhorn", "Freshwater Shrimp"]
const VARIANT_HP: Array[int]       = [60,         40,               50,             70,           70,           15]
const VARIANT_SPEED: Array[float]  = [1.4,        2.0,              1.8,            1.5,          1.2,          0.8]
const VARIANT_SCALE: Array[float]  = [1.2,        0.75,             0.70,           1.0,          1.3,          0.7]

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

# Hunting (Flowerhorn)
var _hunt_target: Node = null
var _orbit_angle: float = 0.0
var _hunt_cooldown: float = 0.0
var _hunt_scan_timer: float = 0.0

# Cache
var _bob_rate: float = 1.0
var _boids_result: Vector3 = Vector3.FORWARD
var _alert_check_cooldown: float = 0.0

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

# Hunting (Flowerhorn)
const HUNT_RADIUS: float = 14.0
const HUNT_ATTACK_DIST: float = 0.4
const ORBIT_RADIUS: float = 6.0
const ORBIT_SPEED: float = 0.6
const HUNT_CHASE_SPEED_MULT: float = 1.5
const BURST_DIST: float = 1.5
const PREY_ALONE_RADIUS: float = 5.0

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
	defense      = 5 if _is_predator() else 0
	attack_power = 25 if _is_predator() else 0
	melee_damage = attack_power
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
	_fish_mesh.color_pattern = VARIANT_PATTERN[fish_variant]
	_fish_mesh.body_z_scale  = VARIANT_BODY_Z[fish_variant]
	if fish_variant == FishVariant.FLOWERHORN:
		_fish_mesh.body_triangular = true
		_fish_mesh.has_horns = true
	elif fish_variant == FishVariant.SHRIMP:
		_fish_mesh.body_shape = FishMesh.BodyShape.SHRIMP
	_fish_mesh.build(self)
	_rig = _fish_mesh.rig

	_fish_anim = FishAnimator.new()
	_fish_anim.setup(_fish_mesh, self)

func _ready() -> void:
	super._ready()
	_home = global_position
	_bob_phase = randf_range(0.0, TAU)
	_bob_rate = randf_range(0.6, 1.4)
	add_to_group("fish")
	var a := randf_range(0.0, TAU)
	_swim_dir = Vector3(cos(a), 0, sin(a))
	_target_dir = _swim_dir

func _physics_process(delta: float) -> void:
	if not is_alive:
		if _state == State.DEAD:
			_death_timer -= delta
			velocity.x *= 0.85
			velocity.z *= 0.85
			velocity.y -= 1.5 * delta
			if _fish_anim:
				_fish_anim.animate(delta)
			rotation.x = lerp(rotation.x, PI, delta * 1.2)
			move_and_slide()
			if _death_timer <= 0.0:
				queue_free()
		return

	_bob_phase += delta * _bob_rate
	_scan_timer -= delta
	_wall_cooldown -= delta
	_wall_memory_timer = max(0.0, _wall_memory_timer - delta)
	_alert_check_cooldown -= delta
	if _flee_timer > 0.0:
		_flee_timer -= delta
	if _alert_timer > 0.0:
		_alert_timer -= delta

	if _is_solitary():
		# Hunting AI cho predator, wander cho solitary thường
		_target_dir = _hunt_behavior(delta) if _is_predator() else _wander_dir()
		if not _is_predator() and _wall_cooldown <= 0.0:
			_avoid_walls()
	else:
		# Scan neighbors periodically + recompute boids only on new scan
		if _scan_timer <= 0.0:
			_scan_neighbors()
			_boids_result = _compute_boids()
		var boids_dir := _boids_result

		# Alert propagation — tối đa 2 lần/giây
		if _alert_check_cooldown <= 0.0:
			_check_alert()
			_alert_check_cooldown = 0.5

		# Determine target direction
		if _flee_timer > 0.0:
			pass  # _target_dir already set by take_damage
		elif _alert_timer > 0.0:
			_alert_flee()
		else:
			_target_dir = boids_dir

	# Wall avoidance raycast — solitary tự xử lý bên trong
	if not _is_solitary() and _wall_cooldown <= 0.0:
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

	var spd: float
	if _is_predator() and _hunt_target != null and is_instance_valid(_hunt_target):
		var to_prey := (_hunt_target as Node3D).global_position - global_position
		to_prey.y = 0.0
		if to_prey.length() < BURST_DIST:
			spd = move_speed * HUNT_CHASE_SPEED_MULT
		else:
			spd = move_speed
	elif _flee_timer > 0.0:
		spd = sprint_speed
	else:
		spd = move_speed

	var water_y: float
	if fish_variant == FishVariant.SNAKEHEAD:
		# Cá lóc: tầng đáy, thỉnh thoảng nổi lên mặt nước rồi lặn xuống
		var dive_k := sin(_bob_phase * 0.12)
		if dive_k > 0.70:
			water_y = 0.38  # nổi gần mặt
		else:
			water_y = 0.05  # đáy hồ
	elif fish_variant == FishVariant.FLOWERHORN:
		water_y = 0.15  # tầng giữa
	elif fish_variant == FishVariant.SHRIMP:
		water_y = 0.06  # đáy hồ
	else:
		water_y = 0.2
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

func _is_solitary() -> bool:
	return fish_variant == FishVariant.SNAKEHEAD or fish_variant == FishVariant.FLOWERHORN

func _is_predator() -> bool:
	return fish_variant == FishVariant.FLOWERHORN

func _wander_dir() -> Vector3:
	# Đổi hướng liên tục theo thời gian — bơi vòng quanh hồ
	var a := sin(_bob_phase * 0.3) * 2.0 + sin(_bob_phase * 0.7) * 1.5
	var result := Vector3(cos(a), 0, sin(a))
	# Biên mềm — nếu xa home quá thì quay về
	var to_home := _home - global_position
	to_home.y = 0.0
	if to_home.length_squared() > 225.0:
		result = result.lerp(to_home.normalized(), 0.3)
	# Tránh tường đã va gần đây
	if _wall_memory_timer > 0.0:
		result += _wall_memory * 3.0
	return result.normalized()

func _scan_neighbors() -> void:
	_scan_timer = randf_range(0.3, 0.8)
	_neighbors = get_tree().get_nodes_in_group("fish")
	# Filter out self, far ones, and predators
	_neighbors = _neighbors.filter(func(n):
		return n != self and is_instance_valid(n) and n is FishCharacter \
			and not (n as FishCharacter)._is_predator() \
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
		result = _wander_dir()

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
	var to_home_vec := _home - global_position
	if to_home_vec.length_squared() > HOME_RADIUS * HOME_RADIUS:
		var back := to_home_vec
		back.y = 0.0
		if back.length_squared() > 0.01 and _flee_timer <= 0.0 and _alert_timer <= 0.0:
			_target_dir = _target_dir.lerp(back.normalized(), 0.3).normalized()

func _is_prey(variant: int) -> bool:
	return variant == FishVariant.TILAPIA or variant == FishVariant.PERCH

func _scan_prey() -> void:
	var all_fish := get_tree().get_nodes_in_group("fish")
	var nearest_dist_sq := HUNT_RADIUS * HUNT_RADIUS
	_hunt_target = null
	for f in all_fish:
		if f == self or not is_instance_valid(f):
			continue
		var other := f as FishCharacter
		if not _is_prey(other.fish_variant):
			continue
		var d_sq := global_position.distance_squared_to(other.global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			_hunt_target = other

func _is_prey_alone(prey: FishCharacter) -> bool:
	var prey_pos := prey.global_position
	var radius_sq := PREY_ALONE_RADIUS * PREY_ALONE_RADIUS
	for f in get_tree().get_nodes_in_group("fish"):
		if f == self or f == prey or not is_instance_valid(f):
			continue
		var other := f as FishCharacter
		if not _is_prey(other.fish_variant):
			continue
		if prey_pos.distance_squared_to(other.global_position) < radius_sq:
			return false
	return true

func _hunt_behavior(delta: float) -> Vector3:
	_hunt_scan_timer -= delta
	if _hunt_scan_timer <= 0.0:
		_hunt_scan_timer = randf_range(0.5, 1.5)
		_scan_prey()
	_hunt_cooldown -= delta

	if _hunt_target != null and is_instance_valid(_hunt_target):
		var prey := _hunt_target as FishCharacter
		if not prey.is_alive:
			_hunt_target = null
			return _wander_dir()

		var to_prey := prey.global_position - global_position
		to_prey.y = 0.0
		var dist := to_prey.length()

		if dist < HUNT_ATTACK_DIST:
			if _hunt_cooldown <= 0.0:
				_hunt_cooldown = 1.0
				prey.take_damage(attack_power, self)
			return to_prey.normalized()
		elif _is_prey_alone(prey):
			# Rượt đuổi khi con mồi đi lẻ
			return to_prey.normalized()
		else:
			# Quay vòng quanh đàn, chờ cơ hội
			_orbit_angle += delta * ORBIT_SPEED
			var orbit_offset := Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * ORBIT_RADIUS
			var target_pos := prey.global_position + orbit_offset
			var orbit_dir := (target_pos - global_position).normalized()
			return orbit_dir
	else:
		return _wander_dir()

func take_damage(dmg: int, attacker: Node3D = null) -> void:
	super.take_damage(dmg, attacker)
	if is_alive:
		if _is_predator():
			_hunt_target = null
		_flee_timer = randf_range(2.5, 4.5)
		_alert_timer = _flee_timer
		if attacker:
			var away := global_position - attacker.global_position
			away.y = 0.0
			if away.length_squared() > 0.01:
				_target_dir = away.normalized()
				_swim_dir = _target_dir
				_turn_rate = 12.0

# ── Loot ──────────────────────────────────────────────────────────────────────

# Mỗi biến thể: [ { item_id, rate_0_1 }, ... ]
const LOOT_TABLE: Dictionary = {
	FishVariant.CARP:       [ { id = "ca_chep",       rate = 0.50 } ],
	FishVariant.PERCH:      [ { id = "ca_ro",         rate = 0.50 } ],
	FishVariant.TILAPIA:    [ { id = "ca_dieu_hong",  rate = 0.50 } ],
	FishVariant.SNAKEHEAD:  [ { id = "ca_loc",        rate = 0.60 } ],
	FishVariant.FLOWERHORN: [ { id = "ca_la_han",     rate = 0.70 } ],
	FishVariant.SHRIMP:     [ { id = "tom",           rate = 0.40 } ],
}

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")

func _die(_attacker: Node3D = null) -> void:
	super._die(_attacker)
	_roll_loot()

func _roll_loot() -> void:
	var table: Array = LOOT_TABLE.get(fish_variant, [])
	var world := get_tree().current_scene
	if world == null:
		return
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db
	for entry in table:
		if randf() < entry.rate:
			var defn: ItemDef = db.get(entry.id)
			if defn:
				var vel := Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
				_DroppedItem.spawn(world, defn, global_position, 1, vel, global_position.y)
